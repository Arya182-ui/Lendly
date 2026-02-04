# Lendly Security & Reliability Review

## Scope
This review covers the Flutter client code under `lib/` with a focus on security, reliability, and performance risks surfaced by a lightweight static scan and targeted file review.

## Methods
- Manual review of configuration, authentication, session, and logging utilities.
- Static scan for high-risk patterns such as plaintext logging, `print`/`debugPrint`, and non-HTTPS handling.

## Key Findings (Security & Privacy)
### 1) Sensitive data can be logged in plaintext
- `AppLogger.logApiRequest` logs full request bodies and headers when debug mode is enabled, which can include authentication tokens or PII if not sanitized before logging.【F:lib/services/app_logger.dart†L171-L205】
- `ApiClient` logs token length and other authentication metadata; `FirebaseAuthService` logs token length and user identifiers, which increases risk if logs are exfiltrated or retained on device in cleartext.【F:lib/services/api_client.dart†L468-L510】【F:lib/services/firebase_auth_service.dart†L93-L122】
- Multiple services and screens use `print`/`debugPrint` heavily, which can leak internal state or user data in production builds if not disabled or redacted.【F:lib/services/group_service.dart†L22-L47】【F:lib/screens/home/home_screen.dart†L141-L262】

**Required changes**
- Introduce a centralized log redaction/sanitization policy for headers, tokens, and PII before they reach `AppLogger` (e.g., mask `Authorization`, emails, user IDs, and tokens).【F:lib/services/app_logger.dart†L171-L205】
- Replace `print`/`debugPrint` in production paths with the structured logger and ensure debug logs are compiled out or disabled in production builds.【F:lib/services/group_service.dart†L22-L47】【F:lib/screens/home/home_screen.dart†L141-L262】

### 2) Non-HTTPS URLs are accepted for profile and avatar links
- Avatar and profile URL validations explicitly allow `http://` URLs, which can expose user traffic to MITM attacks or content injection in transit.【F:lib/utils/avatar_utils.dart†L23-L49】【F:lib/screens/profile/profile_screen.dart†L1106-L1203】

**Required changes**
- Enforce HTTPS-only URL handling for user-provided links and avatar URLs, or explicitly whitelist known hosts while rejecting `http://` schemes.【F:lib/utils/avatar_utils.dart†L23-L49】【F:lib/screens/profile/profile_screen.dart†L1106-L1203】

### 3) Tokens stored in SharedPreferences (non-secure)
- `SessionService` persists an `auth_token` in `SharedPreferences`, which is not secure storage on mobile platforms.【F:lib/services/session_service.dart†L73-L129】

**Required changes**
- Remove token storage from `SharedPreferences` and rely solely on `flutter_secure_storage` (or platform Keychain/Keystore). If backward compatibility is required, migrate and wipe the legacy value on upgrade.【F:lib/services/session_service.dart†L73-L129】

## Reliability & Stability Findings
### 4) Excessive debug logging may degrade performance
- The home screen uses extensive `debugPrint` statements inside hot paths and API calls, which can slow UI rendering and inflate logs in development and production if not gated.【F:lib/screens/home/home_screen.dart†L141-L262】

**Required changes**
- Introduce log level gating for UI screens and remove high-volume logging from production builds to reduce runtime overhead.【F:lib/screens/home/home_screen.dart†L141-L262】

### 5) Network timeout consistency and error handling
- Network timeouts are defined in `EnvConfig`, but many individual requests still use per-request timeouts. Ensure all services use the shared config to avoid inconsistent behavior and timeouts across endpoints.【F:lib/config/env_config.dart†L39-L83】【F:lib/services/group_service.dart†L12-L24】

**Required changes**
- Standardize all request timeouts on `EnvConfig` values and ensure error mapping is consistent across services (e.g., unify network vs. server error categorization).【F:lib/config/env_config.dart†L39-L83】【F:lib/services/group_service.dart†L12-L24】

## Optimization Opportunities
- **Log volume reduction**: Reduce repeated logging and wrap `debugPrint` behind `kDebugMode` or `EnvConfig.enableDebugMode` to minimize UI thread overhead.【F:lib/screens/home/home_screen.dart†L141-L262】
- **Centralized API configuration**: Keep `ApiConfig` as the single source of truth for base URLs and headers, and remove any lingering hardcoded URLs elsewhere if discovered during deeper audits.【F:lib/config/api_config.dart†L1-L34】【F:lib/config/env_config.dart†L23-L36】

## Suggested Follow-Up Work
1. Add a security-focused lint rule set (or custom lint rules) to prevent `print`/`debugPrint` in production code paths and to detect `http://` usage.
2. Add automated log redaction tests covering `AppLogger.logApiRequest` and any error reporting pipeline.
3. Perform an end-to-end review of API response handling to ensure safe parsing of unexpected responses and prevent runtime crashes.

---

If you want, I can implement the required changes in a follow-up PR.
