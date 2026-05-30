import 'package:flutter/material.dart';

import '../models/inspection.dart';

class StatusBadge extends StatelessWidget {
  final InspectionStatus status;

  const StatusBadge({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: 0.65),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _statusLabel(status),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(InspectionStatus status) {
    switch (status) {
      case InspectionStatus.accepted:
        return const Color(0xFF1FB337);
      case InspectionStatus.rejected:
        return const Color(0xFFD32F2F);
      case InspectionStatus.submitted:
        return const Color(0xFF075DCC);
      case InspectionStatus.draft:
        return const Color(0xFF667085);
    }
  }

  String _statusLabel(InspectionStatus status) {
    switch (status) {
      case InspectionStatus.accepted:
        return 'ACCEPTED';
      case InspectionStatus.rejected:
        return 'REJECTED';
      case InspectionStatus.submitted:
        return 'SUBMITTED';
      case InspectionStatus.draft:
        return 'DRAFT';
    }
  }
}
