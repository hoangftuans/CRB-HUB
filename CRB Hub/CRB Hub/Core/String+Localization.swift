import Foundation

extension String {
    /// Returns the localized version of this string
    var localized: String {
        NSLocalizedString(self, comment: "")
    }
    
    /// Returns a localized formatted string with arguments
    func localized(with arguments: CVarArg...) -> String {
        String(format: self.localized, arguments: arguments)
    }
}
