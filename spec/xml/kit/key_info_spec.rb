# frozen_string_literal: true

RSpec.describe Xml::Kit::KeyInfo do
  subject { described_class.new }

  describe '#to_xml' do
    specify { expect(Hash.from_xml(subject.to_xml)).not_to be_empty }
    specify { expect { subject.asymmetric_cipher }.to raise_error(/encryption_certificate is not specified/) }

    context 'when using a DSA key' do
      subject { described_class.new(x509: x509) }

      let(:x509) do
        certificate = OpenSSL::X509::Certificate.new
        certificate.subject = certificate.issuer = OpenSSL::X509::Name.parse(Xml::Kit::SelfSignedCertificate::SUBJECT)
        certificate.not_before = Time.now
        certificate.not_after = certificate.not_before + 30 * 24 * 60 * 60
        certificate.public_key = public_key
        certificate.serial = 0x0
        certificate.version = 2
        certificate
      end
      let(:public_key) { private_key.public_key }
      let(:private_key) { OpenSSL::PKey::DSA.new(2048) }

      specify { expect { subject.asymmetric_cipher }.to raise_error(/OpenSSL::PKey::DSA is not supported/) }
    end

    context 'with encrypted key' do
      let(:encrypted_key) { ::Xml::Kit::EncryptedKey.new(id: id, asymmetric_cipher: asymmetric_cipher, symmetric_cipher: symmetric_cipher) }
      let(:symmetric_cipher) { ::Xml::Kit::Crypto::SymmetricCipher.new }
      let(:asymmetric_cipher) { ::Xml::Kit::Crypto.cipher_for(algorithm, private_key.public_key) }
      let(:algorithm) { ::Xml::Kit::Crypto::RsaCipher::ALGORITHM }
      let(:id) { ::Xml::Kit::Id.generate }
      let(:private_key) { OpenSSL::PKey::RSA.new(2048) }
      let(:result) { Hash.from_xml(subject.to_xml) }

      before do
        subject.encrypted_key = encrypted_key
      end

      specify { expect(result['KeyInfo']['EncryptedKey']['EncryptionMethod']['Algorithm']).to eql(algorithm) }
      specify { expect(private_key.private_decrypt(Base64.decode64(result['KeyInfo']['EncryptedKey']['CipherData']['CipherValue']))).to eql(symmetric_cipher.key) }
      specify { expect(subject.symmetric_cipher).to eql(symmetric_cipher) }
      specify { expect(subject.asymmetric_cipher).to eql(asymmetric_cipher) }
    end

    context 'with key name' do
      let(:result) { Hash.from_xml(subject.to_xml) }

      before do
        subject.key_name = 'samlkey'
      end

      specify { expect(result['KeyInfo']['KeyName']).to eql('samlkey') }
    end

    context 'with key value' do
      let(:result) { Hash.from_xml(subject.to_xml) }
      let(:modulus) { 'xA7SEU+e0yQH5rm9kbCDN9o3aPIo7HbP7tX6WOocLZAtNfyxSZDU16ksL6WjubafOqNEpcwR3RdFsT7bCqnXPBe5ELh5u4VEy19MzxkXRgrMvavzyBpVRgBUwUlV5foK5hhmbktQhyNdy/6LpQRhDUDsTvK+g9Ucj47es9AQJ3U=' }
      let(:exponent) { 'AQAB' }

      before do
        subject.key_value.rsa.modulus = modulus
        subject.key_value.rsa.exponent = exponent
      end

      specify { expect(result['KeyInfo']['KeyValue']['RSAKeyValue']['Modulus']).to eql(modulus) }
      specify { expect(result['KeyInfo']['KeyValue']['RSAKeyValue']['Exponent']).to eql(exponent) }
    end

    context 'with retrieval method' do
      let(:result) { Hash.from_xml(subject.to_xml) }
      let(:uri) { Xml::Kit::Id.generate }
      let(:type) { 'http://www.w3.org/2001/04/xmlenc#EncryptedKey' }

      before do
        subject.retrieval_method.uri = uri
        subject.retrieval_method.type = type
      end

      specify { expect(result['KeyInfo']['RetrievalMethod']).to be_present }
      specify { expect(result['KeyInfo']['RetrievalMethod']['xmlns']).to eql(::Xml::Kit::Namespaces::XMLDSIG) }
      specify { expect(result['KeyInfo']['RetrievalMethod']['URI']).to eql(uri) }
      specify { expect(result['KeyInfo']['RetrievalMethod']['Type']).to eql(type) }
    end

    context 'with x509 data' do
      let(:key_pair) { ::Xml::Kit::KeyPair.generate(use: :encryption) }
      let(:x509_certificate) { key_pair.certificate.x509 }
      let(:subject_key_identifier) { x509_certificate.extensions.find { |x| x.oid == 'subjectKeyIdentifier' }.value }

      before do
        subject.x509_data = x509_certificate
      end

      specify { expect(Hash.from_xml(subject.to_xml)['KeyInfo']['X509Data']['X509SKI']).to eql(Base64.strict_encode64(subject_key_identifier)) }
      specify { expect(Hash.from_xml(subject.to_xml)['KeyInfo']['X509Data']['X509Certificate']).to eql(key_pair.certificate.stripped) }
      specify { expect(subject.asymmetric_cipher.key.to_pem).to eql(x509_certificate.public_key.to_pem) }
    end
  end
end
