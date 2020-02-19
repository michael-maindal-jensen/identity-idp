require 'rails_helper'

RSpec.describe ServiceProviderSessionDecorator do
  let(:view_context) { ActionController::Base.new.view_context }
  subject do
    ServiceProviderSessionDecorator.new(
      sp: sp,
      view_context: view_context,
      sp_session: {},
      service_provider_request: ServiceProviderRequestProxy.new,
    )
  end
  let(:sp) { build_stubbed(:service_provider) }
  let(:sp_name) { subject.sp_name }
  let(:sp_create_link) { '/sign_up/enter_email' }

  before do
    allow(view_context).to receive(:sign_up_email_path).
      and_return('/sign_up/enter_email')
  end

  it 'has the same public API as SessionDecorator' do
    SessionDecorator.public_instance_methods.each do |method|
      expect(
        described_class.public_method_defined?(method),
      ).to be(true), "expected #{described_class} to have ##{method}"
    end
  end

  describe '#return_to_service_provider_partial' do
    it 'returns the correct partial' do
      expect(subject.return_to_service_provider_partial).to eq(
        'devise/sessions/return_to_service_provider',
      )
    end
  end

  describe '#nav_partial' do
    it 'returns the correct partial' do
      expect(subject.nav_partial).to eq 'shared/nav_branded'
    end
  end

  describe '#new_session_heading' do
    it 'returns the correct string' do
      expect(subject.new_session_heading).to eq I18n.t('headings.sign_in_with_sp', sp: sp_name)
    end
  end

  describe '#verification_method_choice' do
    it 'returns the correct string' do
      expect(subject.verification_method_choice).to eq(
        I18n.t('idv.messages.select_verification_with_sp', sp_name: sp_name),
      )
    end
  end

  describe '#sp_msg' do
    context 'sp has custom alert' do
      it 'uses the custom template' do
        expect(subject.sp_msg('sign_in')).
          to eq "<b>custom sign in help text for #{sp.friendly_name}</b>"
      end
    end

    context 'sp does not have a custom alert' do
      let(:sp) { build_stubbed(:service_provider_without_help_text) }

      it 'uses the custom template' do
        expect(subject.sp_msg('sign_in')).
          to be_nil
      end
    end
  end

  describe '#sp_name' do
    it 'returns the SP friendly name if present' do
      expect(subject.sp_name).to eq sp.friendly_name
      expect(subject.sp_name).to_not be_nil
    end

    it 'returns the agency name if friendly name is not present' do
      sp = build_stubbed(:service_provider, friendly_name: nil)
      subject = ServiceProviderSessionDecorator.new(
        sp: sp,
        view_context: view_context,
        sp_session: {},
        service_provider_request: ServiceProviderRequestProxy.new,
      )
      expect(subject.sp_name).to eq sp.agency
      expect(subject.sp_name).to_not be_nil
    end
  end

  describe '#sp_agency' do
    it 'returns the SP agency if present' do
      expect(subject.sp_agency).to eq sp.agency
      expect(subject.sp_agency).to_not be_nil
    end

    it 'returns the friendly name if the agency is not present' do
      sp = build_stubbed(:service_provider, friendly_name: 'friend', agency: nil)
      subject = ServiceProviderSessionDecorator.new(
        sp: sp,
        view_context: view_context,
        sp_session: {},
        service_provider_request: ServiceProviderRequestProxy.new,
      )
      expect(subject.sp_agency).to eq sp.friendly_name
      expect(subject.sp_agency).to_not be_nil
    end
  end

  describe '#sp_logo' do
    context 'service provider has a logo' do
      it 'returns the logo' do
        sp_logo = 'real_logo.svg'
        sp = build_stubbed(:service_provider, logo: sp_logo)

        subject = ServiceProviderSessionDecorator.new(
          sp: sp,
          view_context: view_context,
          sp_session: {},
          service_provider_request: ServiceProviderRequestProxy.new,
        )

        expect(subject.sp_logo).to eq sp_logo
      end
    end

    context 'service provider does not have a logo' do
      it 'returns the default logo' do
        sp = build_stubbed(:service_provider, logo: nil)

        subject = ServiceProviderSessionDecorator.new(
          sp: sp,
          view_context: view_context,
          sp_session: {},
          service_provider_request: ServiceProviderRequestProxy.new,
        )

        expect(subject.sp_logo).to eq 'generic.svg'
      end
    end
  end

  describe '#sp_logo_url' do
    context 'service provider has a logo' do
      it 'returns the logo' do
        sp_logo = '18f.svg'
        sp = build_stubbed(:service_provider, logo: sp_logo)

        subject = ServiceProviderSessionDecorator.new(
          sp: sp,
          view_context: view_context,
          sp_session: {},
          service_provider_request: ServiceProviderRequestProxy.new,
        )

        expect(subject.sp_logo_url).to match(%r{sp-logos\/18f-[0-9a-f]+\.svg$})
      end
    end

    context 'service provider does not have a logo' do
      it 'returns the default logo' do
        sp = build_stubbed(:service_provider, logo: nil)

        subject = ServiceProviderSessionDecorator.new(
          sp: sp,
          view_context: view_context,
          sp_session: {},
          service_provider_request: ServiceProviderRequestProxy.new,
        )

        expect(subject.sp_logo_url).to match(%r{/sp-logos/generic-.+\.svg})
      end
    end

    context 'service provider has a remote logo' do
      it 'returns the remote logo' do
        logo = 'https://raw.githubusercontent.com/18F/identity-idp/master/app/assets/images/sp-logos/generic.svg'
        sp = build_stubbed(:service_provider, logo: logo)

        subject = ServiceProviderSessionDecorator.new(
          sp: sp,
          view_context: view_context,
          sp_session: {},
          service_provider_request: ServiceProviderRequestProxy.new,
        )

        expect(subject.sp_logo_url).to eq(logo)
      end
    end
  end

  describe '#cancel_link_url' do
    subject(:decorator) do
      ServiceProviderSessionDecorator.new(
        sp: sp,
        view_context: view_context,
        sp_session: { request_id: 'foo' },
        service_provider_request: ServiceProviderRequestProxy.new,
      )
    end

    before do
      allow(view_context).to receive(:new_user_session_url).
        and_return('https://www.example.com/')
    end

    it 'returns view_context.new_user_session_url' do
      expect(decorator.cancel_link_url).
        to eq 'https://www.example.com/'
    end
  end

  describe '#failure_to_proof_url' do
    it 'returns the failure_to_proof_url if present on the sp' do
      url = 'https://www.example.com/fail'
      allow_any_instance_of(ServiceProvider).to receive(:failure_to_proof_url).and_return(url)
      expect(subject.failure_to_proof_url).to eq url
    end

    it 'returns the return_to_sp_url if the failure_to_proof_url is not present on the sp' do
      url = 'https://www.example.com/'
      allow_any_instance_of(ServiceProvider).to receive(:failure_to_proof_url).and_return(nil)
      allow_any_instance_of(ServiceProvider).to receive(:return_to_sp_url).and_return(url)
      expect(subject.failure_to_proof_url).to eq url
    end
  end

  describe '#sp_return_url' do
    it 'does not raise an error if request_url is nil' do
      allow(subject).to receive(:request_url).and_return(nil)
      allow(sp).to receive(:redirect_uris).and_return(['foo'])
      subject.sp_return_url
    end
  end

  describe 'mfa_expiration_interval' do
    context 'with an AAL2 sp' do
      before do
        allow(sp).to receive(:aal).and_return(2)
      end

      it { expect(subject.mfa_expiration_interval).to eq(12.hours) }
    end

    context 'with an IAL2 sp' do
      before do
        allow(sp).to receive(:ial).and_return(2)
      end

      it { expect(subject.mfa_expiration_interval).to eq(12.hours) }
    end

    context 'with an sp that is not AAL2 or IAL2' do
      it { expect(subject.mfa_expiration_interval).to eq(30.days) }
    end
  end
end
