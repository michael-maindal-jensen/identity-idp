require 'rails_helper'

feature 'SP Costing', :email do
  include SpAuthHelper
  include SamlAuthHelper
  include IdvHelper
  include DocAuthHelper
  include IdvFromSpHelper

  before do
    enable_doc_auth
  end

  let(:issuer) { 'urn:gov:gsa:openidconnect:sp:server' }
  let(:agency_id) { 2 }
  let(:email) { 'test@test.com' }
  let(:password) { Features::SessionHelper::VALID_PASSWORD }

  it 'logs the correct costs for an ial1 user creation from sp with oidc' do
    create_ial1_user_from_sp(email)

    expect_sp_cost_type(0, 1, 'sms')
    expect_sp_cost_type(1, 1, 'user_added')
    expect_sp_cost_type(2, 1, 'authentication')
  end

  it 'logs the correct costs for an ial2 user creation from sp with oidc' do
    create_ial2_user_from_sp(email)

    expect_sp_cost_type(0, 2, 'sms')
    expect_sp_cost_type(1, 2, 'acuant_front_image')
    expect_sp_cost_type(2, 2, 'acuant_back_image')
    expect_sp_cost_type(3, 2, 'lexis_nexis_resolution')
    expect_sp_cost_type(4, 2, 'lexis_nexis_address')
    expect_sp_cost_type(5, 2, 'user_added')
    expect_sp_cost_type(6, 2, 'authentication')
  end

  it 'logs the correct costs for an ial1 authentication' do
    create_ial1_user_from_sp(email)
    SpCost.delete_all

    # track costs without dealing with 'remember device'
    Capybara.reset_session!

    visit_idp_from_sp_with_ial1(:oidc)
    fill_in_credentials_and_submit(email, password)
    fill_in_code_with_last_phone_otp
    click_submit_default

    expect_sp_cost_type(0, 1, 'digest')
    expect_sp_cost_type(1, 1, 'sms')
    expect_sp_cost_type(2, 1, 'authentication')
  end

  it 'logs the correct costs for an ial2 authentication' do
    create_ial2_user_from_sp(email)
    SpCost.delete_all

    # track costs without dealing with 'remember device'
    Capybara.reset_session!

    visit_idp_from_sp_with_ial2(:oidc)
    fill_in_credentials_and_submit(email, password)
    fill_in_code_with_last_phone_otp
    click_submit_default

    expect_sp_cost_type(0, 2, 'digest')
    expect_sp_cost_type(1, 2, 'sms')
    expect_sp_cost_type(2, 2, 'authentication')
  end

  it 'logs the correct costs for a direct authentication' do
    visit root_path
    create_ial1_user_directly(email)
    SpCost.delete_all

    # track costs without dealing with 'remember device'
    Capybara.reset_session!

    visit root_path
    fill_in_credentials_and_submit(email, password)
    fill_in_code_with_last_phone_otp
    click_submit_default

    expect_direct_cost_type(0, 'digest')
  end

  def expect_sp_cost_type(sp_cost_index, ial, token)
    sp_cost = sp_costs(sp_cost_index)
    expect(sp_cost.ial).to eq(ial)
    expect(sp_cost.issuer).to eq(issuer)
    expect(sp_cost.agency_id).to eq(agency_id)
    expect(sp_cost.cost_type).to eq(token)
  end

  def expect_direct_cost_type(sp_cost_index, token)
    sp_cost = sp_costs(sp_cost_index)
    expect(sp_cost.issuer).to eq('')
    expect(sp_cost.agency_id).to eq(0)
    expect(sp_cost.cost_type).to eq(token)
  end

  def sp_costs(index)
    SpCost.order('id asc')[index]
  end
end
