import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:khalti_checkout_flutter/khalti_checkout_flutter.dart';

void main() {
  runApp(
    const MaterialApp(
      home: KhaltiSDKDemo(),
    ),
  );
}

class KhaltiSDKDemo extends StatefulWidget {
  const KhaltiSDKDemo({super.key});

  @override
  State<KhaltiSDKDemo> createState() => _KhaltiSDKDemoState();
}

class _KhaltiSDKDemoState extends State<KhaltiSDKDemo> {
  final _formKey = GlobalKey<FormState>();
  final _paymentUrlController = TextEditingController();

  PaymentResult? paymentResult;

  /// Last non-payment outcome reported through `onMessage` (cancelled, expired, error...).
  String? message;

  @override
  void dispose() {
    _paymentUrlController.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    if (!_formKey.currentState!.validate()) return;

    final paymentUrl = _paymentUrlController.text.trim();
    setState(() {
      paymentResult = null;
      message = null;
    });

    final khalti = await Khalti.init(
      enableDebugging: true,
      payConfig: KhaltiPayConfig(
        publicKey:
            '4aa1b684f4de4860968552558fc8487d', // This is a dummy public key for example purpose
        environment: _environmentOf(paymentUrl),
        paymentUrl: paymentUrl,
      ),
      onPaymentResult: (paymentResult, khalti) {
        log(paymentResult.toString());
        setState(() {
          this.paymentResult = paymentResult;
          message = null;
        });
        khalti.close(context);
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
        setState(() {
          paymentResult = null;
          message = 'Event: $event\n'
              'Description: ${_shorten(description)}\n'
              'Status Code: $statusCode\n'
              'Needs Payment Confirmation: $needsPaymentConfirmation';
        });
        khalti.close(context);
      },
      onReturn: () => log('Successfully redirected to return_url.'),
    );

    if (!mounted) return;
    await khalti.open(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Image.asset(
                  'assets/seru.png',
                  height: 160,
                  width: 160,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _paymentUrlController,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Payment URL',
                    hintText: 'https://test-pay.khalti.com/?pidx=...',
                    helperText:
                        'The payment_url received after initiating the payment.',
                    border: OutlineInputBorder(),
                  ),
                  validator: _validatePaymentUrl,
                  onFieldSubmitted: (_) => _pay(),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _pay,
                  child: const Text('Pay with Khalti'),
                ),
                const SizedBox(height: 32),
                if (message != null)
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, color: Colors.red),
                  )
                else if (paymentResult != null)
                  Column(
                    children: [
                      Text('pidx: ${paymentResult!.payload?.pidx}'),
                      Text('Status: ${paymentResult!.payload?.status}'),
                      Text(
                        'Amount Paid: ${paymentResult!.payload?.totalAmount}',
                      ),
                      Text(
                        'Transaction ID: ${paymentResult!.payload?.transactionId}',
                      ),
                    ],
                  ),
                const SizedBox(height: 32),
                const Text(
                  'This is a demo application developed by some merchant.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Validates that the input is an http(s) URL carrying a non-empty `pidx`,
/// which is what the SDK reads the payment identifier from.
String? _validatePaymentUrl(String? value) {
  final input = value?.trim() ?? '';
  if (input.isEmpty) return 'Enter the payment URL';

  final uri = Uri.tryParse(input);
  if (uri == null ||
      !uri.hasScheme ||
      !uri.isScheme('https') && !uri.isScheme('http')) {
    return 'Enter a valid URL';
  }

  if ((uri.queryParameters['pidx'] ?? '').isEmpty) {
    return 'The URL has no pidx';
  }
  return null;
}

/// Payment URLs on the test host run against the test environment.
Environment _environmentOf(String paymentUrl) {
  final host = Uri.tryParse(paymentUrl)?.host ?? '';
  return host.startsWith('test-') ? Environment.test : Environment.prod;
}

/// Keeps long descriptions (e.g. an HTML error page) from filling the screen.
String _shorten(Object? description, {int max = 120}) {
  final text = description.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  return text.length <= max ? text : '${text.substring(0, max)}...';
}
