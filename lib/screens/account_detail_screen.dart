import 'package:flutter/material.dart';
import '../models/account.dart';
import '../models/fund_account.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_time_formatter.dart';
import '../widgets/app_dialogs.dart';

class AccountDetailScreen extends StatelessWidget {
  final Account account;

  const AccountDetailScreen({super.key, required this.account});

  bool get isFund => account is FundAccount;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
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
          account.name,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.bar_chart_outlined, color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.red[400]),
            onPressed: () => _showDeleteDialog(context),
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined, color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
            onPressed: () {},
          ),
        ],
      ),
      body: isFund ? _buildFundDetail(context, isDark) : _buildNormalDetail(context, isDark),
    );
  }

  Widget _buildNormalDetail(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSummaryCard(context, isDark),
          const SizedBox(height: 24),
          _buildActionButtons(context),
          const SizedBox(height: 16),
          _buildTimeInfo(context, isDark),
          const SizedBox(height: 24),
          _buildTransactionHistory(context, isDark),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            '当前金额',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? const Color(0xFF9CA3AF) : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            CurrencyFormatter.format(account.amount),
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              side: BorderSide(color: Theme.of(context).primaryColor),
            ),
            child: Text(
              '增减金额',
              style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 16),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: Text(
              '更新金额',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeInfo(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('创建时间', style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF9CA3AF) : Colors.grey[600])),
              const SizedBox(height: 4),
              Text(
                DateTimeFormatter.formatDateTime(account.addDate),
                style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurface),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('更新时间', style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF9CA3AF) : Colors.grey[600])),
              const SizedBox(height: 4),
              Text(
                DateTimeFormatter.formatDateTime(account.updateDate),
                style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurface),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionHistory(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('变动历史', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: isDark ? const Color(0xFFD1D5DB) : Colors.grey[700])),
          const SizedBox(height: 16),
          _buildTransactionItem(context, isDark,
            title: '新增资产：${account.type.displayName}',
            amount: '+${CurrencyFormatter.format(account.amount)}',
            date: DateTimeFormatter.formatDateTime(account.addDate),
            isAdd: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(BuildContext context, bool isDark, {
    required String title,
    required String amount,
    required String date,
    bool isAdd = true,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isAdd ? const Color(0xFF10B981).withOpacity(0.1) : const Color(0xFFEF4444).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isAdd ? Icons.add : Icons.remove,
              size: 18,
              color: isAdd ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 2),
                Text(date, style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF6B7280) : Colors.grey[500])),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isAdd ? const Color(0xFF10B981) : Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF), size: 20),
        ],
      ),
    );
  }

  // 基金详情页（参考9.jpg）
  Widget _buildFundDetail(BuildContext context, bool isDark) {
    final fundAccount = account as FundAccount;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildFundSummaryCard(context, fundAccount, isDark),
          const SizedBox(height: 24),
          _buildFundActionButtons(context),
          const SizedBox(height: 16),
          _buildFundTimeInfo(context, isDark),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildFundSummaryCard(BuildContext context, FundAccount fund, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            '当前净值',
            style: TextStyle(fontSize: 14, color: isDark ? const Color(0xFF9CA3AF) : Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          Text(
            CurrencyFormatter.format(fund.calculatedAmount),
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${fund.profitRate >= 0 ? '+' : ''}${fund.profitRate.toStringAsFixed(2)}%',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: fund.isProfitable 
                  ? const Color(0xFFEF4444)  // 正收益：红色
                  : const Color(0xFF10B981), // 负收益：绿色
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFundActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              side: BorderSide(color: Theme.of(context).primaryColor),
            ),
            child: Text(
              '刷新净值',
              style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 16),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            child: Text(
              '修改金额',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFundTimeInfo(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('创建时间', style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF9CA3AF) : Colors.grey[600])),
              const SizedBox(height: 4),
              Text(
                DateTimeFormatter.formatDateTime(account.addDate),
                style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurface),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('更新时间', style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF9CA3AF) : Colors.grey[600])),
              const SizedBox(height: 4),
              Text(
                DateTimeFormatter.formatDateTime(account.updateDate),
                style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurface),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    AppDialogs.showDeleteConfirm(
      context: context,
      accountName: account.name,
    ).then((confirmed) {
      if (confirmed) {
        Navigator.pop(context, true);
      }
    });
  }
}
