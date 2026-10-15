import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/native/khalti_native_api.g.dart',
  kotlinOut:
      'android/src/main/kotlin/com/khalti/khalti_checkout_flutter/KhaltiNativeApi.g.kt',
  kotlinOptions: KotlinOptions(package: 'com.khalti.khalti_checkout_flutter'),
))
/// How the Khalti app finished the payment, as reported by its `status` extra.
enum KhaltiAppStatus {
  /// The payment was made just now.
  completed,

  /// The payment had already been made earlier.
  settled,

  /// The payment link has expired.
  expired,

  /// The payment could not be loaded or processed.
  error,

  /// The user backed out without paying.
  cancelled,
}

/// Result handed back by the Khalti app.
class KhaltiAppResult {
  KhaltiAppResult({required this.status, this.message});

  final KhaltiAppStatus status;

  /// Human readable description from the Khalti app, if any.
  final String? message;
}

@HostApi()
abstract class KhaltiNativeApi {
  /// Launches the native Khalti app for the payment identified by [pidx] and
  /// waits for it to finish.
  ///
  /// The native side is responsible for building the Khalti app deep link
  /// from [pidx]. This has to be `@async`: whether the Khalti app is even
  /// installed is only discovered asynchronously (via a proxy activity's
  /// result), well after this call would otherwise have already returned.
  ///
  /// Returns how the Khalti app finished. A result without a recognisable
  /// `status` extra is reported as [KhaltiAppStatus.error].
  ///
  /// Throws (surfaces as `PlatformException` in Dart) with code
  /// `APP_NOT_FOUND` if the Khalti app isn't installed, `NO_ACTIVITY` if
  /// there's no attached activity to launch from, or `MISSING_PIDX`.
  @async
  KhaltiAppResult openKhaltiApp(String pidx);
}