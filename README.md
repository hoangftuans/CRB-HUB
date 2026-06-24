# CRB Hub — Cereblix (CRB) iOS Wallet

🇻🇳 [Tiếng Việt](#tiếng-việt) | 🇺🇸 [English](#english)

---

## English

[![Platform](https://img.shields.io/badge/Platform-iOS%2018.0%2B-blue.svg)]()
[![Language](https://img.shields.io/badge/Language-Swift%205.0%20%2F%20SwiftUI-orange.svg)]()
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**CRB Hub** is a premium native iOS non-custodial wallet built using SwiftUI for the Cereblix (CRB) blockchain. The application delivers robust local key management, mining dashboard statistics, P2P exchange trading, and multi-language support (11 languages) with local fiat currency conversion.

### 👤 Project Owner
This project is owned and maintained by **Hoang Tuan Nguyen**.

> [!IMPORTANT]
> **Cereblix Native & Secured**: This app runs **100% on the Cereblix network**. All private-key access is protected through iOS Keychain access control (`kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` + current biometric set). Wallet passwords are used for app unlock and verifier checks only; no password-encrypted private-key fallback copy is stored. Your private keys never leave your device.

### 🌟 Key Features
* **Non-Custodial Wallet Management**: Generate a random ed25519 keypair or import via a 64-character hex private key. Securely encrypted and stored locally in the iOS Keychain.
* **Biometric Verification**: Verify sensitive actions (key export, trade actions) using Face ID / Touch ID.
* **Mining Monitor**: Track personal hashrates, worker statuses (Active/Idle), and Pool stats (Pool hashrate, active miners, blocks, pool fees, minimum payout). Includes a one-tap run command copy helper.
* **P2P OTC Market & Trading**: Decentralized P2P login using ed25519 wallet signatures. View real-time order books, tickers, and recent trades. Manage complete trade lifecycles (Lock, Complete, Cancel, Appeal) with encrypted chat, block list controls, and feedback.
* **USDT Wallet & SafeTrade Integration**: Link SafeTrade API credentials, sync supported USDT deposit wallets, choose default P2P receiving wallets per rail, view balances, and prepare protected USDT transfers for P2P escrow workflows.
* **Production Transaction Protection**: CRB sends require biometric-protected Keychain access. USDT SafeTrade withdrawals unlock the API secret from biometric-protected Keychain before request signing.
* **Localization & Fiat Conversion**: Supports 11 languages out-of-the-box (English, Vietnamese, Russian, Chinese, Korean, Japanese, Thai, Indonesian, Spanish, French, German). Converts CRB values to local fiat currencies dynamically (USD, VND, EUR, CNY, JPY, KRW, THB, IDR, RUB, GBP) with offline caching.
* **Decimal-Safe Money Handling**: CRB/USDT prices, fiat rates, balances, and P2P amounts are handled with `Decimal` or integer base units to preserve small values such as `0.000x`.

### Recent Production Hardening
* Upgraded Keychain private-key storage to passcode-required, this-device-only, biometric-current-set access control.
* Hardened wallet password handling with PBKDF2-HMAC-SHA256 verification, stronger password policy, lockout after repeated failures, and no password-encrypted private-key fallback storage.
* Added app auto-lock/unlock for wallet content after backgrounding.
* Added custom-node signing metadata validation against the official Cereblix node before CRB transaction signing.
* Moved SafeTrade API key into Keychain and protected the SafeTrade API secret with biometric Keychain access control.
* Switched Cereblix TLS pinning toward public-key pinning while keeping the legacy leaf certificate pin as a compatibility fallback.
* Implemented real CRB transaction signing and broadcast payloads aligned with Cereblix transaction formats.
* Hardened P2P login signing against replay by validating the canonical OTC challenge before signing.
* Linked USDT wallets directly into P2P offer creation, take-offer flows, trade detail, and persisted wallet bindings.
* Added SafeTrade API settings, connection test, USDT deposit wallet sync, spot balance retrieval, and withdraw request plumbing.
* Restricted P2P USDT rails to the project-supported networks and validates receiving addresses before create/take actions.
* Replaced floating-point money paths with `Decimal` caches, formatting, conversion, and token-balance parsing.
* Hardened custom node URLs, URL query construction, clipboard handling, app background privacy, app version display, and Settings scrolling behavior.
* Standardized P2P trading labels (SELL/BUY) and fully synchronized 11-language localizations across all P2P screens (tickers, stats, order books, empty states, chat, and challenge login steps).
* Locked settings views horizontally (`ScrollView(.vertical)`) and wrapped/resized settings sections to prevent horizontal dragging or scrolling overflow on smaller devices.
* Made application version display robust and dynamic via bundle dictionaries query, with fallback defaults for Xcode Previews and Simulator builds.

### 🛠️ Architecture & Tech Stack
* **UI**: SwiftUI (iOS 18.0+)
* **Crypto**: Apple CryptoKit (ed25519 signatures)
* **Storage**: iOS Keychain Services (`kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly`, biometric access control) & UserDefaults
* **State Management**: `@Observable` architecture with view models refreshing dynamically

```mermaid
graph TD
    A[CRB_HubApp] --> B[ContentView - TabView]
    B --> C[WalletHomeView]
    B --> D[MiningDashboardView]
    B --> E[P2PMarketView]
    B --> F[SettingsView]
    
    C --> G[WalletViewModel]
    D --> H[MiningViewModel]
    E --> I[P2PViewModel]
    
    G --> J[CereblixAPIClient]
    H --> K[MiningAPIClient]
    I --> L[P2PAPIClient]
    
    C --> N[WalletCore]
    N --> O[KeychainStore]
    O --> P[iOS Keychain + Face ID]
```

### 🌍 Supported Languages
* `en` (English) - USD (United States Dollar)
* `vi` (Tiếng Việt) - VND (Vietnamese Dong)
* `ru` (Русский) - RUB (Russian Ruble)
* `zh-Hans` (简体中文) - CNY (Chinese Yuan)
* `ko` (한국어) - KRW (Korean Won)
* `ja` (日本語) - JPY (Japanese Yen)
* `th` (ไทย) - THB (Thai Baht)
* `id` (Bahasa Indonesia) - IDR (Indonesian Rupiah)
* `es` (Español) - EUR / USD (Euro / Dollar)
* `fr` (Français) - EUR (Euro)
* `de` (Deutsch) - EUR (Euro)

### 🚀 Getting Started
1. Clone the repository:
   ```bash
   git clone https://github.com/[username]/CRBHub.git
   cd CRBHub
   ```
2. Open the Xcode workspace:
   ```bash
   open "CRB Hub/CRB Hub.xcodeproj"
   ```
3. Set your **Signing & Capabilities** team under project settings.
4. Run the project (`Cmd + R`) on an iOS 18.0+ Simulator or real device.

### 📦 App Store Submission Readiness
* **Privacy Description**: `NSFaceIDUsageDescription` is preconfigured in `Info.plist` to explain how Face ID protects keys locally.
* **Export Compliance**: Uses Apple's standard CryptoKit. When submitting to App Store Connect, select **Yes** for the export compliance exemption as it utilizes standard built-in operating system encryption.
* **Age Rating**: Due to real-time P2P exchange and financial transaction capabilities, age rating should be configured as **17+**.

---

## Tiếng Việt

[![Platform](https://img.shields.io/badge/N%E1%BB%81n%20T%E1%BA%A3ng-iOS%2018.0%2B-blue.svg)]()
[![Language](https://img.shields.io/badge/Ng%C3%B4n%20Ng%E1%BB%AF-Swift%205.0%20%2F%20SwiftUI-orange.svg)]()
[![License](https://img.shields.io/badge/Gi%E1%BA%A5y%20Ph%C3%A9p-MIT-green.svg)](LICENSE)

**CRB Hub** là ứng dụng ví phi lưu ký (non-custodial wallet) chạy native trên hệ điều hành iOS dành cho mạng lưới Cereblix (CRB). Ứng dụng cung cấp các tính năng quản lý tài sản bảo mật cao, theo dõi khai thác (mining monitoring), trao đổi giao dịch P2P OTC và tích hợp đa ngôn ngữ toàn diện.

### 👤 Chủ Sở Hữu
Dự án được sở hữu và phát triển bởi **Hoang Tuan Nguyen**.

> [!IMPORTANT]
> **Hoạt động 100% trên Cereblix**: Dự án được xây dựng và chạy **100% trực tiếp trên mạng lưới Cereblix**. Mọi đường đọc khóa bí mật đều đi qua Keychain access control (`kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` + bộ sinh trắc học hiện tại). Mật khẩu ví chỉ dùng cho mở khóa app và xác minh, không lưu thêm bản khóa bí mật mã hóa bằng mật khẩu. Khóa bí mật của bạn không bao giờ rời khỏi thiết bị.

### 🌟 Tính Năng Chính
* **Quản Lý Ví Bảo Mật**: Tạo ví mới (sinh cặp khóa ed25519 ngẫu nhiên) hoặc nhập ví cũ (qua khóa bí mật Hex 64 ký tự). Khóa được mã hóa và lưu trữ an toàn cục bộ trong iOS Keychain.
* **Bảo Vệ Sinh Trắc Học**: Xác thực Face ID / Touch ID để phê duyệt giao dịch và xuất khóa bảo mật.
* **Theo Dõi Khai Thác**: Hiển thị hashrate cá nhân, hashrate pool, thợ đào đang hoạt động, khối tìm thấy, phí pool và hạn mức thanh toán. Hỗ trợ sao chép lệnh chạy miner chỉ với 1 lượt chạm.
* **Thị Trường P2P OTC**: Đăng nhập P2P không mật khẩu sử dụng chữ ký số ed25519. Xem sổ lệnh, ticker và lịch sử giao dịch. Quản lý trạng thái giao dịch (Khóa quỹ, Hoàn thành, Hủy, Khiếu nại) đi kèm phòng chat trực tiếp mã hóa, chặn người dùng và đánh giá tín nhiệm.
* **Ví USDT & SafeTrade**: Liên kết API SafeTrade, đồng bộ ví nhận USDT theo mạng được hỗ trợ, chọn ví mặc định cho P2P, xem số dư và chuẩn bị luồng chuyển USDT có xác thực.
* **Bảo Vệ Giao Dịch Production**: Chuyển CRB yêu cầu Keychain sinh trắc học. Rút USDT qua SafeTrade mở khóa API secret từ Keychain sinh trắc học trước khi ký request.
* **Đa Ngôn Ngữ & Quy Đổi Ngoại Tệ**: Hỗ trợ tự động 11 ngôn ngữ phổ biến nhất dựa trên ngôn ngữ thiết bị. Quy đổi số dư CRB sang tỷ giá fiat nội địa tương ứng với vùng (Region) của điện thoại (VND, USD, EUR, CNY, JPY, KRW, THB, IDR, RUB, GBP) với cơ chế lưu đệm offline.
* **Tính Toán Tiền Bằng Decimal**: Giá CRB/USDT, tỷ giá fiat, số dư và khối lượng P2P dùng `Decimal` hoặc đơn vị gốc để giữ chính xác các giá trị rất nhỏ như `0.000x`.

### Nâng Cấp Production Gần Đây
* Nâng bảo vệ Keychain lên passcode-required, this-device-only và biometric-current-set.
* Tăng cường mật khẩu ví bằng PBKDF2-HMAC-SHA256, chính sách mật khẩu mạnh hơn, lockout khi nhập sai nhiều lần và loại bỏ bản private-key fallback mã hóa bằng mật khẩu.
* Thêm app auto-lock/unlock sau khi ứng dụng vào background.
* Thêm kiểm tra metadata ký giao dịch từ custom node với official Cereblix node trước khi ký CRB.
* Chuyển SafeTrade API key vào Keychain và bảo vệ SafeTrade API secret bằng Keychain sinh trắc học.
* Chuyển TLS pinning của Cereblix sang hướng public-key pinning, giữ leaf pin cũ làm fallback tương thích.
* Thêm mật khẩu ví dự phòng cho các luồng mở khóa khi Face ID / Touch ID thất bại.
* Kích hoạt ký và broadcast giao dịch CRB thật theo định dạng giao dịch Cereblix.
* Siết P2P login signing bằng cách xác thực challenge OTC chuẩn trước khi ký.
* Liên kết ví USDT trực tiếp vào create offer, take offer, trade detail và lưu binding theo giao dịch.
* Thêm cài đặt SafeTrade API, test kết nối, đồng bộ ví nạp USDT, xem số dư spot và plumbing withdraw.
* Giới hạn rail USDT cho P2P theo mạng dự án hỗ trợ và validate địa chỉ trước khi tạo/take lệnh.
* Chuyển các đường tiền khỏi `Double`, dùng `Decimal` cho cache giá, tỷ giá, formatter, balance và P2P amount.
* Hardening custom node URL, URL query, clipboard, che app khi background, hiển thị version và khóa scroll ngang ở Settings.
* Chuẩn hóa và đồng bộ hóa ngôn ngữ sàn giao dịch P2P hoàn chỉnh (nhãn MUA/BÁN, thông số ticker, sổ lệnh, trạng thái trống, đoạn chat trực tiếp, và các bước đăng nhập bảo mật) hỗ trợ tiếng Việt và 11 ngôn ngữ.
* Khóa cố định chiều ngang Settings (`ScrollView(.vertical)`), thu gọn và tối ưu hóa các section cài đặt để chống trượt/kéo ngang màn hình trên thiết bị nhỏ (như iPhone SE/12 mini).
* Tự động hiển thị động phiên bản ứng dụng trong About lấy trực tiếp từ Bundle, tích hợp cơ chế fallback dự phòng chống lỗi hiển thị "Unknown" khi chạy Xcode Preview hoặc Simulator.

### 🛠️ Công Nghệ & Kiến Trúc
* **Giao Diện**: SwiftUI (iOS 18.0+)
* **Mã Hóa**: Apple CryptoKit (chữ ký số ed25519)
* **Lưu Trữ**: Keychain Services (`kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly`, biometric access control) & UserDefaults
* **Quản Lý Trạng Thái**: Kiến trúc `@Observable` với các View Models cập nhật thời gian thực

### 🌍 Ngôn Ngữ Hỗ Trợ
* `en` (English) - USD (Đô la Mỹ)
* `vi` (Tiếng Việt) - VND (Đồng Việt Nam)
* `ru` (Русский) - RUB (Rúp Nga)
* `zh-Hans` (简体中文) - CNY (Nhân dân tệ)
* `ko` (한국어) - KRW (Won Hàn Quốc)
* `ja` (日本語) - JPY (Yên Nhật)
* `th` (ไทย) - THB (Baht Thái)
* `id` (Bahasa Indonesia) - IDR (Rupiah Indonesia)
* `es` (Español) - EUR / USD (Euro / Đô la)
* `fr` (Français) - EUR (Euro)
* `de` (Deutsch) - EUR (Euro)

### 🚀 Hướng Dẫn Cài Đặt & Chạy Dự Án
1. Clone mã nguồn:
   ```bash
   git clone https://github.com/hoangftuans/CRB-HUB
   cd CRBHub
   ```
2. Mở dự án trong Xcode:
   ```bash
   open "CRB Hub/CRB Hub.xcodeproj"
   ```
3. Thiết lập mục **Signing & Capabilities** bằng tài khoản Developer cá nhân hoặc doanh nghiệp.
4. Nhấn `Cmd + R` để khởi chạy ứng dụng trên Simulator hoặc thiết bị chạy iOS 18.0+.

### 📦 Kế Hoạch Đưa Lên App Store
* **Quyền Riêng Tư**: Quyền Face ID `NSFaceIDUsageDescription` đã cấu hình sẵn trong `Info.plist` giải thích cách Face ID bảo vệ khóa ví cục bộ.
* **Chứng Chỉ Mã Hóa**: Ứng dụng sử dụng CryptoKit gốc của hệ điều hành. Khi gửi bản build lên App Store Connect, hãy chọn **Yes** cho mục miễn trừ chứng nhận xuất khẩu mật mã (Export Compliance Exemption).
* **Độ Tuổi**: Đánh giá độ tuổi nên được chọn ở mức **17+** do tính năng quản lý tài chính và giao dịch P2P tiền điện tử.

---

## 📄 License

This project is licensed under the terms of the **MIT License**. See [LICENSE](LICENSE) for details.
Dự án được cấp phép hoạt động theo các điều khoản của **MIT License**. Xem file [LICENSE](LICENSE) để biết thêm chi tiết.
