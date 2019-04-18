require 'core_extensions/string/permit'

class ApplicationController < ActionController::Base # rubocop:disable Metrics/ClassLength
  String.include CoreExtensions::String::Permit
  include UserSessionContext
  include VerifyProfileConcern
  include LocaleHelper

  FLASH_KEYS = %w[alert error notice success warning].freeze

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  rescue_from ActionController::InvalidAuthenticityToken, with: :invalid_auth_token
  rescue_from ActionController::UnknownFormat, with: :render_not_found
  [
    ActiveRecord::ConnectionTimeoutError,
    PG::ConnectionBad, # raised when a Postgres connection times out
    Rack::Timeout::RequestTimeoutException,
    Redis::BaseConnectionError,
  ].each do |error|
    rescue_from error, with: :render_timeout
  end

  helper_method :decorated_session, :reauthn?, :user_fully_authenticated?

  prepend_before_action :add_new_relic_trace_attributes
  prepend_before_action :session_expires_at
  prepend_before_action :set_locale
  before_action :disable_caching

  skip_before_action :handle_two_factor_authentication

  def session_expires_at
    now = Time.zone.now
    session[:session_expires_at] = now + Devise.timeout_in
    session[:pinged_at] ||= now
    redirect_on_timeout
  end

  def append_info_to_payload(payload)
    payload[:user_id] = analytics_user.uuid
    payload[:user_agent] = request.user_agent
    payload[:ip] = request.remote_ip
    payload[:host] = request.host
  end

  attr_writer :analytics

  def analytics
    @analytics ||=
      Analytics.new(user: analytics_user, request: request, sp: current_sp&.issuer, ahoy: ahoy)
  end

  def analytics_user
    warden.user || AnonymousUser.new
  end

  def user_event_creator
    @user_event_creator ||= UserEventCreator.new(request, current_user)
  end
  delegate :create_user_event, :create_user_event_with_disavowal, to: :user_event_creator

  def decorated_session
    @_decorated_session ||= DecoratedSession.new(
      sp: current_sp,
      view_context: view_context,
      sp_session: sp_session,
      service_provider_request: service_provider_request,
    ).call
  end

  def default_url_options
    { locale: locale_url_param, host: Figaro.env.domain_name }
  end

  def sign_out
    request.cookie_jar.delete('ahoy_visit')
    super
  end

  private

  # These attributes show up in New Relic traces for all requests.
  # https://docs.newrelic.com/docs/agents/manage-apm-agents/agent-data/collect-custom-attributes
  def add_new_relic_trace_attributes
    ::NewRelic::Agent.add_custom_attributes(
      amzn_trace_id: request.headers['X-Amzn-Trace-Id'],
    )
  end

  def disable_caching
    response.headers['Cache-Control'] = 'no-store'
    response.headers['Pragma'] = 'no-cache'
  end

  def redirect_on_timeout
    return unless params[:timeout]

    unless current_user
      flash[:notice] = t('notices.session_cleared', minutes: Figaro.env.session_timeout_in_minutes)
    end
    begin
      redirect_to url_for(permitted_timeout_params)
    rescue ActionController::UrlGenerationError # binary data in params cause redirect to throw this
      head :bad_request
    end
  end

  def permitted_timeout_params
    params.permit(:request_id)
  end

  def current_sp
    @current_sp ||= sp_from_sp_session || sp_from_request_id
  end

  def sp_from_sp_session
    sp = ServiceProvider.from_issuer(sp_session[:issuer])
    sp if sp.is_a? ServiceProvider
  end

  def sp_from_request_id
    sp = ServiceProvider.from_issuer(service_provider_request.issuer)
    sp if sp.is_a? ServiceProvider
  end

  def service_provider_request
    @service_provider_request ||= ServiceProviderRequest.from_uuid(params[:request_id])
  end

  def after_sign_in_path_for(_user)
    user_session.delete(:stored_location) || sp_session[:request_url] || signed_in_url
  end

  def signed_in_url
    user_fully_authenticated? ? account_or_verify_profile_url : user_two_factor_authentication_url
  end

  def two_2fa_setup
    if MfaPolicy.new(current_user).multiple_factors_enabled?
      after_multiple_2fa_sign_up
    else
      user_session[:no_mfa_bypass] = true if MfaPolicy.new(current_user).two_factor_enabled?
      two_factor_options_url
    end
  end

  def after_multiple_2fa_sign_up
    if session[:sp]
      sign_up_completed_url
    elsif current_user.decorate.password_reset_profile.present?
      reactivate_account_url
    else
      after_sign_in_path_for(current_user)
    end
  end

  def reauthn_param
    params[:reauthn]
  end

  def invalid_auth_token(_exception)
    controller_info = "#{controller_path}##{action_name}"
    analytics.track_event(
      Analytics::INVALID_AUTHENTICITY_TOKEN,
      controller: controller_info,
      user_signed_in: user_signed_in?,
    )
    flash[:error] = t('errors.invalid_authenticity_token')
    redirect_back fallback_location: new_user_session_url
  end

  def user_fully_authenticated?
    !reauthn? && user_signed_in? &&
      multiple_factors_enabled? && is_fully_authenticated?
  end

  def reauthn?
    reauthn = reauthn_param
    reauthn.present? && reauthn == 'true'
  end

  def confirm_two_factor_authenticated
    authenticate_user!(force: true)

    return if user_fully_authenticated?

    return prompt_to_set_up_2fa unless multiple_factors_enabled?

    prompt_to_enter_otp
  end

  def prompt_to_set_up_2fa
    redirect_to two_factor_options_url
  end

  def prompt_to_enter_otp
    redirect_to user_two_factor_authentication_url
  end

  def multiple_factors_enabled?
    MfaPolicy.new(current_user).multiple_factors_enabled?
  end

  def skip_session_expiration
    @skip_session_expiration = true
  end

  def set_locale
    I18n.locale = LocaleChooser.new(params[:locale], request).locale
  end

  def sp_session
    session.fetch(:sp, {})
  end

  def render_not_found
    render template: 'pages/page_not_found', layout: false, status: :not_found, formats: :html
  end

  def render_timeout(exception)
    analytics.track_event(Analytics::RESPONSE_TIMED_OUT, analytics_exception_info(exception))
    render template: 'pages/page_took_too_long',
           layout: false, status: :service_unavailable, formats: :html
  end

  def render_full_width(template, **opts)
    render template, **opts, layout: 'base'
  end

  def analytics_exception_info(exception)
    {
      backtrace: Rails.backtrace_cleaner.send(:filter, exception.backtrace),
      exception_message: exception.to_s,
      exception_class: exception.class.name,
    }
  end

  def check_two_mfa_bypass
    return if no_bypass || MfaPolicy.new(current_user).multiple_factors_enabled?
    redirect_to auth_url
  end

  def no_bypass
    user_session && user_session[:no_mfa_bypass]
  end

  # rubocop:disable Metrics/MethodLength
  # rubocop:disable Metrics/AbcSize
  def auth_url
    if TwoFactorAuthentication::PivCacPolicy.new(current_user).enabled?
      login_two_factor_piv_cac_url
    elsif TwoFactorAuthentication::WebauthnPolicy.new(current_user).enabled?
      login_two_factor_webauthn_url
    elsif TwoFactorAuthentication::AuthAppPolicy.new(current_user).enabled?
      login_two_factor_authenticator_url
    elsif TwoFactorAuthentication::PhonePolicy.new(current_user).enabled?
      login_two_factor_url(otp_delivery_preference: :sms, reauthn: false)
    elsif TwoFactorAuthentication::BackupCodePolicy.new(current_user).enabled?
      login_two_factor_backup_code_url
    else
      login_two_factor_personal_key_url
    end
  end
  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/MethodLength
end
