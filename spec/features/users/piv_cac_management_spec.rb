require 'rails_helper'

feature 'PIV/CAC Management' do
  def find_form(page, attributes)
    page.all('form').detect do |form|
      attributes.all? { |key, value| form[key] == value }
    end
  end

  context 'with no piv/cac associated yet' do
    let(:uuid) { SecureRandom.uuid }
    let(:user) { create(:user, :signed_up, :with_phone, with: { phone: '+1 202-555-1212' }) }

    context 'with an account allowed to use piv/cac' do
      before(:each) do
        allow_any_instance_of(
          TwoFactorAuthentication::PivCacPolicy,
        ).to receive(:available?).and_return(true)
      end

      scenario 'allows association of a piv/cac with an account' do
        allow(LoginGov::Hostdata).to receive(:env).and_return('test')
        allow(LoginGov::Hostdata).to receive(:domain).and_return('example.com')

        stub_piv_cac_service

        sign_in_and_2fa_user(user)
        visit account_path
        click_link t('forms.buttons.enable'), href: setup_piv_cac_url

        expect(page.response_headers['Content-Security-Policy']).
          to(include("form-action https://*.pivcac.test.example.com 'self';"))

        nonce = piv_cac_nonce_from_form_action

        visit_piv_cac_service(setup_piv_cac_url,
                              nonce: nonce,
                              uuid: uuid,
                              subject: 'SomeIgnoredSubject')

        expect(current_path).to eq account_path
        expect(page.find('.remove-piv')).to_not be_nil

        user.reload
        expect(user.piv_cac_configurations.first.x509_dn_uuid).to eq uuid
        expect(user.events.order(created_at: :desc).last.event_type).to eq('piv_cac_enabled')
      end

      scenario 'disallows add if 2 piv cacs' do
        stub_piv_cac_service
        user_id = user.id
        ::PivCacConfiguration.create!(user_id: user_id, x509_dn_uuid: 'foo', name: 'key1')

        sign_in_and_2fa_user(user)

        expect(page).to have_link(t('forms.buttons.enable'), href: setup_piv_cac_url)
        visit account_path

        ::PivCacConfiguration.create!(user_id: user_id, x509_dn_uuid: 'bar', name: 'key2')
        visit account_path
        expect(page).to_not have_link(t('forms.buttons.enable'), href: setup_piv_cac_url)

        visit setup_piv_cac_path
        expect(current_path).to eq account_path
      end

      scenario 'disallows association of a piv/cac with the same name' do
        stub_piv_cac_service

        sign_in_and_2fa_user(user)
        visit account_path
        click_link t('forms.buttons.enable'), href: setup_piv_cac_url

        nonce = piv_cac_nonce_from_form_action

        visit_piv_cac_service(setup_piv_cac_url,
                              nonce: nonce,
                              uuid: uuid,
                              subject: 'SomeIgnoredSubject')

        expect(current_path).to eq account_path

        click_link t('forms.buttons.enable'), href: setup_piv_cac_url
        user.reload
        fill_in 'name', with: user.piv_cac_configurations.first.name
        click_button t('forms.piv_cac_setup.submit')

        expect(page).to have_content(I18n.t('errors.piv_cac_setup.unique_name'))
      end

      scenario 'displays error for a bad piv/cac and accepts more error info' do
        stub_piv_cac_service

        sign_in_and_2fa_user(user)
        visit account_path
        click_link t('forms.buttons.enable'), href: setup_piv_cac_url

        nonce = piv_cac_nonce_from_form_action
        visit_piv_cac_service(setup_piv_cac_url,
                              nonce: nonce,
                              error: 'certificate.bad',
                              key_id: 'AB:CD:EF')
        expect(current_path).to eq setup_piv_cac_path
        expect(page).to have_content(t('headings.piv_cac_setup.certificate.bad'))
      end

      scenario 'displays error for an expired piv/cac and accepts more error info' do
        stub_piv_cac_service

        sign_in_and_2fa_user(user)
        visit account_path
        click_link t('forms.buttons.enable'), href: setup_piv_cac_url

        nonce = piv_cac_nonce_from_form_action
        visit_piv_cac_service(setup_piv_cac_url,
                              nonce: nonce,
                              error: 'certificate.expired',
                              key_id: 'AB:CD:EF')
        expect(current_path).to eq setup_piv_cac_path
        expect(page).to have_content(t('headings.piv_cac_setup.certificate.expired'))
      end

      scenario "doesn't allow unassociation of a piv/cac" do
        stub_piv_cac_service

        sign_in_and_2fa_user(user)
        visit account_path
        form = find_form(page, action: disable_piv_cac_url)
        expect(form).to be_nil
      end

      context 'when the user does not have a 2nd mfa yet' do
        it 'does prompt to set one up after configuring PIV/CAC' do
          stub_piv_cac_service

          MfaContext.new(user).phone_configurations.clear
          sign_in_and_2fa_user(user)
          visit account_path
          click_link t('forms.buttons.enable'), href: setup_piv_cac_url

          expect(page).to have_current_path(setup_piv_cac_path)

          nonce = piv_cac_nonce_from_form_action
          visit_piv_cac_service(setup_piv_cac_url,
                                nonce: nonce,
                                uuid: SecureRandom.uuid,
                                subject: 'SomeIgnoredSubject')

          expect(page).to have_current_path account_path
        end
      end
    end
  end

  context 'with a piv/cac associated' do
    let(:user) do
      create(:user, :signed_up, :with_piv_or_cac, :with_phone, with: { phone: '+1 202-555-1212' })
    end

    scenario 'does allow association of another piv/cac with the account' do
      stub_piv_cac_service

      sign_in_and_2fa_user(user)
      visit account_path
      expect(page).to have_link(t('forms.buttons.enable'), href: setup_piv_cac_url)
    end

    scenario 'allows disassociation of the piv/cac' do
      stub_piv_cac_service

      sign_in_and_2fa_user(user)
      visit account_path

      expect(page.find('.remove-piv')).to_not be_nil
      page.find('.remove-piv').click

      expect(current_path).to eq piv_cac_delete_path
      click_on t('account.index.piv_cac_confirm_delete')

      expect(current_path).to eq account_path

      expect(page).to have_link(t('forms.buttons.enable'), href: setup_piv_cac_url)

      user.reload
      expect(user.piv_cac_configurations.first&.x509_dn_uuid).to be_nil
      expect(user.events.order(created_at: :desc).last.event_type).to eq('piv_cac_disabled')
    end
  end

  context 'with PIV/CAC as the only MFA method' do
    let(:user) { create(:user, :with_piv_or_cac) }

    scenario 'disallows disassociation PIV/CAC' do
      sign_in_and_2fa_user(user)
      visit account_path

      form = find_form(page, action: disable_piv_cac_url)
      expect(form).to be_nil

      user.reload
      expect(user.piv_cac_configurations.first.x509_dn_uuid).to_not be_nil
    end
  end
end
