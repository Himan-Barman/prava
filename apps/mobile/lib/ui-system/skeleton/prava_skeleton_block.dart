import 'package:flutter/material.dart';

class PravaSkeletonBlock extends StatelessWidget {
  final double height;
  final double width;
  final BorderRadius radius;

  const PravaSkeletonBlock({
    super.key,
    required this.height,
    this.width = double.infinity,
    this.radius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: isDark ? Colors.white12 : Colors.black12,
        borderRadius: radius,
      ),
    );
  }
}
