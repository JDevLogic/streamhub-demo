import 'package:flutter/material.dart';
import 'states.dart' show ShimmerLoading, SkeletonLeaf;

/// Skeleton for a vertical content card (used in HorizontalContentRow and grid).
class CardSkeleton extends StatelessWidget {
  const CardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      builder: (gradient) => SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonLeaf(
              height: 200,
              width: 140,
              radius: 12,
              gradient: gradient,
            ),
            const SizedBox(height: 8),
            SkeletonLeaf(
              height: 12,
              width: 110,
              radius: 4,
              gradient: gradient,
            ),
            const SizedBox(height: 4),
            SkeletonLeaf(
              height: 10,
              width: 60,
              radius: 4,
              gradient: gradient,
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for a horizontal episode card (used in HorizontalEpisodioRow).
class EpisodeCardSkeleton extends StatelessWidget {
  const EpisodeCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      builder: (gradient) => SizedBox(
        width: 260,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonLeaf(
              height: 156,
              width: 260,
              radius: 12,
              gradient: gradient,
            ),
            const SizedBox(height: 8),
            SkeletonLeaf(
              height: 14,
              width: 180,
              radius: 4,
              gradient: gradient,
            ),
            const SizedBox(height: 5),
            SkeletonLeaf(
              height: 11,
              width: 100,
              radius: 4,
              gradient: gradient,
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for a horizontal continue watching card (used in ContinuarViendoRow).
class ContinueWatchingSkeleton extends StatelessWidget {
  const ContinueWatchingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      builder: (gradient) => Container(
        width: 200,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF141428), // VoidTheme.card
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            SkeletonLeaf(
              width: 48,
              height: 48,
              radius: 10,
              gradient: gradient,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   SkeletonLeaf(
                    height: 12,
                    width: 100,
                    radius: 4,
                    gradient: gradient,
                  ),
                  const SizedBox(height: 6),
                   SkeletonLeaf(
                    height: 9,
                    width: 60,
                    radius: 4,
                    gradient: gradient,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for the top header of DetailScreen.
class DetailHeaderSkeleton extends StatelessWidget {
  const DetailHeaderSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      builder: (gradient) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonLeaf(
            height: 340,
            width: double.infinity,
            radius: 0,
            gradient: gradient,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                SkeletonLeaf(
                  width: 100,
                  height: 36,
                  radius: 10,
                  gradient: gradient,
                ),
                const SizedBox(width: 12),
                SkeletonLeaf(
                  width: 80,
                  height: 16,
                  radius: 4,
                  gradient: gradient,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLeaf(width: 80, height: 18, radius: 4, gradient: gradient),
                const SizedBox(height: 12),
                SkeletonLeaf(width: double.infinity, height: 13, radius: 4, gradient: gradient),
                const SizedBox(height: 8),
                SkeletonLeaf(width: double.infinity, height: 13, radius: 4, gradient: gradient),
                const SizedBox(height: 8),
                SkeletonLeaf(width: 200, height: 13, radius: 4, gradient: gradient),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for a list tile in EpisodiosScreen.
class EpisodeListTileSkeleton extends StatelessWidget {
  const EpisodeListTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      builder: (gradient) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF141428), // VoidTheme.card
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            SkeletonLeaf(
              width: 38,
              height: 38,
              radius: 10,
              gradient: gradient,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLeaf(
                    height: 14,
                    width: 140,
                    radius: 4,
                    gradient: gradient,
                  ),
                  const SizedBox(height: 6),
                  SkeletonLeaf(
                    height: 10,
                    width: 60,
                    radius: 4,
                    gradient: gradient,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SkeletonLeaf(
              width: 42,
              height: 42,
              radius: 13,
              gradient: gradient,
            ),
          ],
        ),
      ),
    );
  }
}
