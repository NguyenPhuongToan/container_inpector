import 'package:flutter/material.dart';

import '../../models/inspection.dart';
import '../../services/api_service.dart';
import '../../widgets/status_badge.dart';

class ManagerReviewScreen extends StatefulWidget {
  final ContainerInspection inspection;

  const ManagerReviewScreen({
    super.key,
    required this.inspection,
  });

  @override
  State<ManagerReviewScreen> createState() => _ManagerReviewScreenState();
}

class _ManagerReviewScreenState extends State<ManagerReviewScreen> {
  final _apiService = ApiService();
  bool isBusy = false;
  late InspectionStatus currentStatus;

  static const List<String> photoLabels = [
    'Container Door Number',
    'Flexitank Serial Number',
    'Front',
    'Rear',
    'Left Side',
    'Right Side',
    'Front Left',
    'Front Right',
    'Rear Left',
    'Rear Right',
    'Ceiling',
    'Floor',
  ];

  @override
  void initState() {
    super.initState();
    currentStatus = widget.inspection.status;
  }

  Future<void> runAction({
    required String title,
    required String confirmation,
    required String confirmLabel,
    required Future<void> Function() action,
    required String successMessage,
    VoidCallback? onSuccess,
    bool popOnSuccess = true,
  }) async {
    final confirmed = await _confirmAction(
      title: title,
      message: confirmation,
      confirmLabel: confirmLabel,
    );

    if (!confirmed) return;

    setState(() {
      isBusy = true;
    });

    try {
      await action();
      onSuccess?.call();
      _showMessage(successMessage);
      if (mounted && popOnSuccess) Navigator.of(context).pop();
    } catch (_) {
      _showMessage('Action failed. Please check the backend connection.');
    } finally {
      if (mounted) {
        setState(() {
          isBusy = false;
        });
      }
    }
  }

  Future<void> runExportAction({
    required String title,
    required String confirmation,
    required String confirmLabel,
    required Future<String> Function() action,
  }) async {
    final confirmed = await _confirmAction(
      title: title,
      message: confirmation,
      confirmLabel: confirmLabel,
    );

    if (!confirmed) return;

    setState(() {
      isBusy = true;
    });

    try {
      final message = await action();
      _showMessage(message);
    } catch (_) {
      _showMessage('Export failed. Please check the backend connection.');
    } finally {
      if (mounted) {
        setState(() {
          isBusy = false;
        });
      }
    }
  }

  Future<bool> _confirmAction({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inspection = widget.inspection;
    final canDecide = currentStatus == InspectionStatus.submitted;
    final canExport = currentStatus == InspectionStatus.accepted;

    return Scaffold(
      appBar: AppBar(
        title: Text(inspection.containerNumber),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: StatusBadge(status: currentStatus),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InfoCard(inspection: inspection),
          const SizedBox(height: 18),
          const Text(
            'Inspection Photos',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          if (inspection.imageUrls.isEmpty)
            const _EmptyImagesCard()
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 720 ? 4 : 2;

                return GridView.builder(
                  itemCount: inspection.imageUrls.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.9,
                  ),
                  itemBuilder: (context, index) {
                    final label = index < photoLabels.length
                        ? photoLabels[index]
                        : 'Photo ${index + 1}';

                    return _ReviewPhotoTile(
                      imageUrl: inspection.imageUrls[index],
                      index: index,
                      label: label,
                    );
                  },
                );
              },
            ),
          const SizedBox(height: 24),
          _ActionButton(
            isBusy: isBusy,
            icon: Icons.check_circle_rounded,
            label: currentStatus == InspectionStatus.accepted
                ? 'Container Accepted'
                : 'Accept Container',
            filled: true,
            onPressed: canDecide
                ? () => runAction(
                      title: 'Accept Container',
                      confirmation:
                          'Are you sure you want to accept this inspection?',
                      confirmLabel: 'Accept',
                      action: () => _apiService.acceptInspection(inspection.id),
                      successMessage: 'Inspection accepted.',
                      popOnSuccess: false,
                      onSuccess: () {
                        setState(() {
                          currentStatus = InspectionStatus.accepted;
                        });
                      },
                    )
                : null,
          ),
          const SizedBox(height: 10),
          _ActionButton(
            isBusy: isBusy,
            icon: Icons.cancel_rounded,
            label: currentStatus == InspectionStatus.rejected
                ? 'Container Rejected'
                : 'Reject Container',
            onPressed: canDecide
                ? () => runAction(
                      title: 'Reject Container',
                      confirmation:
                          'Are you sure you want to reject this inspection?',
                      confirmLabel: 'Reject',
                      action: () => _apiService.rejectInspection(inspection.id),
                      successMessage: 'Inspection rejected.',
                      onSuccess: () {
                        setState(() {
                          currentStatus = InspectionStatus.rejected;
                        });
                      },
                    )
                : null,
          ),
          const SizedBox(height: 10),
          _ActionButton(
            isBusy: isBusy,
            icon: Icons.table_chart_rounded,
            label: canExport
                ? 'Export Excel and Email'
                : 'Excel Available After Acceptance',
            onPressed: canExport
                ? () => runExportAction(
                      title: 'Export Excel',
                      confirmation:
                          'Export this accepted inspection as an Excel data file and email it to the manager?',
                      confirmLabel: 'Export',
                      action: () =>
                          _apiService.exportExcelAndEmail(inspection.id),
                    )
                : null,
          ),
          const SizedBox(height: 10),
          _ActionButton(
            isBusy: isBusy,
            icon: Icons.description_rounded,
            label: canExport
                ? 'Generate Photo Report and Email'
                : 'Report Available After Acceptance',
            onPressed: canExport
                ? () => runExportAction(
                      title: 'Generate Photo Report',
                      confirmation:
                          'Generate the formatted photo report and email it to the manager?',
                      confirmLabel: 'Generate',
                      action: () =>
                          _apiService.generateReportAndEmail(inspection.id),
                    )
                : null,
          ),
          const SizedBox(height: 10),
          _ActionButton(
            isBusy: isBusy,
            icon: Icons.slideshow_rounded,
            label: canExport
                ? 'Export Fitting Photo PPT and Email'
                : 'PPT Available After Acceptance',
            onPressed: canExport
                ? () => runExportAction(
                      title: 'Export Fitting Photo PPT',
                      confirmation:
                          'Generate one fitting photo PowerPoint for all accepted containers with booking ${inspection.bookingNumber}?',
                      confirmLabel: 'Export',
                      action: () =>
                          _apiService.exportFittingPhotoAndEmail(inspection.id),
                    )
                : null,
          ),
        ],
      ),
    );
  }
}

class _EmptyImagesCard extends StatelessWidget {
  const _EmptyImagesCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text(
        'No inspection images uploaded.',
        style: TextStyle(
          color: Color(0xFF667085),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ReviewPhotoTile extends StatelessWidget {
  final String imageUrl;
  final int index;
  final String label;

  const _ReviewPhotoTile({
    required this.imageUrl,
    required this.index,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => FullscreenImageScreen(
                imageUrl: imageUrl,
                title: label,
              ),
            ),
          );
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return Container(
                  color: const Color(0xFFE7EDF4),
                  child: const Icon(
                    Icons.broken_image_rounded,
                    color: Color(0xFF667085),
                    size: 40,
                  ),
                );
              },
            ),
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF075DCC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                color: Colors.black.withValues(alpha: 0.58),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final bool isBusy;
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.isBusy,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final buttonLabel = isBusy
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label);

    if (filled) {
      return FilledButton.icon(
        onPressed: isBusy ? null : onPressed,
        icon: Icon(icon),
        label: buttonLabel,
      );
    }

    return OutlinedButton.icon(
      onPressed: isBusy ? null : onPressed,
      icon: Icon(icon),
      label: buttonLabel,
    );
  }
}

class FullscreenImageScreen extends StatelessWidget {
  final String imageUrl;
  final String title;

  const FullscreenImageScreen({
    super.key,
    required this.imageUrl,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 5,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.broken_image_rounded,
                    color: Colors.white70,
                    size: 56,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Image could not be loaded.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final ContainerInspection inspection;

  const _InfoCard({required this.inspection});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _InfoRow('Container Number', inspection.containerNumber),
          _InfoRow(
            'Flexitank Number',
            inspection.flexitankNumber.isEmpty ? '-' : inspection.flexitankNumber,
          ),
          _InfoRow('Booking Number', inspection.bookingNumber),
          _InfoRow('Truck Number', inspection.truckNumber),
          _InfoRow('Worker', inspection.workerName),
          _InfoRow('Port / Location', inspection.portName),
          _InfoRow('Submitted At', inspection.formattedDate),
          _InfoRow('Notes', inspection.notes.isEmpty ? '-' : inspection.notes),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF667085),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
