import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pay/pay.dart';

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();

  factory PaymentService() => _instance;

  PaymentService._internal();

  Pay? _payClient;

  Future<void> initialize({bool useProduction = false}) async {
    try {
      PaymentConfiguration config;

      final jConfigProd = await rootBundle.loadString(
        'assets/payment/gpay_config_production.json',
      );

      final jConfigTest = await rootBundle.loadString(
        'assets/payment/gpay_config_test.json',
      );

      if (useProduction) {
        config = PaymentConfiguration.fromJsonString(jConfigProd);
      } else {
        config = PaymentConfiguration.fromJsonString(jConfigTest);
      }

      _payClient = Pay({PayProvider.google_pay: config});
    } catch (e) {
      if (kDebugMode) {
        print('Error inicializando PaymentService: $e');
      }
      rethrow;
    }
  }

  Future<bool> canMakePayments() async {
    if (_payClient == null) {
      await initialize();
    }

    try {
      final canPay = await _payClient!.userCanPay(PayProvider.google_pay);
      return canPay;
    } catch (e) {
      if (kDebugMode) {
        print('Error verificando Google Pay: $e');
      }
      return false;
    }
  }

  Future<Map<String, dynamic>?> makePayment({
    required String label,
    required double amount,
    required String productId,
  }) async {
    try {
      if (_payClient == null) {
        await initialize();
      }

      final canPay = await canMakePayments();
      if (!canPay) {
        throw Exception('Google Pay no disponible');
      }

      final paymentItem = PaymentItem(
        label: label,
        amount: amount.toStringAsFixed(2),
        status: PaymentItemStatus.final_price,
      );

      final result = await _payClient!.showPaymentSelector(
        PayProvider.google_pay,
        [paymentItem],
      );

      final token = result.toString();

      return {
        'success': true,
        'token': token,
        'productId': productId,
        'amount': amount,
        'label': label,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error en el pago: $e');
      }
      rethrow;
    }
  }
}
