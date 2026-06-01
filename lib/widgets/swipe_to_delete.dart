import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SwipeToDelete extends StatefulWidget {
  final Widget child;
  final VoidCallback onDelete;

  const SwipeToDelete({
    super.key,
    required this.child,
    required this.onDelete,
  });

  @override
  State<SwipeToDelete> createState() => _SwipeToDeleteState();
}

class _SwipeToDeleteState extends State<SwipeToDelete>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _fullSwipeController;
  
  double _currentOffset = 0.0;
  double _totalDragDistance = 0.0;
  bool _isFullSwiping = false;
  double _deleteButtonWidth = 80.0;

  static const double _initialDeleteButtonWidth = 80.0;
  static const double _showThreshold = 60.0;
  static const double _fullSwipeThreshold = 120.0;
  static const double _cardMarginRight = 16.0;
  static const double _cardMarginBottom = 10.0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    
    _fullSwipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _fullSwipeController.dispose();
    super.dispose();
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    if (_animationController.isAnimating) {
      _animationController.stop();
    }
    if (_fullSwipeController.isAnimating) {
      _fullSwipeController.stop();
    }
    
    _totalDragDistance = 0.0;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    final delta = details.delta.dx;

    if (delta < 0 && !_isFullSwiping) {
      setState(() {
        _totalDragDistance += delta.abs();
        _currentOffset += delta;
        _currentOffset = _currentOffset.clamp(-(_initialDeleteButtonWidth + _cardMarginRight + 50), 0);
        
        if (_totalDragDistance >= _fullSwipeThreshold) {
          _triggerFullSwipeDelete();
        }
      });
    } else if (delta > 0 && _currentOffset < 0 && !_isFullSwiping) {
      setState(() {
        _currentOffset += delta;
        _totalDragDistance -= delta.abs();
        if (_totalDragDistance < 0) _totalDragDistance = 0;
        
        if (_currentOffset > 0) _currentOffset = 0;
      });
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_isFullSwiping) return;
    
    if (_currentOffset <= -_showThreshold) {
      _animateTo(-(_initialDeleteButtonWidth + _cardMarginRight));
      HapticFeedback.lightImpact();
    } else {
      _reset();
    }
  }

  void _triggerFullSwipeDelete() {
    if (_isFullSwiping) return;
    
    setState(() => _isFullSwiping = true);
    
    HapticFeedback.heavyImpact();
    
    final expandAnimation = Tween<double>(
      begin: _deleteButtonWidth,
      end: MediaQuery.of(context).size.width,
    ).animate(CurvedAnimation(
      parent: _fullSwipeController,
      curve: Curves.easeOut,
    ));

    expandAnimation.addListener(() {
      if (mounted) {
        setState(() {
          _deleteButtonWidth = expandAnimation.value;
          _currentOffset = -(_deleteButtonWidth + _cardMarginRight);
        });
      }
    });

    _fullSwipeController.reset();
    _fullSwipeController.forward().then((_) {
      if (mounted) {
        _reset();
        
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            widget.onDelete();
            setState(() => _isFullSwiping = false);
          }
        });
      }
    });
  }

  void _animateTo(double targetOffset) {
    final animation = Tween<double>(
      begin: _currentOffset,
      end: targetOffset,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    animation.addListener(() {
      if (mounted) {
        setState(() {
          _currentOffset = animation.value;
        });
      }
    });

    _animationController.reset();
    _animationController.forward();
  }

  void _reset() {
    _animateTo(0);
    if (mounted) {
      setState(() => _deleteButtonWidth = _initialDeleteButtonWidth);
    }
  }

  void _onTapDelete() {
    _reset();
    
    Future.delayed(const Duration(milliseconds: 280), () {
      if (mounted) {
        widget.onDelete();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: _onHorizontalDragStart,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      // 左滑状态下，点击任意区域（除删除按钮）则回弹取消
      onTap: _currentOffset != 0 ? _reset : null,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (_currentOffset != 0)
            Positioned(
              right: _cardMarginRight,
              top: 0,
              bottom: _cardMarginBottom,
              width: _deleteButtonWidth,
              child: GestureDetector(
                onTap: _onTapDelete,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.delete_outline,
                        color: Colors.white,
                        size: 28,
                      ),
                      if (_isFullSwiping || _deleteButtonWidth > _initialDeleteButtonWidth + 20)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            '删除',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

          Transform.translate(
            offset: Offset(_currentOffset, 0),
            transformHitTests: true,
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
