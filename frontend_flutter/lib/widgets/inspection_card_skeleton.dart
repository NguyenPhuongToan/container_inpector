import 'package:flutter/material.dart';

import 'skeleton_loader.dart';

class InspectionCardSkeleton extends StatelessWidget {
  const InspectionCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            SkeletonLoader(
              width: 52,
              height: 52,
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLoader(width: double.infinity, height: 16),
                  SizedBox(height: 10),
                  SkeletonLoader(width: 170, height: 12),
                  SizedBox(height: 8),
                  SkeletonLoader(width: 130, height: 12),
                ],
              ),
            ),
            SizedBox(width: 12),
            SkeletonLoader(
              width: 72,
              height: 24,
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
          ],
        ),
      ),
    );
  }
}
