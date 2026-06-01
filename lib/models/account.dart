class Account {
  final String id;
  final String name;
  final AssetType type;
  final AssetSubType subType;
  final double amount;
  final String currency;
  final DateTime addDate;
  final DateTime? updateDate;
  final String? remark;
  final int sortOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Account({
    required this.id,
    required this.name,
    required this.type,
    required this.subType,
    required this.amount,
    this.currency = 'CNY',
    required this.addDate,
    this.updateDate,
    this.remark,
    this.sortOrder = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'sub_type': subType.name,
      'amount': amount,
      'currency': currency,
      'add_date': addDate.toIso8601String(),
      'update_date': updateDate?.toIso8601String(),
      'remark': remark,
      'sort_order': sortOrder,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'],
      name: map['name'],
      type: AssetType.values.firstWhere((e) => e.name == map['type']),
      subType: AssetSubType.values.firstWhere((e) => e.name == map['sub_type']),
      amount: map['amount'],
      currency: map['currency'] ?? 'CNY',
      addDate: DateTime.parse(map['add_date']),
      updateDate: map['update_date'] != null ? DateTime.parse(map['update_date']) : DateTime.parse(map['updated_at']),
      remark: map['remark'],
      sortOrder: map['sort_order'] ?? 0,
      isActive: map['is_active'] == 1,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  Account copyWith({
    String? name,
    double? amount,
    String? currency,
    DateTime? addDate,
    String? remark,
    DateTime? updateDate,
  }) {
    return Account(
      id: id,
      name: name ?? this.name,
      type: type,
      subType: subType,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      addDate: addDate ?? this.addDate,
      updateDate: updateDate ?? DateTime.now(),
      remark: remark ?? this.remark,
      sortOrder: sortOrder,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

enum AssetType {
  liquid('流动资金', '#54c871'),
  investment('投资', '#6361d1'),
  fixed_asset('固定资产', '#5f7bd7'),
  receivable('应收款项', '#9eb2f3'),
  liability('负债', '#c6cfe1');

  const AssetType(this.displayName, this.color);
  final String displayName;
  final String color;

  String get description {
    switch (this) {
      case AssetType.liquid:
        return '现金、微信、支付宝等';
      case AssetType.investment:
        return '基金、股票等';
      case AssetType.fixed_asset:
        return '房产、汽车等';
      case AssetType.receivable:
        return '借出资金、押金等';
      case AssetType.liability:
        return '信用卡、贷款等';
    }
  }
}

enum AssetSubType {
  cash('现金'),
  digital_wallet('网络账户'),
  debit_card('储蓄卡'),
  other_liquid('其他流动资金'),
  fund('基金'),
  stock('股票'),
  bond('债券'),
  other_investment('其他投资'),
  property('房产'),
  vehicle('汽车'),
  other_fixed('其他固定资产'),
  lending('借出资金'),
  deposit('待收款项'),
  other_receivable('其他应收'),
  credit_card('信用卡'),
  loan('贷款'),
  other_liability('其他负债');

  const AssetSubType(this.displayName);
  final String displayName;

  AssetType get parentType {
    if (index <= 3) return AssetType.liquid;
    if (index <= 7) return AssetType.investment;
    if (index <= 10) return AssetType.fixed_asset;
    if (index <= 13) return AssetType.receivable;
    return AssetType.liability;
  }
}
