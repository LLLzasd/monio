import 'package:flutter/foundation.dart';
import '../models/account.dart';
import '../models/fund_account.dart';
import '../database/database_helper.dart';
import '../services/fund_api_service.dart';

class AccountProvider with ChangeNotifier {
  List<Account> _accounts = [];
  bool _isLoading = false;
  bool _isAmountVisible = true;
  bool _hasInitializedFundData = false; // 标记是否已执行过首次基金数据初始化

  List<Account> get accounts => _accounts;
  bool get isLoading => _isLoading;
  bool get isAmountVisible => _isAmountVisible;

  /// 检查是否需要初始化基金数据（只在首次调用时返回true）
  bool get needsFundInitialization => !_hasInitializedFundData;

  /// 标记基金数据已初始化
  void markFundDataInitialized() {
    _hasInitializedFundData = true;
  }

  Future<void> loadAccounts() async {
    _isLoading = true;
    notifyListeners();

    try {
      _accounts = await DatabaseHelper.instance.readAll();
    } catch (e) {
      print('Error loading accounts: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<Account> getAccountsByType(AssetType type) {
    return _accounts.where((a) => a.type == type && a.isActive).toList();
  }

  double getTotalByType(AssetType type) {
    return getAccountsByType(type).fold(0.0, (sum, a) => sum + a.amount);
  }

  double getNetWorth() {
    double assets = 0.0;
    double liabilities = 0.0;

    for (var account in _accounts.where((a) => a.isActive)) {
      if (account.type == AssetType.liability) {
        liabilities += account.amount;
      } else {
        assets += account.amount;
      }
    }

    return assets - liabilities;
  }

  void toggleAmountVisibility() {
    _isAmountVisible = !_isAmountVisible;
    notifyListeners();
  }

  Future<bool> addAccount(Account account) async {
    try {
      await DatabaseHelper.instance.create(account);
      _accounts.add(account);
      notifyListeners();
      return true;
    } catch (e) {
      print('Error adding account: $e');
      return false;
    }
  }

  Future<bool> updateAccount(Account account) async {
    try {
      await DatabaseHelper.instance.update(account);
      final index = _accounts.indexWhere((a) => a.id == account.id);
      if (index != -1) {
        _accounts[index] = account;
      }
      notifyListeners();
      return true;
    } catch (e) {
      print('Error updating account: $e');
      return false;
    }
  }

  Future<bool> deleteAccount(String id) async {
    try {
      await DatabaseHelper.instance.delete(id);
      _accounts.removeWhere((a) => a.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      print('Error deleting account: $e');
      return false;
    }
  }

  /// 刷新所有基金的净值数据（从 API 获取最新数据）
  /// 失败的基金会进行重试，最多尝试3次
  Future<void> refreshFundNavData() async {
    try {
      final fundAccounts = _accounts
          .where((a) => a.subType == AssetSubType.fund)
          .toList();

      // 记录需要重试的基金（最多重试2次，加上初始尝试共3次）
      List<FundAccount> failedAccounts = fundAccounts.whereType<FundAccount>().toList();
      const maxRetries = 2;

      for (int attempt = 0; attempt <= maxRetries && failedAccounts.isNotEmpty; attempt++) {
        if (attempt > 0) {
          print('🔄 第${attempt}次重试刷新失败基金，共${failedAccounts.length}个');
        }

        final nextFailedAccounts = <FundAccount>[];

        for (var account in failedAccounts) {
          if (account.fundInfo != null) {
            try {
              // 使用真实 API 获取最新净值数据（包含 fallback 机制）
              final updatedFundInfo = await FundApiService.getFundDetail(account.fundInfo!.fundCode);

              if (updatedFundInfo != null && updatedFundInfo.nav > 0) {
                final oldNav = account.currentNav;
                final newNav = updatedFundInfo.nav;
                final changeAmount = (newNav - oldNav) * account.shares;

                // 记录净值变化历史（每次刷新都记录）
                await DatabaseHelper.instance.saveFundNavHistory(
                  fundCode: account.fundInfo!.fundCode,
                  fundName: account.fundInfo!.fundName,
                  type: 'refresh',
                  oldNav: oldNav,
                  newNav: newNav,
                  changeAmount: changeAmount,
                );

                final updatedFund = account.copyWithFund(
                  fundInfo: updatedFundInfo,
                  amount: account.shares * updatedFundInfo.nav, // 重新计算当前金额
                );

                await DatabaseHelper.instance.update(updatedFund);

                final index = _accounts.indexWhere((a) => a.id == account.id);
                if (index != -1) {
                  _accounts[index] = updatedFund;
                }
              }
            } catch (e) {
              print('❌ 刷新基金 ${account.fundInfo?.fundCode ?? 'unknown'} 失败 (第${attempt + 1}次): $e');
              // 加入下一轮重试列表
              if (attempt < maxRetries) {
                nextFailedAccounts.add(account);
              } else {
                print('⚠️ 基金 ${account.fundInfo?.fundCode ?? 'unknown'} 已达到最大重试次数，放弃刷新');
              }
            }
          }
        }

        failedAccounts = nextFailedAccounts;
      }

      notifyListeners();
    } catch (e) {
      print('Error refreshing fund data: $e');
      rethrow;
    }
  }

  /// 刷新单个基金的净值数据
  Future<void> refreshSingleFundNav(String accountId) async {
    try {
      final account = _accounts.firstWhere((a) => a.id == accountId);

      if (account is FundAccount && account.fundInfo != null) {
        final updatedFundInfo = await FundApiService.getFundDetail(account.fundInfo!.fundCode);

        if (updatedFundInfo != null && updatedFundInfo.nav > 0) {
          final updatedFund = account.copyWithFund(
            fundInfo: updatedFundInfo,
            amount: account.shares * updatedFundInfo.nav,
          );

          await DatabaseHelper.instance.update(updatedFund);

          final index = _accounts.indexWhere((a) => a.id == accountId);
          if (index != -1) {
            _accounts[index] = updatedFund;
          }

          notifyListeners();
        }
      }
    } catch (e) {
      print('Error refreshing single fund: $e');
      rethrow;
    }
  }

  // ========== 历史净资产对比功能 ==========

  /// 保存当前净资产快照到历史记录
  Future<void> saveNetWorthSnapshot() async {
    try {
      final netWorth = getNetWorth();
      double totalAssets = 0;
      double totalLiabilities = 0;

      for (var account in _accounts.where((a) => a.isActive)) {
        if (account.type == AssetType.liability) {
          totalLiabilities += account.amount;
        } else {
          totalAssets += account.amount;
        }
      }

      await DatabaseHelper.instance.saveNetWorthHistory(
        date: DateTime.now(),
        totalAssets: totalAssets,
        totalLiabilities: totalLiabilities,
        netWorth: netWorth,
      );
    } catch (e) {
      print('❌ 保存净资产快照失败: $e');
    }
  }

  /// 获取指定日期的净资产（如果没有则返回最近的一个）
  Future<double?> getNetWorthAtDate(DateTime targetDate) async {
    try {
      // 获取所有历史记录
      final history = await DatabaseHelper.instance.getNetWorthHistory(limit: 365); // 最近一年
      
      if (history.isEmpty) return null;

      DateTime? closestDate;
      double? closestNetWorth;

      for (var record in history) {
        final dateStr = record['date'] as String;
        final date = DateTime.parse(dateStr);
        final netWorth = record['net_worth'] as double;

        // 找到目标日期或之前最近的日期
        if (!date.isAfter(targetDate)) {
          if (closestDate == null || date.isAfter(closestDate!)) {
            closestDate = date;
            closestNetWorth = netWorth;
          }
        }
      }

      return closestNetWorth;
    } catch (e) {
      print('❌ 查询历史净资产失败: $e');
      return null;
    }
  }

  /// 根据时间段获取收益变化
  Future<Map<String, dynamic>?> getChangeByPeriod(String period) async {
    try {
      final now = DateTime.now();
      DateTime compareDate;
      String periodLabel;

      switch (period) {
        case 'today':
          compareDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
          periodLabel = '昨日';
          break;
        case 'lastMonth':
          compareDate = DateTime(now.year, now.month - 1, now.day);
          periodLabel = '上月同期';
          break;
        case 'lastQuarter':
          compareDate = now.subtract(const Duration(days: 90));
          periodLabel = '上季度';
          break;
        case 'lastYear':
          compareDate = DateTime(now.year - 1, now.month, now.day);
          periodLabel = '去年同期';
          break;
        default:
          return null;
      }

      final thenNetWorth = await getNetWorthAtDate(compareDate);
      final nowNetWorth = getNetWorth();

      if (thenNetWorth == null || thenNetWorth == 0) {
        return {
          'change': 0.0,
          'changePercent': 0.0,
          'periodLabel': periodLabel,
          'hasData': false,
        };
      }

      final change = nowNetWorth - thenNetWorth;
      final changePercent = (change / thenNetWorth) * 100;

      return {
        'change': change,
        'changePercent': changePercent,
        'periodLabel': periodLabel,
        'hasData': true,
        'thenNetWorth': thenNetWorth,
        'nowNetWorth': nowNetWorth,
      };
    } catch (e) {
      print('❌ 计算收益变化失败: $e');
      return null;
    }
  }
}
