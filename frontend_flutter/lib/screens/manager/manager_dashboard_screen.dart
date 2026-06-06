import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/inspection.dart';
import '../../services/api_service.dart';
import '../../widgets/inspection_card_skeleton.dart';
import '../../widgets/status_badge.dart';
import 'manager_review_screen.dart';

class ManagerDashboardScreen extends StatefulWidget {
  const ManagerDashboardScreen({super.key});

  @override
  State<ManagerDashboardScreen> createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen> {
  final _apiService = ApiService();
  final _containerController = TextEditingController();
  final _workerController = TextEditingController();
  final _portController = TextEditingController();
  String _status = 'submitted';
  int _pendingCount = 0;
  int _lastKnownPendingCount = 0;
  bool _isExportingSelection = false;
  final Set<String> _selectedInspectionIds = {};
  Timer? _pollingTimer;
  late Future<List<ContainerInspection>> inspectionsFuture;

  @override
  void initState() {
    super.initState();
    inspectionsFuture = _loadInspections();
    _loadPendingCount();
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _loadPendingCount(),
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _containerController.dispose();
    _workerController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<List<ContainerInspection>> _loadInspections() {
    return _apiService.getInspections(
      status: _status.isEmpty ? null : _status,
      containerNumber: _containerController.text.trim(),
      workerName: _workerController.text.trim(),
      portName: _portController.text.trim(),
    );
  }

  Future<void> refresh() async {
    setState(() {
      inspectionsFuture = _loadInspections();
    });
    await _loadPendingCount();
    await inspectionsFuture;
  }

  void _setStatus(String status) {
    setState(() {
      _status = status;
      _selectedInspectionIds.clear();
      inspectionsFuture = _loadInspections();
    });
  }

  void _filterByStatus(String status) => _setStatus(status);

  Future<void> _loadPendingCount() async {
    try {
      final list = await _apiService.getInspections(status: 'submitted');
      final newCount = list.length;
      if (!mounted) return;

      if (newCount > _lastKnownPendingCount && _lastKnownPendingCount != 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${newCount - _lastKnownPendingCount} new inspection(s) waiting for review',
            ),
            backgroundColor: const Color(0xFF075DCC),
            action: SnackBarAction(
              label: 'Review',
              textColor: Colors.white,
              onPressed: () => _filterByStatus('submitted'),
            ),
          ),
        );
      }

      setState(() {
        _pendingCount = newCount;
        _lastKnownPendingCount = newCount;
      });
    } catch (_) {
      return;
    }
  }

  bool _canSelect(ContainerInspection inspection) {
    return inspection.status == InspectionStatus.accepted;
  }

  void _toggleSelection(ContainerInspection inspection, bool selected) {
    if (!_canSelect(inspection)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only accepted inspections can be grouped for a report.'),
        ),
      );
      return;
    }

    setState(() {
      if (selected) {
        _selectedInspectionIds.add(inspection.id);
      } else {
        _selectedInspectionIds.remove(inspection.id);
      }
    });
  }

  Future<void> _exportSelectedFittingPhotos(
    List<ContainerInspection> inspections,
  ) async {
    final selected = inspections
        .where((inspection) => _selectedInspectionIds.contains(inspection.id))
        .toList();

    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one accepted inspection.')),
      );
      return;
    }

    final bookingNumbers = {
      for (final inspection in selected) inspection.bookingNumber.trim().toLowerCase(),
    };
    if (bookingNumbers.length > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select inspections from the same booking number.'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create Group Report'),
          content: Text(
            'Create one fitting photo PowerPoint for ${selected.length} selected inspection(s) with booking ${selected.first.bookingNumber}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Create Report'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _isExportingSelection = true;
    });

    try {
      final message = await _apiService.exportSelectedFittingPhotosAndEmail(
        selected.map((inspection) => inspection.id).toList(),
      );
      if (!mounted) return;
      setState(() {
        _selectedInspectionIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report export failed. Please check the backend connection.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExportingSelection = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manager Review'),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_rounded),
                onPressed: () => _filterByStatus('submitted'),
              ),
              if (_pendingCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE53935),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _pendingCount > 99 ? '99+' : '$_pendingCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            onPressed: refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterPanel(
            status: _status,
            containerController: _containerController,
            workerController: _workerController,
            portController: _portController,
            onStatusChanged: _setStatus,
            onApply: refresh,
            onClear: () {
              _containerController.clear();
              _workerController.clear();
              _portController.clear();
              _setStatus('submitted');
            },
          ),
          Expanded(
            child: FutureBuilder<List<ContainerInspection>>(
              future: inspectionsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: 6,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, __) => const InspectionCardSkeleton(),
                  );
                }

                if (snapshot.hasError) {
                  return _MessageState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Cannot load inspections',
                    message: 'Check backend connection and manager login.',
                    onRetry: refresh,
                  );
                }

                final inspections = snapshot.data ?? [];
                _selectedInspectionIds.removeWhere(
                  (id) => !inspections.any(
                    (inspection) =>
                        inspection.id == id && _canSelect(inspection),
                  ),
                );

                if (inspections.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 160),
                        _EmptyDashboardState(),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: refresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: inspections.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _SelectionReportBar(
                            selectedCount: _selectedInspectionIds.length,
                            isBusy: _isExportingSelection,
                            onCreateReport: () =>
                                _exportSelectedFittingPhotos(inspections),
                            onClear: () {
                              setState(() {
                                _selectedInspectionIds.clear();
                              });
                            },
                          ),
                        );
                      }

                      final listIndex = index - 1;
                      final inspection = inspections[listIndex];
                      final canSelect = _canSelect(inspection);
                      final isSelected =
                          _selectedInspectionIds.contains(inspection.id);

                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: listIndex == inspections.length - 1 ? 0 : 12,
                        ),
                        child: Material(
                          color: Colors.white,
                          elevation: 2,
                          shadowColor: Colors.black.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ManagerReviewScreen(
                                    inspection: inspection,
                                  ),
                                ),
                              );
                              await refresh();
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: isSelected,
                                    onChanged: canSelect
                                        ? (value) => _toggleSelection(
                                              inspection,
                                              value ?? false,
                                            )
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF075DCC)
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      Icons.inventory_2_outlined,
                                      color: Color(0xFF075DCC),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          inspection.containerNumber,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${inspection.bookingNumber} - ${inspection.portName} - ${inspection.workerName} - ${inspection.formattedDate}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFF667085),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  StatusBadge(status: inspection.status),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionReportBar extends StatelessWidget {
  final int selectedCount;
  final bool isBusy;
  final VoidCallback onCreateReport;
  final VoidCallback onClear;

  const _SelectionReportBar({
    required this.selectedCount,
    required this.isBusy,
    required this.onCreateReport,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFEAF2FF),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 560;
            final summary = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.checklist_rounded, color: Color(0xFF075DCC)),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    selectedCount == 0
                        ? 'Tick accepted inspections to group in one report.'
                        : '$selectedCount inspection(s) selected',
                    style: const TextStyle(
                      color: Color(0xFF12355B),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            );
            final actions = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: selectedCount == 0 || isBusy ? null : onClear,
                  child: const Text('Clear'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed:
                      selectedCount == 0 || isBusy ? null : onCreateReport,
                  icon: isBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.slideshow_rounded),
                  label: const Text('Create Report'),
                ),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  summary,
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: actions,
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: summary),
                actions,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  final String status;
  final TextEditingController containerController;
  final TextEditingController workerController;
  final TextEditingController portController;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onApply;
  final VoidCallback onClear;

  const _FilterPanel({
    required this.status,
    required this.containerController,
    required this.workerController,
    required this.portController,
    required this.onStatusChanged,
    required this.onApply,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _StatusChip(
                    label: 'All',
                    value: '',
                    status: status,
                    onChanged: onStatusChanged,
                  ),
                  _StatusChip(
                    label: 'Submitted',
                    value: 'submitted',
                    status: status,
                    onChanged: onStatusChanged,
                  ),
                  _StatusChip(
                    label: 'Accepted',
                    value: 'accepted',
                    status: status,
                    onChanged: onStatusChanged,
                  ),
                  _StatusChip(
                    label: 'Rejected',
                    value: 'rejected',
                    status: status,
                    onChanged: onStatusChanged,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 720;
                final fields = [
                  _FilterField(
                    controller: containerController,
                    label: 'Container',
                    icon: Icons.numbers_rounded,
                    onSubmitted: onApply,
                  ),
                  _FilterField(
                    controller: workerController,
                    label: 'Worker',
                    icon: Icons.person_rounded,
                    onSubmitted: onApply,
                  ),
                  _FilterField(
                    controller: portController,
                    label: 'Port',
                    icon: Icons.location_on_rounded,
                    onSubmitted: onApply,
                  ),
                ];

                if (!wide) {
                  return Column(
                    children: [
                      for (final field in fields) ...[
                        field,
                        const SizedBox(height: 8),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: onClear,
                              child: const Text('Clear'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              onPressed: onApply,
                              child: const Text('Apply'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    for (final field in fields) ...[
                      Expanded(child: field),
                      const SizedBox(width: 8),
                    ],
                    OutlinedButton(
                      onPressed: onClear,
                      child: const Text('Clear'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: onApply,
                      child: const Text('Apply'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final String value;
  final String status;
  final ValueChanged<String> onChanged;

  const _StatusChip({
    required this.label,
    required this.value,
    required this.status,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: status == value,
        onSelected: (_) => onChanged(value),
      ),
    );
  }
}

class _FilterField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final VoidCallback onSubmitted;

  const _FilterField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => onSubmitted(),
      decoration: InputDecoration(
        isDense: true,
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _EmptyDashboardState extends StatelessWidget {
  const _EmptyDashboardState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: Color(0xFFB0B7C3),
          ),
          SizedBox(height: 16),
          Text(
            'No inspections found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'All caught up!',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF667085),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onRetry;

  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: const Color(0xFF075DCC)),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF667085),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}
