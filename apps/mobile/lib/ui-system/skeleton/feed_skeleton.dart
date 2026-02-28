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
          return const Padding(
            padding: EdgeInsets.only(bottom: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// Header
                Row(
                  children: [
                    PravaSkeletonBlock(
                      height: 44,
                      width: 44,
                      radius: BorderRadius.all(Radius.circular(22)),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: PravaSkeletonBlock(height: 14),
                    ),
                  ],
                ),

                SizedBox(height: 12),

                /// Text
                PravaSkeletonBlock(height: 14),
                SizedBox(height: 6),
                PravaSkeletonBlock(height: 14, width: 260),

                SizedBox(height: 12),

                /// Media
                PravaSkeletonBlock(
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
