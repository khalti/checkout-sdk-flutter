<p align="center">
<img src="https://raw.githubusercontent.com/khalti/checkout-sdk-flutter/main/assets/khalti_logo.png" height="100" alt="Khalti Payment Gateway" />
</p>

<p align="center">
<strong>Khalti Payment Gateway for Flutter</strong>
</p>

<p align="center">
<a href="https://pub.dartlang.org/packages/khalti_checkout_flutter"><img src="https://img.shields.io/pub/v/khalti_checkout_flutter.svg" alt="Pub"></a>
<a href="https://docs.khalti.com/"><img src="https://img.shields.io/badge/Khalti-Docs-blueviolet" alt="Khalti Docs"></a>
<a href="https://github.com/khalti/checkout-sdk-flutter/blob/main/LICENSE"><img src="https://img.shields.io/badge/License-BSD--3-informational" alt="BSD-3 License"></a>
<a href="https://github.com/khalti/checkout-sdk-flutter/issues"><img src="https://img.shields.io/github/issues/khalti/checkout-sdk-flutter" alt="GitHub issues"></a>
<a href="https://khalti.com"><img src="https://img.shields.io/website?url=https%3A%2F%2Fdocs.khalti.com" alt="Website"></a>
<a href="https://www.facebook.com/khalti.official"><img src="https://img.shields.io/badge/follow--000?style=social&logo=facebook" alt="Follow Khalti in Facebook"></a>
<a href="https://www.instagram.com/khaltiofficial"><img src="https://img.shields.io/badge/follow--000?style=social&logo=instagram" alt="Follow Khalti in Instagram"></a>
<a href="https://twitter.com/intent/follow?screen_name=khaltiofficial"><img src="https://img.shields.io/twitter/follow/khaltiofficial?style=social" alt="Follow Khalti in Twitter"></a>
<a href="https://www.youtube.com/channel/UCrXM4HqK9th3E2a04Z9Lh-Q"><img src="https://img.shields.io/badge/subscribe--000?style=social&logo=youtube" alt="Subscribe Youtube Channel"></a>
</p>

---

Khalti is a payment gateway, digital wallet and API provider system for various online services for Nepal.

With this package, you can accepts payments from:
- Khalti users.
- eBanking users of our partner banks.
- Mobile banking users of our mobile banking partner banks.
- SCT/VISA card holders.
- connectIPS users.

Using Khalti Payment Gateway, you do not need to integrate with individual banks.

- [Introduction](#introduction)
- [Getting Started](#getting-started)
- [Supported Platforms](#supported-platforms)
- [How it works](#how-it-works)
- [Setup](#setup)
  - [Android](#android)
  - [iOS](#ios)
  - [Web](#web)
- [Launching Payment Interface](#launching-payment-interface)
  - [Generating the payment URL](#generating-the-payment-url)
  - [Khalti Initialization](#khalti-initialization)
  - [Loading payment interface](#loading-payment-interface)
- [Handling the result](#handling-the-result)
- [Payment verification API](#payment-verification-api)
- [Closing the Khalti payment gateway page](#closing-the-khalti-payment-gateway-page)
- [Testing](#testing)
- [Migrating to 2.0.0](#migrating-to-200)
- [Example](#example)
- [Contributing](#contributing)
- [Support](#support)
- [License](#license)


# Introduction
Read the introduction [here](https://docs.khalti.com/).

# Getting Started
Integrating Khalti Payment Gateway requires merchant account. 
You can always [create one easily from here](https://khalti.com/join/merchant/#/).

Read the steps to integrate Khalti Payment Gateway in details [here](https://docs.khalti.com/getting-started/).

# Supported Platforms
Android | iOS | Web | Desktop (macOS, Linux, Windows)
:-----: | :-: | :-: | :-----------------------------:
  ✔️    |  ✔️ |  ❌ |                ❌

# How it works
When `open()` is called, the SDK first tries to complete the payment in the **Khalti app**. If the Khalti app is not installed, it falls back to the payment page in an in-app WebView.

- **Android**: the SDK launches the Khalti app and receives the outcome back directly (paid, already paid, expired, cancelled or error). A paid payment is then verified with Khalti before it is reported to you.
- **iOS**: the SDK opens the Khalti app. iOS does not let an app return a result to the app that opened it, so the SDK verifies the payment with Khalti when the user comes back to your app, and reports the verified status.
- **Khalti app not installed**: the payment page opens in a WebView inside your app, as in earlier versions.

Every outcome is reported through the callbacks you pass to `Khalti.init()`, see [Handling the result](#handling-the-result).

# Setup
Detailed setup for each platform.

## Android
No configuration is required. The SDK adds a small transparent activity to your app's manifest automatically.

The minimum supported Android SDK version is **24**.

## iOS
No configuration is required. The SDK opens the Khalti app through its universal link and falls back to the `khalti://` scheme, so you do not need to add anything to `LSApplicationQueriesSchemes`.

To bring the user back to your app automatically after the payment, set a `return_url` that opens your app (for example an app link on your own domain) when you [generate the payment URL](#generating-the-payment-url). The Khalti app opens it with `pidx` and `status` added as query parameters. If you do not, the user returns to your app manually, and the SDK still verifies the payment.

## Web
Since, the SDK uses [flutter_inappwebview](https://pub.dev/packages/flutter_inappwebview) internally to load the payment gateway, check its doc for the necessary web setup.

# Launching Payment Interface

## Generating the payment URL
A payment must be initiated via a server side POST request before being able to proceed. The response contains the `payment_url`, which includes the unique product identifier `pidx`. Read [here](https://docs.khalti.com/khalti-epayment/#initiating-a-payment-request) for information on how to initiate a payment along with other extra parameters.

```bash
curl -X POST "https://khalti.com/api/v2/epayment/initiate/" \
  -H "Authorization: key <merchant secret key>" \
  -H "Content-Type: application/json" \
  -d '{
    "return_url": "https://merchant.example/return",
    "website_url": "https://merchant.example",
    "amount": 1000,
    "purchase_order_id": "order-1",
    "purchase_order_name": "Order 1"
  }'
```

- `amount` is in paisa, so `1000` is Rs. 10.
- The request must be made from your server. Never ship your secret key inside the app.
- Pass the `payment_url` from the response to the SDK as-is.

A payment URL is valid for a limited time (30 minutes) and can be paid once.

## Khalti Initialization
Before being able to launch Khalti payment gateway, it is necessary to initialize `Khalti` object. The initialization can be done by a static `init()` method.

```dart
class KhaltiSDKDemo extends StatefulWidget {
  const KhaltiSDKDemo({super.key});

  @override
  State<KhaltiSDKDemo> createState() => _KhaltiSDKDemoState();
}

class _KhaltiSDKDemoState extends State<KhaltiSDKDemo> {
  Khalti? khalti;

  Future<void> startPayment(String paymentUrl) async {
    final payConfig = KhaltiPayConfig(
      publicKey: '__live_public_key__', // Merchant's public key
      paymentUrl: paymentUrl, // The `payment_url` received after initiating the payment.
      environment: Environment.prod,
    );

    khalti = await Khalti.init(
      enableDebugging: true,
      payConfig: payConfig,
      onPaymentResult: (paymentResult, khalti) {
        log(paymentResult.toString());
      },
      onMessage: (
        khalti, {
        description,
        statusCode,
        event,
        needsPaymentConfirmation,
      }) async {
        log(
          'Description: $description, Status Code: $statusCode, Event: $event, NeedsPaymentConfirmation: $needsPaymentConfirmation',
        );
      },
      onReturn: () => log('Successfully redirected to return_url.'),
    );

    if (!mounted) return;
    await khalti!.open(context);
  }

  @override
  Widget build(BuildContext context) {
    // Rest of the code
  }
}
```

`Khalti.init()` can also be called once, for example inside `initState`, when the payment URL is already known.

The static `init()` method takes in a few arguments:

- **enableDebugging**: A boolean argument that is when set to true can be used to view network logs in the debug console. It is set to `false` by default.
- **payConfig**: An instance of `KhaltiPayConfig()`. It is used to set few config data. The instance of `KhaltiPayConfig` takes in few arguments:

  ```dart
  final payConfig = KhaltiPayConfig(
    publicKey: '__live_public_key__', // Merchant's public key
    paymentUrl: paymentUrl, // The `payment_url` received after initiating the payment.
    environment: Environment.prod,
  );
  ```
  - **publicKey**: Merchant's live or test public key provided by Khalti.
  - **paymentUrl**: The `payment_url` received after initiating the payment via a server-side POST request. It must contain the `pidx` query parameter, which the SDK reads the payment identifier from (available as `payConfig.pidx`). `Khalti.init()` throws an `ArgumentError` if it is missing.
  - **environment**: An enum that determines whether test API or production API should be invoked. Can be either `Environment.prod` or `Environment.test`. Set to `Environment.prod` by default.
- **onPaymentResult**: A callback function that is triggered with the verified payment once the user has paid. The callback takes in two arguments.
  - **paymentResult**: An instance of `PaymentResult` class. It provides some informations about the payment. Following data is provided by this instance.
    - **payload**: An instance of `PaymentPayload`. It contains general informations such as `pidx`, `totalAmount`, `transactionId`, `status`, `fee`, `refunded`, `purchaseOrderId`, `purchaseOrderName` and `extraMerchantParams` regarding the payment made.  
  - **khalti**: An instance of `Khalti`. Can be used to invoke any methods provided by this instance.

  ```dart
  onPaymentResult(paymentResult, khalti) {
    print(paymentResult.payload?.status);
    print(paymentResult.payload?.pidx);
    print(paymentResult.payload?.totalAmount);
    print(paymentResult.payload?.transactionId);
  }
  ```

  Always check `payload.status`. A verified payment can also be `Pending`, `Refunded` and so on, not only `Completed`.
  
- **onReturn**: A callback function that gets triggered when the user has returned from a payment, before `onPaymentResult`. It is not called when the payment is cancelled or has expired.

- **onMessage**: A callback function that is triggered to convey any message. It gets triggered when the payment did not complete, or when any issue is encountered. This callback provides the error description, the status code (only for network errors) and information about what happened via the `KhaltiEvent` enum:

  ```dart
  enum KhaltiEvent {
    /// Event for when khalti payment page is disposed.
    kpgDisposed,

    /// Event for when the user cancels the payment in the Khalti app.
    cancelled,

    /// Event for when the payment link has expired.
    paymentExpired,

    /// Event for when the Khalti app fails to load or process the payment.
    kpgLoadFailure,

    /// Event for when return url fails to load from the API.
    returnUrlLoadFailure,

    /// Event for when there's an exception when making a network call.
    networkFailure,

    /// Event for when there's a HTTP failure when making a network call for verifying payment status.
    paymentLookupfailure,

    /// An unknown event.
    unknown
  }
  ```
  Additionally, it also provides a bool `needsPaymentConfirmation` which needs to be checked. If it is true, the state of the payment is not known, and developers should confirm it, either with the [payment verification API](#payment-verification-api) provided by the SDK or on their server. The callback also provides the instance of `Khalti`.

  ```dart
  onMessage: (
    khalti, {
    description,
    statusCode,
    event,
    needsPaymentConfirmation,
  }) {
    log('Description: $description, Status Code: $statusCode, Event: $event, NeedsPaymentConfirmation: $needsPaymentConfirmation');
  }
  ```

## Loading payment interface
SDK users should invoke the `open()` method provided by the SDK to start the payment. It returns a `Future`, which completes once the payment has been handed over (to the Khalti app, or to the WebView).

```dart
await khalti.open(context); // Assuming that khalti is a variable that holds the instance of `Khalti`.
```

If the Khalti app is not installed, the SDK uses [flutter_inappwebview](https://pub.dev/packages/flutter_inappwebview) to push the payment page into your route instead.

# Handling the result
Whatever happens, the outcome reaches exactly one of your callbacks.

| Outcome | Callback | `event` | `needsPaymentConfirmation` |
|---|---|---|---|
| Paid, or already paid | `onReturn`, then `onPaymentResult` | none | none |
| User backed out of the Khalti app | `onMessage` | `cancelled` | `true` |
| Payment link expired | `onMessage` | `paymentExpired` | `false` |
| The Khalti app could not load or process the payment | `onMessage` | `kpgLoadFailure` | `true` |
| User closed the WebView | `onMessage` | `kpgDisposed` | `true` |
| Verification failed because of a network problem | `onMessage` | `networkFailure` | `true` |
| Verification request was rejected | `onMessage` | `paymentLookupfailure` | `false` |
| The Khalti app could not be launched for another reason | `onMessage` | `unknown` | `false` |

On iOS the verified payment status decides the outcome: `Initiated` or `User canceled` is reported as `cancelled`, `Expired` as `paymentExpired`, and anything else through `onPaymentResult`.

```dart
onMessage: (khalti, {description, statusCode, event, needsPaymentConfirmation}) async {
  switch (event) {
    case KhaltiEvent.cancelled:
    case KhaltiEvent.kpgDisposed:
      // The user left without paying.
      break;
    case KhaltiEvent.paymentExpired:
      // Create a new payment and try again.
      break;
    default:
      if (needsPaymentConfirmation == true) await khalti.verify();
  }
}
```

# Payment verification API
A payment verification API that confirms the status of the payment made, is called by the SDK internally after a payment. However, if the users receive `needsPaymentConfirmation` as true in `onMessage` callback, they are supposed to called the payment verification API manually to be sure about the payment status. It can be done with a method provided by the `Khalti` instance.

```dart
await khalti.verify(); // Assuming that khalti is a variable that holds the instance of `Khalti`.
```

The instance of `Khalti` is provided in the `onPaymentResult` and `onMessage` callback which can be used to invoke any public functions provide by `Khalti` class.

For anything that matters, such as fulfilling an order, also confirm the payment on your server with the [payment lookup API](https://docs.khalti.com/khalti-epayment/), and compare the `pidx` and amount with your own order.

# Closing the Khalti payment gateway page
After payment is successfully made, developers can opt to pop the page that was pushed in their route. The SDK provides a `close()` method.

```dart
khalti.close(context);
```

This only applies to the WebView. When the payment is made in the Khalti app, no page is pushed, so `close()` does nothing.

# Testing
- Use `Environment.test` with the merchant's test public key, and create the payment on the test environment (`dev.khalti.com`) so the SDK can verify it.
- Create a fresh payment URL for every attempt. A payment URL can be paid once and expires after 30 minutes.
- To test the expired case, use a payment URL older than 30 minutes. To test the already-paid case, reuse one that has been paid.
- The Khalti app and the SDK must use the same environment, or the payment will not be found.
- On Android, the SDK detects the production Khalti app (`com.khalti`). Other builds of the Khalti app are not detected, and the WebView is used instead.

# Migrating to 2.0.0
- **`pidx` is no longer a `KhaltiPayConfig` parameter.** The SDK reads it from `paymentUrl`.

  ```dart
  // Before
  KhaltiPayConfig(publicKey: key, pidx: pidx, paymentUrl: paymentUrl, environment: Environment.prod);

  // After
  KhaltiPayConfig(publicKey: key, paymentUrl: paymentUrl, environment: Environment.prod);
  ```

  Pass the `payment_url` you received when initiating the payment, unchanged. If it has no `pidx` query parameter, `Khalti.init()` throws an `ArgumentError`.
- **`open()` returns a `Future<void>`** and now opens the Khalti app first. The WebView is used only if the app is not installed.
- **`KhaltiEvent` has new values**: `cancelled`, `paymentExpired` and `kpgLoadFailure`. If you `switch` over `KhaltiEvent` exhaustively, add them.
- **Android**: the SDK is now an Android plugin and requires a minimum SDK version of 24.

# Example
For a more detailed example, check the [examples](./example/) directory inside `khalti_checkout_flutter` package.

# Contributing
Contributions are always welcome. Also, if you have any confusion, please feel free to create an issue.
   
# Support
**For Queries, feel free to call us at:**

_**Contact Our Merchant Team**_
* Mobile (Viber / Whatsapp): 9801165557
* Email: merchant@khalti.com

(To integrate Khalti to your business and other online platforms.)

_**Contact Our Merchant Support**_
* Mobile (Viber / Whatsapp): 9801165565, 9801856451
* Email: merchantcare@khalti.com

_**Contact Our Technical Team**_
* Mobile (Viber / Whatsapp): 9801856383
* Email : techsupport@khalti.com / merchantsupport@khalti.com

(For payment gateway integration support.)
   
# License
```
Copyright (c) 2024 The Khalti Authors. All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above
      copyright notice, this list of conditions and the following
      disclaimer in the documentation and/or other materials provided
      with the distribution.
    * Neither the name of Sparrow Pay Pvt. Ltd. nor the names of its
      contributors may be used to endorse or promote products derived
      from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```
