import Foundation
import Crypto

extension Data {
    public func sha256() -> Self {
        let hash = SHA256.hash(data: self)
        return Data(hash)
    }
}
