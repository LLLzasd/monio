import 'package:intl/intl.dart';

class CurrencyFormatter {
  static String format(double amount, {bool showSign = false}) {
    final formatter = NumberFormat.currency(
      locale: 'zh_CN',
      symbol: '',
      decimalDigits: 2,
    );

    String formatted = formatter.format(amount);

    if (showSign && amount > 0) {
      formatted = '+$formatted';
    }

    return formatted;
  }

  static String formatCompact(double amount) {
    if (amount >= 100000000) {
      return '${(amount / 100000000).toStringAsFixed(2)}亿';
    } else if (amount >= 10000) {
      return '${(amount / 10000).toStringAsFixed(2)}万';
    }
    return format(amount);
  }
}
