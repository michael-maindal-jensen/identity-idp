require 'rails_helper'

describe ServiceProviderRequestProxy do
  before do
    ServiceProviderRequestProxy.flush
  end

  describe '.from_uuid' do
    context 'when the record exists' do
      it 'returns the record matching the uuid' do
        sp_request = ServiceProviderRequestProxy.create(
          uuid: '123',
          issuer: 'foo',
          url: 'http://bar.com', ial: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF
        )
        expect(ServiceProviderRequestProxy.from_uuid('123')).to eq sp_request
      end

      it 'both loa1 and ial1 values return the same thing' do
        sp_request = ServiceProviderRequestProxy.create(
          uuid: '123',
          issuer: 'foo',
          url: 'http://bar.com',
          ial: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
        )

        expect(sp_request.loa).to eq(sp_request.ial)
        expect(ServiceProviderRequestProxy.from_uuid('123')).to eq sp_request
      end

      it 'both loa3 and ial2 values return the same thing' do
        sp_request = ServiceProviderRequestProxy.create(
          uuid: '123',
          issuer: 'foo',
          url: 'http://bar.com',
          ial: Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
        )

        expect(sp_request.loa).to eq(sp_request.ial)
        expect(ServiceProviderRequestProxy.from_uuid('123')).to eq sp_request
      end
    end

    context 'when the record does not exists' do
      it 'returns an instance of NullServiceProviderRequest' do
        expect(ServiceProviderRequestProxy.from_uuid('123')).
          to be_an_instance_of NullServiceProviderRequest
      end

      it 'returns an instance of NullServiceProviderRequest when the uuid contains a null byte' do
        expect(ServiceProviderRequestProxy.from_uuid("\0")).
          to be_an_instance_of NullServiceProviderRequest
      end
    end
  end
end
