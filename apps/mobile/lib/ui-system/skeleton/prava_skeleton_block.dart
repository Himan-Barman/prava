import 'package:flutter/material.dart';

import '../colors.dart';

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
    final tokens = context.pravaColors;

    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: tokens.skeletonBase,
        borderRadius: radius,
      ),
    );
  }
}
