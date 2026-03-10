import Foundation

#if canImport(Security)
import Security
#endif

public struct RandomBytes {
  public enum Error: Swift.Error {
    case failedGenerate(statusCode: Int)
    case other
  }
  
  public static func generate(length: Int) throws -> Data {
#if os(Linux)
    return try generateLinux(length: length)
#else
    return try generateDarwin(length: length)
#endif
  }
  
#if os(Linux)
  private static func generateLinux(length: Int) throws -> Data {
    guard let file = FileHandle(forReadingAtPath: "/dev/urandom") else {
      throw Error.failedGenerate(statusCode: -1)
    }
    defer { try? file.close() }
    let data = file.readData(ofLength: length)
    guard data.count == length else {
      throw Error.failedGenerate(statusCode: -1)
    }
    return data
  }
#else
  private static func generateDarwin(length: Int) throws -> Data {
    var outputBuffer = Data(count: length)
    let resultCode = try outputBuffer.withUnsafeMutableBytes {
      guard let baseAddress = $0.baseAddress else { throw Error.other }
      return SecRandomCopyBytes(kSecRandomDefault, length, baseAddress)
    }
    guard resultCode == errSecSuccess else {
      throw Error.failedGenerate(statusCode: Int(resultCode))
    }
    return outputBuffer
  }
#endif
}
