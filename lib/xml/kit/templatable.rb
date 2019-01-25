# frozen_string_literal: true

module Xml
  module Kit
    module Templatable
      # Can be used to disable embeding a signature.
      # By default a signature will be embedded if a signing
      # certificate is available.
      attr_accessor :embed_signature

      # Used to enable/disable encrypting the document.
      attr_accessor :encrypt

      # The [Xml::Kit::KeyPair] to use for generating a signature.
      attr_accessor :signing_key_pair

      # The [Xml::Kit::Certificate] that contains the public key to use for encrypting the document.
      attr_accessor :encryption_certificate

      # Returns the generated XML document with an XML Digital Signature and XML Encryption.
      def to_xml(xml: ::Builder::XmlMarkup.new, pretty: false)
        result = signatures.complete(render(self, xml: xml))
        pretty ? Nokogiri::XML(result).to_xml(indent: 2) : result
      end

      def encrypt_key_for(xml:, id:, public_key:, key:)
        ::Xml::Kit::EncryptedKey.new(id: id, public_key: public_key, key: key).to_xml(xml: xml)
      end

      def encryption_for(*args, &block)
        ::Xml::Kit.deprecate('encryption_for is deprecated. Use encrypt_data_for instead.')
        encrypt_data_for(*args, &block)
      end

      def encrypt_data_for(xml:, key_info: nil, symmetric_cipher: Crypto::SymmetricCipher.new)
        return yield xml unless encrypt?

        temp = ::Builder::XmlMarkup.new
        yield temp
        ::Xml::Kit::Encryption.new(
          signatures.complete(temp.target!),
          encryption_certificate.public_key,
          symmetric_algorithm: symmetric_cipher,
          key_info: key_info
        ).to_xml(xml: xml)
      end

      def render(model, options)
        ::Xml::Kit::Template.new(model).to_xml(options)
      end

      def signature_for(reference_id:, xml:)
        return unless sign?

        signatures.build(reference_id).to_xml(xml: xml)
      end

      # Allows you to specify which key pair to use for generating an XML digital signature.
      #
      # @param key_pair [Xml::Kit::KeyPair] the key pair to use for signing.
      def sign_with(key_pair)
        self.signing_key_pair = key_pair
        self.embed_signature = true
        signatures.sign_with(key_pair)
      end

      # Allows you to specify which public key to use for generating an XML encrypted element.
      #
      # @param certificate [Xml::Kit::Certificate] the certificate containing the public key to use for encryption.
      def encrypt_with(certificate)
        self.encrypt = true
        self.encryption_certificate = certificate
      end

      private

      def sign?
        embed_signature
      end

      # @!visibility private
      def signatures
        @signatures ||= ::Xml::Kit::Signatures.new(
          key_pair: signing_key_pair,
          digest_method: digest_method,
          signature_method: signature_method
        )
      end

      def digest_method
        :SHA256
      end

      def signature_method
        :SHA256
      end

      # @!visibility private
      def encrypt?
        encrypt && encryption_certificate
      end
    end
  end
end
