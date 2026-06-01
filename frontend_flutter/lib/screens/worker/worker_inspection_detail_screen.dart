import 'package:flutter/material.dart';

import '../../models/inspection.dart';
import '../../widgets/status_badge.dart';

class WorkerInspectionDetailScreen extends StatelessWidget {
  final ContainerInspection inspection;

  const WorkerInspectionDetailScreen({
    super.key,
    required this.inspection,
  });

  @override
  Widget build(BuildContext context) {
    final urls = inspection.images.isNotEmpty
        ? inspection.images.map((image) => image.url).toList()
        : inspection.imageUrls;
    final labels = inspection.images.isNotEmpty
        ? inspection.images.map((image) => image.label).toList()
        : List.generate(urls.length, (index) => 'Photo ${index + 1}');

    return Scaffold(
      appBar: AppBar(
        title: Text(inspection.containerNumber),
        backgroundColor: const Color(0xFF075DCC),
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: StatusBadge(status: inspection.status)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildInfoRow('Container No', inspection.containerNumber),
                  const Divider(height: 1),
                  _buildInfoRow('Booking No', inspection.bookingNumber),
                  const Divider(height: 1),
                  _buildInfoRow('Truck No', inspection.truckNumber),
                  const Divider(height: 1),
                  _buildInfoRow('Worker', inspection.workerName),
                  const Divider(height: 1),
                  _buildInfoRow('Port', inspection.portName),
                  const Divider(height: 1),
                  _buildInfoRow('Date', inspection.formattedDate),
                  if (inspection.notes.isNotEmpty) ...[
                    const Divider(height: 1),
                    _buildInfoRow('Notes', inspection.notes),
                  ],
                ],
              ),
            ),
          ),
          if (urls.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Photos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              itemCount: urls.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemBuilder: (context, index) {
                return _PhotoCell(
                  url: urls[index],
                  label: labels[index],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF667085),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoCell extends StatelessWidget {
  final String url;
  final String label;

  const _PhotoCell({
    required this.url,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => _FullscreenImageDialog(url: url),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return Container(
                    color: const Color(0xFFE8EDF5),
                    child: const Icon(
                      Icons.broken_image_rounded,
                      color: Color(0xFF667085),
                    ),
                  );
                },
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  color: Colors.black54,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 7,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FullscreenImageDialog extends StatelessWidget {
  final String url;

  const _FullscreenImageDialog({required this.url});

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 5,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) {
                  return const Icon(
                    Icons.broken_image_rounded,
                    color: Colors.white70,
                    size: 56,
                  );
                },
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: AppBar(
              automaticallyImplyLeading: false,
              backgroundColor: Colors.black54,
              actions: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
