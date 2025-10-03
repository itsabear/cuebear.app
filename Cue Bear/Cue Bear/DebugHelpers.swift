import Foundation

/// Debug-only print function that compiles out in Release builds
/// This ensures no logging in production builds for privacy and performance
func debugPrint(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    #if DEBUG
    let output = items.map { "\($0)" }.joined(separator: separator)
    Swift.print(output, terminator: terminator)
    #endif
}