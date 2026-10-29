import 'package:flutter/material.dart';

import '../core/brand_config.dart';

/// Formal neutral-grey shimmer skeleton for loading states.
class BrandedSkeleton extends StatefulWidget {
  const BrandedSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 8,
    this.brand,
  });

  final double? width;
  final double height;
  final double borderRadius;
  final BrandConfig? brand;

  @override
  State<BrandedSkeleton> createState() => _BrandedSkeletonState();
}

class _BrandedSkeletonState extends State<BrandedSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1 + _controller.value * 2, 0),
              end: Alignment(_controller.value * 2, 0),
              colors: const [
                Color(0xFFE9EBEE),
                Color(0xFFF7F8FA),
                Color(0xFFF7F8FA),
                Color(0xFFE9EBEE),
              ],
            ),
          ),
        );
      },
    );
  }
}

class BrandedSkeletonList extends StatelessWidget {
  const BrandedSkeletonList({super.key, this.count = 4, this.brand});

  final int count;
  final BrandConfig? brand;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => BrandedSkeleton(
        brand: brand,
        height: 72,
        borderRadius: 12,
      ),
    );
  }
}