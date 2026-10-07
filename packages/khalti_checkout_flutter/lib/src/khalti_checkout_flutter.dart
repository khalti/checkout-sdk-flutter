// Copyright (c) 2024 The Khalti Authors. All rights reserved.

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:khalti_checkout_core/khalti_checkout_core.dart';
import 'package:khalti_checkout_flutter/src/data/core/exception_handler.dart';
import 'package:khalti_checkout_flutter/src/data/khalti_http_client.dart';
import 'package:khalti_checkout_flutter/src/native/khalti_native_api.g.dart';
import 'package:khalti_checkout_flutter/src/strings.dart';
import 'package:khalti_checkout_flutter/src/widget/khalti_webview.dart';
import 'package:url_launcher/url_launcher.dart';

export 'package:khalti_checkout_core/khalti_checkout_core.dart';

/// Environment to choose to different API endpoints based on the selected [Environment].
///
/// Can be: `prod` or `test`.
enum Environment {
  /// Production
  prod,

  /// Test / Staging
  test,
}

/// Various events associated with different actions.
enum KhaltiEvent {
  /// Event for when khalti payment page is disposed.
  kpgDisposed,

  /// Event for when the user cancels the payment in the Khalti app.
  ///
  /// Only reported when paying through the Khalti app. The webview reports
  /// [kpgDisposed] when the user backs out.
  cancelled,

  /// Event for when the payment link has expired.
  ///
  /// Only reported when paying through the Khalti app.
  paymentExpired,

  /// Event for when the Khalti app fails to load or process the payment.
  ///
  /// Only reported when paying through the Khalti app.
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

/// Callback for when a successful or failed payment result is obtained.
typedef OnPaymentResult = FutureOr<void> Function(
  PaymentResult paymentResult,
  Khalti khalti,
);

/// Callback for when any exceptions occur.
typedef OnMessage = FutureOr<void> Function(
  Khalti khalti, {
  int? statusCode,
  Object? description,
  KhaltiEvent? event,
  bool? needsPaymentConfirmation,
});

/// Callback for when user is redirected to `return_url`.
typedef OnReturn = FutureOr<void> Function();

/// The entrypoint class for Khalti.
class Khalti extends Equatable {
  /// Constructor for [Khalti].
  const Khalti._({
    required this.payConfig,
    required this.onPaymentResult,
    required this.onMessage,
    this.onReturn,
  });

  /// Config class necessary to hold all the necessary informations needed to initialize the SDK.
  final KhaltiPayConfig payConfig;

  /// A callback which is to be triggered when any payment is made.
  final OnPaymentResult onPaymentResult;

  /// Callback for when any exceptions occur.
  final OnMessage onMessage;

  /// Callback for when user is redirected to `return_url`.
  final OnReturn? onReturn;

  /// Initializes Khalti Configuration.
  static Future<Khalti> init({
    required KhaltiPayConfig payConfig,
    required OnPaymentResult onPaymentResult,
    required OnMessage onMessage,
    OnReturn? onReturn,
    bool enableDebugging = false,
  }) async {
    if (payConfig.pidx.isEmpty) {
      throw ArgumentError.value(
        payConfig.paymentUrl,
        'payConfig.paymentUrl',
        'must contain a non-empty "pidx" query parameter',
      );
    }

    KhaltiService.enableDebugging = enableDebugging;
    KhaltiService.publicKey = payConfig.publicKey;

    await KhaltiConfig.getConfig();

    return Khalti._(
      payConfig: payConfig,
      onPaymentResult: onPaymentResult,
      onMessage: onMessage,
      onReturn: onReturn,
    );
  }

  @internal

  /// Helper boolean value to indicate if the webpage has been popped already to avoid multiple pops.
  ///
  /// Avoid using it outside of this library.
  static bool hasPopped = false;

  /// Helper boolean value to indicate whether [KhaltiWebView] is currently
  /// the active route, i.e. whether there's actually something for [close]
  /// to pop. Never true for the native Khalti app flow, since that never
  /// pushes a route of its own.
  ///
  /// Avoid using it outside of this library.
  static bool isWebViewActive = false;

  /// A http [service] to make requests to Khalti APIs.
  static KhaltiService get service => _service;

  /// Method to start the payment.
  ///
  /// Tries the native Khalti app first and reports the outcome through the
  /// callbacks given to [init]:
  ///
  /// * paid (or already paid): [onReturn], then [onPaymentResult] with the
  ///   verified [PaymentResult] (its payload carries the actual status), or
  ///   [onMessage] if verification itself fails.
  /// * user backed out of the Khalti app: [onMessage] with
  ///   [KhaltiEvent.cancelled].
  /// * payment link expired: [onMessage] with [KhaltiEvent.paymentExpired].
  /// * Khalti app failed to load or process the payment: [onMessage] with
  ///   [KhaltiEvent.kpgLoadFailure].
  /// * the app couldn't be launched for an unexpected reason: [onMessage]
  ///   with [KhaltiEvent.unknown].
  ///
  /// Falls back to [KhaltiWebView] if the Khalti app isn't installed.
  Future<void> open(BuildContext context) async {
    hasPopped = false;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return _openKhaltiAppOnIos(context);
    }

    final KhaltiAppResult result;
    try {
      result = await KhaltiNativeApi().openKhaltiApp(payConfig.pidx);
    } on PlatformException catch (e) {
      if (e.code == _appNotFound || e.code == _noActivity) {
        if (!context.mounted) return;
        return _openWebView(context);
      }
      return onMessage(
        event: KhaltiEvent.unknown,
        description: e.message ?? e.code,
        needsPaymentConfirmation: false,
        this,
      );
    }

    switch (result.status) {
      case KhaltiAppStatus.completed || KhaltiAppStatus.settled:
        await onReturn?.call();
        return verify();
      case KhaltiAppStatus.expired:
        return onMessage(
          event: KhaltiEvent.paymentExpired,
          description: result.message,
          needsPaymentConfirmation: false,
          this,
        );
      case KhaltiAppStatus.error:
        return onMessage(
          event: KhaltiEvent.kpgLoadFailure,
          description: result.message,
          needsPaymentConfirmation: true,
          this,
        );
      case KhaltiAppStatus.cancelled:
        return onMessage(
          event: KhaltiEvent.cancelled,
          description: result.message ?? s_paymentCancelled,
          needsPaymentConfirmation: true,
          this,
        );
    }
  }

  /// Launches the Khalti app on iOS.
  ///
  /// The universal link is tried first. [LaunchMode.externalNonBrowserApplication]
  /// only opens it if an app claims the link, which isn't the case for builds
  /// installed without the matching associated domain (e.g. from Xcode), so the
  /// `khalti://` scheme is tried next. Launching a scheme doesn't need an
  /// `LSApplicationQueriesSchemes` entry; only `canLaunchUrl` does, so it isn't
  /// used. If neither opens, the Khalti app isn't installed and the webview is
  /// used instead.
  ///
  /// iOS has no way to hand a result back to the calling app, so once the app
  /// is launched the payment is verified when the user returns to this app, see
  /// [_reportAfterReturningToApp].
  Future<void> _openKhaltiAppOnIos(BuildContext context) async {
    final query = {'t': 'intent-pay', 'pidx': payConfig.pidx};

    var launched = await _tryLaunch(
      Uri.https('khalti.com', '/go/', query),
      LaunchMode.externalNonBrowserApplication,
    );
    launched = launched ||
        await _tryLaunch(
            Uri(scheme: 'khalti', host: 'go', queryParameters: query),
            LaunchMode.externalApplication);

    if (launched) {
      return _KhaltiAppReturnObserver.start(_reportAfterReturningToApp);
    }

    if (!context.mounted) return;
    _openWebView(context);
  }

  /// Verifies the payment once the user is back from the Khalti app and reports
  /// it through the callbacks, mapping the verified status the same way the
  /// Android result statuses are:
  ///
  /// * `Initiated` (nothing happened) or `User canceled`: [KhaltiEvent.cancelled].
  /// * `Expired`: [KhaltiEvent.paymentExpired].
  /// * anything else (`Completed`, `Pending`, `Refunded`, ...): [onReturn], then
  ///   [onPaymentResult] with the verified payload.
  ///
  /// Verification failures are reported as by [verify].
  Future<void> _reportAfterReturningToApp() {
    return handlePaymentVerificationException(
      caller: () => service.verify(
        payConfig.pidx,
        isProd: payConfig.environment == Environment.prod,
      ),
      onMessage: onMessage,
      onPaymentResult: (paymentResult, khalti) async {
        switch (paymentResult.payload?.status?.trim().toLowerCase()) {
          case 'initiated' || 'user canceled':
            return onMessage(
              event: KhaltiEvent.cancelled,
              description: s_paymentCancelled,
              needsPaymentConfirmation: true,
              this,
            );
          case 'expired':
            return onMessage(
              event: KhaltiEvent.paymentExpired,
              description: s_paymentExpired,
              needsPaymentConfirmation: false,
              this,
            );
          default:
            await onReturn?.call();
            return onPaymentResult(paymentResult, khalti);
        }
      },
      khalti: this,
    );
  }

  Future<bool> _tryLaunch(Uri uri, LaunchMode mode) async {
    try {
      return await launchUrl(uri, mode: mode);
    } on PlatformException {
      return false;
    }
  }

  void _openWebView(BuildContext context) {
    isWebViewActive = true;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return KhaltiWebView(khalti: this);
        },
      ),
    );
  }

  /// Helper method to call payment verification API.
  Future<void> verify() async {
    return handlePaymentVerificationException(
      caller: () => service.verify(
        payConfig.pidx,
        isProd: payConfig.environment == Environment.prod,
      ),
      onMessage: onMessage,
      onPaymentResult: onPaymentResult,
      khalti: this,
    );
  }

  /// Helper method to call payment detail fetching API.
  Future<PaymentDetailModel> fetchPaymentDetail() async {
    final paymentUri = Uri.tryParse(payConfig.paymentUrl);
    if (paymentUri == null) {
      return PaymentDetailModel(returnUrl: null);
    }

    final returnUrl = paymentUri.queryParameters['return_url'];
    if (returnUrl == null) {
      return PaymentDetailModel(returnUrl: null);
    }

    return PaymentDetailModel(returnUrl: returnUrl);
  }

  /// Helper method to close the webview.
  ///
  /// No-op when using the native Khalti app flow, since that never pushes a
  /// route of its own for this to close.
  void close(BuildContext context) {
    if (isWebViewActive && !hasPopped) {
      hasPopped = true;
      isWebViewActive = false;
      Navigator.pop(context);
    }
  }

  /// Overrides [Khalti.service] with the provided [service].
  ///
  /// This can be used to provide mock implementation of [KhaltiService]
  /// for testing purposes.
  @visibleForTesting
  static set debugKhaltiServiceOverride(KhaltiService service) {
    _service = service;
  }

  @override
  List<Object?> get props => [payConfig, onPaymentResult, onMessage, onReturn];
}

/// Waits for the user to come back to the app after leaving it for the Khalti
/// app, then runs [onReturned] once.
///
/// Only a return that follows the app actually going to the background counts:
/// the lifecycle also reports `resumed` after a transient `inactive` (system
/// dialogs, the notification shade), which isn't a return from Khalti.
class _KhaltiAppReturnObserver with WidgetsBindingObserver {
  _KhaltiAppReturnObserver._(this._onReturned);

  final Future<void> Function() _onReturned;

  bool _wentToBackground = false;

  static _KhaltiAppReturnObserver? _active;

  static void start(Future<void> Function() onReturned) {
    _active?._stop();
    _active = _KhaltiAppReturnObserver._(onReturned);
    WidgetsBinding.instance.addObserver(_active!);
  }

  void _stop() {
    WidgetsBinding.instance.removeObserver(this);
    if (_active == this) _active = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        _wentToBackground = true;
      case AppLifecycleState.resumed when _wentToBackground:
        _stop();
        _onReturned();
      default:
        break;
    }
  }
}

const _appNotFound = 'APP_NOT_FOUND';
const _noActivity = 'NO_ACTIVITY';

KhaltiService _service = KhaltiService(client: KhaltiHttpClient());

/// A class to hold necessary informations for loading the flutter SDK.
class KhaltiPayConfig extends Equatable {
  /// A class to hold necessary informations for loading the flutter SDK.
  ///
  /// Constructor for [KhaltiPayConfig].
  const KhaltiPayConfig({
    required this.publicKey,
    required this.paymentUrl,
    this.openInKhalti = false,
    this.environment = Environment.prod,
  });

  /// Public Key
  final String publicKey;

  /// A boolean to determine whether to launch WebView or open in khalti app.
  final bool openInKhalti;

  /// Environment to run the SDK against.
  ///
  /// Can be: `prod` or `test`.
  ///
  /// Defaults to `prod`.
  final Environment environment;

  /// Payment URL to redirect for making payments.
  ///
  /// This is the `payment_url` received after initiating the payment via a
  /// server-side POST request. It has to contain the `pidx` query parameter.
  final String paymentUrl;

  /// Payment unique identifier, read from the `pidx` query parameter of
  /// [paymentUrl].
  ///
  /// Empty if [paymentUrl] has none, which [Khalti.init] rejects.
  String get pidx => Uri.tryParse(paymentUrl)?.queryParameters['pidx'] ?? '';

  @override
  List<Object?> get props {
    return [
      publicKey,
      openInKhalti,
      environment,
      paymentUrl,
    ];
  }
}
