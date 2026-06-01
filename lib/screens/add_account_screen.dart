import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/account.dart';
import '../providers/account_provider.dart';
import '../utils/constants.dart';
import '../widgets/app_dialogs.dart';

class AddAccountScreen extends StatefulWidget {
  final AssetType assetType;
  final AssetSubType subType;

  const AddAccountScreen({
    super.key,
    required this.assetType,
    required this.subType,
  });

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _remarkController = TextEditingController();

  String _selectedCurrency = 'CNY';
  DateTime _selectedDate = DateTime.now();
  bool _isSubmitting = false;
  
  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final account = Account(
        id: const Uuid().v4(),
        name: _nameController.text.trim(),
        type: widget.assetType,
        subType: widget.subType,
        amount: double.parse(_amountController.text),
        currency: _selectedCurrency,
        addDate: _selectedDate,
        updateDate: DateTime.now(),
        remark: _remarkController.text.isNotEmpty ? _remarkController.text : null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final success = await context.read<AccountProvider>().addAccount(account);

      if (mounted && success) {
        Navigator.popUntil(context, (route) => route.isFirst);
        AppDialogs.showSuccessToast(context: context, message: '账户添加成功');
      }
    } catch (e) {
      if (mounted) {
        AppDialogs.showErrorToast(context: context, message: '添加失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      locale: const Locale('zh', 'CN'),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  void _selectCurrency() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...AppConstants.currencies.entries.map((entry) {
                return ListTile(
                  title: Text('${entry.value} (${entry.key})',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                  trailing: _selectedCurrency == entry.key
                      ? Icon(Icons.check, color: Theme.of(context).primaryColor)
                      : null,
                  onTap: () {
                    setState(() => _selectedCurrency = entry.key);
                    Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
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
          '添加${widget.subType.displayName}',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.check, color: Theme.of(context).primaryColor, size: 28),
            onPressed: _isSubmitting ? null : _submitForm,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildBasicInfoCard(),
              const SizedBox(height: 16),
              _buildDateCard(),
              const SizedBox(height: 16),
              _buildRemarkCard(),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // 名称字段 - 使用币种样式
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '名称',
                  style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
                ),
                Expanded(
                  child: TextFormField(
                    controller: _nameController,
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '请输入名称';
                      }
                      if (value.trim().length > 50) {
                        return '名称不能超过50个字符';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ),
          Divider(color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB)),
          // 币种选择器
          GestureDetector(
            onTap: _selectCurrency,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '币种',
                    style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
                  ),
                  Row(
                    children: [
                      Text(
                        '${AppConstants.currencies[_selectedCurrency]} ($_selectedCurrency)',
                        style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
                      ),
                      Icon(Icons.chevron_right, color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Divider(color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB)),
          // 金额字段 - 使用币种样式
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '金额',
                  style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
                ),
                Expanded(
                  child: TextFormField(
                    controller: _amountController,
                    textAlign: TextAlign.right,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入金额';
                      }
                      final amount = double.tryParse(value);
                      if (amount == null || amount < 0) {
                        return '请输入有效金额';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateCard() {
    return GestureDetector(
      onTap: _selectDate,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '添加日期',
              style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
            ),
            Row(
              children: [
                Text(
                  '${_selectedDate.year}年${_selectedDate.month.toString().padLeft(2, '0')}月${_selectedDate.day.toString().padLeft(2, '0')}日',
                  style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
                ),
                Icon(Icons.chevron_right, color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemarkCard() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '备注（可选）',
            style: TextStyle(fontSize: 16, color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _remarkController,
            maxLines: 5,
            maxLength: 200,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              border: InputBorder.none,
              counterText: '',
            ),
          ),
        ],
      ),
    );
  }
}
