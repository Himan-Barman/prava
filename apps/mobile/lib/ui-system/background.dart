import 'package:flutter/material.dart';

import 'colors.dart';

class PravaBackground extends StatelessWidget {
  const PravaBackground({super.key, this.isDark});

  final bool? isDark;

  @override
  Widget build(BuildContext context) {
    final useDark =
        isDark ?? Theme.of(context).brightness == Brightness.dark;
    final color =
        useDark ? PravaColors.darkBgMain : PravaColors.lightBgMain;

    return SizedBox.expand(
      child: ColoredBox(color: color),
    );
  }
}
