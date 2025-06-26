import 'package:flutter/material.dart';

class ScrollAwareFAB extends StatefulWidget {
  final Widget child;
  final ScrollController scrollController;
  final Duration animationDuration;
  final Curve animationCurve;

  const ScrollAwareFAB({
    Key? key,
    required this.child,
    required this.scrollController,
    this.animationDuration = const Duration(milliseconds: 300),
    this.animationCurve = Curves.easeInOut,
  }) : super(key: key);

  @override
  State<ScrollAwareFAB> createState() => _ScrollAwareFABState();
}

class _ScrollAwareFABState extends State<ScrollAwareFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isVisible = true;
  static const double _scrollThreshold = 20.0;
  double _lastScrollPosition = 0.0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
      value: 1.0,
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: widget.animationCurve,
      reverseCurve: widget.animationCurve.flipped,
    );

    widget.scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_handleScroll);
    _animationController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    final currentPosition = widget.scrollController.position.pixels;
    final scrollDelta = currentPosition - _lastScrollPosition;

    if (scrollDelta.abs() > _scrollThreshold) {
      final isScrollingDown = scrollDelta > 0;
      if (isScrollingDown != !_isVisible) {
        setState(() {
          _isVisible = !isScrollingDown;
          if (_isVisible) {
            _animationController.forward();
          } else {
            _animationController.reverse();
          }
        });
      }
      _lastScrollPosition = currentPosition;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: FadeTransition(opacity: _animation, child: widget.child),
    );
  }
}
