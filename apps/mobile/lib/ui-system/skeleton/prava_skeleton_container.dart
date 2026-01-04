import 'package:flutter/material.dart';

class PravaSkeletonContainer extends StatefulWidget {
  final Widget child;

  const PravaSkeletonContainer({super.key, required this.child});

  @override
  State<PravaSkeletonContainer> createState() =>
      _PravaSkeletonContainerState();
}

class _PravaSkeletonContainerState extends State<PravaSkeletonContainer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _opacity = Tween<double>(begin: 0.55, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: widget.child,
    );
  }
}
