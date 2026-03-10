import Foundation
import Crypto
import BigInt

/// Ed25519 to X25519 key conversion using Swift Crypto and BigInt.
/// Matches libsodium's crypto_sign_ed25519_*_to_curve25519 behavior.

private let curve25519Prime: BigUInt = (BigUInt(1) << 255) - 19
private let two255: BigUInt = BigUInt(1) << 255

/// Convert Ed25519 public key (32 bytes, little-endian) to X25519 public key (32 bytes).
func ed25519PublicKeyToCurve25519(_ ed25519PublicKey: Data) throws -> Data {
    guard ed25519PublicKey.count == 32 else {
        throw X25519.X25519ConversionError.publicKeyConversionFailed(code: -1)
    }
    let y = bigUIntFromLittleEndian32(ed25519PublicKey) & (two255 - 1)
    let one = BigUInt(1)
    let oneMinusY = y == 0 ? one : curve25519Prime + one - y
    guard oneMinusY != 0 else {
        throw X25519.X25519ConversionError.publicKeyConversionFailed(code: -2)
    }
    let inv = modInverse(oneMinusY, curve25519Prime)
    let u = ((one + y) * inv) % curve25519Prime
    return dataFromBigUInt32(u)
}

/// Convert Ed25519 private key (32 bytes seed, or 64 bytes seed+pubkey as in TweetNaCl) to X25519 private key (32 bytes).
/// Uses SHA512(seed)[0..<32] then clamping (per libsodium/signal).
func ed25519PrivateKeyToCurve25519(_ ed25519PrivateKey: Data) throws -> Data {
    let seed: Data = ed25519PrivateKey.count >= 32 ? Data(ed25519PrivateKey.prefix(32)) : ed25519PrivateKey
    guard seed.count == 32 else {
        throw X25519.X25519ConversionError.privateKeyConversionFailed(code: -1)
    }
    let h = SHA512.hash(data: seed)
    var bytes = [UInt8](h.prefix(32))
    bytes[0] &= 248
    bytes[31] &= 127
    bytes[31] |= 64
    return Data(bytes)
}

private func modInverse(_ a: BigUInt, _ m: BigUInt) -> BigUInt {
    modPow(a, m - 2, m)
}

private func modPow(_ base: BigUInt, _ exp: BigUInt, _ mod: BigUInt) -> BigUInt {
    var result = BigUInt(1)
    var base = base % mod
    var exp = exp
    while exp > 0 {
        if exp % 2 == 1 {
            result = (result * base) % mod
        }
        base = (base * base) % mod
        exp = exp / 2
    }
    return result
}

private func bigUIntFromLittleEndian32(_ data: Data) -> BigUInt {
    var value = BigUInt(0)
    for (i, byte) in data.enumerated() {
        value += BigUInt(byte) << (i * 8)
    }
    return value
}

private func dataFromBigUInt32(_ value: BigUInt) -> Data {
    var v = value
    var bytes = [UInt8](repeating: 0, count: 32)
    for i in 0..<32 {
        bytes[i] = UInt8(truncatingIfNeeded: v % 256)
        v = v / 256
    }
    return Data(bytes)
}
