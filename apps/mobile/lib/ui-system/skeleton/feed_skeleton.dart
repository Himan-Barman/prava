import 'package:flutter/material.dart';
import 'prava_skeleton_container.dart';
import 'prava_skeleton_block.dart';

class FeedSkeleton extends StatelessWidget {
  const FeedSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return PravaSkeletonContainer(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        itemBuilder: (_, __) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// Header
                const Row(
                  children: const [
                    PravaSkeletonBlock(
                      height: 44,
                      width: 44,
                      radius: BorderRadius.all(Radius.circular(22)),
                    ),
                    SizedBox(width: 12),
                    const Expanded(
                      child: PravaSkeletonBlock(height: 14),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                /// Text
                const PravaSkeletonBlock(height: 14),
                const SizedBox(height: 6),
                const PravaSkeletonBlock(height: 14, width: 260),

                const SizedBox(height: 12),

                /// Media
                const PravaSkeletonBlock(
                  height: 180,
                  radius: BorderRadius.all(Radius.circular(16)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
