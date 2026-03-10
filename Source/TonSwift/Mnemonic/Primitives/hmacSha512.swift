import Foundation
import Crypto

public func hmacSha512(phrase: String, password: String) -> Data {
    let phraseData = Data(phrase.utf8)
    let passwordData = Data(password.utf8)
    let symmetricKey = SymmetricKey(data: phraseData)
    let authenticationCode = HMAC<SHA512>.authenticationCode(for: passwordData, using: symmetricKey)
    return Data(authenticationCode)
}
