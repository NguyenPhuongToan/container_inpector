import 'package:flutter/material.dart';

import '../../models/inspection.dart';
import '../../services/api_service.dart';
import '../../widgets/status_badge.dart';

class WorkerHistoryScreen extends StatefulWidget {
  const WorkerHistoryScreen({super.key});

  @override
  State<WorkerHistoryScreen> createState() => _WorkerHistoryScreenState();
}

class _WorkerHistoryScreenState extends State<WorkerHistoryScreen> {
  final _apiService = ApiService();
  String _status = '';
  late Future<List<ContainerInspection>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<ContainerInspection>> _load() {
    return _apiService.getInspections(
      status: _status.isEmpty ? null : _status,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  void _setStatus(String status) {
    setState(() {
      _status = status;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Worker History'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _status.isEmpty,
                  onTap: () => _setStatus(''),
                ),
                _FilterChip(
                  label: 'Submitted',
                  selected: _status == 'submitted',
                  onTap: () => _setStatus('submitted'),
                ),
                _FilterChip(
                  label: 'Accepted',
                  selected: _status == 'accepted',
                  onTap: () => _setStatus('accepted'),
                ),
                _FilterChip(
                  label: 'Rejected',
                  selected: _status == 'rejected',
                  onTap: () => _setStatus('rejected'),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<ContainerInspection>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _HistoryMessage(
                    icon: Icons.cloud_off_rounded,
                    title: 'Cannot load history',
                    message: 'Check backend connection and sign in again.',
                    onRetry: _refresh,
                  );
                }

                final inspections = snapshot.data ?? [];
                if (inspections.isEmpty) {
                  return _HistoryMessage(
                    icon: Icons.inbox_rounded,
                    title: 'No inspections found',
                    message: 'Your submitted inspections will appear here.',
                    onRetry: _refresh,
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: inspections.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final inspection = inspections[index];
                      return _HistoryTile(inspection: inspection);
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

class _HistoryTile extends StatelessWidget {
  final ContainerInspection inspection;

  const _HistoryTile({required this.inspection});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF075DCC).withValues(alpha: 0.12),
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
              crossAxisAlignment: CrossAxisAlignment.start,
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
                  '${inspection.portName} - ${inspection.photoCount} photos - ${inspection.formattedDate}',
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
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _HistoryMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onRetry;

  const _HistoryMessage({
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
