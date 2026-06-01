import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/account.dart';
import '../models/fund_account.dart';
import '../providers/account_provider.dart';
import '../utils/constants.dart';
import '../utils/currency_formatter.dart';
import '../widgets/app_dialogs.dart';

class EditAccountScreen extends StatefulWidget {
  final Account account;

  const EditAccountScreen({super.key, required this.account});

  @override
  State<EditAccountScreen> createState() => _EditAccountScreenState();
}

class _EditAccountScreenState extends State<EditAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  late TextEditingController _remarkController;
  late TextEditingController _sharesController;
  late TextEditingController _unitPriceController; // 持有单价
  late TextEditingController _costPriceController;

  String _selectedCurrency = 'CNY';
  bool _isSubmitting = false;

  bool get isFundAccount => widget.account is FundAccount;
  FundAccount? get fundAccount => isFundAccount ? widget.account as FundAccount : null;
  
  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.account.name);
    _sharesController = TextEditingController();
    _unitPriceController = TextEditingController(); // 持有单价
    _costPriceController = TextEditingController();
    _remarkController =
        TextEditingController(text: widget.account.remark ?? '');
    _selectedCurrency = widget.account.currency;

    if (isFundAccount && fundAccount != null) {
      _amountController = TextEditingController(
          text: fundAccount!.calculatedAmount.toString());
      _sharesController =
          TextEditingController(text: fundAccount!.shares.toString());
      // 初始化持有单价
      if (fundAccount!.unitPrice != null) {
        _unitPriceController =
            TextEditingController(text: fundAccount!.unitPrice.toString());
      }
      _costPriceController =
          TextEditingController(text: fundAccount!.costPrice.toString());
      
      // 添加监听器：当持有单价或份额变化时，自动计算成本价
      _unitPriceController.addListener(_autoCalculateCost);
      _sharesController.addListener(_autoCalculateCost);
    } else {
      _amountController =
          TextEditingController(text: widget.account.amount.toString());
    }
  }

  /// 自动计算成本价（持有单价 × 持有份额）
  void _autoCalculateCost() {
    final unitPriceText = _unitPriceController.text.trim();
    final sharesText = _sharesController.text.trim();
    
    // 只有在两个值都有效时才自动计算
    if (unitPriceText.isNotEmpty && sharesText.isNotEmpty) {
      final unitPrice = double.tryParse(unitPriceText);
      final shares = double.tryParse(sharesText);
      
      if (unitPrice != null && unitPrice > 0 && shares != null && shares > 0) {
        final calculatedCost = unitPrice * shares;
        final currentCostText = _costPriceController.text.trim();
        
        // 只有当成本价为空、0 或与当前计算值不同时才更新
        final currentCost = double.tryParse(currentCostText);
        if (currentCost == null || currentCost == 0 || 
            (currentCost - calculatedCost).abs() < 0.01) {  // 允许微小误差
          _costPriceController.text = calculatedCost.toStringAsFixed(2);
        }
      }
    }
  }

  @override
  void dispose() {
    // 移除监听器
    _unitPriceController.removeListener(_autoCalculateCost);
    _sharesController.removeListener(_autoCalculateCost);
    
    _nameController.dispose();
    _amountController.dispose();
    _remarkController.dispose();
    _sharesController.dispose();
    _unitPriceController.dispose(); // 释放持有单价控制器
    _costPriceController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      bool success;

      if (isFundAccount && fundAccount != null) {
        final shares = double.parse(_sharesController.text);
        
        // 解析持有单价（可选）
        double? unitPrice;
        if (_unitPriceController.text.isNotEmpty) {
          unitPrice = double.tryParse(_unitPriceController.text);
        }
        
        // 计算成本价：优先使用自动计算的值（持有单价 × 持有份额）
        double costPrice;
        
        if (_costPriceController.text.isNotEmpty) {
          costPrice = double.parse(_costPriceController.text);
        } else if (unitPrice != null && unitPrice > 0) {
          costPrice = unitPrice * shares; // 自动计算：持有单价 × 份额
        } else {
          costPrice = fundAccount!.fundInfo?.nav ?? fundAccount!.costPrice;
        }

        final updatedFund = fundAccount!.copyWithFund(
          name: _nameController.text.trim(),
          shares: shares,
          costPrice: costPrice,
          unitPrice: unitPrice, // 保存持有单价
        );

        success =
            await context.read<AccountProvider>().updateAccount(updatedFund);
      } else {
        final updatedAccount = widget.account.copyWith(
          name: _nameController.text.trim(),
          amount: double.parse(_amountController.text),
          currency: _selectedCurrency,
          remark:
              _remarkController.text.isNotEmpty ? _remarkController.text : null,
        );

        success =
            await context.read<AccountProvider>().updateAccount(updatedAccount);
      }

      if (mounted && success) {
        Navigator.pop(context, true);
        AppDialogs.showSuccessToast(context: context, message: '保存成功');
      }
    } catch (e) {
      if (mounted) {
        AppDialogs.showErrorToast(context: context, message: '保存失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await AppDialogs.showDeleteConfirm(
      context: context,
      accountName: widget.account.name,
    );

    if (confirmed) {
      final success = await context
          .read<AccountProvider>()
          .deleteAccount(widget.account.id);

      if (mounted && success) {
        Navigator.pop(context, true);
        AppDialogs.showSuccessToast(context: context, message: '账户已成功删除');
      }
    }
  }

  void _selectCurrency() {
    if (isFundAccount) {
      return;
    }

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
          '编辑资产',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.red[400]),
            onPressed: _deleteAccount,
          ),
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
              if (isFundAccount && fundAccount != null)
                ..._buildFundEditForm()
              else
                ..._buildNormalEditForm(),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFundEditForm() {
    final fund = fundAccount!;
    
    return [
      // 第一个卡片：基金信息
      Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 第一行：基金代码（只读）
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '基金',
                    style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
                  ),
                  Text(
                    fund.fundInfo?.fundCode ?? '',
                    style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
                  ),
                ],
              ),
            ),

            Divider(color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB), height: 1),

            // 第三行：持有单价（用户输入）
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '持有单价',
                    style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _unitPriceController,
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        hintText: '请输入持有单价（可选）',
                        hintStyle: TextStyle(color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
            ),

            Divider(color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB), height: 1),

            // 第二行：持有份额
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '持有份额',
                    style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _sharesController,
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        hintText: '请输入持有份额',
                        hintStyle: TextStyle(color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) return '请输入持有份额';
                        if (double.tryParse(value) == null || double.parse(value) <= 0)
                          return '请输入有效份额';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ),

            Divider(color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB), height: 1),

            // 第三行：单位净值（自动填充，只读）
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '单位净值',
                    style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
                  ),
                  Text(
                    fund.fundInfo?.nav.toStringAsFixed(4) ?? '0.0000',
                    style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
                  ),
                ],
              ),
            ),

            Divider(color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB), height: 1),

            // 第四行：成本价
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '成本价',
                    style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _costPriceController,
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        hintText: '请输入成本价（可选）',
                        hintStyle: TextStyle(color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      const SizedBox(height: 16),

      // 第二个卡片：其他信息（基金名称、币种、金额）
      Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 基金名称
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                fund.fundInfo?.fundName ?? fund.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),

            const SizedBox(height: 16),

            Divider(color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB), height: 1),

            // 币种
            GestureDetector(
              onTap: _selectCurrency,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '币种',
                      style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AppConstants.currencies[_selectedCurrency] ?? '',
                          style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.lock,
                            size: 18,
                            color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF)),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right,
                            color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            Divider(color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB), height: 1),

            // 金额（自动计算，只读显示）
            Padding(
              padding: const EdgeInsets.only(top: 18, bottom: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '金额（自动计算）',
                  style: TextStyle(fontSize: 14, color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF)),
                ),
              ),
            ),

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                CurrencyFormatter.format(fund.calculatedAmount),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),

      const SizedBox(height: 16),

      // 备注
      Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '备注（可选）',
              style: TextStyle(fontSize: 14, color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF)),
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
      ),
    ];
  }

  List<Widget> _buildNormalEditForm() {
    return [
      // 第一个卡片：基本信息（资产类型、名称、币种、金额）
      Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 资产类型（只读显示）
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '资产类型',
                    style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
                  ),
                  Text(
                    widget.account.subType.displayName,
                    style: TextStyle(
                      fontSize: 16, 
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),

            Divider(color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB), height: 1),

            // 名称字段
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
                        if (value == null || value.isEmpty)
                          return '请输入名称';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ),

            Divider(color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB), height: 1),

            // 币种（锁定不可编辑）
            Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 18),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '币种',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppConstants.currencies[_selectedCurrency] ?? '',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.lock,
                          size: 18,
                          color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF)),
                    ],
                  ),
                ],
              ),
            ),

            Divider(color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB), height: 1),

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
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
                      validator: (value) {
                        if (value == null || value.isEmpty)
                          return '请输入金额';
                        if (double.tryParse(value) == null)
                          return '请输入有效金额';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      const SizedBox(height: 16),

      // 第二个卡片：备注
      Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '备注（可选）',
              style: TextStyle(
                fontSize: 14, 
                color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF)),
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
      ),
    ];
  }
}
