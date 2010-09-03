require 'openssl'
require 'digest/sha2'
 
module Crypto
  KEY = "15fef02a369f3a5e5a99b1ffd37276260725a8c2f36d7356777ea2367067d2395ead83e6cd2c3e9f6bc3c276ede59596e66a1dd426fc488a6eb6a33aa112bef15"
 
  def self.encrypt(plain_text)
    crypto = start(:encrypt)
 
    cipher_text = crypto.update(plain_text)
    cipher_text << crypto.final
 
    cipher_hex = cipher_text.unpack("H*").join
 
    return cipher_hex
  end
 
  def self.decrypt(cipher_hex)
    crypto = start(:decrypt)
 
    cipher_text = cipher_hex.gsub(/(..)/){|h| h.hex.chr}
 
    plain_text = crypto.update(cipher_text)
    plain_text << crypto.final
 
    return plain_text
  end
 
  private
 
    def self.start(mode)
      crypto = OpenSSL::Cipher::Cipher.new('aes-256-ecb').send(mode)
      crypto.key = Digest::SHA256.hexdigest(KEY)
      return crypto
    end
end
