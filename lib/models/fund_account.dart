import 'account.dart';

class FundInfo {
  final String fundCode;
  final String fundName;
  final double nav; // 单位净值 (Net Asset Value) - 昨日净值
  final DateTime? navDate;
  final String fundType;

  // 新增字段 - 实时估值数据
  final double? estimatedNav; // 估算净值 (gsz) - 盘中实时估值
  final double? estimatedChangePercent; // 估算涨跌幅 (gszzl) - 实时涨跌%
  final String? estimatedTime; // 估值时间 (gztime)
  final double? yesterdayChangePercent; // 昨日涨跌幅 (zzl)
  final double? lastNav; // 上一个交易日净值

  FundInfo({
    required this.fundCode,
    required this.fundName,
    required this.nav,
    this.navDate,
    this.fundType = 'ETF',
    this.estimatedNav,
    this.estimatedChangePercent,
    this.estimatedTime,
    this.yesterdayChangePercent,
    this.lastNav,
  });

  factory FundInfo.fromJson(Map<String, dynamic> json) {
    return FundInfo(
      fundCode: json['fundcode'] ?? json['code'] ?? '',
      fundName: json['name'] ?? json['shortname'] ?? '',
      nav: double.tryParse(json['dwjz']?.toString() ?? '0') ?? 0.0,
      navDate: json['jzrq'] != null ? DateTime.parse(json['jzrq']) : null,
      fundType: json['type'] ?? 'ETF',
      // 解析实时估值数据
      estimatedNav: json['gsz'] != null ? double.tryParse(json['gsz'].toString()) : null,
      estimatedChangePercent: json['gszzl'] != null ? double.tryParse(json['gszzl'].toString()) : null,
      estimatedTime: json['gztime']?.toString(),
      yesterdayChangePercent: json['zzl'] != null ? double.tryParse(json['zzl'].toString()) : null,
      lastNav: json['lastNav'] != null ? double.tryParse(json['lastNav'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fundCode': fundCode,
      'fundName': fundName,
      'nav': nav,
      'navDate': navDate?.toIso8601String(),
      'fundType': fundType,
      // 实时估值数据
      'estimatedNav': estimatedNav,
      'estimatedChangePercent': estimatedChangePercent,
      'estimatedTime': estimatedTime,
      'yesterdayChangePercent': yesterdayChangePercent,
      'lastNav': lastNav,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'fund_code': fundCode,
      'fund_name': fundName,
      'nav': nav,
      'nav_date': navDate?.toIso8601String(),
      'fund_type': fundType,
      // 实时估值数据
      'estimated_nav': estimatedNav,
      'estimated_change_percent': estimatedChangePercent,
      'estimated_time': estimatedTime,
      'yesterday_change_percent': yesterdayChangePercent,
      'last_nav': lastNav,
    };
  }

  static FundInfo fromMap(Map<String, dynamic> map) {
    return FundInfo(
      fundCode: map['fund_code'],
      fundName: map['fund_name'],
      nav: map['nav'],
      navDate: map['nav_date'] != null ? DateTime.parse(map['nav_date']) : null,
      fundType: map['fund_type'] ?? 'ETF',
      // 实时估值数据
      estimatedNav: map['estimated_nav'],
      estimatedChangePercent: map['estimated_change_percent'],
      estimatedTime: map['estimated_time'],
      yesterdayChangePercent: map['yesterday_change_percent'],
      lastNav: map['last_nav'],
    );
  }

  // 计算属性 - 便捷访问
  double? get currentEstimatedNav => estimatedNav ?? nav; // 当前估值（优先使用估算净值）
  double? get changePercent => estimatedChangePercent ?? yesterdayChangePercent; // 涨跌幅

  bool get hasRealTimeData => estimatedNav != null && estimatedChangePercent != null; // 是否有实时数据
  bool get isPositive => (changePercent ?? 0) >= 0; // 是否上涨

  @override
  String toString() => '$fundName ($fundCode)${estimatedChangePercent != null ? ' ${(estimatedChangePercent! > 0 ? "+" : "")}$estimatedChangePercent%' : ''}';
}

class FundAccount extends Account {
  final FundInfo? fundInfo;
  final double shares; // 持有份额
  final double costPrice; // 成本价（总成本 = 持有单价 × 份额 或手动输入）
  final double? unitPrice; // 持有单价（可选）

  FundAccount({
    required super.id,
    required super.name,
    required super.type,
    required super.subType,
    required super.amount,
    super.currency,
    required super.addDate,
    super.updateDate,
    super.remark,
    super.sortOrder,
    super.isActive,
    required super.createdAt,
    required super.updatedAt,
    this.fundInfo,
    this.shares = 0.0,
    this.costPrice = 0.0,
    this.unitPrice, // 可选
  });

  double get currentNav => fundInfo?.nav ?? 0.0;

  double get calculatedAmount => shares * currentNav;

  // costPrice 存储的是总成本金额（不是每股成本）
  double get totalCost => costPrice;

  // 基于持有单价的成本（如果有的话）
  double get costBasedOnUnitPrice {
    if (unitPrice != null && unitPrice! > 0) {
      return unitPrice! * shares;
    }
    return costPrice; // 否则使用存储的 costPrice
  }

  // 实际使用的成本价（优先使用单价计算的）
  double get effectiveCost {
    // 优先级：手动输入的成本价 > 基于单价的成本
    if (costPrice > 0) return costPrice;
    if (unitPrice != null && unitPrice! > 0) return unitPrice! * shares;
    return 0;
  }

  double get profit => calculatedAmount - effectiveCost;

  double get profitRate {
    final cost = effectiveCost;
    
    if (cost > 0) {
      // 有有效成本价：（当前金额 - 总成本）/ 总成本 * 100%
      return (calculatedAmount - cost) / cost * 100;
    } else if (unitPrice != null && unitPrice! > 0) {
      // 有持有单价但无总成本：用单价计算
      final unitCost = unitPrice! * shares;
      return (calculatedAmount - unitCost) / unitCost * 100;
    } else if (amount > 0 && amount != calculatedAmount) {
      // 没有成本价但有初始金额记录：(当前金额 - 初始金额) / 初始金额 * 100%
      return (calculatedAmount - amount) / amount * 100;
    } else {
      // 完全无法计算
      return 0.0;
    }
  }

  bool get isProfitable => profitRate >= 0;

  FundAccount copyWithFund({
    FundInfo? fundInfo,
    double? shares,
    double? costPrice,
    double? amount,
    String? name,
    double? unitPrice,
  }) {
    return FundAccount(
      id: id,
      name: name ?? (fundInfo?.fundName ?? this.name),
      type: type,
      subType: subType,
      amount: amount ?? calculatedAmount,
      currency: currency,
      addDate: addDate,
      updateDate: DateTime.now(),
      remark: remark,
      sortOrder: sortOrder,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      fundInfo: fundInfo ?? this.fundInfo,
      shares: shares ?? this.shares,
      costPrice: costPrice ?? this.costPrice,
      unitPrice: unitPrice ?? this.unitPrice,
    );
  }

  Map<String, dynamic> toFundMap() {
    final map = toMap();
    map['shares'] = shares;
    map['cost_price'] = costPrice;
    if (unitPrice != null) {
      map['unit_price'] = unitPrice;
    }
    if (fundInfo != null) {
      map['fund_info'] = fundInfo!.toMap();
    }
    return map;
  }
}

// 基金数据库 - 现在完全依赖API获取数据
class FundDatabase {
  static List<FundInfo> searchFunds(String query) {
    // 不再使用本地预设数据，全部通过API获取
    return [];
  }

  static FundInfo? getFundByCode(String code) {
    // 通过API获取，本地不缓存
    return null;
  }
}
