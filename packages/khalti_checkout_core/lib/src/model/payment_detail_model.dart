import 'package:equatable/equatable.dart';

/// This class holds necessary information that is necessary for the payment webview to load.
class PaymentDetailModel extends Equatable {
  /// Constructor for `PaymentDetailModel`.
  ///
  /// This class holds necessary information that is necessary for the payment webview to load.
  const PaymentDetailModel({this.returnUrl});

  /// Helper factory constructor to return an instance of `PaymentDetailModel` with no return url.
  factory PaymentDetailModel.empty() => const PaymentDetailModel();

  /// The `return_url` associated with the payment.
  final String? returnUrl;

  @override
  List<Object?> get props => [returnUrl];

  /// Factory to create [PaymentDetailModel] instance from [map].
  factory PaymentDetailModel.fromJson(Map<String, dynamic> map) {
    return PaymentDetailModel(returnUrl: map['return_url'] as String?);
  }
}
