import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/account_provider.dart';
import '../models/account.dart';
import '../database/database_helper.dart';
import '../services/excel_export_service.dart';
import '../widgets/app_dialogs.dart';
import 'package:file_picker/file_picker.dart';

class DataManagementScreen extends StatefulWidget {
  const DataManagementScreen({super.key});

  @override
  State<DataManagementScreen> createState() => _DataManagementScreenState();
}

class _DataManagementScreenState extends State<DataManagementScreen> {
  bool _isExporting = false;
  bool _isImporting = false;
  bool _isClearing = false;

  /// 显示确认对话框并清除所有数据
  Future<void> _showClearAllDataConfirmation() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 28),
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red[700],
                  size: 32,
                ),
                const SizedBox(height: 12),
                Text(
                  '确认清除所有数据？',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    '此操作将永久删除以下所有数据：',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF3B1C1C) : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Column(
                    children: [
                      _buildWarningItem('所有资产账户'),
                      _buildWarningItem('净资产历史记录'),
                      _buildWarningItem('基金净值变化历史'),
                      _buildWarningItem('账户金额和配置信息'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E3A5F) : const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700], size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '建议：清除前请先导出备份！',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Divider(height: 1, color: isDark ? const Color(0xFF38383A) : const Color(0xFFE5E7EB)),
                IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.of(dialogContext).pop(false),
                          behavior: HitTestBehavior.translucent,
                          child: SizedBox(
                            height: 48,
                            child: Center(
                              child: Text(
                                '取消',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF3B82F6),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(width: 1, color: isDark ? const Color(0xFF38383A) : const Color(0xFFE5E7EB)),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.of(dialogContext).pop(true),
                          behavior: HitTestBehavior.translucent,
                          child: SizedBox(
                            height: 48,
                            child: Center(
                              child: const Text(
                                '确认清除',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFFEF4444),
                              ),
                            ),
                          ),
                        ),
                      ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirm == true) {
      await _clearAllData();
    }
  }

  Widget _buildWarningItem(String title, [String? subtitle]) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 执行清除所有数据操作
  Future<void> _clearAllData() async {
    setState(() => _isClearing = true);

    try {
      // 1. 清除净资产历史记录
      await DatabaseHelper.instance.clearNetWorthHistory();
      
      // 2. 清除基金净值变化历史
      await DatabaseHelper.instance.clearFundNavHistory();
      
      // 3. 清除所有资产账户
      await DatabaseHelper.instance.clearAllAccounts();
      
      // 4. 重新加载空数据到 Provider
      if (mounted) {
        await context.read<AccountProvider>().loadAccounts();
        
        AppDialogs.showSuccessToast(
          context: context,
          message: '所有数据已成功清除',
        );
      }
    } catch (e) {
      if (mounted) {
        AppDialogs.showErrorToast(
          context: context,
          message: '❌ 清除失败：$e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isClearing = false);
      }
    }
  }

  Future<void> _exportToExcel() async {
    setState(() => _isExporting = true);

    try {
      final provider = context.read<AccountProvider>();
      
      double totalAssets = 0.0;
      double totalLiabilities = 0.0;

      for (var account in provider.accounts.where((a) => a.isActive)) {
        if (account.type == AssetType.liability) {
          totalLiabilities += account.amount;
        } else {
          totalAssets += account.amount;
        }
      }

      final netWorth = totalAssets - totalLiabilities;

      await DatabaseHelper.instance.saveNetWorthHistory(
        date: DateTime.now(),
        totalAssets: totalAssets,
        totalLiabilities: totalLiabilities,
        netWorth: netWorth,
      );

      final history = await DatabaseHelper.instance.getNetWorthHistory(limit: 365);

      await ExcelExportService.exportToExcel(
        provider.accounts,
        netWorthHistory: history,
      );

      if (mounted) {
        AppDialogs.showSuccessToast(
          context: context,
          message: '导出成功\n文件已保存至：Download/monio/\n共 ${history.length} 天净资产历史',
        );
      }
    } catch (e) {
      if (mounted) {
        AppDialogs.showErrorToast(context: context, message: '导出失败：$e');
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _importFromExcel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result == null || result.files.isEmpty) return;

      final filePath = result.files.single.path;
      if (filePath == null) return;

      setState(() => _isImporting = true);

      final importResult = await ExcelExportService.importFromExcel(filePath);

      await context.read<AccountProvider>().loadAccounts();

      if (mounted) {
        _showImportResultDialog(importResult);
      }
    } catch (e) {
      if (mounted) {
        AppDialogs.showErrorToast(context: context, message: '导入失败：$e');
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  void _showImportResultDialog(ImportResult result) {
    AppDialogs.showImportResult(
      context: context,
      isSuccess: result.errors.isEmpty,
      summary: result.summary,
      errors: result.errors,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
        title: const Text(
          '数据管理',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle('导入数据'),
          const SizedBox(height: 12),
          _buildImportCard(isDark),
          const SizedBox(height: 32),
          _buildSectionTitle('导出数据'),
          const SizedBox(height: 12),
          _buildExportCard(isDark),
          const SizedBox(height: 32),
          _buildSectionTitle('数据清除'),
          const SizedBox(height: 12),
          _buildClearAllDataCard(isDark),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  Widget _buildImportCard(bool isDark) {
    return GestureDetector(
      onTap: _isImporting ? null : _importFromExcel,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(20),
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
              child: _isImporting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isDark
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFF6B7280),
                      ),
                    )
                  : Icon(
                      Icons.file_upload_outlined,
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
                    '资产数据导入',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '从Excel文件导入资产数据',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark
                  ? const Color(0xFF6B7280)
                  : const Color(0xFF9CA3AF),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportCard(bool isDark) {
    return GestureDetector(
      onTap: _isExporting ? null : _exportToExcel,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(20),
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
              child: _isExporting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isDark
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFF6B7280),
                      ),
                    )
                  : Icon(
                      Icons.file_download_outlined,
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
                    '资产数据导出',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isExporting ? '正在导出...' : '导出所有资产账户信息为Excel表格',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark
                  ? const Color(0xFF6B7280)
                  : const Color(0xFF9CA3AF),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClearAllDataCard(bool isDark) {
    return GestureDetector(
      onTap: _isClearing ? null : _showClearAllDataConfirmation,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1F2937).withOpacity(0.5)
              : const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isClearing 
                ? Colors.red[300]!.withOpacity(0.5)
                : Colors.red[200]!,
            width: _isClearing ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF7F1D1D)
                    : const Color(0xFFFECACA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _isClearing
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDark ? const Color(0xFFF87171) : Colors.red[700]!,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.delete_forever_outlined,
                      color: isDark
                          ? const Color(0xFFF87171)
                          : const Color(0xFFDC2626),
                      size: 24,
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '清除所有数据',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? const Color(0xFFFCA5A5)
                          : const Color(0xFF991B1B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isClearing ? '正在清除...' : '永久删除所有资产和历史记录',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? const Color(0xFFF87171)
                          : const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
            ),
            if (!_isClearing)
              Icon(
                Icons.chevron_right,
                color: isDark
                    ? const Color(0xFFF87171)
                    : const Color(0xFFDC2626),
              )
            else
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDark ? const Color(0xFFF87171) : Colors.red[700]!,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
