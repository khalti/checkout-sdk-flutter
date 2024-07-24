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
