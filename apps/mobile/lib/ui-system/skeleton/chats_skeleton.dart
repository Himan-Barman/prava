import 'package:flutter/material.dart';
import 'prava_skeleton_container.dart';
import 'prava_skeleton_block.dart';

class ChatsSkeleton extends StatelessWidget {
  const ChatsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return PravaSkeletonContainer(
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 10,
        separatorBuilder: (_, __) => const SizedBox(height: 18),
        itemBuilder: (_, __) {
          return const Row(
            children: const [
              PravaSkeletonBlock(
                height: 52,
                width: 52,
                radius: BorderRadius.all(Radius.circular(26)),
              ),
              SizedBox(width: 14),
              const Expanded(
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    PravaSkeletonBlock(height: 14, width: 160),
                    SizedBox(height: 6),
                    PravaSkeletonBlock(height: 12, width: 220),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
