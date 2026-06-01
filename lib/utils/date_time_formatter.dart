class DateTimeFormatter {
  static String formatDateTime(DateTime? dateTime) {
    if (dateTime == null) {
      return _formatDateTime(DateTime.now());
    }
    return _formatDateTime(dateTime);
  }

  static String _formatDateTime(DateTime dateTime) {
    final year = dateTime.year;
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    
    return '$year-$month-$day $hour:$minute';
  }

  static String formatDate(DateTime? dateTime) {
    if (dateTime == null) {
      return _formatDate(DateTime.now());
    }
    return _formatDate(dateTime);
  }

  static String formatShortDate(DateTime? dateTime) {
    if (dateTime == null) {
      return _formatShortDate(DateTime.now());
    }
    return _formatShortDate(dateTime);
  }

  static String formatRelativeTime(DateTime? dateTime) {
    if (dateTime == null) {
      return '未知';  // 当时间为null时显示"未知"
    }
    return _formatRelativeTime(dateTime);
  }

  static String _formatDate(DateTime dateTime) {
    final year = dateTime.year;
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  static String _formatShortDate(DateTime dateTime) {
    final month = dateTime.month;
    final day = dateTime.day;

    return '$month月$day日 更新';
  }

  static String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return '刚刚更新';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}分钟前 更新';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}小时前 更新';
    } else if (dateTime.year == now.year) {
      return '${dateTime.month}月${dateTime.day}日 更新';
    } else {
      return '${dateTime.year}年${dateTime.month}月${dateTime.day}日 更新';
    }
  }
}
