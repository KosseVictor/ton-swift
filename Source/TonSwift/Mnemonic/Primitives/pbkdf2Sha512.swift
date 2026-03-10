import Foundation
import Crypto

public let pbkdf2Sha512Iterations = 100000

/// PBKDF2 with HMAC-SHA512. Cross-platform (Crypto/CryptoKit).
public func pbkdf2Sha512(phrase: Data, salt: Data, iterations: Int = pbkdf2Sha512Iterations, keyLength: Int = 64) -> [UInt8] {
    var result = [UInt8]()
    result.reserveCapacity(keyLength)
    var blockIndex: UInt32 = 1
    while result.count < keyLength {
        var block = Data()
        block.append(salt)
        block.append(contentsOf: withUnsafeBytes(of: blockIndex.bigEndian) { Array($0) })
        var u = [UInt8](HMAC<SHA512>.authenticationCode(for: block, using: SymmetricKey(data: phrase)))
        var t = u
        for _ in 1..<iterations {
            u = [UInt8](HMAC<SHA512>.authenticationCode(for: Data(u), using: SymmetricKey(data: phrase)))
            for i in 0..<t.count {
                t[i] ^= u[i]
            }
        }
        result.append(contentsOf: t)
        blockIndex += 1
    }
    return Array(result.prefix(keyLength))
}
