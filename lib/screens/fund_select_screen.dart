import 'package:flutter/material.dart';
import '../models/fund_account.dart';
import '../services/fund_api_service.dart';

class FundSelectScreen extends StatefulWidget {
  final Function(FundInfo) onFundSelected;

  const FundSelectScreen({super.key, required this.onFundSelected});

  @override
  State<FundSelectScreen> createState() => _FundSelectScreenState();
}

class _FundSelectScreenState extends State<FundSelectScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<FundInfo> _filteredFunds = [];
  bool _hasSearched = false;
  bool _isSearching = false;

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    setState(() {
      if (query.isEmpty) {
        _filteredFunds = [];
        _hasSearched = false;
        _isSearching = false;
      } else {
        // 输入1个字符就立即开始搜索（实时搜索）
        _hasSearched = true;
        _performApiSearch(query);
      }
    });
  }

  Future<void> _performApiSearch(String query) async {
    setState(() => _isSearching = true);

    try {
      // 调用API搜索基金（带防抖延迟）
      await Future.delayed(const Duration(milliseconds: 300));

      // 检查是否还在搜索同一个查询（防止快速输入导致的结果混乱）
      if (_searchController.text.trim() != query) return;

      final results = await FundApiService.searchFunds(query);

      if (mounted) {
        setState(() {
          _filteredFunds = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      print('搜索错误: $e');
      if (mounted) {
        setState(() {
          _filteredFunds = [];
          _isSearching = false;
        });
      }
    }
  }

  void _performSearch() {
    FocusScope.of(context).unfocus();
    _onSearchChanged();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
          '选择基金',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: '',
          hintStyle: TextStyle(color: isDark ? const Color(0xFF6B7280) : Colors.grey[400]),
          prefixIcon: Icon(Icons.search, color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF)),
          suffixIcon: _isSearching && _searchController.text.isNotEmpty
              ? TextButton(
                  onPressed: () {
                    _searchController.clear();
                    FocusScope.of(context).unfocus();
                    _onSearchChanged();
                  },
                  child: Text('搜索', style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 16)),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _performSearch(),
      ),
    );
  }

  Widget _buildContent() {
    // 初始状态（未搜索）
    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_outlined, size: 80, color: isDark ? const Color(0xFF4B5563) : Colors.grey[200]),
            const SizedBox(height: 16),
            Text(
              '输入基金代码实时搜索',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? const Color(0xFF6B7280) : Colors.grey[400],
              ),
            ),
          ],
        ),
      );
    }

    // 搜索中状态
    if (_isSearching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Theme.of(context).primaryColor),
            const SizedBox(height: 16),
            Text(
              '正在搜索...',
              style: TextStyle(fontSize: 14, color: isDark ? const Color(0xFF9CA3AF) : Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    // 搜索后无结果
    if (_filteredFunds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.find_in_page_outlined, size: 80, color: isDark ? const Color(0xFF4B5563) : Colors.grey[200]),
            const SizedBox(height: 16),
            Text(
              '未找到匹配的基金',
              style: TextStyle(fontSize: 16, color: isDark ? const Color(0xFF9CA3AF) : Colors.grey[500]),
            ),
            const SizedBox(height: 8),
            Text(
              '请检查代码或名称是否正确',
              style: TextStyle(fontSize: 14, color: isDark ? const Color(0xFF6B7280) : Colors.grey[400]),
            ),
          ],
        ),
      );
    }

    // 有搜索结果
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredFunds.length,
      itemBuilder: (context, index) {
        final fund = _filteredFunds[index];
        return _buildFundItem(fund);
      },
    );
  }

  Widget _buildFundItem(FundInfo fund) {
    return GestureDetector(
      onTap: () => widget.onFundSelected(fund),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fund.fundName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fund.fundCode,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 只在有净值数据时显示（输入>=4位且API成功返回）
                if (fund.nav > 0)
                  Text(
                    fund.nav.toStringAsFixed(4),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                // 输入<=4位或无净值时：不显示任何内容，保持右侧整洁
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
