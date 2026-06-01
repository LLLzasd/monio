import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import '../models/account.dart';
import '../database/database_helper.dart';

class NetWorthTrendChart extends StatefulWidget {
  final List<Account> accounts;

  const NetWorthTrendChart({super.key, required this.accounts});

  @override
  State<NetWorthTrendChart> createState() => _NetWorthTrendChartState();
}

class _NetWorthTrendChartState extends State<NetWorthTrendChart> with TickerProviderStateMixin {
  String _selectedRange = '30天';
  
  // 真实历史数据（从数据库加载）
  List<Map<String, dynamic>> _historyData = [];
  bool _isLoadingHistory = true;

  // 动画相关
  late AnimationController _animationController;
  List<FlSpot> _previousSpots = []; // 上一次的数据点
  List<FlSpot> _targetSpots = [];   // 目标数据点
  bool _isAnimating = false;         // 是否正在执行动画

  @override
  void initState() {
    super.initState();
    
    // 初始化动画控制器 - 使用线性曲线实现更平滑的过渡
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500), // 500ms 的动画时长
    );
    
    // 监听动画进度，每帧更新UI
    _animationController.addListener(() {
      if (_animationController.isAnimating) {
        setState(() {});
      }
    });
    
    // 动画完成后的回调
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isAnimating = false;
          _previousSpots = List.from(_targetSpots);
        });
      }
    });
    
    _loadHistoryData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// 从数据库加载真实的历史净资产数据
  Future<void> _loadHistoryData() async {
    setState(() => _isLoadingHistory = true);
    
    try {
      // 根据选择的时间范围确定查询天数
      // 注意：增加缓冲天数，因为可能有些天没有数据记录
      int days;
      switch (_selectedRange) {
        case '6月':
          days = 200; // 180天 + 20天缓冲
          break;
        case '1年':
          days = 400; // 365天 + 35天缓冲
          break;
        case '全部年份':
          days = 365 * 5 + 50; // 最近5年 + 缓冲
          break;
        default: // 30天
          days = 45; // 30天 + 15天缓冲，确保包含最新数据
      }
      
      final history = await DatabaseHelper.instance.getNetWorthHistory(limit: days);
      
      if (mounted) {
        // 保存旧数据作为动画起点
        final newSpots = _generateChartDataFromHistory(history);
        
        // 如果有数据变化且不是首次加载，启动过渡动画
        if (newSpots.isNotEmpty && _previousSpots.isNotEmpty && !_isAnimating) {
          _targetSpots = newSpots;
          _isAnimating = true;
          
          // 从当前位置开始动画（使用线性曲线实现平滑过渡）
          _animationController.value = 0.0;
          _animationController.forward(from: 0.0);
        } else if (newSpots.isNotEmpty) {
          // 首次加载或无旧数据：直接显示
          _previousSpots = newSpots;
          _targetSpots = newSpots;
        }
        
        setState(() {
          _historyData = history;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      print('❌ 加载历史净资产数据失败: $e');
      if (mounted) {
        setState(() => _isLoadingHistory = false);
      }
    }
  }

  /// 基于历史数据生成图表点（带参数版本）
  List<FlSpot> _generateChartDataFromHistory(List<Map<String, dynamic>> historyData) {
    if (historyData.isEmpty) return [];
    
    final now = DateTime.now();
    DateTime startDate;
    
    // 根据选择范围过滤数据
    switch (_selectedRange) {
      case '6月':
        startDate = now.subtract(const Duration(days: 180));
        break;
      case '1年':
        startDate = now.subtract(const Duration(days: 365));
        break;
      case '全部年份':
        // 全部年份：使用所有可用数据
        if (historyData.isNotEmpty) {
          final firstDateStr = historyData.first['date'] as String;
          startDate = DateTime.parse(firstDateStr);
        } else {
          startDate = now.subtract(const Duration(days: 365 * 5));
        }
        break;
      default: // 30天
        startDate = now.subtract(const Duration(days: 30));
    }

    // 过滤在范围内的数据
    var filteredData = historyData.where((record) {
      final dateStr = record['date'] as String;
      final date = DateTime.parse(dateStr);
      return !date.isBefore(startDate) && !date.isAfter(now);
    }).toList();

    // 如果没有数据，返回空
    if (filteredData.isEmpty) {
      // 尝试放宽条件，只要有一条数据就显示
      filteredData = historyData.take(1).toList();
      if (filteredData.isEmpty) return [];
    }

    // 转换为 FlSpot 列表
    List<FlSpot> spots = [];
    
    if (_selectedRange == '全部年份') {
      // 全部年份模式：按年份聚合
      Map<int, Map<String, dynamic>> yearlyData = {};
      final currentYear = DateTime.now().year;
      
      for (var record in filteredData) {
        final dateStr = record['date'] as String;
        final date = DateTime.parse(dateStr);
        final year = date.year;
        final netWorth = record['net_worth'] as double;
        
        if (!yearlyData.containsKey(year)) {
          // 第一次遇到该年，记录
          yearlyData[year] = {
            'date': date,
            'netWorth': netWorth,
          };
        } else {
          final existingDate = yearlyData[year]!['date'] as DateTime;
          
          if (year == currentYear) {
            // 当前年份：选择最新的（当天）数据
            if (date.isAfter(existingDate)) {
              yearlyData[year] = {
                'date': date,
                'netWorth': netWorth,
              };
            }
          } else {
            // 历史年份：选择该年最后一天的数据
            if (date.isAfter(existingDate)) {
              yearlyData[year] = {
                'date': date,
                'netWorth': netWorth,
              };
            }
          }
        }
      }
      
      // 排序并转换为 FlSpot
      var sortedYears = yearlyData.keys.toList()..sort();
      int xIndex = 0;
      for (var year in sortedYears) {
        double amountInWan = yearlyData[year]!['netWorth'] / 10000;
        spots.add(FlSpot(xIndex.toDouble(), amountInWan));
        xIndex++;
      }
    } else {
      // 其他模式（30天、6月、1年）：按日期显示
      
      // 计算总天数（X轴的总范围）
      int totalDays;
      switch (_selectedRange) {
        case '6月':
          totalDays = 180;
          break;
        case '1年':
          totalDays = 365;
          break;
        default: // 30天
          totalDays = 30;
      }
      
      // 基于起始日期计算每个数据点的X坐标
      for (int i = 0; i < filteredData.length; i++) {
        var record = filteredData[i];
        final dateStr = record['date'] as String;
        final date = DateTime.parse(dateStr);
        final netWorth = record['net_worth'] as double;
        
        double amountInWan = netWorth / 10000;
        
        // X值 = 距离起始日期的天数（确保在 0 到 totalDays 范围内）
        double xValue = date.difference(startDate).inDays.toDouble();
        
        // 确保X值在有效范围内
        xValue = xValue.clamp(0.0, totalDays.toDouble());
        
        spots.add(FlSpot(xValue, amountInWan));
      }
    }

    return spots;
  }

  @override
  void didUpdateWidget(NetWorthTrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当账户列表变化时重新加载数据
    if (widget.accounts.length != oldWidget.accounts.length) {
      _loadHistoryData();
    }
  }

  List<FlSpot> get _chartData {
    // 如果正在执行动画，返回插值后的数据
    if (_isAnimating && _previousSpots.isNotEmpty && _targetSpots.isNotEmpty) {
      return _getInterpolatedSpots(_previousSpots, _targetSpots, _animationController.value);
    }
    
    // 否则使用目标数据或从历史数据生成
    if (_targetSpots.isNotEmpty) {
      return _targetSpots;
    }
    
    // 如果有真实历史数据，使用它
    if (_historyData.isNotEmpty) {
      final spots = _generateChartDataFromHistory(_historyData);
      _previousSpots = spots;
      _targetSpots = spots;
      return spots;
    }
    
    // 否则回退到模拟数据（兼容旧逻辑）
    return _generateSimulatedChartData();
  }

  /// 在两个数据集之间进行线性插值
  List<FlSpot> _getInterpolatedSpots(List<FlSpot> from, List<FlSpot> to, double t) {
    // 使用线性曲线确保平滑过渡
    t = Curves.linear.transform(t);
    
    // 确保t在0-1范围内
    t = t.clamp(0.0, 1.0);
    
    // 如果数据点数量不同，需要特殊处理
    int maxLen = math.max(from.length, to.length);
    List<FlSpot> interpolated = [];
    
    for (int i = 0; i < maxLen; i++) {
      double fromX = i < from.length ? from[i].x : (from.isNotEmpty ? from.last.x : 0);
      double fromY = i < from.length ? from[i].y : (from.isNotEmpty ? from.last.y : 0);
      double toX = i < to.length ? to[i].x : (to.isNotEmpty ? to.last.x : 0);
      double toY = i < to.length ? to[i].y : (to.isNotEmpty ? to.last.y : 0);
      
      // 线性插值
      double interpolatedX = fromX + (toX - fromX) * t;
      double interpolatedY = fromY + (toY - fromY) * t;
      
      interpolated.add(FlSpot(interpolatedX, interpolatedY));
    }
    
    return interpolated;
  }

  /// 回退方案：基于当前账户模拟历史数据（旧逻辑）
  List<FlSpot> _generateSimulatedChartData() {
    final now = DateTime.now();
    DateTime startDate;

    switch (_selectedRange) {
      case '6月':
        startDate = now.subtract(const Duration(days: 180));
        break;
      case '1年':
        startDate = now.subtract(const Duration(days: 365));
        break;
      case '全部年份':
        return _generateAllYearsData(now);
      default: // 30天
        startDate = now.subtract(const Duration(days: 30));
    }

    // 生成每天的数据点（始终以当前时间作为终点）
    List<FlSpot> spots = [];
    DateTime currentDate = startDate;

    while (!currentDate.isAfter(now)) {
      double totalAmount = 0;

      // 计算当天的总资产（只计算已存在的账户）
      for (var account in widget.accounts) {
        if (!currentDate.isBefore(account.addDate)) {
          totalAmount += account.amount;
        }
      }

      // 将金额转换为万元单位
      double amountInWan = totalAmount / 10000;

      spots.add(FlSpot(
        currentDate.difference(startDate).inDays.toDouble(),
        amountInWan,
      ));

      currentDate = currentDate.add(const Duration(days: 1));
    }

    return spots;
  }

  /// 生成“全部年份”数据：显示之前年份最后一天和当前日期的数据
  List<FlSpot> _generateAllYearsData(DateTime now) {
    if (widget.accounts.isEmpty) {
      // 无账户时返回空数据
      return [];
    }

    List<FlSpot> spots = [];

    // 检查是否有跨年数据（有账户在去年或之前添加）
    bool hasCrossYearData = widget.accounts.any(
      (account) => account.addDate.year < now.year
    );

    int xIndex = 0;

    // 如果有跨年数据，添加之前年份最后一天的数据
    if (hasCrossYearData) {
      // 找到之前的年份中最后一个年份
      int lastHistoricalYear = widget.accounts
          .map((a) => a.addDate.year)
          .where((year) => year < now.year)
          .reduce((a, b) => a > b ? a : b);

      // 该年的最后一天（12月31日）
      DateTime lastYearEnd = DateTime(lastHistoricalYear, 12, 31);

      // 计算该天的总资产
      double totalAmount = 0;
      for (var account in widget.accounts) {
        if (!lastYearEnd.isBefore(account.addDate)) {
          totalAmount += account.amount;
        }
      }
      double amountInWan = totalAmount / 10000;

      spots.add(FlSpot(xIndex.toDouble(), amountInWan));
      xIndex++;
    }

    // 添加当前日期的数据
    double currentAmount = 0;
    for (var account in widget.accounts) {
      if (!now.isBefore(account.addDate)) {
        currentAmount += account.amount;
      }
    }
    double currentAmountInWan = currentAmount / 10000;

    spots.add(FlSpot(xIndex.toDouble(), currentAmountInWan));

    return spots;
  }

  String _formatYAxisValue(double value) {
    if (value >= 10000) {
      return '${(value / 10000).toStringAsFixed(1)}亿';
    } else if (value >= 100) {
      final millions = value / 100;
      return '${millions.toStringAsFixed(1)}M';
    } else if (value >= 1) {
      return '${value.toStringAsFixed(1)}w';
    } else {
      return value.toStringAsFixed(1);
    }
  }

  String _formatXAxisValue(double value, DateTime startDate) {
    if (_selectedRange == '全部年份') {
      // 全部年份模式：显示年份
      final keyDates = _getAllYearsKeyDatesFromHistory();
      int index = value.toInt();
      if (index >= 0 && index < keyDates.length) {
        DateTime date = keyDates[index];
        return '${date.year}';
      }
      return '';
    }

    // 其他模式：基于天数偏移计算日期（X轴值 = 距起始日期的天数）
    final date = startDate.add(Duration(days: value.toInt()));
    
    // 根据时间范围选择不同的显示格式
    switch (_selectedRange) {
      case '30天':
        // 30天：显示 月/日，确保覆盖完整30天
        return '${date.month}/${date.day}';
      case '6月':
        // 6月：统一使用 月/日 格式，与其他模式保持一致
        return '${date.month}/${date.day}';
      case '1年':
        // 1年：显示 月/日 或 年-月（如果跨年）
        if (date.month == 1 || date.day == 1) {
          return '${date.year}/${date.month}';
        }
        return '${date.month}/${date.day}';
      default:
        return '${date.month}/${date.day}';
    }
  }

  /// 从历史数据中获取"全部年份"模式的年份列表
  List<DateTime> _getAllYearsKeyDatesFromHistory() {
    if (_historyData.isEmpty) return [];
    
    Set<int> years = {};
    
    for (var record in _historyData) {
      final dateStr = record['date'] as String;
      final date = DateTime.parse(dateStr);
      years.add(date.year);
    }
    
    // 排序并返回每年的代表性日期
    var sortedYears = years.toList()..sort();
    return sortedYears.map((year) => DateTime(year)).toList();
  }

  Widget _buildTimeRangeButton(String label, {bool isSelected = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () {
        setState(() => _selectedRange = label);
        // 切换时间范围时重新加载历史数据
        _loadHistoryData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? const Color(0xFF3A3A3C)   // 深色模式选中：中灰
                  : const Color(0xFF3A3A3C)) // 浅色模式选中：中灰 #3a3a3c
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected 
                ? Colors.white 
                : (isDark
                    ? const Color(0xFF9CA3AF)    // 深色模式未选：灰色
                    : const Color(0xFF6B7280)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_chartData.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoadingHistory)
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else ...[
              Icon(Icons.show_chart, size: 48, color: isDark ? const Color(0xFF6B7280) : Colors.grey[400]),
              const SizedBox(height: 12),
              Text(
                _historyData.isEmpty ? '暂无历史数据' : '暂无数据',
                style: TextStyle(fontSize: 16, color: isDark ? const Color(0xFF9CA3AF) : Colors.grey[600]),
              ),
              if (_historyData.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '使用App后会自动保存净资产快照',
                    style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF6B7280) : Colors.grey[500]),
                  ),
                ),
            ],
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 第一行：标题 + 时间选择器
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '净资产趋势',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,  // 深色模式：白色
                ),
              ),
              // 时间范围选择器
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTimeRangeButton('30天', isSelected: _selectedRange == '30天'),
                    const SizedBox(width: 4),
                    _buildTimeRangeButton('6月', isSelected: _selectedRange == '6月'),
                    const SizedBox(width: 4),
                    _buildTimeRangeButton('1年', isSelected: _selectedRange == '1年'),
                    const SizedBox(width: 4),
                    _buildTimeRangeButton('全部年份', isSelected: _selectedRange == '全部年份'),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 图表 - 使用 ClipRect 防止动画过程中溢出
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4), // 增加上下边距
            child: ClipRect(
              child: SizedBox(
                height: 330, // 增加高度以容纳所有标签
                child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: _calculateYInterval(),
                  verticalInterval: _calculateXInterval(),
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                      strokeWidth: 1,
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(
                      color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 48, // 进一步增加底部空间
                      interval: _calculateXInterval(),
                      getTitlesWidget: (value, meta) {
                        final startDate = _getStartDate();
                        final maxX = _getMaxX();

                        // 根据不同模式调整偏移量
                        double offset = 0;
                        if (_selectedRange == '全部年份') {
                          // 全部年份模式：年份标签（2026）需要更多空间
                          offset = value >= maxX - 0.5 ? 28 : 0;
                        } else {
                          // 其他模式：日期标签偏移
                          offset = value >= maxX - 1 ? 20 : 0;
                        }

                        return Padding(
                          padding: EdgeInsets.only(top: 8, right: offset),
                          child: Text(
                            _formatXAxisValue(value, startDate),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 75, // 增加左侧空间
                      interval: _calculateYInterval(),
                      getTitlesWidget: (value, meta) {
                        final maxY = _calculateMaxY();
                        
                        // 计算是否是最上面的标签，如果是则增加顶部padding避免被截断
                        final bool isTopLabel = value >= maxY * 0.9;
                        
                        return Padding(
                          padding: EdgeInsets.only(
                            right: 12,
                            top: isTopLabel ? 8 : 0, // 最上面的标签增加顶部空间
                          ),
                          child: Text(
                            _formatYAxisValue(value),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: _getMinX(),
                maxX: _getMaxX(),
                minY: 0,
                maxY: _calculateMaxY(),
                lineTouchData: const LineTouchData(
                  enabled: false,
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: _chartData,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: isDark ? const Color(0xFFF9FAFB) : const Color(0xFF111827),
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          (isDark ? const Color(0xFFF9FAFB) : const Color(0xFF111827)).withOpacity(0.15),
                          (isDark ? const Color(0xFFF9FAFB) : const Color(0xFF111827)).withOpacity(0.02),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ), // 关闭 ClipRect
        ), // 关闭 Padding
      ],
      ),
    );
  }

  DateTime _getStartDate() {
    final now = DateTime.now();
    switch (_selectedRange) {
      case '6月':
        return now.subtract(const Duration(days: 180));
      case '1年':
        return now.subtract(const Duration(days: 365));
      case '全部年份':
        if (widget.accounts.isEmpty) return now;
        return widget.accounts
            .map((a) => a.addDate)
            .reduce((a, b) => a.isBefore(b) ? a : b);
      default:
        return now.subtract(const Duration(days: 30));
    }
  }

  /// 计算Y轴最大值 - 基于实际数据，避免过度放大
  double _calculateMaxY() {
    if (_chartData.isEmpty) return 10;

    // 使用数据的实际最大值（更准确反映数据范围）
    double maxVal = _chartData.map((e) => e.y).reduce(math.max);

    // 增加顶部空间到10-12%，确保最上面的标签能完整显示
    maxVal = maxVal * 1.12;

    // 确保最小值为10（万元）
    maxVal = math.max(maxVal, 10);

    // 将maxY向上取整到interval的整数倍（避免与最后一个刻度重叠）
    final interval = _calculateYIntervalForMaxY(maxVal);
    final ceilingMax = (maxVal / interval).ceil() * interval;
    
    return math.max(ceilingMax, maxVal);
  }

  /// 为maxY计算合适的interval（内部使用）
  double _calculateYIntervalForMaxY(double maxY) {
    if (maxY <= 0) return 10;

    // 目标显示4-5个刻度
    var interval = maxY / 4;

    // 取整到合适的数值（1, 2, 5, 10, 20, 50...）
    final magnitude = math.pow(10, (math.log(interval) / math.ln10).floor());
    final normalized = interval / magnitude;

    double niceInterval;
    if (normalized < 1.5) {
      niceInterval = magnitude.toDouble();
    } else if (normalized < 3) {
      niceInterval = (2 * magnitude).toDouble();
    } else if (normalized < 7) {
      niceInterval = (5 * magnitude).toDouble();
    } else {
      niceInterval = (10 * magnitude).toDouble();
    }

    return math.max(niceInterval, 1);
  }

  double _calculateYInterval() {
    if (_chartData.isEmpty) return 10;

    final maxY = _calculateMaxY();
    if (maxY <= 0) return 10;

    // 目标显示4-5个刻度
    var interval = maxY / 4;

    // 取整到合适的数值（1, 2, 5, 10, 20, 50...）
    final magnitude = math.pow(10, (math.log(interval) / math.ln10).floor());
    final normalized = interval / magnitude;

    double niceInterval;
    if (normalized < 1.5) {
      niceInterval = magnitude.toDouble();
    } else if (normalized < 3) {
      niceInterval = (2 * magnitude).toDouble();
    } else if (normalized < 7) {
      niceInterval = (5 * magnitude).toDouble();
    } else {
      niceInterval = (10 * magnitude).toDouble();
    }

    // 确保最小间隔为1
    return math.max(niceInterval, 1);
  }

  double _calculateXInterval() {
    if (_chartData.isEmpty) return 7;
    
    // 根据不同时间范围设置固定的总天数
    int totalDays = _getTotalDaysForRange();
    
    if (_selectedRange == '全部年份') {
      // 全部年份模式：基于年份数量
      int yearCount = _chartData.length;
      if (yearCount <= 5) {
        return 1; // 每年都显示标签
      } else {
        return (yearCount / 5).ceilToDouble(); // 大约5-6个刻度
      }
    } else {
      // 其他模式：使用固定的天数范围
      // 目标：显示 5-6 个均匀分布的刻度标签
      final targetTickCount = 5.0;
      double interval = totalDays / targetTickCount;
      
      // 确保最小间隔合理
      interval = math.max(interval, 1);
      
      return interval;
    }
  }

  /// 获取当前时间范围的总天数
  int _getTotalDaysForRange() {
    switch (_selectedRange) {
      case '6月':
        return 180;
      case '1年':
        return 365;
      case '全部年份':
        return _chartData.length; // 年份数量
      default: // 30天
        return 30;
    }
  }

  /// 获取 X 轴最小值（始终为 0）
  double _getMinX() {
    return 0.0;
  }

  /// 获取 X 轴最大值（基于选择的时间范围或实际数据）
  double _getMaxX() {
    if (_chartData.isEmpty) return 30; // 默认30天
    
    switch (_selectedRange) {
      case '全部年份':
        // 全部年份模式：基于年份数量
        double maxIndex = (_chartData.length - 1).toDouble();
        return math.max(maxIndex, 0);
      case '6月':
      case '1年':
        // 对于固定时间范围，使用实际数据的最大X值，但确保不小于理论范围
        int theoreticalMax = _selectedRange == '6月' ? 180 : 365;
        if (_chartData.isNotEmpty) {
          // 使用实际数据中的最大X值
          double actualMax = _chartData.map((e) => e.x).reduce(math.max);
          // 确保至少显示到理论范围或实际数据范围（取较大值）
          return math.max(actualMax, theoreticalMax.toDouble());
        }
        return theoreticalMax.toDouble();
      default: // 30天
        // 30天模式：使用实际数据的最大X值，确保显示完整时间范围
        if (_chartData.isNotEmpty) {
          double actualMax = _chartData.map((e) => e.x).reduce(math.max);
          // 确保至少显示30天范围
          return math.max(actualMax, 30.0);
        }
        return 30.0;
    }
  }
}
