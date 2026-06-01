import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';
import '../models/account.dart';
import '../models/fund_account.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('assets.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 5, // 升级版本号（4 → 5）
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE accounts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        sub_type TEXT NOT NULL,
        amount REAL NOT NULL DEFAULT 0,
        currency TEXT NOT NULL DEFAULT 'CNY',
        add_date TEXT NOT NULL,
        update_date TEXT,
        remark TEXT,
        sort_order INTEGER DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        
        -- 基金特殊字段
        shares REAL DEFAULT 0,
        cost_price REAL DEFAULT 0,
        unit_price REAL DEFAULT NULL, -- 持有单价（可选）
        fund_code TEXT,
        fund_name TEXT,
        fund_nav REAL DEFAULT 0,
        fund_nav_date TEXT,
        fund_type TEXT
      )
    ''');

    await db.execute('CREATE INDEX idx_accounts_type ON accounts(type)');
    await db.execute('CREATE INDEX idx_accounts_active ON accounts(is_active)');
    await db.execute('CREATE INDEX idx_fund_code ON accounts(fund_code)');

    await db.execute('''
      CREATE TABLE net_worth_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        total_assets REAL NOT NULL DEFAULT 0,
        total_liabilities REAL NOT NULL DEFAULT 0,
        net_worth REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('CREATE UNIQUE INDEX idx_nwh_date ON net_worth_history(date)');

    // 基金净值变化历史表
    await db.execute('''
      CREATE TABLE fund_nav_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fund_code TEXT NOT NULL,
        fund_name TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'refresh',
        old_nav REAL DEFAULT 0,
        new_nav REAL DEFAULT 0,
        change_amount REAL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    
    await db.execute('CREATE INDEX idx_fnh_fund_code ON fund_nav_history(fund_code)');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 添加基金字段
      await db.execute('ALTER TABLE accounts ADD COLUMN shares REAL DEFAULT 0');
      await db.execute('ALTER TABLE accounts ADD COLUMN cost_price REAL DEFAULT 0');
      await db.execute('ALTER TABLE accounts ADD COLUMN fund_code TEXT');
      await db.execute('ALTER TABLE accounts ADD COLUMN fund_name TEXT');
      await db.execute('ALTER TABLE accounts ADD COLUMN fund_nav REAL DEFAULT 0');
      await db.execute('ALTER TABLE accounts ADD COLUMN fund_nav_date TEXT');
      await db.execute('ALTER TABLE accounts ADD COLUMN fund_type TEXT');
      
      await db.execute('CREATE INDEX idx_fund_code ON accounts(fund_code)');
    }

    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE net_worth_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          total_assets REAL NOT NULL DEFAULT 0,
          total_liabilities REAL NOT NULL DEFAULT 0,
          net_worth REAL NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL
        )
      ''');

      await db.execute('CREATE UNIQUE INDEX idx_nwh_date ON net_worth_history(date)');
    }

    if (oldVersion < 4) {
      // 添加持有单价字段
      await db.execute('ALTER TABLE accounts ADD COLUMN unit_price REAL DEFAULT NULL');
    }

    if (oldVersion < 5) {
      // 添加基金净值变化历史表
      await db.execute('''
        CREATE TABLE fund_nav_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          fund_code TEXT NOT NULL,
          fund_name TEXT NOT NULL,
          type TEXT NOT NULL DEFAULT 'refresh',
          old_nav REAL DEFAULT 0,
          new_nav REAL DEFAULT 0,
          change_amount REAL DEFAULT 0,
          created_at TEXT NOT NULL
        )
      ''');
      
      await db.execute('CREATE INDEX idx_fnh_fund_code ON fund_nav_history(fund_code)');
    }
  }

  Future<int> create(Account account) async {
    final db = await instance.database;
    
    Map<String, dynamic> map = account.toMap();
    
    // 如果是基金账户，添加特殊字段
    if (account.runtimeType.toString() == 'FundAccount') {
      final fundAccount = account as dynamic;
      map['shares'] = fundAccount.shares ?? 0;
      map['cost_price'] = fundAccount.costPrice ?? 0;
      map['unit_price'] = fundAccount.unitPrice; // 持有单价
      if (fundAccount.fundInfo != null) {
        map['fund_code'] = fundAccount.fundInfo!.fundCode;
        map['fund_name'] = fundAccount.fundInfo!.fundName;
        map['fund_nav'] = fundAccount.fundInfo!.nav;
        map['fund_nav_date'] = fundAccount.fundInfo!.navDate?.toIso8601String();
        map['fund_type'] = fundAccount.fundInfo!.fundType;
      }
    }
    
    return await db.insert('accounts', map);
  }

  Future<Account> read(String id) async {
    final db = await instance.database;
    final maps = await db.query(
      'accounts',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return _createAccountFromMap(maps.first);
    } else {
      throw Exception('ID $id not found');
    }
  }

  Future<List<Account>> readAll() async {
    final db = await instance.database;
    final result = await db.query('accounts', orderBy: 'sort_order ASC');
    return result.map((map) => _createAccountFromMap(map)).toList();
  }

  Future<List<Account>> readByType(AssetType type) async {
    final db = await instance.database;
    final result = await db.query(
      'accounts',
      where: 'type = ? AND is_active = 1',
      whereArgs: [type.name],
      orderBy: 'sort_order ASC',
    );
    return result.map((map) => _createAccountFromMap(map)).toList();
  }

  Future<int> update(Account account) async {
    final db = await instance.database;
    
    Map<String, dynamic> map = account.toMap();
    
    // 如果是基金账户，更新特殊字段
    if (account.runtimeType.toString() == 'FundAccount') {
      final fundAccount = account as dynamic;
      map['shares'] = fundAccount.shares ?? 0;
      map['cost_price'] = fundAccount.costPrice ?? 0;
      map['unit_price'] = fundAccount.unitPrice; // 持有单价
      if (fundAccount.fundInfo != null) {
        map['fund_code'] = fundAccount.fundInfo!.fundCode;
        map['fund_name'] = fundAccount.fundInfo!.fundName;
        map['fund_nav'] = fundAccount.fundInfo!.nav;
        map['fund_nav_date'] = fundAccount.fundInfo!.navDate?.toIso8601String();
        map['fund_type'] = fundAccount.fundInfo!.fundType;
      }
    }
    
    return db.update(
      'accounts',
      map,
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  Future<int> delete(String id) async {
    final db = await instance.database;
    return await db.delete(
      'accounts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<double> getTotalByType(AssetType type) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM accounts WHERE type = ? AND is_active = 1',
      [type.name],
    );
    return result.first['total'] as double;
  }

  Future<double> getNetWorth() async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(CASE WHEN type != 'liability' THEN amount ELSE 0 END), 0) -
        COALESCE(SUM(CASE WHEN type = 'liability' THEN amount ELSE 0 END), 0)
        as net_worth
      FROM accounts WHERE is_active = 1
    ''');
    return result.first['net_worth'] as double;
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }

  /// 保存净资产历史记录（优化版：自动清理旧数据）
  /// 存储策略：
  /// 1. 最近一年（今天到去年同一天）：保留所有明细数据
  /// 2. 超过一年的历史：每年只保留该年最后一天的记录
  Future<void> saveNetWorthHistory({
    required DateTime date,
    required double totalAssets,
    required double totalLiabilities,
    required double netWorth,
    bool autoCleanup = true, // 新增参数：是否自动清理
  }) async {
    final db = await instance.database;
    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    await db.insert(
      'net_worth_history',
      {
        'date': dateStr,
        'total_assets': totalAssets,
        'total_liabilities': totalLiabilities,
        'net_worth': netWorth,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // 自动清理旧数据（保留最近1年明细 + 历史年汇总）
    if (autoCleanup) {
      await _cleanupNetWorthHistory();
    }
  }

  /// 批量保存净资产历史记录（高性能版本）
  /// 用于导入场景，只在最后执行一次清理
  Future<void> batchSaveNetWorthHistory(List<Map<String, dynamic>> records) async {
    if (records.isEmpty) return;

    final db = await instance.database;
    final batch = db.batch();

    for (var record in records) {
      batch.insert(
        'net_worth_history',
        {
          'date': record['date'],
          'total_assets': record['totalAssets'] ?? 0.0,
          'total_liabilities': record['totalLiabilities'] ?? 0.0,
          'net_worth': record['netWorth'] ?? 0.0,
          'created_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(); // 一次性提交所有插入

    // 只在最后执行一次清理
    await _cleanupNetWorthHistory();
  }

  /// 清理净资产历史数据
  /// - 保留最近1年的所有明细
  /// - 超过1年的部分，每年只保留最后一天的数据
  Future<void> _cleanupNetWorthHistory() async {
    final db = await instance.database;
    final now = DateTime.now();

    // 计算一年前的日期（去年同一天）
    final oneYearAgo = DateTime(now.year - 1, now.month, now.day);
    final oneYearAgoStr = DateFormat('yyyy-MM-dd').format(oneYearAgo);

    // 使用优化的SQL：一次性查询需要保留的数据
    final cleanData = await db.rawQuery('''
      SELECT * FROM (
        -- 第一部分：保留最近1年的所有明细
        SELECT * FROM net_worth_history 
        WHERE date >= ?
        
        UNION ALL
        
        -- 第二部分：超过1年的历史，每年只保留最后一天
        SELECT nh.* FROM net_worth_history nh
        INNER JOIN (
          SELECT MAX(date) as max_date 
          FROM net_worth_history 
          WHERE date < ?
          GROUP BY strftime('%Y', date)
        ) grouped ON nh.date = grouped.max_date
      )
      ORDER BY date ASC
    ''', [oneYearAgoStr, oneYearAgoStr]);

    // 清空原表并重新插入清理后的数据
    if (cleanData.isNotEmpty) {
      await db.delete('net_worth_history');

      for (var row in cleanData) {
        await db.insert(
          'net_worth_history',
          {
            'date': row['date'],
            'total_assets': row['total_assets'],
            'total_liabilities': row['total_liabilities'],
            'net_worth': row['net_worth'],
            'created_at': row['created_at'] ?? DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
  }

  /// 手动清理净资产历史数据（可在外部调用）
  Future<void> cleanupNetWorthHistory() async {
    await _cleanupNetWorthHistory();
  }

  Future<List<Map<String, dynamic>>> getNetWorthHistory({
    int? limit,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await instance.database;

    String where = '1=1';
    List<dynamic> whereArgs = [];

    if (startDate != null) {
      where += ' AND date >= ?';
      whereArgs.add(DateFormat('yyyy-MM-dd').format(startDate));
    }

    if (endDate != null) {
      where += ' AND date <= ?';
      whereArgs.add(DateFormat('yyyy-MM-dd').format(endDate));
    }

    // 使用子查询获取最新的limit条数据
    if (limit != null && limit > 0) {
      final result = await db.rawQuery('''
        SELECT * FROM net_worth_history
        WHERE $where
        ORDER BY date DESC
        LIMIT ?
      ''', [...whereArgs, limit]);

      // 反转顺序，使数据按时间升序排列（从早到晚）
      return result.reversed.toList();
    }

    return await db.query(
      'net_worth_history',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'date ASC',
      limit: limit,
    );
  }

  Account _createAccountFromMap(Map<String, dynamic> map) {
    final subTypeStr = map['sub_type'];
    
    // 如果是基金账户，创建 FundAccount 对象
    if (subTypeStr == 'fund' && map['fund_code'] != null) {
      FundInfo? fundInfo;
      
      // 创建基金信息对象
      if (map['fund_code'] != null && map['fund_code'].toString().isNotEmpty) {
        fundInfo = FundInfo(
          fundCode: map['fund_code'],
          fundName: map['fund_name'] ?? '',
          nav: map['fund_nav'] ?? 0.0,
          navDate: map['fund_nav_date'] != null ? DateTime.parse(map['fund_nav_date']) : null,
          fundType: map['fund_type'] ?? 'ETF',
        );
      }
      
      return FundAccount(
        id: map['id'],
        name: map['fund_name'] ?? map['name'],
        type: AssetType.values.firstWhere((e) => e.name == map['type']),
        subType: AssetSubType.fund,
        amount: (map['shares'] ?? 0.0) * (map['fund_nav'] ?? 0.0),
        currency: map['currency'] ?? 'CNY',
        addDate: DateTime.parse(map['add_date']),
        updateDate: map['update_date'] != null ? DateTime.parse(map['update_date']) : DateTime.parse(map['updated_at']),
        remark: map['remark'],
        sortOrder: map['sort_order'] ?? 0,
        isActive: map['is_active'] == 1,
        createdAt: DateTime.parse(map['created_at']),
        updatedAt: DateTime.parse(map['updated_at']),
        fundInfo: fundInfo,
        shares: map['shares'] ?? 0.0,
        costPrice: map['cost_price'] ?? 0.0,
        unitPrice: map['unit_price'], // 持有单价
      );
    }
    
    // 普通账户
    return Account.fromMap(map);
  }

  /// 清除所有净资产历史记录
  Future<void> clearNetWorthHistory() async {
    final db = await database;
    await db.delete('net_worth_history');
  }

  /// 清除所有资产账户
  Future<void> clearAllAccounts() async {
    final db = await database;
    await db.delete('accounts');
  }

  /// 清除基金净值变化历史
  Future<void> clearFundNavHistory() async {
    final db = await database;
    await db.delete('fund_nav_history');
  }

  // ========== 基金净值变化历史 ==========

  /// 保存基金净值变化记录
  Future<void> saveFundNavHistory({
    required String fundCode,
    required String fundName,
    required String type, // 'refresh' 或 'add'
    double oldNav = 0.0,
    double newNav = 0.0,
    double changeAmount = 0.0,
  }) async {
    final db = await database;
    
    // 规范化基金代码（统一为6位格式）
    final normalizedCode = _normalizeFundCode(fundCode);
    
    await db.insert(
      'fund_nav_history',
      {
        'fund_code': normalizedCode, // 使用规范化的代码
        'fund_name': fundName,
        'type': type,
        'old_nav': oldNav,
        'new_nav': newNav,
        'change_amount': changeAmount,
        'created_at': DateTime.now().toIso8601String(),
      },
    );
  }

  /// 获取基金净值变化历史（只返回最近30天的记录）
  Future<List<Map<String, dynamic>>> getFundNavHistory({
    required String fundCode,
    int? limit,
  }) async {
    final db = await database;

    // 规范化 fundCode（补齐6位）
    final normalizedCode = _normalizeFundCode(fundCode);

    // 计算30天前的日期
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();

    // 查询时匹配原始代码或规范化后的代码，且只返回最近30天
    return await db.query(
      'fund_nav_history',
      where: '(fund_code = ? OR fund_code = ?) AND created_at >= ?',
      whereArgs: [fundCode, normalizedCode, thirtyDaysAgo],
      orderBy: 'created_at DESC',
      limit: limit ?? 100,
    );
  }
  
  /// 规范化基金代码（补齐6位，如 1875 -> 001875）
  static String _normalizeFundCode(String code) {
    // 如果已经是6位或更长，直接返回
    if (code.length >= 6) {
      return code;
    }
    
    // 补齐6位（前面补0）
    return code.padLeft(6, '0');
  }
}
