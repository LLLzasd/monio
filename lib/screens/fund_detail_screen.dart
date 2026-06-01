import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/fund_account.dart';
import '../providers/account_provider.dart';
import '../database/database_helper.dart';
import '../widgets/app_dialogs.dart';
import 'edit_account_screen.dart';

class FundDetailScreen extends StatefulWidget {
  final FundAccount fundAccount;

  const FundDetailScreen({super.key, required this.fundAccount});

  @override
  State<FundDetailScreen> createState() => _FundDetailScreenState();
}

class _FundDetailScreenState extends State<FundDetailScreen> {
  List<Map<String, dynamic>> _navHistory = [];
  bool _isLoading = true;
  FundAccount? _currentFund;

  @override
  void initState() {
    super.initState();
    // 从 Provider 获取最新数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAndLoadHistory();
    });
  }

  Future<void> _refreshAndLoadHistory() async {
    try {
      // 从 Provider 获取最新的基金账户数据（确保 fundInfo 是最新的）
      final provider = context.read<AccountProvider>();
      final latestAccount = provider.accounts.firstWhere(
        (a) => a.id == widget.fundAccount.id,
        orElse: () => widget.fundAccount,
      );
      
      if (latestAccount is FundAccount && mounted) {
        setState(() {
          _currentFund = latestAccount;
        });
        
        print('📊 最新基金信息: ${_currentFund!.fundInfo?.fundCode} - ${_currentFund!.name}');
        
        await _loadNavHistory();
      } else if (mounted) {
        _currentFund = widget.fundAccount;
        await _loadNavHistory();
      }
    } catch (e) {
      print('❌ 获取最新基金数据失败: $e');
      if (mounted) {
        _currentFund = widget.fundAccount;
        await _loadNavHistory();
      }
    }
  }

  Future<void> _loadNavHistory() async {
    setState(() => _isLoading = true);
    
    try {
      final fundCode = _currentFund?.fundInfo?.fundCode ?? widget.fundAccount.fundInfo?.fundCode ?? '';
      print('📊 加载基金变动历史: fundCode=$fundCode');
      
      if (fundCode.isEmpty) {
        print('⚠️ 基金代码为空，无法加载历史');
        setState(() => _isLoading = false);
        return;
      }
      
      final history = await DatabaseHelper.instance.getFundNavHistory(
        fundCode: fundCode,
      );
      
      print('📊 查询到 ${history.length} 条变动记录');
      for (var item in history) {
        print('  - [${item['type']}] ${item['fund_name']}: ¥${item['change_amount']} @ ${item['created_at']}');
      }
      
      if (mounted) {
        setState(() {
          _navHistory = history;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      print('❌ 加载变动历史失败: $e');
      print('❌ Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fund = _currentFund ?? widget.fundAccount;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        elevation: 0,
        centerTitle: false, // 标题靠左
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 20, color: isDark ? Colors.white : const Color(0xFF333333)),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Text(
          fund.name,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF333333),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.red[400], size: 22),
            onPressed: _showDeleteConfirm,
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined, color: const Color(0xFF999999), size: 22),
            onPressed: _navigateToEdit,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNavCard(context, fund, isDark),
            const SizedBox(height: 24),
            _buildHistorySection(context, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildNavCard(BuildContext context, FundAccount fund, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '当前净值',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF999999),
            ),
          ),
          const SizedBox(height: 12),
          // 金额 - 居中
          Center(
            child: Text(
              '${fund.calculatedAmount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF333333),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 收益率 - 居中
          Center(
            child: Text(
              '收益率 ${fund.profitRate >= 0 ? '+' : ''}${fund.profitRate.toStringAsFixed(2)}%',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: fund.profitRate >= 0 
                    ? (isDark ? const Color(0xFFFF453A) : const Color(0xFFFF3B30)) // 正数：红色（涨）
                    : (isDark ? const Color(0xFF30D158) : const Color(0xFF34C759)), // 负数：绿色（跌）
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '变动历史',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 12),
        if (_isLoading)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          )
        else if (_navHistory.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                '暂无变动记录',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF999999),
                ),
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _navHistory.map((item) => _buildHistoryItem(item, isDark)).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> item, bool isDark) {
    final type = item['type'] as String? ?? 'refresh';
    final fundName = item['fund_name'] as String? ?? '';
    final title = type == 'add' ? '新增资产：$fundName' : '自动刷新净值';
    final oldNav = item['old_nav'] as double? ?? 0.0;
    final newNav = item['new_nav'] as double? ?? 0.0;
    final changeAmount = item['change_amount'] as double? ?? 0.0;
    final timeStr = item['created_at'] as String? ?? '';
    
    DateTime? time;
    try {
      time = DateTime.parse(timeStr);
    } catch (_) {}
    
    final timeDisplay = time != null 
        ? '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
        : '';

    // 根据类型设置颜色
    final isAddType = type == 'add';
    final iconBgColor = isAddType 
        ? (isDark ? const Color(0xFF30D158) : const Color(0xFF34C759))
        : const Color(0xFFFF9500); // 橙色
    
    return Container(
      margin: const EdgeInsets.only(bottom: 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF38383A) : const Color(0xFFF0F0F0),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 左侧图标
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconBgColor.withOpacity(isAddType ? 0.15 : 1.0),
            ),
            child: Icon(
              isAddType ? Icons.add : Icons.refresh,
              size: 18,
              color: isAddType ? iconBgColor : Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          // 中间内容
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF333333),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!isAddType && oldNav > 0 && newNav > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '¥${oldNav.toStringAsFixed(3)} → ¥${newNav.toStringAsFixed(3)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF999999),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  timeDisplay,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF8E8E93) : const Color(0xFFBBBBBB),
                  ),
                ),
              ],
            ),
          ),
          // 右侧金额和箭头
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${changeAmount >= 0 ? "+" : "-"}${changeAmount.abs().toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: changeAmount == 0
                      ? (isDark ? const Color(0xFF8E8E93) : const Color(0xFF999999)) // 无变化：灰色
                      : changeAmount > 0
                          ? (isDark ? const Color(0xFFFF453A) : const Color(0xFFFF3B30)) // 增加：红色
                          : (isDark ? const Color(0xFF30D158) : const Color(0xFF34C759)), // 减少：绿色
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: isDark ? const Color(0xFF8E8E93) : const Color(0xFFCCCCCC),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm() async {
    final confirmed = await AppDialogs.showDeleteConfirm(
      context: context,
      title: '删除资产',
      content: '确认删除该基金？此操作将无法撤销。',
      accountName: widget.fundAccount.name,
    );

    if (confirmed && mounted) {
      final success = await context.read<AccountProvider>().deleteAccount(widget.fundAccount.id);
      
      if (success && mounted) {
        AppDialogs.showSuccessToast(context: context, message: '资产已成功删除');
        Navigator.pop(context, true);
      }
    }
  }

  void _navigateToEdit() async {
    final fundToEdit = _currentFund ?? widget.fundAccount;
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditAccountScreen(account: fundToEdit),
      ),
    );
    
    if (result == true && mounted) {
      await context.read<AccountProvider>().loadAccounts();
      // 刷新当前页面数据
      await _refreshAndLoadHistory();
    }
  }
}
