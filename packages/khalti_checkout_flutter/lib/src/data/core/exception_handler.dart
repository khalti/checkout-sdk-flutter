import 'package:khalti_checkout_flutter/khalti_checkout_flutter.dart';

/// Helper function that handles exception when verify api is called.
Future<void> handlePaymentVerificationException({
  required Future<PaymentPayload> Function() caller,
  required OnPaymentResult onPaymentResult,
  required OnMessage onMessage,
  required Khalti khalti,
}) async {
  try {
    final result = await caller();
    return onPaymentResult(
      PaymentResult(payload: result),
      khalti,
    );
  } on ExceptionHttpResponse catch (e) {
    return onMessage(
      statusCode: e.statusCode,
      description: e.detail,
      event: KhaltiEvent.networkFailure,
      needsPaymentConfirmation: true,
      khalti,
    );
  } on FailureHttpResponse catch (e) {
    return onMessage(
      statusCode: e.statusCode,
      description: e.data,
      event: KhaltiEvent.paymentLookupfailure,
      needsPaymentConfirmation: false,
      khalti,
    );
  }
}

/// Helper function that handles exception when detail fetching api is called.
Future<PaymentDetailModel> handleFetchDetailException({
  required Future<PaymentDetailModel> Function() caller,
  required OnPaymentResult onPaymentResult,
  required OnMessage onMessage,
  required Khalti khalti,
}) async {
  try {
    final result = await caller();
    return result;
  } on ExceptionHttpResponse catch (e) {
    onMessage(
      statusCode: e.statusCode,
      description: e.detail,
      event: KhaltiEvent.networkFailure,
      needsPaymentConfirmation: true,
      khalti,
    );
    return PaymentDetailModel.empty();
  } on FailureHttpResponse catch (e) {
    onMessage(
      statusCode: e.statusCode,
      description: e.data,
      event: KhaltiEvent.returnUrlLoadFailure,
      needsPaymentConfirmation: false,
      khalti,
    );
    return PaymentDetailModel.empty();
  }
}
