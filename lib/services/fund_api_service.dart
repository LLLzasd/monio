import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/fund_account.dart';
import 'fund_database_manager.dart';

class FundApiService {
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    validateStatus: (status) => status != null && status < 500,
    headers: {
      'Referer': 'https://fund.eastmoney.com/',
      'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15',
    },
  ));

  /// 搜索基金（本地模糊搜索 + API获取净值）
  static Future<List<FundInfo>> searchFunds(String query) async {
    if (query.isEmpty || query.length > 6 || query.length < 1) {
      return [];
    }

    print('🔍 开始搜索基金: "$query"');

    try {
      // 确保数据库可用
      await FundDatabaseManager.ensureDatabaseAvailable();

      // 从本地数据库进行模糊搜索（最多10个）
      List<FundCode> matchedFunds = await FundDatabaseManager.searchFundsLocally(
        query,
        limit: 10, // 只返回前10个
      );

      print('📋 本地匹配到 ${matchedFunds.length} 个基金');

      if (matchedFunds.isEmpty) {
        print('✗ 未找到匹配的基金');
        return [];
      }

      List<FundInfo> results = [];

      // 对每个匹配的基金处理
      for (var fundCode in matchedFunds) {
        FundInfo fundInfo;

        if (query.length >= 4 && _isNumeric(query)) {
          // 输入>=4位数字：调用API获取实时净值
          print('📡 调用API获取净值: ${fundCode.code}');
          final apiFund = await _fetchSingleFund(fundCode.code);

          if (apiFund != null) {
            fundInfo = apiFund;
            // 显示实时估值信息（如果有）
            if (fundInfo.hasRealTimeData) {
              print('✅ 获取到实时估值: ${fundCode.name} - 净值:${fundInfo.nav} 估值:${fundInfo.estimatedNav} 涨跌:${fundInfo.estimatedChangePercent}%');
            } else {
              print('✅ 获取到净值: ${fundCode.name} - ${fundInfo.nav}');
            }
          } else {
            // API失败，使用本地数据（净值为0）
            fundInfo = FundInfo(
              fundCode: fundCode.code,
              fundName: fundCode.name,
              nav: 0,
            );
            print('⚠️ API失败，使用本地数据: ${fundCode.name}');
          }
        } else {
          // 输入<=4位：只显示本地数据，净值设为空
          fundInfo = FundInfo(
            fundCode: fundCode.code,
            fundName: fundCode.name,
            nav: -1, // 特殊值表示不显示净值
          );
          print('📝 本地模式(无净值): ${fundCode.code} - ${fundCode.name}');
        }

        results.add(fundInfo);
      }

      print('🎯 搜索完成，共 ${results.length} 个结果');
      return results;

    } catch (e, stackTrace) {
      print('❌ 搜索错误: $e');
      print('堆栈: $stackTrace');
      return [];
    }
  }

  /// 判断字符串是否为纯数字
  static bool _isNumeric(String str) {
    return RegExp(r'^[0-9]+$').hasMatch(str);
  }

  /// 精确查询单个基金的净值（带 fallback 机制）
  /// 首先尝试 fundgz 接口（实时估值），失败时回退到 lsjz 接口（历史净值）
  static Future<FundInfo?> _fetchSingleFund(String fundCode) async {
    try {
      final url = 'https://fundgz.1234567.com.cn/js/$fundCode.js?rt=${DateTime.now().millisecondsSinceEpoch}';

      final response = await _dio.get(
        url,
        options: Options(
          responseType: ResponseType.plain,
        ),
      );

      // 404表示基金不存在
      if (response.statusCode == 404) {
        return null;
      }

      if (response.statusCode == 200) {
        String body = response.data.toString().trim();

        if (body.isEmpty || body.contains('暂无该基金')) {
          return null;
        }

        // 检查是否返回空数据（如 jsonpgz();）- 某些基金不提供实时估值
        if (body == 'jsonpgz();' || body == 'jsonpgz()' || body.length < 20) {
          print('⚠️ fundgz 接口返回空数据，尝试 fallback 到历史净值接口...');
          FundInfo? fallbackResult = await _fetchFundFromHistory(fundCode);
          if (fallbackResult != null) {
            return fallbackResult;
          }
          return null;
        }

        FundInfo? result = _parseSingleFund(body);

        // 如果解析成功但净值为0或null，也尝试fallback
        if (result != null && result.nav == 0) {
          print('⚠️ fundgz 返回净值为0，尝试 fallback...');
          FundInfo? fallbackResult = await _fetchFundFromHistory(fundCode);
          if (fallbackResult != null && fallbackResult.nav > 0) {
            return fallbackResult;
          }
        }

        return result;
      }

      return null;

    } on DioException catch (e) {
      if (e.response?.statusCode != 404) {
        print('❌ DIO异常(${e.type}): ${e.message}');
        // 网络错误时也尝试 fallback
        print('⚠️ 网络错误，尝试 fallback 到历史净值接口...');
        return await _fetchFundFromHistory(fundCode);
      }
      return null;
    } catch (e) {
      print('❌ 错误: $e');
      // 其他异常时也尝试 fallback
      return await _fetchFundFromHistory(fundCode);
    }
  }

  /// Fallback: 从历史净值接口获取基金数据（用于 fundgz 无数据的基金，如 QDII、FOF 等）
  static Future<FundInfo?> _fetchFundFromHistory(String fundCode) async {
    try {
      print('📡 调用历史净值接口(lsjz): $fundCode');

      // 使用东方财富历史净值API
      final url = 'https://fundf10.eastmoney.com/F10DataApi.aspx?type=lsjz&code=$fundCode&page=1&per=1&sdate=&edate=';

      final response = await _dio.get(
        url,
        options: Options(
          responseType: ResponseType.plain,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        String content = response.data.toString();

        if (content.isEmpty || content.contains('暂无数据')) {
          print('❌ 历史净值接口也无数据');
          return null;
        }

        // 解析HTML表格中的最新净值
        Map<String, dynamic>? latestData = _parseLatestNavFromHtml(content);

        if (latestData != null) {
          print('✅ 从历史净值接口获取到数据: ${latestData['name']} - 净值: ${latestData['nav']}');

          // 尝试从搜索接口获取基金名称（如果HTML中没有）
          if (latestData['name'] == null || latestData['name'].toString().isEmpty) {
            String? fundName = await _searchFundName(fundCode);
            if (fundName != null) {
              latestData['name'] = fundName;
            }
          }

          return FundInfo(
            fundCode: fundCode,
            fundName: latestData['name'] ?? '未知基金',
            nav: double.tryParse(latestData['nav'].toString()) ?? 0.0,
            navDate: latestData['date'] != null ? DateTime.parse(latestData['date'].toString()) : null,
            // 标记为无实时估值数据
            estimatedNav: null,
            estimatedChangePercent: latestData['growth'] != null ? double.tryParse(latestData['growth'].toString()) : null,
            yesterdayChangePercent: latestData['growth'] != null ? double.tryParse(latestData['growth'].toString()) : null,
          );
        }
      }

      return null;
    } catch (e) {
      print('❌ Fallback 获取历史净值错误: $e');
      return null;
    }
  }

  /// 解析HTML表格中的最新净值数据
  static Map<String, dynamic>? _parseLatestNavFromHtml(String htmlContent) {
    try {
      RegExp rowRegex = RegExp(r'<tr[^>]*>[\s\S]*?</tr>');
      Iterable<RegExpMatch> matches = rowRegex.allMatches(htmlContent);

      for (var match in matches) {
        String row = match.group(0) ?? '';
        
        // 跳过表头
        if (row.contains('<th>')) continue;

        RegExp cellRegex = RegExp(r'<td[^>]*>(.*?)</td>');
        Iterable<RegExpMatch> cells = cellRegex.allMatches(row);
        List<String> cellValues = cells.map((m) =>
          m.group(1)?.replaceAll(RegExp(r'<[^>]*>'), '').trim() ?? ''
        ).toList();

        if (cellValues.length >= 3) {
          String date = cellValues[0];
          String navStr = cellValues[1];

          double? nav = double.tryParse(navStr);
          
          // 查找涨跌幅（通常在第4列，格式为 x.xx% 或 +x.xx%）
          double? growth;
          for (int i = 2; i < cellValues.length; i++) {
            String val = cellValues[i];
            Match? growthMatch = RegExp(r'([-+]?\d+(?:\.\d+)?)\s*%').firstMatch(val);
            if (growthMatch != null) {
              growth = double.tryParse(growthMatch.group(1) ?? '');
              break;
            }
          }

          if (nav != null && nav > 0 && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
            return {
              'date': date,
              'nav': nav,
              'growth': growth,
            };
          }
        }
      }

      return null;
    } catch (e) {
      print('❌ 解析HTML净值错误: $e');
      return null;
    }
  }

  /// 从搜索接口查询基金名称
  static Future<String?> _searchFundName(String fundCode) async {
    try {
      List<FundCode> results = await FundDatabaseManager.searchFundsLocally(fundCode, limit: 1);
      if (results.isNotEmpty) {
        return results.first.name;
      }
    } catch (e) {
      // 忽略错误
    }
    return null;
  }

  /// 解析单个基金数据（完整版本 - 包含实时估值）
  static FundInfo? _parseSingleFund(String responseBody) {
    try {
      String jsonStr = responseBody.trim();

      // 移除JSONP包装
      if (jsonStr.startsWith('jsonpgz(')) {
        jsonStr = jsonStr.substring(8);
      }
      if (jsonStr.endsWith(');')) {
        jsonStr = jsonStr.substring(0, jsonStr.length - 2);
      } else if (jsonStr.endsWith(')')) {
        jsonStr = jsonStr.substring(0, jsonStr.length - 1);
      }

      Map<String, dynamic> data = json.decode(jsonStr);

      String code = data['fundcode']?.toString() ?? '';
      String name = data['name']?.toString() ?? '';
      double nav = double.tryParse(data['dwjz']?.toString() ?? '0') ?? 0.0;
      String? jzrq = data['jzrq']?.toString();

      // 解析实时估值数据（real-time-fund 项目核心数据）
      double? estimatedNav = data['gsz'] != null ? double.tryParse(data['gsz'].toString()) : null;
      double? estimatedChangePercent = data['gszzl'] != null ? double.tryParse(data['gszzl'].toString()) : null;
      String? estimatedTime = data['gztime']?.toString();

      if (code.isNotEmpty && name.isNotEmpty) {
        return FundInfo(
          fundCode: code,
          fundName: name,
          nav: nav,
          navDate: jzrq != null ? DateTime.parse(jzrq) : null,
          // 实时估值数据
          estimatedNav: estimatedNav,
          estimatedChangePercent: estimatedChangePercent,
          estimatedTime: estimatedTime,
        );
      }

      return null;
    } catch (e) {
      // JSON解析失败，尝试正则
      return _parseWithRegex(responseBody);
    }
  }

  /// 正则解析（回退方案）- 增强版支持估值数据
  static FundInfo? _parseWithRegex(String rawString) {
    try {
      String? code = RegExp(r'"fundcode"\s*:\s*"([^"]+)"').firstMatch(rawString)?.group(1);
      String? name = RegExp(r'"name"\s*:\s*"([^"]+)"').firstMatch(rawString)?.group(1);
      String? dwjz = RegExp(r'"dwjz"\s*:\s*"([^"]+)"').firstMatch(rawString)?.group(1);

      // 解析估算净值数据
      String? gsz = RegExp(r'"gsz"\s*:\s*"([^"]+)"').firstMatch(rawString)?.group(1);
      String? gszzl = RegExp(r'"gszzl"\s*:\s*"([^"]+)"').firstMatch(rawString)?.group(1);
      String? gztime = RegExp(r'"gztime"\s*:\s*"([^"]+)"').firstMatch(rawString)?.group(1);

      if (code != null && code.isNotEmpty && name != null && name.isNotEmpty) {
        return FundInfo(
          fundCode: code,
          fundName: name,
          nav: double.tryParse(dwjz ?? '0') ?? 0.0,
          // 实时估值数据
          estimatedNav: gsz != null ? double.tryParse(gsz) : null,
          estimatedChangePercent: gszzl != null ? double.tryParse(gszzl) : null,
          estimatedTime: gztime,
        );
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// 获取基金详情（完整信息 - 包含实时估值）
  static Future<FundInfo?> getFundDetail(String fundCode) async {
    return await _fetchSingleFund(fundCode);
  }

  /// 获取历史净值数据（参考 real-time-fund 的 lsjz 接口）
  /// 返回最近几天的净值数据，用于计算涨跌幅等
  static Future<Map<String, dynamic>?> getFundHistory(String fundCode, {int days = 3}) async {
    try {
      final url = 'https://fundf10.eastmoney.com/F10DataApi.aspx?type=lsjz&code=$fundCode&page=1&per=$days&sdate=&edate=';

      final response = await _dio.get(
        url,
        options: Options(
          responseType: ResponseType.plain,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        String content = response.data.toString();

        if (content.contains('暂无数据')) {
          return null;
        }

        // 解析HTML表格中的净值数据
        List<Map<String, dynamic>> navList = [];
        RegExp rowRegex = RegExp(r'<tr[^>]*>[\s\S]*?</tr>');
        Iterable<RegExpMatch> matches = rowRegex.allMatches(content);

        for (var match in matches) {
          String row = match.group(0) ?? '';
          RegExp cellRegex = RegExp(r'<td[^>]*>(.*?)</td>');
          Iterable<RegExpMatch> cells = cellRegex.allMatches(row);
          List<String> cellValues = cells.map((m) =>
            m.group(1)?.replaceAll(RegExp(r'<[^>]*>'), '').trim() ?? ''
          ).toList();

          if (cellValues.length >= 2) {
            String date = cellValues[0];
            double? nav = double.tryParse(cellValues[1]);

            // 查找涨跌幅（通常在后面几列，格式为 x.xx%）
            double? growth;
            for (var val in cellValues) {
              Match? growthMatch = RegExp(r'([-+]?\d+(?:\.\d+)?)\s*%').firstMatch(val);
              if (growthMatch != null) {
                growth = double.tryParse(growthMatch.group(1) ?? '');
                break;
              }
            }

            if (nav != null && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
              navList.add({
                'date': date,
                'nav': nav,
                'growth': growth,
              });
            }
          }
        }

        if (navList.isNotEmpty) {
          // 返回最新的净值数据
          var latest = navList.last;
          var previous = navList.length > 1 ? navList[navList.length - 2] : null;

          return {
            'latest': latest,
            'previous': previous,
            'all': navList,
          };
        }
      }

      return null;

    } catch (e) {
      print('❌ 获取历史净值错误: $e');
      return null;
    }
  }

  /// 强制刷新数据库（用于测试）
  static Future<bool> refreshDatabase() async {
    return await FundDatabaseManager.downloadFundDatabase();
  }
}
