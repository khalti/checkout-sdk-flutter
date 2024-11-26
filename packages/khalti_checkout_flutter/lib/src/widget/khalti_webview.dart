import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:khalti_checkout_flutter/khalti_checkout_flutter.dart';
import 'package:khalti_checkout_flutter/src/data/core/exception_handler.dart';
import 'package:khalti_checkout_flutter/src/strings.dart';
import 'package:khalti_checkout_flutter/src/util/utils.dart';
import 'package:khalti_checkout_flutter/src/widget/khalti_pop_scope.dart';

/// A WebView wrapper for displaying Khalti Payment Interface.
class KhaltiWebView extends StatefulWidget {
  /// Constructor for initializing [KhaltiWebView].
  const KhaltiWebView({
    super.key,
    required this.khalti,
  });

  /// The instance of [Khalti].
  final Khalti khalti;

  @override
  State<KhaltiWebView> createState() => _KhaltiWebViewState();
}

class _KhaltiWebViewState extends State<KhaltiWebView> {
  Future<PaymentDetailModel>? paymentDetail;
  final webViewControllerCompleter = Completer<InAppWebViewController>();
  final showLinearProgressIndicator = ValueNotifier(true);

  @override
  void initState() {
    super.initState();
    paymentDetail = widget.khalti.fetchPaymentDetail();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: kIsWeb
          ? null
          : AppBar(
              title: const Text(s_payWithKhalti),
              actions: [
                IconButton(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                )
              ],
              elevation: 4,
            ),
      body: Column(
        children: [
          ValueListenableBuilder(
            valueListenable: showLinearProgressIndicator,
            builder: (_, showLoader, __) {
              return showLoader
                  ? const LinearProgressIndicator(color: Colors.deepPurple)
                  : const SizedBox.shrink();
            },
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: StreamBuilder(
                stream: connectivityUtil.internetConnectionListenableStatus,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();

                  final connectionStatus = snapshot.data!;

                  switch (connectionStatus) {
                    case InternetStatus.connected:
                      return FutureBuilder<PaymentDetailModel>(
                        future: paymentDetail,
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return _KhaltiWebViewClient(
                              showLinearProgressIndicator:
                                  showLinearProgressIndicator,
                              webViewControllerCompleter:
                                  webViewControllerCompleter,
                              returnUrl: snapshot.data?.returnUrl,
                            );
                          } else if (snapshot.hasError) {
                            Future.microtask(() =>
                                showLinearProgressIndicator.value = false);
                            return const _KhaltiError(
                              icon: Icon(Icons.error),
                              errorMessage: 'Unable to load return_url',
                              errorDescription:
                                  "There was an error setting up your payment. Please try again later.",
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      );
                    case InternetStatus.disconnected:
                      Future.microtask(
                          () => showLinearProgressIndicator.value = false);
                      return const _KhaltiError(
                        icon: Icon(Icons
                            .signal_wifi_statusbar_connected_no_internet_4),
                        errorMessage: s_noInternet,
                        errorDescription: s_noInternetDisplayMessage,
                      );
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _reload() async {
    if (webViewControllerCompleter.isCompleted) {
      final webViewController = await webViewControllerCompleter.future;
      webViewController.loadUrl(
        urlRequest: URLRequest(
          url: WebUri('javascript:window.location.reload(true)'),
        ),
      );
    }
  }
}

class _KhaltiWebViewClient extends StatelessWidget {
  const _KhaltiWebViewClient({
    required this.showLinearProgressIndicator,
    required this.webViewControllerCompleter,
    this.returnUrl,
  });

  final ValueNotifier<bool> showLinearProgressIndicator;
  final Completer<InAppWebViewController?> webViewControllerCompleter;
  final String? returnUrl;

  @override
  Widget build(BuildContext context) {
    final khalti =
        context.findAncestorWidgetOfExactType<KhaltiWebView>()!.khalti;
    final payConfig = khalti.payConfig;
    final isProd = payConfig.environment == Environment.prod;
    return KhaltiPopScope(
      onPopInvoked: (didPop, _) async {
        if (didPop) return;
        Khalti.hasPopped = true;
        return khalti.onMessage(
          event: KhaltiEvent.kpgDisposed,
          description: s_kpgDisposed,
          needsPaymentConfirmation: true,
          khalti,
        );
      },
      child: InAppWebView(
        onLoadStop: (controller, webUri) async {
          showLinearProgressIndicator.value = false;
          if (webUri.isNotNull && returnUrl.isNotNullAndNotEmpty) {
            final currentStringUrl = webUri.toString();
            if (currentStringUrl.contains(returnUrl!)) {
              // Necessary if the user wants to perform an action when a payment is made.
              await khalti.onReturn?.call();

              final pidx = payConfig.pidx;

              return handlePaymentVerificationException(
                caller: () => Khalti.service.verify(pidx, isProd: isProd),
                onPaymentResult: khalti.onPaymentResult,
                onMessage: khalti.onMessage,
                khalti: khalti,
              );
            }
          }
        },
        onReceivedError: (_, webResourceRequest, error) async {
          if (returnUrl.isNotNullAndNotEmpty &&
              webResourceRequest.url.toString().contains(returnUrl!)) {
            showLinearProgressIndicator.value = false;
            return khalti.onMessage(
              description: error.description,
              event: KhaltiEvent.returnUrlLoadFailure,
              needsPaymentConfirmation: true,
              khalti,
            );
          }
        },
        onReceivedHttpError: (_, webResourceRequest, response) async {
          if (returnUrl.isNotNullAndNotEmpty &&
              webResourceRequest.url.toString().contains(returnUrl!)) {
            showLinearProgressIndicator.value = false;
            return khalti.onMessage(
              statusCode: response.statusCode,
              event: KhaltiEvent.returnUrlLoadFailure,
              needsPaymentConfirmation: true,
              khalti,
            );
          }
        },
        onWebViewCreated: webViewControllerCompleter.complete,
        initialSettings: InAppWebViewSettings(
          useOnLoadResource: true,
          useHybridComposition: true,
          clearCache: true,
          cacheEnabled: false,
          cacheMode: CacheMode.LOAD_NO_CACHE,
        ),
        initialUrlRequest: URLRequest(
          url: WebUri.uri(
            Uri.parse(isProd ? prodPaymentUrl : testPaymentUrl).replace(
              queryParameters: {'pidx': payConfig.pidx},
            ),
          ),
        ),
        onProgressChanged: (_, progress) {
          if (progress == 100) showLinearProgressIndicator.value = false;
        },
      ),
    );
  }
}

/// A widget that is displayed when there is no internet connection.
class _KhaltiError extends StatelessWidget {
  /// Constructor for [_KhaltiError].
  ///
  /// A widget that is displayed when there is no internet connection.
  const _KhaltiError({this.icon, this.errorMessage, this.errorDescription});

  final Icon? icon;
  final String? errorMessage;
  final String? errorDescription;

  @override
  Widget build(BuildContext context) {
    return icon.isNotNull && errorMessage.isNotNull
        ? Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  icon!,
                  const SizedBox(height: 10),
                  Text(
                    errorMessage!,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  if (errorDescription.isNotNull)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                      child: Text(errorDescription!),
                    ),
                ],
              ),
            ),
          )
        : const SizedBox.shrink();
  }
}
