import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/account.dart';
import '../models/fund_account.dart';
import '../providers/account_provider.dart';
import '../database/database_helper.dart';
import '../utils/constants.dart';
import '../utils/currency_formatter.dart';
import '../widgets/app_dialogs.dart';
import 'fund_select_screen.dart';

class AddFundScreen extends StatefulWidget {
  final AssetType assetType;
  final AssetSubType subType;

  const AddFundScreen({
    super.key,
    required this.assetType,
    required this.subType,
  });

  @override
  State<AddFundScreen> createState() => _AddFundScreenState();
}

class _AddFundScreenState extends State<AddFundScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _sharesController = TextEditingController();
  final _unitPriceController = TextEditingController(); // 持有单价
  final _costPriceController = TextEditingController();
  final _remarkController = TextEditingController();

  FundInfo? _selectedFund;
  String _selectedCurrency = 'CNY';
  DateTime _selectedDate = DateTime.now();
  bool _isSubmitting = false;

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  /// 计算当前金额：优先使用净值，如果净值为0则使用持有单价
  double get calculatedAmount {
    final nav = _selectedFund?.nav ?? 0;
    final shares = double.tryParse(_sharesController.text) ?? 0;
    
    if (nav > 0) {
      return nav * shares; // 正常情况：净值 × 份额
    } else {
      // 净值为0时（特殊基金），尝试使用持有单价
      final unitPrice = double.tryParse(_unitPriceController.text);
      if (unitPrice != null && unitPrice > 0) {
        return unitPrice * shares;
      }
      return 0;
    }
  }

  /// 自动计算的成本价（持有单价 × 持有份额）
  double get autoCalculatedCost {
    final unitPrice = double.tryParse(_unitPriceController.text);
    final shares = double.tryParse(_sharesController.text);

    if (unitPrice != null && unitPrice > 0 && shares != null && shares > 0) {
      return unitPrice * shares;
    }
    return 0; // 无法计算
  }

  @override
  void initState() {
    super.initState();
    _sharesController.addListener(_onInputChanged);
    _unitPriceController.addListener(_onInputChanged);
    _costPriceController.addListener(_onCostPriceManualChanged);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _sharesController.dispose();
    _unitPriceController.dispose();
    _costPriceController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  /// 当持有单价或份额变化时，自动更新成本价
  void _onInputChanged() {
    setState(() {});
    
    // 如果填写了持有单价，自动填充成本价
    if (_unitPriceController.text.isNotEmpty && 
        _sharesController.text.isNotEmpty &&
        autoCalculatedCost > 0) {
      // 只在用户没有手动输入成本价时自动更新
      if (!_isUserEditingCostPrice) {
        _costPriceController.text = autoCalculatedCost.toStringAsFixed(2);
        _costPriceController.selection = TextSelection.fromPosition(
          TextPosition(offset: _costPriceController.text.length),
        );
      }
    }
  }

  bool _isUserEditingCostPrice = false;

  /// 用户手动编辑成本价时的处理
  void _onCostPriceManualChanged() {
    setState(() => _isUserEditingCostPrice = true);
    
    // 延迟重置标记（允许下一次自动计算）
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _isUserEditingCostPrice = false);
      }
    });
  }

  void _onFundSelected(FundInfo fund) {
    setState(() => _selectedFund = fund);
    Navigator.pop(context);
  }

  void _navigateToFundSelect() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FundSelectScreen(onFundSelected: _onFundSelected),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedFund == null) {
      if (_nameController.text.isEmpty || _amountController.text.isEmpty) {
        AppDialogs.showErrorToast(context: context, message: '请填写名称和金额');
        return;
      }
      _submitNormalAccount();
    } else {
      if (_sharesController.text.isEmpty) {
        AppDialogs.showErrorToast(context: context, message: '请输入持有份额');
        return;
      }
      _submitFundAccount();
    }
  }

  Future<void> _submitNormalAccount() async {
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
        remark: _remarkController.text.isNotEmpty ? _remarkController.text : null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final success =
          await context.read<AccountProvider>().addAccount(account);

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

  Future<void> _submitFundAccount() async {
    setState(() => _isSubmitting = true);

    try {
      final shares = double.parse(_sharesController.text);
      
      // 计算成本价：优先使用自动计算的值（持有单价 × 持有份额）
      double costPrice;
      
      if (_unitPriceController.text.isNotEmpty && autoCalculatedCost > 0) {
        costPrice = autoCalculatedCost;
      } else if (_costPriceController.text.isNotEmpty) {
        costPrice = double.parse(_costPriceController.text);
      } else {
        costPrice = _selectedFund!.nav;
      }

      final account = FundAccount(
        id: const Uuid().v4(),
        name: _selectedFund!.fundName,
        type: widget.assetType,
        subType: widget.subType,
        amount: calculatedAmount,
        currency: _selectedCurrency,
        addDate: _selectedDate,
        updateDate: DateTime.now(),
        remark: _remarkController.text.isNotEmpty ? _remarkController.text : null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        fundInfo: _selectedFund,
        shares: shares,
        costPrice: costPrice,
        unitPrice: _unitPriceController.text.isNotEmpty 
            ? double.tryParse(_unitPriceController.text) 
            : null,
      );

      final success =
          await context.read<AccountProvider>().addAccount(account);

      if (mounted && success) {
        // 记录新增资产变动历史
        print('💾 保存新增基金变动历史: ${_selectedFund!.fundCode}');
        
        try {
          await DatabaseHelper.instance.saveFundNavHistory(
            fundCode: _selectedFund!.fundCode,
            fundName: _selectedFund!.fundName,
            type: 'add',
            newNav: _selectedFund!.nav,
            changeAmount: calculatedAmount,
          );
          print('✅ 新增基金变动历史保存成功');
        } catch (e) {
          print('❌ 保存新增基金变动历史失败（非致命）: $e');
        }
        
        Navigator.popUntil(context, (route) => route.isFirst);
        AppDialogs.showSuccessToast(context: context, message: '基金添加成功');
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
              // 第一个卡片：基金信息（合并基金代码+详细信息）
              _buildFundCard(),
              const SizedBox(height: 16),

              // 根据是否选择基金显示不同的表单字段
              if (_selectedFund == null)
                ..._buildUnselectedForm()
              else
                ..._buildSelectedForm(),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFundCard() {
    if (_selectedFund == null) {
      // 未选择基金：只显示"请选择基金"
      return GestureDetector(
        onTap: _navigateToFundSelect,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '基金',
                style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '请选择基金',
                    style: TextStyle(fontSize: 16, color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF)),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF)),
                ],
              ),
            ],
          ),
        ),
      );
    } else {
      // 已选择基金：显示完整信息（基金代码 + 名称 + 净值 + 持有份额 + 成本价）
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 第一行：基金代码（可点击重新选择）
            GestureDetector(
              onTap: _navigateToFundSelect,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '基金',
                      style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _selectedFund!.fundCode,
                          style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right, color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            Divider(color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB), height: 1),

            // 第二行：持有份额（与单位净值样式一致）
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
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
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

            // 第三行：单位净值（自动填充）
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
                    _selectedFund!.nav.toStringAsFixed(4),
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

            // 第四行：成本价（自动计算或手动输入）
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '成本价',
                    style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
                  ),
                  const SizedBox(width: 4),
                  // 显示自动计算提示
                  if (_unitPriceController.text.isNotEmpty && 
                      _sharesController.text.isNotEmpty &&
                      autoCalculatedCost > 0)
                    Text(
                      '自动',
                      style: TextStyle(fontSize: 11, color: Colors.blue[400]),
                    )
                  else
                    const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _costPriceController,
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        hintText: _unitPriceController.text.isNotEmpty
                            ? '输入单价后自动计算'
                            : '请输入成本价（可选）',
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

            const SizedBox(height: 4),
          ],
        ),
      );
    }
  }

  // ========== 未选择基金的表单（参考6.jpg）==========
  List<Widget> _buildUnselectedForm() {
    return [
      // 第二个卡片：基本信息（名称、币种、金额）
      Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: '名称',
                labelStyle: TextStyle(color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF), fontSize: 14),
                border: InputBorder.none,
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              validator: (value) {
                if (value == null || value.isEmpty) return '请输入名称';
                return null;
              },
            ),

            Divider(color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB), height: 1),

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
                          '${AppConstants.currencies[_selectedCurrency]} ($_selectedCurrency)',
                          style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right, color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            Divider(color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB), height: 1),

            TextFormField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: '金额',
                labelStyle: TextStyle(color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF), fontSize: 14),
                border: InputBorder.none,
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              validator: (value) {
                if (value == null || value.isEmpty) return '请输入金额';
                if (double.tryParse(value) == null) return '请输入有效金额';
                return null;
              },
            ),
          ],
        ),
      ),

      const SizedBox(height: 16),

      // 添加日期
      GestureDetector(
        onTap: _selectDate,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_selectedDate.year}年${_selectedDate.month.toString().padLeft(2, '0')}月${_selectedDate.day.toString().padLeft(2, '0')}日',
                    style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF)),
                ],
              ),
            ],
          ),
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
              decoration: const InputDecoration(
                border: InputBorder.none,
                counterText: '',
              ),
            ),
          ],
        ),
      ),
    ];
  }

  // ========== 已选择基金的表单（参考8.jpg）==========
  List<Widget> _buildSelectedForm() {
    return [
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
                _selectedFund?.fundName ?? '',
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
                          '${AppConstants.currencies[_selectedCurrency]} ($_selectedCurrency)',
                          style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right, color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            Divider(color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB), height: 1),

            // 金额（自动计算）
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
                CurrencyFormatter.format(calculatedAmount),
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

      // 添加日期
      GestureDetector(
        onTap: _selectDate,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_selectedDate.year}年${_selectedDate.month.toString().padLeft(2, '0')}月${_selectedDate.day.toString().padLeft(2, '0')}日',
                    style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF)),
                ],
              ),
            ],
          ),
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
              decoration: const InputDecoration(
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
