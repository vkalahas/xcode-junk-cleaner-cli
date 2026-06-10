import Foundation

public struct Colorizer {
    public static let isColorEnabled: Bool = {
        // Only enable color when writing directly to a TTY (terminal)
        return isatty(STDOUT_FILENO) != 0
    }()
    
    public enum Color: String {
        case black = "\u{001B}[0;30m"
        case red = "\u{001B}[0;31m"
        case green = "\u{001B}[0;32m"
        case yellow = "\u{001B}[0;33m"
        case blue = "\u{001B}[0;34m"
        case magenta = "\u{001B}[0;35m"
        case cyan = "\u{001B}[0;36m"
        case white = "\u{001B}[0;37m"
        case bold = "\u{001B}[1m"
        case boldGreen = "\u{001B}[1;32m"
        case boldYellow = "\u{001B}[1;33m"
        case boldRed = "\u{001B}[1;31m"
        case boldCyan = "\u{001B}[1;36m"
        case reset = "\u{001B}[0;0m"
    }
    
    public static func color(_ text: String, _ color: Color) -> String {
        guard isColorEnabled else { return text }
        return "\(color.rawValue)\(text)\(Color.reset.rawValue)"
    }
}

extension String {
    public func colored(_ color: Colorizer.Color) -> String {
        return Colorizer.color(self, color)
    }
}
