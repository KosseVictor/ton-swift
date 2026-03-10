import Foundation
import Crypto

public enum X25519 {
  enum Error: Swift.Error {
    case sharedSecretError(code: Int)
  }
  
  public struct PrivateKey: Key, Equatable, Codable {
    public let data: Data
    
    public init(data: Data) {
      self.data = data
    }
  }
  
  public struct PublicKey: Key, Equatable, Codable {
    public let data: Data
    
    public init(data: Data) {
      self.data = data
    }
  }
  
  static func getSharedSecret(privateKey: X25519.PrivateKey, publicKey: X25519.PublicKey) throws -> Data {
    let cryptoPrivateKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: privateKey.data)
    let cryptoPublicKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: publicKey.data)
    let sharedSecret = try cryptoPrivateKey.sharedSecretFromKeyAgreement(with: cryptoPublicKey)
    return sharedSecret.withUnsafeBytes { Data($0) }
  }
}

public extension X25519 {
  enum X25519ConversionError: Swift.Error {
    case publicKeyConversionFailed(code: Int)
    case privateKeyConversionFailed(code: Int)
  }
}

extension PublicKey {
  var toX25519: X25519.PublicKey {
    get throws {
      let data = try ed25519PublicKeyToCurve25519(self.data)
      return X25519.PublicKey(data: data)
    }
  }
}

extension PrivateKey {
  var toX25519: X25519.PrivateKey {
    get throws {
      let data = try ed25519PrivateKeyToCurve25519(self.data)
      return X25519.PrivateKey(data: data)
    }
  }
}

private extension Int {
  static let privateKeyLength: Int = 32
  static let publicKeyLength: Int = 32
  static let sharedSecretLength: Int = 32
}
