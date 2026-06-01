import 'package:flutter/material.dart';
import '../models/account.dart';
import '../utils/constants.dart';
import 'add_account_screen.dart';
import 'add_fund_screen.dart';

class SelectSubTypeScreen extends StatelessWidget {
  final AssetType assetType;

  const SelectSubTypeScreen({super.key, required this.assetType});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subTypes = AppConstants.getSubTypesForType(assetType);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          assetType.displayName,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text(
              '选择${assetType.displayName}类型',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: subTypes.length,
                itemBuilder: (context, index) {
                  final subType = subTypes[index];
                  return _buildSubTypeCard(context, subType);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubTypeCard(BuildContext context, AssetSubType subType) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    IconData iconData;
    switch (subType) {
      case AssetSubType.cash:
        iconData = Icons.money;
        break;
      case AssetSubType.digital_wallet:
        iconData = Icons.language;
        break;
      case AssetSubType.debit_card:
        iconData = Icons.credit_card;
        break;
      case AssetSubType.other_liquid:
        iconData = Icons.phone_android;
        break;
      case AssetSubType.fund:
        iconData = Icons.show_chart;
        break;
      case AssetSubType.stock:
        iconData = Icons.candlestick_chart;
        break;
      case AssetSubType.bond:
        iconData = Icons.description;
        break;
      case AssetSubType.other_investment:
        iconData = Icons.savings;
        break;
      case AssetSubType.property:
        iconData = Icons.home_work;
        break;
      case AssetSubType.vehicle:
        iconData = Icons.directions_car;
        break;
      case AssetSubType.other_fixed:
        iconData = Icons.build;
        break;
      case AssetSubType.lending:
        iconData = Icons.person;
        break;
      case AssetSubType.deposit:
        iconData = Icons.list_alt;
        break;
      case AssetSubType.other_receivable:
        iconData = Icons.note;
        break;
      case AssetSubType.credit_card:
        iconData = Icons.credit_score;
        break;
      case AssetSubType.loan:
        iconData = Icons.account_balance;
        break;
      case AssetSubType.other_liability:
        iconData = Icons.help_outline;
        break;
    }

    return GestureDetector(
      onTap: () {
        // 如果是基金子类型，跳转到基金专用添加页面
        if (subType == AssetSubType.fund) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddFundScreen(
                assetType: assetType,
                subType: subType,
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddAccountScreen(
                assetType: assetType,
                subType: subType,
              ),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppConstants.parseColor(subType.parentType.color),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(iconData, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                subType.displayName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }
}
