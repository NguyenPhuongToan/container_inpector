import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/image_slot.dart';

class CameraCard extends StatefulWidget {
  final ImageSlot slot;
  final VoidCallback onTap;

  const CameraCard({
    super.key,
    required this.slot,
    required this.onTap,
  });

  @override
  State<CameraCard> createState() => _CameraCardState();
}

class _CameraCardState extends State<CameraCard> {
  Uint8List? _cachedBytes;
  String? _cachedPath;

  Future<Uint8List?> _getBytes() async {
    final image = widget.slot.image;
    if (image == null) return null;
    if (_cachedPath == image.path && _cachedBytes != null) return _cachedBytes;
    final bytes = await image.readAsBytes();
    _cachedPath = image.path;
    _cachedBytes = bytes;
    return bytes;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      elevation: 5,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: SizedBox.expand(
                    child: widget.slot.image != null
                        ? FutureBuilder<Uint8List?>(
                            future: _getBytes(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              return Image.memory(
                                snapshot.data!,
                                fit: BoxFit.cover,
                                cacheWidth: 200,
                              );
                            },
                          )
                        : _EmptyImagePreview(slot: widget.slot),
                  ),
                ),
                Container(
                  height: 46,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  color: Colors.white,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.slot.title,
                      maxLines: 1,
                      style: const TextStyle(
                        color: Color(0xFF111111),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFF075DCC),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: Text(
                  '${widget.slot.angle}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            if (widget.slot.isCaptured)
              const Positioned(
                top: 8,
                right: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFF2DBB27),
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 22,
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

class _EmptyImagePreview extends StatelessWidget {
  final ImageSlot slot;

  const _EmptyImagePreview({required this.slot});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFE7EDF4),
            Color(0xFFC9D3DE),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: Alignment.center,
            child: Icon(
              _iconForSlot(slot.title),
              color: const Color(0xFF6F7C89),
              size: 44,
            ),
          ),
          const Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: Icon(
              Icons.add_a_photo_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForSlot(String title) {
    return Icons.inventory_2_rounded;
  }
}
