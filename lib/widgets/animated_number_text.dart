import 'package:flutter/material.dart';

class AnimatedNumberText extends StatefulWidget {
  final double value;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;
  final String prefix;
  final String suffix;
  final int decimalPlaces;
  final bool isEnabled;

  const AnimatedNumberText({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 800),
    this.curve = Curves.easeOutCubic,
    this.prefix = '',
    this.suffix = '',
    this.decimalPlaces = 2,
    this.isEnabled = true,
  });

  @override
  State<AnimatedNumberText> createState() => _AnimatedNumberTextState();
}

class _AnimatedNumberTextState extends State<AnimatedNumberText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _displayValue = 0;
  double _previousValue = 0;
  bool _hasInitialized = false; // 标记是否已完成首次初始化

  @override
  void initState() {
    super.initState();
    _displayValue = widget.value;
    _previousValue = widget.value;

    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _animation = Tween<double>(
      begin: _previousValue,
      end: _displayValue,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    _animation.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(AnimatedNumberText oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 首次初始化时不播放动画（直接显示目标值）
    if (!_hasInitialized) {
      _hasInitialized = true;
      _displayValue = widget.value;
      _previousValue = widget.value;
      _animation = Tween<double>(
        begin: _displayValue,
        end: _displayValue,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: widget.curve,
      ));
      return;
    }

    // ✨ 与当前显示值比较（而非 oldWidget），确保任何变化都触发动画
    final valueDifference = (widget.value - _displayValue).abs();

    if (valueDifference > 0 && widget.isEnabled) { // 只要有任何变化就触发
      _previousValue = _displayValue;
      _displayValue = widget.value;

      // 重新配置动画
      _controller.reset();

      _animation = Tween<double>(
        begin: _previousValue,
        end: _displayValue,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: widget.curve,
      ));

      _controller.forward(); // ✨ 播放动画
    } else {
      // 值完全相同，无需操作（保持当前显示状态）
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentValue = _animation.value;

    return Text(
      '${widget.prefix}${_formatNumber(currentValue)}${widget.suffix}',
      style: widget.style,
    );
  }

  String _formatNumber(double value) {
    // 格式化数字，保留指定小数位
    String formatted = value.toStringAsFixed(widget.decimalPlaces);
    
    // 移除不必要的尾部零（但保留至少 decimalPlaces 位小数）
    if (formatted.contains('.')) {
      List<String> parts = formatted.split('.');
      String decimalPart = parts[1];
      
      while (decimalPart.length > widget.decimalPlaces && 
             decimalPart.endsWith('0')) {
        decimalPart = decimalPart.substring(0, decimalPart.length - 1);
      }
      
      formatted = decimalPart.isEmpty ? parts[0] : '${parts[0]}.$decimalPart';
    }
    
    return formatted;
  }
}
