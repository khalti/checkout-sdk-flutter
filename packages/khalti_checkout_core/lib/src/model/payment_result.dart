import 'package:equatable/equatable.dart';

/// The result after making either a successful or unsuccessful payment.
class PaymentResult extends Equatable {
  /// Constructor for [PaymentResult].
  ///
  /// The result after making either a successful or unsuccessful payment.
  const PaymentResult({
    this.payload,
  });

  /// Payload regarding the product purchased.
  final PaymentPayload? payload;

  @override
  List<Object?> get props => [payload];

  @override
  bool get stringify => true;
}

/// Response model for payment verification lookup.
class PaymentPayload extends Equatable {
  /// Default constructor for [PaymentPayload].
  const PaymentPayload({
    this.pidx,
    this.totalAmount = 0,
    required this.status,
    required this.transactionId,
    this.fee = 0,
    this.refunded = false,
    this.purchaseOrderId,
    this.purchaseOrderName,
    this.extraMerchantParams,
  });

  /// The product idx for the associated payment.
  final String? pidx;

  /// Total Amount associated with the payment made.
  final int totalAmount;

  /// The transaction status for the payment made.
  ///
  /// Can be: Completed, Pending, Failed, Initiated, Refunded or Expired
  final String? status;

  /// Unique transaction id.
  final String? transactionId;

  /// The service charge for the payment.
  final int fee;

  /// Denotes if refund was made in case of any failure.
  final bool refunded;

  /// The id associated with the purchased item.
  final String? purchaseOrderId;

  /// The name associated with the purchased item.
  final String? purchaseOrderName;

  /// Extra information associated with the merchant making the payment.
  final Map<String, dynamic>? extraMerchantParams;

  @override
  List<Object?> get props {
    return [
      pidx,
      totalAmount,
      status,
      transactionId,
      fee,
      refunded,
      purchaseOrderId,
      purchaseOrderName,
      extraMerchantParams,
    ];
  }

  /// Factory to create [PaymentPayload] instance from [map].
  factory PaymentPayload.fromJson(Map<String, dynamic> map) {
    return PaymentPayload(
      pidx: map['pidx'] as String?,
      totalAmount: map['total_amount'] as int,
      status: map['status'] as String?,
      transactionId: map['transaction_id'] as String?,
      fee: map['fee'] as int,
      refunded: map['refunded'] as bool,
      purchaseOrderId: map['purchase_order_id'] as String?,
      purchaseOrderName: map['purchase_order_name'] as String?,
      extraMerchantParams: map['extra_merchant_params'] as Map<String, dynamic>?,
    );
  }
}
