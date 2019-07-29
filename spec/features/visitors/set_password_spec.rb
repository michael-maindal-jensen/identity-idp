require 'rails_helper'

feature 'Visitor sets password during signup' do
  let(:pwned_passwords_file) { 'spec/fixtures/pwned_passwords.txt' }

  scenario 'visitor is redirected back to password form when password is blank' do
    create(:user, :unconfirmed)
    confirm_last_user
    fill_in 'password_form_password', with: ''
    click_button t('forms.buttons.continue')

    expect(page).to have_content t('errors.messages.blank')
    expect(current_url).to eq sign_up_create_password_url
  end

  context 'password field is blank when JS is on', js: true do
    before do
      create(:user, :unconfirmed)
      confirm_last_user
    end

    it 'does not allow the user to submit the form' do
      fill_in 'password_form_password', with: ''

      expect(page).to_not have_button(t('forms.buttons.continue'))
    end
  end

  scenario 'password strength indicator hidden when JS is off' do
    create(:user, :unconfirmed)
    confirm_last_user

    expect(page).to have_css('#pw-strength-cntnr.hide')
  end

  context 'password strength indicator when JS is on', js: true do
    before do
      create(:user, :unconfirmed)
      confirm_last_user
    end

    it 'is visible on page (not have "hide" class)' do
      expect(page).to_not have_css('#pw-strength-cntnr.hide')
    end

    it 'updates as password changes' do
      expect(page).to have_content '...'

      fill_in 'password_form_password', with: 'password'
      expect(page).to have_content 'Very weak'

      fill_in 'password_form_password', with: 'this is a great sentence'
      expect(page).to have_content 'Great!'
    end

    it 'has dynamic password strength feedback' do
      expect(page).to have_content '...'

      fill_in 'password_form_password', with: '123456789'
      expect(page).to have_content t('zxcvbn.feedback.this_is_a_top_10_common_password')
    end
  end

  scenario 'password visibility toggle when JS is on', js: true do
    create(:user, :unconfirmed)
    confirm_last_user

    expect(page).to have_css('input.password[type="password"]')

    find('.checkbox').click

    expect(page).to_not have_css('input.password[type="password"]')
    expect(page).to have_css('input.password[type="text"]')
  end

  context 'password is invalid' do
    scenario 'visitor is redirected back to password form' do
      create(:user, :unconfirmed)
      confirm_last_user
      fill_in 'password_form_password', with: 'Q!2e'

      click_button t('forms.buttons.continue')

      expect(page).to have_content('characters')
      expect(current_url).to eq sign_up_create_password_url
    end

    scenario 'visitor gets password help message' do
      create(:user, :unconfirmed)
      confirm_last_user
      fill_in 'password_form_password', with: '1234567891011'

      click_button t('forms.buttons.continue')

      expect(page).to have_content t('zxcvbn.feedback.this_is_similar_to_a_commonly_used_password')
    end

    scenario 'visitor gets password pwned message' do
      allow(Figaro.env).to receive(:pwned_password_enabled).and_return('true')
      allow(Figaro.env).to receive(:pwned_password_file).and_return(pwned_passwords_file)

      create(:user, :unconfirmed)
      confirm_last_user
      fill_in 'password_form_password', with: '3.1415926535'

      click_button t('forms.buttons.continue')

      expect(page).to have_content t('errors.messages.pwned_password')
    end

    scenario 'visitor does not get password pwned message when feature flag disabled' do
      create(:user, :unconfirmed)
      confirm_last_user
      fill_in 'password_form_password', with: '3.1415926535'

      click_button t('forms.buttons.continue')

      expect(page).to_not have_content t('errors.messages.pwned_password')
    end
  end
end
