import Foundation
import Crypto

public struct HMAC_SHA512 {
  public static func hmacSha512(message: Data, key: Data) -> Data {
    let symmetricKey = SymmetricKey(data: key)
    let authenticationCode = HMAC<SHA512>.authenticationCode(for: message, using: symmetricKey)
    return Data(authenticationCode)
  }
}
