class UserPivCacLoginForm
  include ActiveModel::Model
  include PivCacFormHelpers

  attr_accessor :x509_dn_uuid, :x509_dn, :token, :error_type, :nonce, :user, :key_id

  validates :token, presence: true
  validates :nonce, presence: true

  def submit
    success = valid? && valid_submission?

    errors = error_type ? { type: error_type } : {}
    response_hash = { success: success, errors: errors }
    response_hash[:extra] = { key_id: key_id }
    FormResponse.new(response_hash)
  end

  private

  def valid_submission?
    valid_token? &&
      user_found
  end

  def user_found
    maybe_user = Db::PivCacConfiguration::FindUserByX509.call(x509_dn_uuid)
    if maybe_user.present?
      self.user = maybe_user
      true
    else
      self.error_type = 'user.not_found'
      false
    end
  end
end
