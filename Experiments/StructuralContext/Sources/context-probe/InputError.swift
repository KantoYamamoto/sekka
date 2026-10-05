import Foundation

/// The text reader knows the source path even when Foundation omits userInfo.
struct SourceReadFailure: Error {
  let path: String
  let cause: any Error
}

/// Stable input failure facts, without Foundation's nested error descriptions.
func inputErrorMessage(_ error: any Error) -> String {
  if let source = error as? SourceReadFailure {
    return "Unable to read Swift source as UTF-8 \(String(reflecting: source.path)): \(inputErrorMessage(source.cause))"
  }
  let failure = error as NSError
  guard failure.domain == NSCocoaErrorDomain || failure.domain == NSPOSIXErrorDomain else {
    return String(describing: error)
  }
  let reason: String
  if failure.domain == NSCocoaErrorDomain {
    switch failure.code {
    case CocoaError.Code.fileReadNoSuchFile.rawValue: reason = "Input unavailable"
    case CocoaError.Code.fileReadNoPermission.rawValue: reason = "Input is not readable"
    case CocoaError.Code.fileReadInapplicableStringEncoding.rawValue: reason = "Input is not UTF-8"
    case CocoaError.Code.fileReadUnsupportedScheme.rawValue: reason = "Unsupported input"
    default: reason = "Input read failed"
    }
  } else {
    reason = "Input read failed"
  }
  let path = failure.userInfo[NSFilePathErrorKey] as? String
    ?? (failure.userInfo[NSURLErrorKey] as? URL).flatMap { $0.isFileURL ? $0.path : nil }
  let location = path.map { " path=" + String(reflecting: $0) } ?? ""
  return "\(reason) [\(failure.domain):\(failure.code)]\(location)"
}
