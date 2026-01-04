import 'package:flutter/material.dart';
import 'prava_skeleton_container.dart';
import 'prava_skeleton_block.dart';

class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return PravaSkeletonContainer(
      child: const Column(
        children: const [
          SizedBox(height: 24),
          PravaSkeletonBlock(
            height: 96,
            width: 96,
            radius: BorderRadius.all(Radius.circular(48)),
          ),
          SizedBox(height: 16),
          PravaSkeletonBlock(height: 16, width: 180),
          SizedBox(height: 8),
          PravaSkeletonBlock(height: 14, width: 240),
        ],
      ),
    );
  }
}
