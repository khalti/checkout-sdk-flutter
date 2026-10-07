import 'package:test/test.dart';
import 'package:khalti_checkout_flutter/khalti_checkout_flutter.dart';

KhaltiPayConfig _config(String paymentUrl) {
  return KhaltiPayConfig(publicKey: 'public-key', paymentUrl: paymentUrl);
}

void main() {
  group('KhaltiPayConfig | pidx', () {
    test('is read from the payment url', () {
      final config = _config('https://pay.khalti.com/?pidx=abc123');

      expect(config.pidx, 'abc123');
    });

    test('ignores the other query parameters of the payment url', () {
      final config = _config(
        'https://test-pay.khalti.com/?pidx=abc123&return_url=https%3A%2F%2Fkhalti.com&mode=wallet',
      );

      expect(config.pidx, 'abc123');
    });

    test('is empty when the payment url has no pidx', () {
      expect(_config('https://pay.khalti.com/').pidx, isEmpty);
    });

    test('is empty when the pidx is blank', () {
      expect(_config('https://pay.khalti.com/?pidx=').pidx, isEmpty);
    });

    test('is empty when the payment url cannot be parsed', () {
      expect(_config('http://[invalid').pidx, isEmpty);
    });

    test('configs with the same payment url are equal', () {
      expect(
        _config('https://pay.khalti.com/?pidx=abc123'),
        _config('https://pay.khalti.com/?pidx=abc123'),
      );
    });
  });

  group('Khalti.init', () {
    Future<Khalti> init(String paymentUrl) {
      return Khalti.init(
        payConfig: _config(paymentUrl),
        onPaymentResult: (_, __) {},
        onMessage: (_,
            {description, statusCode, event, needsPaymentConfirmation}) {},
      );
    }

    test('throws when the payment url has no pidx', () {
      expect(init('https://pay.khalti.com/'), throwsArgumentError);
    });

    test('throws when the payment url cannot be parsed', () {
      expect(init('http://[invalid'), throwsArgumentError);
    });
  });
}
