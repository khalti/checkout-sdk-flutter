# [2.0.0-beta.1] - Oct 15, 2026
**Pre-release**

**Breaking changes**
- Remove `pidx` from `KhaltiPayConfig`. It is now read from the `pidx` query parameter of `paymentUrl`, and `Khalti.init` throws an `ArgumentError` if it is missing
- `Khalti.open` now tries the Khalti app first (Android and iOS) and only falls back to the webview if it isn't installed
- `Khalti.open` now returns `Future<void>` instead of `void`
- Add `KhaltiEvent.cancelled`, `KhaltiEvent.paymentExpired` and `KhaltiEvent.kpgLoadFailure`, reported through `onMessage` when paying via the Khalti app. Exhaustive `switch` statements on `KhaltiEvent` need updating
- The package now ships an Android plugin (new native module with `androidx.activity` and Kotlin coroutines dependencies). The minimum supported Android SDK version is 24

**Changes**
- Android: launch the Khalti app and map its result (paid, already paid, expired, cancelled, error) to `onPaymentResult` or `onMessage`
- iOS: open the Khalti app through its universal link, falling back to the `khalti://` scheme, and verify the payment when the user returns to the app
- `Khalti.close` does nothing when the payment is made in the Khalti app, since no page is pushed
- Update the README with the new flow, the callback outcomes and a migration guide
- Example app takes the payment URL from a text field and shows non-success outcomes

# [1.0.1] - Jun 05, 2026
- Accept `paymentUrl` during SDK initialization and use it directly for webview loading
- Derive `returnUrl` from `paymentUrl` instead of making an additional API call
- Update Gradle version in example app

# [1.0.0-dev.9] - Jul 27, 2025
- Update branding and colors for Khalti by IME

# [1.0.0-dev.8] - Feb 10, 2025
- Update versions for the dependencies used

# [1.0.0-dev.7] - Nov 27, 2024
- Update support section doc

# [1.0.0-dev.6] - Nov 26, 2024
- Update doc
- Update deprecated usage of APIs

# [1.0.0-dev.5] - Jul 24, 2024
**Pre-release**
- **BREAKING**: Implement enhanced functionality allowing the SDK to autonomously fetch the `return_url`. This modification eliminates the requirement for developers to manually specify the `return_url` within the `KhaltiPayConfig` instance.
- Remove `SafeArea` from top of the screen when launching webview to avoid bad UI.
- Refactor `KhaltiWebView` widget to avoid re-rendering of entire `Scaffold` widget when linear progress indicator's state gets updated.

# [1.0.0-dev.4] - Apr 4, 2024
**Pre-release**
- Update caching policy to avoid occasional issue when loading khalti payment page.
- Solve an issue where the flutter framework threw an exception when popping out of the khalti payment page.
- Make minor fix in khalti doc
  
# [1.0.0-dev.3] - Apr 2, 2024
**Pre-release**
- Fixed broken links in README.
- Set proper platforms in yaml configuration.

# [1.0.0-dev.2] - Mar 22, 2024
**Pre-release**
- Fixed broken links in README.

# [1.0.0-dev.1] - Mar 22, 2024
**Pre-release**
- Accepts payment using Khalti Wallet, E-Banking, Mobile Banking, Connect IPS and SCT cards.
