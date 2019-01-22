# frozen_string_literal: true

module Xml
  module Kit
    class SelfSignedCertificate
      SUBJECT = '/C=CA/ST=AB/L=Calgary/O=XmlKit/OU=XmlKit/CN=XmlKit'.freeze

      def create(algorithm: 'AES-256-CBC', passphrase: nil, key_pair: OpenSSL::PKey::RSA.new(2048))
        certificate = certificate_for(key_pair.public_key)
        certificate.sign(key_pair, OpenSSL::Digest::SHA256.new)
        [certificate.to_pem, export(key_pair, algorithm, passphrase)]
      end

      private

      def export(key_pair, algorithm, passphrase)
        if passphrase.present?
          cipher = OpenSSL::Cipher.new(algorithm)
          key_pair.export(cipher, passphrase)
        else
          key_pair.export
        end
      end

      def certificate_for(public_key)
        certificate = OpenSSL::X509::Certificate.new
        certificate.subject = certificate.issuer = OpenSSL::X509::Name.parse(SUBJECT)
        certificate.not_before = Time.now
        certificate.not_after = certificate.not_before + 30 * 24 * 60 * 60 # 30 days
        certificate.public_key = public_key
        certificate.serial = 0x0
        certificate.version = 2

        extension_factory = OpenSSL::X509::ExtensionFactory.new
        extension_factory.subject_certificate = certificate
        extension_factory.issuer_certificate = certificate
        certificate.add_extension(extension_factory.create_extension("subjectKeyIdentifier", "hash", false))

        certificate
      end
    end
  end
end
