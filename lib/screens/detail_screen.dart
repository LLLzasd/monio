import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/account.dart';
import '../models/fund_account.dart';
import '../providers/account_provider.dart';
import '../utils/currency_formatter.dart';
import '../utils/constants.dart';
import '../utils/date_time_formatter.dart';
import 'select_sub_type_screen.dart';
import 'edit_account_screen.dart';

class DetailScreen extends StatefulWidget {
  final AssetType assetType;

  const DetailScreen({super.key, required this.assetType});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  bool _isRefreshing = false;
  
  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  Future<void> _refreshFundData(BuildContext context) async {
    if (_isRefreshing) return;
    
    setState(() => _isRefreshing = true);
    
    try {
      final provider = context.read<AccountProvider>();
      await provider.refreshFundNavData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('净值更新成功'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
          widget.assetType.displayName,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        actions: [
          if (widget.assetType == AssetType.investment)
            // 投资页面：同时显示刷新和添加两个按钮
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 刷新按钮
                Container(
                  margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF374151) : Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(Icons.refresh, color: Colors.white, size: 18),
                    onPressed: () => _refreshFundData(context),
                  ),
                ),
                // 添加按钮
                Container(
                  margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF374151) : Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(Icons.add, color: Colors.white, size: 20),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SelectSubTypeScreen(assetType: widget.assetType),
                        ),
                      );
                    },
                  ),
                ),
              ],
            )
          else
            // 其他页面：只显示添加按钮
            Container(
              margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF374151) : Colors.black,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(Icons.add, color: Colors.white, size: 20),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SelectSubTypeScreen(assetType: widget.assetType),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
      body: Consumer<AccountProvider>(
        builder: (context, provider, child) {
          final accounts = provider.getAccountsByType(widget.assetType);
          final total = provider.getTotalByType(widget.assetType);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryCard(total, accounts),
                const SizedBox(height: 24),
                ..._buildAccountGroups(context, accounts),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(double total, List<Account> accounts) {
    final baseColor = AppConstants.parseColor(widget.assetType.color);
    final darkColor = baseColor.withOpacity(0.85);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [baseColor, darkColor],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.assetType.displayName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          if (accounts.isNotEmpty)
            _CustomEllipsisText(
              text: accounts.map((a) => a.name).join('、'),
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            CurrencyFormatter.format(total),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAccountGroups(BuildContext context, List<Account> accounts) {
    if (accounts.isEmpty) {
      return [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 64,
                  color: isDark ? const Color(0xFF6B7280) : Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  '暂无账户',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? const Color(0xFF9CA3AF) : Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '点击右上角 + 添加账户',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? const Color(0xFF6B7280) : Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
        )
      ];
    }

    final groups = <AssetSubType, List<Account>>{};
    for (var account in accounts) {
      groups.putIfAbsent(account.subType, () => []);
      groups[account.subType]!.add(account);
    }

    List<Widget> widgets = [];
    for (var entry in groups.entries) {
      widgets.addAll([
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            entry.key.displayName,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
            ),
          ),
        ),
        ...entry.value.map((account) => _buildAccountCard(context, account)),
      ]);
    }

    return widgets;
  }

  Widget _buildAccountCard(BuildContext context, Account account) {
    // 判断是否为基金账户（使用安全的运行时类型检查）
    final fundAccount = account is FundAccount ? account : null;

    return GestureDetector(
      onTap: () {
        // 所有账户（包括基金）都直接进入编辑页面
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EditAccountScreen(account: account),
          ),
        ).then((result) {
          // 返回后刷新数据
          if (result == true) {
            context.read<AccountProvider>().loadAccounts();
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(
              color: AppConstants.parseColor(account.type.color),
              width: 3,
            ),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // 如果是基金账户，在名称下方显示收益率
                  if (isFund && fundAccount != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${fundAccount.profitRate >= 0 ? '+' : ''}${fundAccount.profitRate.toStringAsFixed(2)}%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: fundAccount.isProfitable 
                            ? const Color(0xFFEF4444)  // 正收益：红色
                            : const Color(0xFF10B981), // 负收益：绿色
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '¥ ',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(account.amount).substring(1),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF), size: 20),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  DateTimeFormatter.formatDateTime(account.updateDate),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomEllipsisText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const _CustomEllipsisText({
    required this.text,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textSpan = TextSpan(text: text, style: style);
        final textPainter = TextPainter(
          text: textSpan,
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);

        if (!textPainter.didExceedMaxLines) {
          return Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
        }

        String displayText = text;
        for (int i = text.length - 1; i > 0; i--) {
          final candidate = '${text.substring(0, i)}...';
          final candidateSpan = TextSpan(text: candidate, style: style);
          final candidatePainter = TextPainter(
            text: candidateSpan,
            maxLines: 1,
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: constraints.maxWidth);

          if (!candidatePainter.didExceedMaxLines) {
            displayText = candidate;
            break;
          }
        }

        return Text(displayText, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
      },
    );
  }
}
