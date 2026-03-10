import Foundation
import CryptoSwift

public struct AES_CBC {
  public enum Error: Swift.Error {
    case encryptionFailed
    case decryptionFailed
  }
  
  public let key: Data
  public let iv: Data
  
  public init(key: Data,
              iv: Data) {
    self.key = key
    self.iv = iv
  }
  
  public func decrypt(cipherData: Data) throws -> Data {
    let aes = try AES(key: Array(key), blockMode: CBC(iv: Array(iv)), padding: .pkcs7)
    let decrypted = try aes.decrypt(Array(cipherData))
    return Data(decrypted)
  }
  
  public func encrypt(data: Data) throws -> Data {
    let aes = try AES(key: Array(key), blockMode: CBC(iv: Array(iv)), padding: .noPadding)
    let encrypted = try aes.encrypt(Array(data))
    return Data(encrypted)
  }
}
