import 'package:flutter/material.dart';

import '../core/brand_config.dart';

/// Navy/orange shimmer skeleton for loading states.
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
    final b = widget.brand ?? BrandConfig.defaults;
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
              colors: [
                b.greyBg,
                b.orange.withValues(alpha: 0.15),
                b.navy.withValues(alpha: 0.08),
                b.greyBg,
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