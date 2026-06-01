import 'package:flutter/material.dart';
import '../models/account.dart';

class AppConstants {
  static const List<AssetType> assetTypes = AssetType.values;

  static List<AssetSubType> getSubTypesForType(AssetType type) {
    return AssetSubType.values.where((sub) => sub.parentType == type).toList();
  }

  static const Map<String, String> currencies = {
    'CNY': '人民币',
    'USD': '美元',
    'EUR': '欧元',
    'JPY': '日元',
    'HKD': '港币',
    'GBP': '英镑',
  };

  static const Color primaryColor = Color(0xFF3B82F6);
  static const Color backgroundColor = Color(0xFFF9FAFB);
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color textPrimaryColor = Color(0xFF111827);
  static const Color textSecondaryColor = Color(0xFF6B7280);
  static const Color textTertiaryColor = Color(0xFF9CA3AF);
  static const Color dividerColor = Color(0xFFE5E7EB);

  static Color parseColor(String hexColor) {
    final colorHex = hexColor.replaceAll('#', '');
    return Color(int.parse('0xFF$colorHex'));
  }
}
