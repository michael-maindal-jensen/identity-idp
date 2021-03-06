Telephony.config do |c|
  c.adapter = Figaro.env.telephony_adapter.to_sym || :test
  c.logger = Logger.new('log/telephony.log', level: :info)

  c.twilio.numbers = JSON.parse(Figaro.env.twilio_numbers || '[]')
  c.twilio.sid = Figaro.env.twilio_sid
  c.twilio.auth_token = Figaro.env.twilio_auth_token
  c.twilio.messaging_service_sid = Figaro.env.twilio_messaging_service_sid
  c.twilio.voice_callback_encryption_key = Figaro.env.twilio_voice_callback_encryption_key
  c.twilio.voice_callback_base_url = "https://#{Figaro.env.domain_name}/api/twilio/voice"
  c.twilio.timeout = Figaro.env.twilio_timeout.to_i unless Figaro.env.twilio_timeout.nil?
  c.twilio.record_voice = Figaro.env.twilio_record_voice == 'true'

  c.pinpoint.sms.region = Figaro.env.pinpoint_sms_region
  c.pinpoint.sms.application_id = Figaro.env.pinpoint_sms_application_id
  c.pinpoint.sms.shortcode = Figaro.env.pinpoint_sms_shortcode
  c.pinpoint.sms.longcode_pool = JSON.parse(Figaro.env.pinpoint_sms_longcode_pool || '[]')
  c.pinpoint.sms.credential_role_arn = Figaro.env.pinpoint_sms_credential_role_arn
  if Figaro.env.pinpoint_sms_credential_role_arn.present?
    c.pinpoint.sms.credential_role_session_name = Socket.gethostname
  end

  c.pinpoint.voice.region = Figaro.env.pinpoint_voice_region
  c.pinpoint.voice.longcode_pool = JSON.parse(Figaro.env.pinpoint_voice_longcode_pool || '[]')
  c.pinpoint.voice.credential_role_arn = Figaro.env.pinpoint_voice_credential_role_arn
  if Figaro.env.pinpoint_voice_credential_role_arn.present?
    c.pinpoint.voice.credential_role_session_name = Socket.gethostname
  end
end
