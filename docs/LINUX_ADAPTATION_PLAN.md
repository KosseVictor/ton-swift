# План адаптации TonSwift под Linux

## Текущее состояние

- **Цель**: библиотека TON (ячейки, кошельки, ключи, мнемоники) на чистом Swift.
- **Сейчас**: только `platforms: [ .iOS(.v13) ]`, сборка и тесты только под macOS/iOS.
- **Проблемы для Linux**: использование Apple-специфичных API (CommonCrypto, Security.framework, CryptoKit, Clibsodium).

---

## 1. Зависимости и платформы

### 1.1 Package.swift

| Действие | Детали |
|----------|--------|
| Добавить платформы | В `platforms` добавить `.macOS(.v10_15)` и `.linux` (или конкретную версию glibc, если нужна). |
| Добавить swift-crypto | `apple/swift-crypto` даёт API, совместимый с CryptoKit, на Linux (реализация на BoringSSL). Использовать для SHA256, HMAC-SHA512, PBKDF2, при необходимости AES и Curve25519. |
| Проверить BigInt | Обычно кроссплатформенный, оставить как есть. |
| TweetNacl | Использование: подписи (NaclSign), ключи из seed. Проверить исходники на наличие только Foundation/Swift; при наличии только Darwin-кода — заменить на реализацию на Swift Crypto или условную компиляцию. |
| Sodium (Clibsodium) | Нужен для X25519 (`crypto_scalarmult`) и конвертации Ed25519↔X25519 (`crypto_sign_ed25519_*_to_curve25519`). Варианты: (A) собрать swift-sodium на Linux с системным libsodium; (B) на Linux заменить эти вызовы на Swift Crypto (Curve25519, при необходимости конвертация ключей). |

Рекомендация: в `Package.swift` добавить зависимость на `swift-crypto` и платформы macOS + Linux; Sodium оставить для Apple, для Linux завести отдельную реализацию X25519/конвертаций на Swift Crypto (см. раздел 4).

---

## 2. Криптография: замена Apple-специфичного кода

### 2.1 Список файлов и API

| Файл | Текущий API | Действие |
|------|-------------|----------|
| `Source/TonSwift/Util/RandomBytes.swift` | `SecRandomCopyBytes` (Security) | На Linux: чтение из `/dev/urandom` или `Glibc.getrandom`; обернуть в `#if os(Linux)` / `#else` (Darwin). |
| `Source/TonSwift/Util/SHA256.swift` | `CommonCrypto` (`CC_SHA256`) | Заменить на `Crypto.SHA256` (или `CryptoKit` на Apple) через общий тип/протокол или `#if canImport(CryptoKit) import CryptoKit #else import Crypto`. |
| `Source/TonSwift/Crypto/HMAC_SHA512.swift` | `CommonCrypto` (`CCHmac`, SHA512) | Заменить на `HMAC<SHA512>` из CryptoKit/Crypto. |
| `Source/TonSwift/Mnemonic/Primitives/hmacSha512.swift` | `CommonCrypto` (CCHmac с строками) | Аналогично — считать данные из строк и использовать HMAC<SHA512>. |
| `Source/TonSwift/Mnemonic/Primitives/pbkdf2Sha512.swift` | `CommonCrypto` (`CCKeyDerivationPBKDF`, SHA512) | В Swift Crypto есть PBKDF2; проверить поддержку SHA512. Если есть — перейти на него; если только SHA256 — оставить условную компиляцию: Darwin — CC*, Linux — своя реализация PBKDF2 поверх HMAC<SHA512> из Crypto. |
| `Source/TonSwift/Crypto/AES_CBC.swift` | `CommonCrypto` (`CCCrypt`, AES-CBC) | Swift Crypto/CryptoKit поддерживают AES. Проверить наличие именно AES-CBC (не только GCM). При отсутствии — обёртка над BoringSSL через Crypto или условная компиляция с реализацией только под Linux (например, через Crypto). |
| `Source/TonSwift/Crypto/25519/Ed25519.swift` | `CryptoKit` (HMAC<SHA512>, SymmetricKey) | Импорт: `#if canImport(CryptoKit) import CryptoKit #else import Crypto`. Остальной код (HMAC, ключи) без изменений, т.к. Swift Crypto повторяет API CryptoKit. |
| `Source/TonSwift/Crypto/25519/X25519.swift` | `Clibsodium` (crypto_scalarmult, ed25519↔curve25519) | См. раздел 4. |

### 2.2 Единый импорт крипто-модуля

- Ввести вспомогательный модуль или в каждом из файлов использовать условный импорт:
  - на Apple: `import CryptoKit`;
  - на Linux: `import Crypto`.
- Либо один общий файл (например, `CryptoCompat.swift`), который реэкспортирует нужные типы под разными платформами, чтобы остальной код не содержал `#if`.

---

## 3. Случайные байты (RandomBytes)

- **Darwin**: оставить `SecRandomCopyBytes`.
- **Linux**:
  - Предпочтительно: `Glibc.getrandom` (если доступен в целевом Swift/Glibc).
  - Запасной вариант: открыть `/dev/urandom` и прочитать `length` байт.
- Интерфейс `RandomBytes.generate(length:) throws -> Data` не менять, только внутреннюю реализацию развести по `#if os(Linux)` / `#else`.

---

## 4. X25519 и конвертация Ed25519 ↔ X25519

- **Текущая реализация**: `X25519.swift` использует Clibsodium:
  - `crypto_scalarmult` — общий секрет X25519;
  - `crypto_sign_ed25519_pk_to_curve25519` / `crypto_sign_ed25519_sk_to_curve25519` — конвертация ключей в расширениях `PublicKey`/`PrivateKey`.
- **Варианты для Linux**:
  1. **Сборка swift-sodium на Linux**: установка `libsodium-dev` и добавление в SPM системной библиотеки (если пакет это поддерживает). Тогда код X25519 можно не трогать.
  2. **Замена на Swift Crypto на Linux**: использовать `Curve25519.KeyAgreement` для X25519; конвертацию Ed25519→X25519 реализовать вручную (формулы есть в стандартах) или взять из другого кроссплатформенного Swift-кода. В `X25519.swift` сделать `#if os(Linux)` ветку с вызовами Swift Crypto и сохранением тех же типов `X25519.PrivateKey`/`PublicKey`.

Рекомендация: сначала попробовать вариант 1; при проблемах с сборкой или версиями libsodium — вариант 2 с условной компиляцией.

---

## 5. TweetNacl

- **Использование**: кошельки (WalletV1–V5, WalletV5Beta), мнемоника (ключи из seed).
- Проверить исходники пакета на наличие `import Darwin`, `import Security`, `CommonCrypto`, `CryptoKit` и т.п.
- Если только Foundation + чистый Swift/C — высока вероятность работы на Linux без изменений.
- Если есть зависимость от Apple-API — либо форк с условной компиляцией, либо замена под Linux на реализацию на Swift Crypto (подпись, ключи), что потребует больше работы.

---

## 6. Foundation и прочее

- `NSRegularExpression` (в `Ed25519.swift`) входит в Foundation на Linux — менять не нужно.
- Остальные импорты `Foundation` (Data, String, и т.д.) кроссплатформенные.
- Проверить тесты на использование классов, доступных только на Apple (UIKit, AppKit) — в юнит-тестах библиотеки их быть не должно.

---

## 7. CI и сборка

| Шаг | Действие |
|-----|-----------|
| Workflow | В `.github/workflows/swift.yml` добавить job на `ubuntu-latest`. |
| Сборка | `swift build` в корне репозитория (или нужной директории с пакетом). |
| Тесты | `swift test`. |
| Кэш | При необходимости кэшировать `.build` и зависимости (например, через `swift package resolve`). |
| Пример (Example) | Оставить текущий job на `macos-latest` для iOS/macOS; Linux job только для библиотеки (SPM). |

---

## 8. Порядок внедрения (краткий)

1. **Package.swift**: добавить платформы (macOS, Linux) и зависимость `swift-crypto`.
2. **RandomBytes**: реализовать Linux-ветку (`/dev/urandom` или getrandom).
3. **SHA256, HMAC_SHA512, hmacSha512**: перевести на CryptoKit/Crypto с условным импортом.
4. **pbkdf2Sha512**: перевести на Swift Crypto или собственную реализацию PBKDF2 на HMAC<SHA512> под Linux.
5. **AES_CBC**: заменить на Crypto/CryptoKit с условной компиляцией при необходимости.
6. **Ed25519**: добавить `#if canImport(CryptoKit) ... #else import Crypto`.
7. **X25519 / Sodium**: проверить сборку swift-sodium на Linux; при неудаче — реализация на Swift Crypto только для Linux.
8. **TweetNacl**: проверить совместимость с Linux; при необходимости — условная компиляция или замена.
9. **CI**: добавить Linux job с `swift build` и `swift test`.
10. **Документация**: обновить README (поддержка Linux, требования: Swift 5.x, на Linux — libsodium при выборе варианта с Sodium).

---

## 9. Риски и проверки

- **Версии Swift**: убедиться, что используемые API Swift Crypto и Foundation доступны на минимальной поддерживаемой версии Swift (сейчас в пакете 5.5).
- **Совместимость результатов**: после замены криптографии прогонять все тесты (мнемоника, ключи, подписи, кошельки) и по возможности сравнить вывод с эталонными векторами на обеих платформах.
- **libsodium на Linux**: при использовании swift-sodium под Linux явно зафиксировать в README необходимость установки `libsodium-dev` (или аналога) и версию.

После выполнения плана библиотека сможет собираться и проходить тесты на Linux при сохранении поддержки iOS/macOS.
