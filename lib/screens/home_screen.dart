import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../models/account.dart';
import '../models/fund_account.dart';
import '../providers/account_provider.dart';
import '../utils/currency_formatter.dart';
import '../utils/constants.dart';
import '../utils/date_time_formatter.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/swipe_to_delete.dart';
import '../widgets/animated_number_text.dart';
import 'select_type_screen.dart';
import 'edit_account_screen.dart';
import 'fund_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  String _selectedTimePeriod = 'today'; // today, lastMonth, lastQuarter, lastYear
  final Set<AssetType> _expandedTypes = {};
  final Map<AssetType, AnimationController> _animationControllers = {};

  // 收益变化数据
  double _changeAmount = 0.0;
  double _changePercent = 0.0;
  bool _hasChangeData = false;
  bool _isLoadingChange = false;

  Timer? _timeUpdateTimer;
  bool _isFirstLoadComplete = false; // 标记首次加载是否完成

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AccountProvider>().loadAccounts().then((_) {
        // 只在首次初始化时自动刷新基金净值数据
        final provider = context.read<AccountProvider>();
        if (provider.needsFundInitialization) {
          _refreshFundData();
          provider.markFundDataInitialized(); // 标记已初始化
        }
      });
    });

    // 初始化时加载当前时间段的收益变化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadChangeData();
    });

    // 启动定时器，每60秒刷新一次时间显示和资产数据（让"xx分钟前更新"自动更新）
    _timeUpdateTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      if (mounted) {
        // 刷新时间显示
        setState(() {});

        // 异步刷新资产数据和对比数据（如果数据变化会触发动画）
        try {
          await context.read<AccountProvider>().loadAccounts();
          _loadChangeData(); // 对比数据变化时会触发滚动动画
        } catch (e) {
          print('⚠️ 定时器刷新数据失败: $e');
        }
      }
    });
  }

  /// 异步刷新基金数据（不阻塞UI）
  Future<void> _refreshFundData() async {
    try {
      await context.read<AccountProvider>().refreshFundNavData();
      
      // 刷新后保存快照并更新收益数据
      await context.read<AccountProvider>().saveNetWorthSnapshot();
      await _loadChangeData();
      
      print('✅ 基金净值数据刷新完成');
    } catch (e) {
      print('⚠️ 基金净值刷新失败（非致命）: $e');
    }
  }

  /// 加载指定时间段的收益变化数据
  Future<void> _loadChangeData() async {
    if (_isLoadingChange) return;

    setState(() => _isLoadingChange = true);

    try {
      final changeData = await context.read<AccountProvider>().getChangeByPeriod(_selectedTimePeriod);

      if (changeData != null) {
        final newAmount = changeData['change'] ?? 0.0;
        final newPercent = changeData['changePercent'] ?? 0.0;
        final newHasData = changeData['hasData'] ?? false;

        // 首次加载时：直接显示目标值，不播放动画
        if (!_isFirstLoadComplete) {
          setState(() {
            _changeAmount = newAmount;
            _changePercent = newPercent;
            _hasChangeData = newHasData;
          });
          _isFirstLoadComplete = true; // 标记首次加载完成
          return; // 直接返回，不触发动画
        }

        // ✨ 后续更新：只要数据不同就更新并允许动画
        // 不再限制变化量大小，让 AnimatedNumberText 自己决定是否需要动画
        if (newAmount != _changeAmount ||
            newPercent != _changePercent ||
            newHasData != _hasChangeData) {
          setState(() {
            _changeAmount = newAmount;
            _changePercent = newPercent;
            _hasChangeData = newHasData;
          });
          // AnimatedNumberText 会自动检测到值变化并播放动画
        }
      }
    } catch (e) {
      print('⚠️ 加载收益数据失败: $e');
    } finally {
      setState(() => _isLoadingChange = false);
    }
  }

  /// 获取收益颜色（用于图标）
  Color _getChangeColor() {
    if (!_hasChangeData) return Colors.grey;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _changeAmount >= 0
        ? (isDark ? const Color(0xFFFF453A) : const Color(0xFFFF3B30)) // 增加：红色
        : (isDark ? const Color(0xFF30D158) : const Color(0xFF34C759)); // 减少：绿色
  }

  /// 获取收益颜色（用于文字）
  Color _getChangeTextColor() {
    if (!_hasChangeData) return Colors.grey;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _changeAmount >= 0
        ? (isDark ? const Color(0xFFFF453A) : const Color(0xFFFF3B30)) // 增加：红色
        : (isDark ? const Color(0xFF30D158) : const Color(0xFF34C759)); // 减少：绿色
  }

  /// 获取趋势图标
  IconData _getTrendIcon() {
    if (!_hasChangeData) return Icons.help_outline;
    return _changeAmount >= 0 ? Icons.trending_up : Icons.trending_down;
  }

  @override
  void dispose() {
    _timeUpdateTimer?.cancel(); // 清理定时器
    for (var controller in _animationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  AnimationController _getOrCreateController(AssetType type) {
    if (!_animationControllers.containsKey(type)) {
      _animationControllers[type] = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
        value: _expandedTypes.contains(type) ? 1.0 : 0.0,
      );
    }
    return _animationControllers[type]!;
  }

  void _toggleExpand(AssetType type) {
    final controller = _getOrCreateController(type);
    final isCurrentlyExpanded = _expandedTypes.contains(type);

    setState(() {
      if (isCurrentlyExpanded) {
        _expandedTypes.remove(type);
        controller.reverse();
      } else {
        _expandedTypes.add(type);
        controller.forward();
      }
    });
  }

  void _showTimePeriodSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _buildTimePeriodSheet(),
    );
  }

  Widget _buildTimePeriodSheet() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '选择对比时间',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF9CA3AF)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildTimeOption(
            icon: Icons.access_time_rounded,
            title: '今日',
            subtitle: '与昨日相比的变化',
            value: 'today',
          ),
          const SizedBox(height: 12),
          _buildTimeOption(
            icon: Icons.calendar_month_outlined,
            title: '上月',
            subtitle: '与上个月同期相比的变化',
            value: 'lastMonth',
          ),
          const SizedBox(height: 12),
          _buildTimeOption(
            icon: Icons.date_range_outlined,
            title: '上季度',
            subtitle: '与上个季度同期相比的变化',
            value: 'lastQuarter',
          ),
          const SizedBox(height: 12),
          _buildTimeOption(
            icon: Icons.today_outlined,
            title: '上年',
            subtitle: '与去年同期相比的变化',
            value: 'lastYear',
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTimeOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
  }) {
    final isSelected = _selectedTimePeriod == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () {
        setState(() => _selectedTimePeriod = value);
        Navigator.pop(context);
        // 加载新选择的时间段数据
        _loadChangeData();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF3A3A3C)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isDark
                    ? const Color(0xFF9CA3AF)
                    : const Color(0xFF6B7280),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: const Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Color(0xFF3B82F6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                ),
              )
            else
              const SizedBox(width: 24, height: 24),
          ],
        ),
      ),
    );
  }

  String _getTimePeriodText() {
    switch (_selectedTimePeriod) {
      case 'today':
        return '今日';
      case 'lastMonth':
        return '上月';
      case 'lastQuarter':
        return '上季度';
      case 'lastYear':
        return '上年';
      default:
        return '今日';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark 
          ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Theme.of(context).scaffoldBackgroundColor)
          : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Theme.of(context).scaffoldBackgroundColor),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SelectTypeScreen()),
                      ).then((_) async {
                        // 添加资产后刷新账户数据和对比数据
                        await context.read<AccountProvider>().loadAccounts(); // 先等待账户数据更新
                        _loadChangeData(); // 然后再刷新对比数据
                      });
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF474747)
                            : const Color(0xFFE2E2E2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFCBCBCB)
                            : const Color(0xFF1F2937),
                        size: 24,
                        weight: 700,
                      ),
                    ),
                  ),
                ],
              ),
              Consumer<AccountProvider>(
                builder: (context, provider, child) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      _buildNetWorthHeader(provider),
                      const SizedBox(height: 24),
                      ...AssetType.values.map((type) => _buildAssetTypeCard(context, provider, type)),
                      const SizedBox(height: 80),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildNetWorthHeader(AccountProvider provider) {
    final netWorth = provider.getNetWorth();
    final displayAmount = provider.isAmountVisible
        ? CurrencyFormatter.format(netWorth)
        : '****';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  '净资产',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => provider.toggleAmountVisibility(),
                  child: Icon(
                    provider.isAmountVisible ? Icons.visibility : Icons.visibility_off,
                    color: const Color(0xFF3B82F6),
                    size: 20,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        provider.isAmountVisible
            ? AnimatedNumberText(
                key: const ValueKey('netWorth'),
                value: netWorth,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
                duration: const Duration(milliseconds: 800),
                decimalPlaces: 2,
              )
            : Text(
                displayAmount,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(_getTrendIcon(), color: _getChangeColor(), size: 16),
            const SizedBox(width: 4),
            // AnimatedNumberText 始终存在（保证动画连续性）
            Opacity(
              opacity: _isLoadingChange ? 0.3 : 1.0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedNumberText(
                    key: const ValueKey('changeAmount'),
                    value: _changeAmount,
                    prefix: _changeAmount >= 0 ? '+' : '',
                    style: TextStyle(
                      fontSize: 14,
                      color: _getChangeTextColor(),
                      fontWeight: FontWeight.w500,
                    ),
                    duration: const Duration(milliseconds: 800),
                    decimalPlaces: 2,
                  ),
                  const SizedBox(width: 8),
                  AnimatedNumberText(
                    key: const ValueKey('changePercent'),
                    value: _changePercent,
                    prefix: _changePercent >= 0 ? '+' : '',
                    suffix: '%',
                    style: TextStyle(
                      fontSize: 14,
                      color: _getChangeTextColor(),
                      fontWeight: FontWeight.w500,
                    ),
                    duration: const Duration(milliseconds: 800),
                    decimalPlaces: 2,
                  ),
                ],
              ),
            ),
            // 加载中提示（紧跟在数字后面）
            if (_isLoadingChange)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  '加载中...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            const SizedBox(width: 12),
            // 只有这个区域可以触发选择对比时间窗口
            GestureDetector(
              onTap: _showTimePeriodSelector,
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getTimePeriodText(),
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down, color: Color(0xFF6B7280), size: 18),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAssetTypeCard(BuildContext context, AccountProvider provider, AssetType type) {
    final total = provider.getTotalByType(type);
    final accounts = provider.getAccountsByType(type);
    final controller = _getOrCreateController(type);

    final String accountNames;
    if (accounts.isEmpty) {
      accountNames = type.description;
    } else {
      accountNames = accounts.map((a) => a.name).join('、');
    }

    DateTime? latestUpdateTime;
    if (accounts.isNotEmpty) {
      final updateDates = accounts
          .map((a) => a.updateDate)
          .where((date) => date != null)
          .cast<DateTime>()
          .toList();

      if (updateDates.isNotEmpty) {
        latestUpdateTime = updateDates.reduce((a, b) => a.isAfter(b) ? a : b);
      }
    }

    // 预构建账户列表（缓存到child参数中，避免每帧重建）
    final accountListWidget = accounts.isNotEmpty
        ? Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: accounts
                  .map((account) => RepaintBoundary(
                        child: _buildAccountItem(context, account),
                      ))
                  .toList(),
            ),
          )
        : const SizedBox.shrink();

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        // 动画状态值
        final colorValue = controller.value.clamp(0.0, 1.0);

        return Column(
          children: [
            GestureDetector(
              onTap: () => _toggleExpand(type),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppConstants.parseColor(type.color),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: Stack(
                      children: [
                        // 颜色层动画（使用简单的ClipRRect替代嵌套AnimatedBuilder）
                        if (colorValue > 0)
                          Positioned.fill(
                            child: ClipRRect(
                              clipper: _ExpandClipper(colorValue),
                              child: Container(
                                color: AppConstants.parseColor(type.color),
                              ),
                            ),
                          ),
                        // 卡片内容层
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    type.displayName,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                  Text(
                                    CurrencyFormatter.format(total),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              SizeTransition(
                                sizeFactor: CurvedAnimation(
                                  parent: ReverseAnimation(controller),
                                  curve: Curves.easeInOut,
                                ),
                                axisAlignment: -1.0,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        flex: 1,
                                        child: Text(
                                          accountNames,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF6B7280),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Flexible(
                                        flex: 1,
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: latestUpdateTime != null
                                              ? Text(
                                                  DateTimeFormatter.formatRelativeTime(latestUpdateTime),
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Color(0xFF9CA3AF),
                                                  ),
                                                )
                                              : const SizedBox.shrink(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // 账户列表展开区域（使用缓存的child参数）
            SizeTransition(
              sizeFactor: CurvedAnimation(
                parent: controller,
                curve: Curves.easeOut,
              ),
              axisAlignment: 0.0,
              child: child!,
            ),
          ],
        );
      },
      // 将账户列表作为child参数传入，避免每帧重建
      child: accountListWidget,
    );
  }

  Widget _buildAccountItem(BuildContext context, Account account) {
    final isFund = account is FundAccount;
    final fundAccount = isFund ? account : null;

    return SwipeToDelete(
      onDelete: () async {
        final confirmed = await AppDialogs.showDeleteConfirm(
          context: context,
        );

        if (confirmed && mounted) {
          final success = await context
              .read<AccountProvider>()
              .deleteAccount(account.id);

          if (success) {
            AppDialogs.showSuccessToast(context: context, message: '资产已成功删除');
            // 删除成功后刷新账户数据和对比数据（确保净资产金额动画生效）
            await context.read<AccountProvider>().loadAccounts(); // 先等待账户数据更新完成
            _loadChangeData(); // 然后再刷新对比数据
          }
        }
      },
      child: GestureDetector(
        onTap: () {
          if (isFund && fundAccount != null) {
            // 基金账户：进入详情页面
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FundDetailScreen(fundAccount: fundAccount!),
              ),
            ).then((result) async {
              if (result == true) {
                await context.read<AccountProvider>().loadAccounts(); // 先等待账户数据更新
                _loadChangeData(); // 然后再刷新对比数据
              }
            });
          } else {
            // 其他账户：进入编辑页面
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EditAccountScreen(account: account),
              ),
            ).then((result) async {
              if (result == true) {
                await context.read<AccountProvider>().loadAccounts(); // 先等待账户数据更新
                _loadChangeData(); // 然后再刷新对比数据
              }
            });
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    if (isFund && fundAccount != null)
                      Text(
                        '${fundAccount.profitRate >= 0 ? '+' : ''}${fundAccount.profitRate.toStringAsFixed(2)}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: fundAccount.isProfitable 
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF10B981),
                        ),
                      )
                    else
                      Text(
                        account.subType.displayName,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.format(account.amount),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.parseColor(account.type.color),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateTimeFormatter.formatRelativeTime(account.updateDate),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 从左向右展开的裁剪器（带圆角）
class _ExpandClipper extends CustomClipper<RRect> {
  final double progress; // 0.0 到 1.0
  static const double _minWidth = 5.0; // 未选中时的最小宽度（颜色条）
  static const double _cardBorderRadius = 12.0; // 卡片圆角半径
  static const double _colorBarBorderRadius = 6.0; // 颜色条圆角半径（比卡片小，更伸展）

  _ExpandClipper(this.progress);

  @override
  RRect getClip(Size size) {
    // 计算宽度：从最小宽度到卡片完整宽度
    final minWidth = _minWidth;
    final maxWidth = size.width;
    final width = minWidth + (maxWidth - minWidth) * progress;

    // 左侧圆角使用较小的半径，让颜色条更伸展
    final leftRadius = Radius.circular(_colorBarBorderRadius);

    // 右侧圆角：未展开时无圆角，完全展开时与卡片一致
    final rightRadius = width >= size.width
        ? Radius.circular(_cardBorderRadius)
        : Radius.zero;

    return RRect.fromRectAndCorners(
      Rect.fromLTWH(0, 0, width, size.height),
      topLeft: leftRadius,
      bottomLeft: leftRadius,
      topRight: rightRadius,
      bottomRight: rightRadius,
    );
  }

  @override
  bool shouldReclip(covariant _ExpandClipper oldClipper) {
    return oldClipper.progress != progress;
  }
}
