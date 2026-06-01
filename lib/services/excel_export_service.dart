import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/account.dart';
import '../models/fund_account.dart';
import '../services/fund_api_service.dart';
import '../database/database_helper.dart';

class ExcelExportService {
  static Future<String> exportToExcel(List<Account> allAccounts, {List<Map<String, dynamic>>? netWorthHistory}) async {
    final excel = Excel.createExcel();
    excel.rename(excel.getDefaultSheet()!, '净资产历史');

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    final now = DateTime.now();

    final activeAccounts = allAccounts.where((a) => a.isActive).toList();
    final fundAccounts = activeAccounts
        .where((a) => a is FundAccount)
        .map((a) => a as FundAccount)
        .toList();
    final otherAccounts = activeAccounts
        .where((a) => a is! FundAccount)
        .toList();

    _createNetWorthHistorySheet(excel['净资产历史'], netWorthHistory ?? [], dateFormat);
    _createFundDataSheet(excel, fundAccounts, dateFormat);
    _createOtherAssetsSheet(excel, otherAccounts, dateFormat);

    final downloadDir = Directory('/storage/emulated/0/Download/monio');
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }

    final fileName = '资产数据_${DateFormat('yyyyMMdd_HHmmss').format(now)}.xlsx';
    final file = File('${downloadDir.path}/$fileName');

    await file.writeAsBytes(excel.save()!);

    return file.path;
  }

  static List<CellValue> _row(List<dynamic> values) {
    return values.map((e) {
      if (e is String) return TextCellValue(e);
      if (e is int) return IntCellValue(e);
      if (e is double) return DoubleCellValue(e);
      return TextCellValue(e.toString());
    }).toList();
  }

  static void _createNetWorthHistorySheet(
    Sheet sheet,
    List<Map<String, dynamic>> history,
    DateFormat dateFormat,
  ) {
    sheet.appendRow(_row(['日期', '净资产（元）']));

    for (var record in history) {
      sheet.appendRow(_row([
        record['date'],
        (record['net_worth'] as double).toStringAsFixed(2),
      ]));
    }
  }

  static void _createFundDataSheet(
    Excel excel,
    List<FundAccount> fundAccounts,
    DateFormat dateFormat,
  ) {
    final sheet = excel['基金数据'];

    sheet.appendRow(_row([
      '基金名称',
      '基金代码',
      '持有份额',
      '持有单价',
      '成本价',
      '添加日期',
      '备注',
    ]));

    for (var fund in fundAccounts) {
      final fundInfo = fund.fundInfo;

      sheet.appendRow(_row([
        fundInfo?.fundName ?? fund.name,
        fundInfo?.fundCode ?? '',
        fund.shares.toStringAsFixed(2),
        fund.unitPrice?.toStringAsFixed(4) ?? '',
        fund.totalCost.toStringAsFixed(2),
        dateFormat.format(fund.addDate),
        fund.remark ?? '',
      ]));
    }
  }

  static void _createOtherAssetsSheet(
    Excel excel,
    List<Account> otherAccounts,
    DateFormat dateFormat,
  ) {
    final sheet = excel['其他资产账户'];

    sheet.appendRow(_row([
      '账户名称',
      '资产类型',
      '子类型',
      '金额（元）',
      '币种',
      '添加日期',
      '备注',
    ]));

    for (var account in otherAccounts) {
      sheet.appendRow(_row([
        account.name,
        account.type.displayName,
        account.subType.displayName,
        account.amount.toStringAsFixed(2),
        account.currency,
        dateFormat.format(account.addDate),
        account.remark ?? '',
      ]));
    }
  }

  static Future<ImportResult> importFromExcel(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('文件不存在：$filePath');
    }

    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);

    final result = ImportResult();

    final netWorthSheet = excel.tables.keys.firstWhere(
      (k) => k.contains('净资产'),
      orElse: () => '',
    );

    final fundSheet = excel.tables.keys.firstWhere(
      (k) => k.contains('基金'),
      orElse: () => '',
    );

    final otherAssetSheet = excel.tables.keys.firstWhere(
      (k) => k.contains('其他资产'),
      orElse: () => '',
    );

    if (netWorthSheet.isNotEmpty && excel.tables[netWorthSheet] != null) {
      await _importNetWorthHistory(excel.tables[netWorthSheet]!, result);
    }

    if (fundSheet.isNotEmpty && excel.tables[fundSheet] != null) {
      await _importFundData(excel.tables[fundSheet]!, result);
    }

    if (otherAssetSheet.isNotEmpty && excel.tables[otherAssetSheet] != null) {
      await _importOtherAssets(excel.tables[otherAssetSheet]!, result);
    }

    return result;
  }

  static Future<void> _importNetWorthHistory(Sheet sheet, ImportResult result) async {
    final db = DatabaseHelper.instance;

    // 使用批量保存，避免每次插入都触发清理
    final records = <Map<String, dynamic>>[];

    for (var i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      try {
        final dateStr = row[0]?.value?.toString() ?? '';
        if (dateStr.isEmpty) continue;

        final date = DateTime.parse(dateStr);
        final netWorth = double.tryParse(row[1]?.value?.toString() ?? '0') ?? 0.0;

        records.add({
          'date': DateFormat('yyyy-MM-dd').format(date),
          'totalAssets': 0.0,
          'totalLiabilities': 0.0,
          'netWorth': netWorth,
        });

        result.netWorthCount++;
      } catch (e) {
        print('导入净资产历史记录失败（第${i + 1}行）：$e');
        result.errors.add('净资产历史第${i + 1}行：$e');
      }
    }

    // 一次性批量保存（只在最后执行一次清理）
    if (records.isNotEmpty) {
      await db.batchSaveNetWorthHistory(records);
    }
  }

  static Future<void> _importFundData(Sheet sheet, ImportResult result) async {
    final db = DatabaseHelper.instance;

    for (var i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      try {
        // 必填项：基金代码
        final fundCode = row[1]?.value?.toString().trim() ?? '';
        if (fundCode.isEmpty) {
          print('⚠️ 第${i + 1}行：基金代码为空，跳过');
          continue;
        }

        // 可选项：从Excel读取的数据（作为备用）
        final excelFundName = row[0]?.value?.toString().trim() ?? '';
        final shares = double.tryParse(row[2]?.value?.toString() ?? '0') ?? 0.0;
        final unitPrice = double.tryParse(row[3]?.value?.toString() ?? '');  // 可选：持有单价
        final costPrice = double.tryParse(row[4]?.value?.toString() ?? '0') ?? 0.0;  // 可选：成本价
        final addDateStr = row[5]?.value?.toString() ?? DateTime.now().toIso8601String();
        final remark = row[6]?.value?.toString();

        DateTime addDate;
        try {
          addDate = DateTime.parse(addDateStr);
        } catch (e) {
          addDate = DateTime.now();
        }

        // 🎯 核心：根据基金代码自动获取基金信息（名称、净值等）
        // ⚠️ 必须调用API获取：基金名称、当前净值（用于计算收益率和当前金额）
        FundInfo? fundInfo;

        // 🔧 规范化基金代码：补全为6位（如 10012 → 001012）
        String normalizedFundCode = _normalizeFundCode(fundCode);

        print('📡 正在获取基金信息: $fundCode (规范化: $normalizedFundCode)');

        // 🔄 多次尝试：先尝试原始代码，再尝试规范化后的代码
        List<String> codesToTry = [];
        if (fundCode != normalizedFundCode) {
          codesToTry = [fundCode, normalizedFundCode]; // 先试原始，再试规范化的
        } else {
          codesToTry = [fundCode];
        }

        for (String codeToTry in codesToTry) {
          if (fundInfo != null) break; // 已成功，不再尝试

          try {
            print('   尝试代码: $codeToTry');
            fundInfo = await FundApiService.getFundDetail(codeToTry);

            if (fundInfo != null) {
              print('✅ 成功获取基金信息: ${fundInfo.fundName} - 净值: ${fundInfo.nav}');
            } else {
              print('⚠️ 未找到基金: $codeToTry');
            }
          } catch (e, stackTrace) {
            print('❌ 获取基金API失败($codeToTry): $e');
          }

          // 如果还有下一个代码要尝试，等待一小段时间避免请求过快
          if (fundInfo == null && codeToTry != codesToTry.last) {
            await Future.delayed(const Duration(milliseconds: 100)); // 减少延迟从200ms到100ms
          }
        }

        // 如果所有尝试都失败，使用备用数据
        if (fundInfo == null) {
          print('⚠️ 所有API调用均失败');
          print('   使用备用数据: Excel名称=$excelFundName, 基金代码=$fundCode');

          fundInfo = FundInfo(
            fundCode: fundCode,
            fundName: excelFundName.isNotEmpty ? excelFundName : '未知基金',
            nav: 0,
          );
        }

        // 🎯 自动计算金额
        double calculatedAmount;
        
        if (fundInfo != null && fundInfo!.nav > 0 && shares > 0) {
          // 方式1：份额 × 单位净值（最准确）✨
          calculatedAmount = shares * fundInfo.nav;
          print('💰 计算金额: $shares × ${fundInfo.nav} = $calculatedAmount');
        } else if (unitPrice != null && unitPrice! > 0 && shares > 0) {
          // 方式2：使用Excel中的持有单价（备选）
          calculatedAmount = shares * unitPrice!;
          print('💰 使用持有单价计算: $shares × $unitPrice = $calculatedAmount');
        } else if (costPrice > 0) {
          // 方式3：使用成本价（最后备选）
          calculatedAmount = costPrice;
          print('💰 使用成本价: $calculatedAmount');
        } else {
          // 无法计算，设为0
          calculatedAmount = 0;
          print('⚠️ 无法计算金额，设为0');
        }

        // 创建基金账户对象
        final account = FundAccount(
          id: const Uuid().v4(),
          name: fundInfo?.fundName ?? (excelFundName.isNotEmpty ? excelFundName : fundCode),
          type: AssetType.investment,
          subType: AssetSubType.fund,
          amount: calculatedAmount,
          currency: 'CNY',
          addDate: addDate,
          updateDate: DateTime.now(),
          remark: remark?.isNotEmpty == true ? remark : null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          fundInfo: fundInfo,
          shares: shares,
          costPrice: costPrice,
          unitPrice: unitPrice,
        );

        await db.create(account);
        
        // 记录新增资产变动历史
        print('💾 [导入] 保存新增基金变动历史: $fundCode');
        
        try {
          await DatabaseHelper.instance.saveFundNavHistory(
            fundCode: fundCode,
            fundName: account.name,
            type: 'add',
            newNav: fundInfo?.nav ?? 0,
            changeAmount: calculatedAmount,
          );
          print('✅ [导入] 新增基金变动历史保存成功');
        } catch (e) {
          print('❌ [导入] 保存新增基金变动历史失败（非致命）: $e');
        }
        
        result.fundCount++;
        print('✅ 成功导入基金: ${account.name} (${fundCode}) - 金额: ${account.amount}');
      } catch (e) {
        print('❌ 导入基金数据失败（第${i + 1}行）：$e');
        result.errors.add('基金数据第${i + 1}行：$e');
      }
    }
  }

  static Future<void> _importOtherAssets(Sheet sheet, ImportResult result) async {
    final db = DatabaseHelper.instance;

    for (var i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      try {
        final name = row[0]?.value?.toString().trim() ?? '';
        if (name.isEmpty) continue;

        final typeStr = row[1]?.value?.toString() ?? 'liquid';
        final subTypeStr = row[2]?.value?.toString() ?? 'cash';
        final amount = double.tryParse(row[3]?.value?.toString() ?? '0') ?? 0.0;
        final currency = row[4]?.value?.toString() ?? 'CNY';
        final addDateStr = row[5]?.value?.toString() ?? DateTime.now().toIso8601String();
        final remark = row[6]?.value?.toString();

        AssetType type;
        try {
          type = AssetType.values.firstWhere((e) => e.displayName == typeStr || e.name == typeStr);
        } catch (e) {
          type = AssetType.liquid;
        }

        AssetSubType subType;
        try {
          subType = AssetSubType.values.firstWhere((e) => e.displayName == subTypeStr || e.name == subTypeStr);
        } catch (e) {
          subType = AssetSubType.cash;
        }

        DateTime addDate;
        try {
          addDate = DateTime.parse(addDateStr);
        } catch (e) {
          addDate = DateTime.now();
        }

        final account = Account(
          id: const Uuid().v4(),
          name: name,
          type: type,
          subType: subType,
          amount: amount,
          currency: currency,
          addDate: addDate,
          updateDate: null,
          remark: remark?.isNotEmpty == true ? remark : null,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await db.create(account);
        result.otherAssetCount++;
      } catch (e) {
        print('导入其他资产失败（第${i + 1}行）：$e');
        result.errors.add('其他资产第${i + 1}行：$e');
      }
    }
  }
}

/// 🔧 规范化基金代码：补全为6位（如 10012 → 001012）
String _normalizeFundCode(String code) {
  if (code.isEmpty) return code;
  
  // 移除可能的前缀（如 "F" 或 "f"）
  String cleanCode = code.replaceAll(RegExp(r'^[Ff]'), '').trim();
  
  // 如果是纯数字，补全为6位
  if (RegExp(r'^[0-9]+$').hasMatch(cleanCode)) {
    return cleanCode.padLeft(6, '0');
  }
  
  // 如果不是纯数字，直接返回
  return cleanCode;
}

class ImportResult {
  int netWorthCount = 0;
  int fundCount = 0;
  int otherAssetCount = 0;
  List<String> errors = [];

  int get totalCount => netWorthCount + fundCount + otherAssetCount;

  String get summary {
    final buffer = StringBuffer();
    if (netWorthCount > 0) buffer.writeln('• 净资产历史记录：$netWorthCount 条');
    if (fundCount > 0) buffer.writeln('• 基金账户：$fundCount 个');
    if (otherAssetCount > 0) buffer.writeln('• 其他资产账户：$otherAssetCount 个');
    if (errors.isNotEmpty) {
      buffer.writeln('\n遇到 ${errors.length} 个错误：');
      for (var error in errors.take(5)) {
        buffer.writeln('  • $error');
      }
      if (errors.length > 5) {
        buffer.writeln('  • ... 还有 ${errors.length - 5} 个错误');
      }
    }
    return buffer.toString().trim();
  }
}

