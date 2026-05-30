import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/image_slot.dart';
import '../../widgets/camera_card.dart';

class CameraGrid extends StatefulWidget {
  const CameraGrid({super.key});

  @override
  State<CameraGrid> createState() => _CameraGridState();
}

class _CameraGridState extends State<CameraGrid> {
  final ImagePicker picker = ImagePicker();

  late List<ImageSlot> slots;
  int currentTab = 0;

  @override
  void initState() {
    super.initState();

    final List<String> titles = [
      "Front",
      "Rear",
      "Left Side",
      "Right Side",
      "Front Left",
      "Front Right",
      "Rear Left",
      "Rear Right",
      "Ceiling",
      "Floor",
      "Door",
      "Lock",
      "CSC Plate",
      "Container Number",
    ];

    slots = List.generate(
      14,
      (index) => ImageSlot(
        angle: index + 1,
        title: titles[index],
      ),
    );
  }

  Future<void> captureImage(int index) async {
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );

    if (pickedFile == null) return;

    setState(() {
      slots[index].image = pickedFile;
    });
  }

  @override
  Widget build(BuildContext context) {
    final int completed = slots.where((slot) => slot.isCaptured).length;
    final double progress = completed / slots.length;

    return Scaffold(
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const _InspectionHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(26, 28, 26, 24),
                children: [
                  _ProgressCard(
                    completed: completed,
                    total: slots.length,
                    progress: progress,
                  ),
                  const SizedBox(height: 32),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final int columns = constraints.maxWidth >= 720 ? 4 : 2;

                      return GridView.builder(
                        itemCount: slots.length,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 26,
                          mainAxisSpacing: 30,
                          childAspectRatio: 0.76,
                        ),
                        itemBuilder: (context, index) {
                          return CameraCard(
                            slot: slots[index],
                            onTap: () => captureImage(index),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                  _SubmitButton(
                    enabled: completed == slots.length,
                    onPressed: () {
                      debugPrint("Ready to submit");
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentTab,
        onDestinationSelected: (index) {
          setState(() {
            currentTab = index;
          });
        },
        backgroundColor: Colors.white,
        indicatorColor: Colors.transparent,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.photo_camera_outlined),
            selectedIcon: Icon(Icons.photo_camera),
            label: 'Inspection',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _InspectionHeader extends StatelessWidget {
  const _InspectionHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 194,
      padding: const EdgeInsets.fromLTRB(32, 52, 32, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF075DCC),
            Color(0xFF0056D6),
          ],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.menu_rounded),
            color: Colors.white,
            iconSize: 34,
          ),
          const SizedBox(width: 24),
          const Expanded(
            child: Text(
              'Container Inspection',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.assignment_outlined),
            color: Colors.white,
            iconSize: 34,
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final int completed;
  final int total;
  final double progress;

  const _ProgressCard({
    required this.completed,
    required this.total,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF075DCC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 20),
              const Expanded(
                child: Text(
                  'Inspection Progress',
                  style: TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$completed / $total',
                      style: const TextStyle(
                        color: Color(0xFF075DCC),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const TextSpan(text: ' Captured'),
                  ],
                ),
                style: const TextStyle(
                  color: Color(0xFF4D4D4D),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 16,
              backgroundColor: const Color(0xFFE1E6ED),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF1FB337),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;

  const _SubmitButton({
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: enabled
              ? const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFF075DCC),
                    Color(0xFF0056D6),
                  ],
                )
              : const LinearGradient(
                  colors: [
                    Color(0xFF9BA8B5),
                    Color(0xFF8794A1),
                  ],
                ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF075DCC).withValues(alpha: 0.20),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: enabled ? onPressed : null,
          icon: const Icon(Icons.cloud_upload_outlined, size: 31),
          label: const Text(
            'Submit Inspection',
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w800,
            ),
          ),
          style: ElevatedButton.styleFrom(
            elevation: 0,
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white,
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}
