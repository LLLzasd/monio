import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

class FundCode {
  final String code;
  final String name;
  final String type;

  FundCode({
    required this.code,
    required this.name,
    required this.type,
  });

  factory FundCode.fromJson(Map<String, dynamic> json) {
    return FundCode(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
    );
  }
}

class FundDatabaseManager {
  static const String _cacheKey = 'fund_db_last_update';
  static const String _fileName = 'fundcode_search.js';
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
    headers: {
      'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X)',
      'Referer': 'https://fund.eastmoney.com/',
    },
  ));

  /// 获取本地缓存目录（使用应用文档目录，确保真实设备可访问）
  static Future<String> get _localPath async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      print('📁 数据库存储路径: ${directory.path}');
      return directory.path;
    } catch (e) {
      print('⚠️ 获取应用文档目录失败，回退到临时目录: $e');
      final directory = await getTemporaryDirectory();
      return directory.path;
    }
  }

  /// 获取缓存文件路径
  static Future<File> get _cacheFile async {
    final path = await _localPath;
    return File('$path/$_fileName');
  }

  /// 检查今天是否已经更新过
  static Future<bool> get isTodayUpdated async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdateStr = prefs.getString(_cacheKey);

      if (lastUpdateStr == null) return false;

      final lastUpdate = DateTime.parse(lastUpdateStr);
      final now = DateTime.now();

      // 检查是否是同一天
      return lastUpdate.year == now.year &&
          lastUpdate.month == now.month &&
          lastUpdate.day == now.day;
    } catch (e) {
      print('检查更新时间错误: $e');
      return false;
    }
  }

  /// 标记今天已更新
  static Future<void> _markTodayUpdated() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, DateTime.now().toIso8601String());
    } catch (e) {
      print('标记更新时间错误: $e');
    }
  }

  /// 下载基金代码数据库
  static Future<bool> downloadFundDatabase() async {
    try {
      final url = 'http://fund.eastmoney.com/js/fundcode_search.js';
      print('📥 开始下载基金代码数据库...');
      print('📥 下载URL: $url');
      print('📥 网络超时设置: connect=${_dio.options.connectTimeout}, receive=${_dio.options.receiveTimeout}');

      final response = await _dio.get(
        url,
        options: Options(
          responseType: ResponseType.plain,
        ),
      );

      print('📥 响应状态码: ${response.statusCode}');
      print('📥 响应大小: ${response.data?.toString().length ?? 0} 字符');

      if (response.statusCode == 200) {
        final file = await _cacheFile;
        
        print('💾 保存到文件: ${file.path}');
        await file.writeAsString(response.data.toString());

        // 标记已更新
        await _markTodayUpdated();

        // 验证保存结果
        final stat = await file.stat();
        print('✅ 基金代码数据库下载成功');
        print('✅ 文件路径: ${file.path}');
        print('✅ 文件大小: ${stat.size} 字节');
        return true;
      } else {
        print('❌ 下载失败，状态码: ${response.statusCode}');
        print('❌ 响应内容: ${response.data?.toString().substring(0, 100)}...');
        return false;
      }
    } on DioException catch (e) {
      print('❌ 下载DIO异常:');
      print('   类型: ${e.type}');
      print('   消息: ${e.message}');
      print('   状态码: ${e.response?.statusCode}');
      print('   响应: ${e.response?.data}');
      return false;
    } catch (e) {
      print('❌ 下载错误: $e');
      return false;
    }
  }

  /// 确保数据库可用（如果需要则下载）
  static Future<bool> ensureDatabaseAvailable() async {
    try {
      // 检查文件是否存在
      final file = await _cacheFile;
      bool exists = await file.exists();
      
      print('📂 检查数据库文件: ${file.path}');
      print('📂 文件存在: $exists');
      print('📂 今天已更新: ${await isTodayUpdated}');

      if (!exists || !(await isTodayUpdated)) {
        if (!exists) {
          print('🔄 数据库文件不存在，需要下载...');
        } else {
          print('🔄 数据库文件已过期，需要更新...');
        }
        return await downloadFundDatabase();
      }

      // 验证文件大小
      final stat = await file.stat();
      print('✅ 基金数据库已是最新，大小: ${stat.size} 字节');
      return true;
    } catch (e, stackTrace) {
      print('❌ 确保数据库可用错误: $e');
      print('❌ 堆栈: $stackTrace');
      return false;
    }
  }

  /// 从本地文件解析所有基金代码
  static Future<List<FundCode>> loadAllFunds() async {
    List<FundCode> funds = [];

    try {
      final file = await _cacheFile;

      if (!await file.exists()) {
        print('⚠️ 缓存文件不存在');
        return funds;
      }

      final content = await file.readAsString();

      if (content.isEmpty) {
        print('⚠️ 缓存文件为空');
        return funds;
      }

      // 解析东方财富的JS格式
      // 格式示例：var r = [["000001","华夏成长","华夏成长混合","HXPZ"],["000002","华夏成长A","华夏成长A混合","HXPZ"],...];
      // 字段说明：[0]=代码, [1]=简称, [2]=全称(显示用), [3]=类型
      int startIndex = content.indexOf('[[');
      int endIndex = content.lastIndexOf(']]') + 2;

      if (startIndex == -1 || endIndex <= startIndex) {
        print('⚠️ 无法找到数据格式');
        return funds;
      }

      String dataStr = content.substring(startIndex, endIndex);

      // 解析JSON数组
      List<dynamic> dataList = json.decode(dataStr);

      for (var item in dataList) {
        if (item is List && item.length >= 3) {
          funds.add(FundCode(
            code: item[0]?.toString() ?? '',
            name: item[2]?.toString() ?? '', // 使用第3位作为全称
            type: item.length > 3 ? (item[3]?.toString() ?? '') : '',
          ));
        }
      }

      print('✅ 成功加载 ${funds.length} 个基金代码');
      return funds;

    } catch (e, stackTrace) {
      print('❌ 解析基金数据库错误: $e');
      print('堆栈: $stackTrace');
      return funds;
    }
  }

  /// 本地模糊搜索（快速）
  static Future<List<FundCode>> searchFundsLocally(String query, {int limit = 10}) async {
    if (query.length < 1) return [];

    try {
      final allFunds = await loadAllFunds();

      if (allFunds.isEmpty) return [];

      // 模糊匹配
      var matched = allFunds.where((fund) =>
        fund.code.contains(query) ||
        fund.name.contains(query)
      ).toList();

      // 只返回前limit个结果
      return matched.take(limit).toList();

    } catch (e) {
      print('❌ 本地搜索错误: $e');
      return [];
    }
  }

  /// 清除缓存（用于测试）
  static Future<void> clearCache() async {
    try {
      final file = await _cacheFile;
      if (await file.exists()) {
        await file.delete();
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);

      print('🗑️ 缓存已清除');
    } catch (e) {
      print('❌ 清除缓存错误: $e');
    }
  }
}
