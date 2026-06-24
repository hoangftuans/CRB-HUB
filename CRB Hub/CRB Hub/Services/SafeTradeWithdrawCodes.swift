import Foundation

struct SafeTradeWithdrawCodes {
    var emailCode: String
    var otpCode: String
    var phoneCode: String

    nonisolated init(emailCode: String = "", otpCode: String = "", phoneCode: String = "") {
        self.emailCode = emailCode
        self.otpCode = otpCode
        self.phoneCode = phoneCode
    }
}

enum SafeTradeWithdrawCodeType: String {
    case email
    case phone
}
