class UserPivCacSetupForm
  include ActiveModel::Model
  include PivCacFormHelpers

  attr_accessor :x509_dn_uuid, :x509_dn, :token, :user, :nonce, :error_type, :name, :key_id
  attr_reader :name_taken

  validates :token, presence: true
  validates :nonce, presence: true
  validates :user, presence: true
  validates :name, presence: true
  validate :name_is_unique

  def submit
    success = valid? && valid_submission?

    errors = error_type ? { type: error_type } : {}
    FormResponse.new(
      success: success && process_valid_submission,
      errors: errors,
      extra: extra_analytics_attributes.merge(error_type ? { key_id: key_id } : {}),
    )
  end

  private

  def process_valid_submission
    Db::PivCacConfiguration::Create.call(user, x509_dn_uuid, @name)
    true
  rescue PG::UniqueViolation
    self.error_type = 'piv_cac.already_associated'
    false
  end

  def valid_submission?
    valid_token? && piv_cac_not_already_associated
  end

  def piv_cac_not_already_associated
    self.x509_dn_uuid = @data['uuid']
    self.x509_dn = @data['subject']
    if Db::PivCacConfiguration::FindUserByX509.call(x509_dn_uuid)
      self.error_type = 'piv_cac.already_associated'
      false
    else
      true
    end
  end

  def user_has_no_piv_cac
    if TwoFactorAuthentication::PivCacPolicy.new(user).enabled?
      self.error_type = 'user.piv_cac_associated'
      false
    else
      true
    end
  end

  def extra_analytics_attributes
    {
      multi_factor_auth_method: 'piv_cac',
    }
  end

  def name_is_unique
    return unless PivCacConfiguration.exists?(user_id: @user.id, name: @name)
    errors.add :name, I18n.t('errors.piv_cac_setup.unique_name')
    @name_taken = true
  end
end
