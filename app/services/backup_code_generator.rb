require 'digest'

class BackupCodeGenerator
  attr_reader :length

  NUMBER_OF_CODES = 10

  def initialize(user, length: 2, split: 4)
    @length = length
    @split = split
    @user = user
  end

  def generate
    delete_existing_codes
    generate_new_codes
  end

  def create
    @user.save
    generate
  end

  def verify(plaintext_code)
    backup_code = normalize(plaintext_code)
    code = BackupCodeConfiguration.find_with_code(code: backup_code, user_id: @user.id)
    return unless code_usable?(code)
    code.update!(used: true, used_at: Time.zone.now)
    true
  end

  def delete_existing_codes
    @user.backup_code_configurations.destroy_all
  end

  def generate_new_codes
    result = []
    NUMBER_OF_CODES.times do
      code = backup_code
      result.push code
      save_code(code)
    end
    result
  end

  private

  def code_usable?(code)
    code && !code.used
  end

  def save_code(code)
    @user.backup_code_configurations.create!(code: code)
  end

  def normalize(plaintext_code)
    plaintext_code.gsub(/\W/, '').downcase.strip
  end

  def backup_code
    normalize(SecureRandom.hex(@split * @length / 2))
  end
end
