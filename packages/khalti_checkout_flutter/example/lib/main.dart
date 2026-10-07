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
  late final Future<Khalti?> khalti;

  String pidx =
      'YOUR_PIDX'; // Should be generated via a server-side POST request.

  PaymentResult? paymentResult;

  /// Last non-payment outcome reported through `onMessage` (cancelled, expired, error...).
  String? message;

  @override
  void initState() {
    super.initState();
    final payConfig = KhaltiPayConfig(
      publicKey:
          '4aa1b684f4de4860968552558fc8487d', // This is a dummy public key for example purpose
      environment: Environment.test,
      paymentUrl:
          'https://test-pay.khalti.com/?pidx=$pidx&return_url=https%3A%2F%2Fdocs.khalti.com%2Fkhalti-epayment&mode=wallet',
    );

    khalti = Khalti.init(
      enableDebugging: true,
      payConfig: payConfig,
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FutureBuilder(
          future: khalti,
          initialData: null,
          builder: (context, snapshot) {
            final khaltiSnapshot = snapshot.data;
            if (khaltiSnapshot == null) {
              return const CircularProgressIndicator.adaptive();
            }
            return SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/seru.png',
                    height: 200,
                    width: 200,
                  ),
                  const SizedBox(height: 120),
                  const Text(
                    'Rs. 22',
                    style: TextStyle(fontSize: 25),
                  ),
                  const Text('1 day fee'),
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        paymentResult = null;
                        message = null;
                      });
                      khaltiSnapshot.open(context);
                    },
                    child: const Text('Pay with Khalti'),
                  ),
                  const SizedBox(height: 120),
                  if (message != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        message!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 15, color: Colors.red),
                      ),
                    )
                  else if (paymentResult == null)
                    Text(
                      'pidx: $pidx',
                      style: const TextStyle(fontSize: 15),
                    )
                  else
                    Column(
                      children: [
                        Text(
                          'pidx: ${paymentResult!.payload?.pidx}',
                        ),
                        Text('Status: ${paymentResult!.payload?.status}'),
                        Text(
                          'Amount Paid: ${paymentResult!.payload?.totalAmount}',
                        ),
                        Text(
                          'Transaction ID: ${paymentResult!.payload?.transactionId}',
                        ),
                      ],
                    ),
                  const SizedBox(height: 120),
                  const Text(
                    'This is a demo application developed by some merchant.',
                    style: TextStyle(fontSize: 12),
                  )
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Keeps long descriptions (e.g. an HTML error page) from filling the screen.
String _shorten(Object? description, {int max = 120}) {
  final text = description.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  return text.length <= max ? text : '${text.substring(0, max)}...';
}
