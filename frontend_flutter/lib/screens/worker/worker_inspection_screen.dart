import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/image_slot.dart';
import '../../services/api_service.dart';
import '../../services/auth_session.dart';
import '../../widgets/camera_card.dart';
import 'worker_history_screen.dart';

class WorkerInspectionScreen extends StatefulWidget {
  const WorkerInspectionScreen({super.key});

  @override
  State<WorkerInspectionScreen> createState() => _WorkerInspectionScreenState();
}

class _WorkerInspectionScreenState extends State<WorkerInspectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
  final _picker = ImagePicker();

  final _containerNumberController = TextEditingController();
  final _flexitankNumberController = TextEditingController();
  final _bookingNumberController = TextEditingController();
  final _truckNumberController = TextEditingController();
  final _workerNameController = TextEditingController();
  final _portNameController = TextEditingController();
  final _notesController = TextEditingController();

  late final List<ImageSlot> slots;
  late final List<int> displayIndexOrder;
  bool isSubmitting = false;

  int get _addedPhotoCount => slots.where((slot) => slot.isCaptured).length;

  @override
  void initState() {
    super.initState();

    // IMPORTANT: this list order is what gets uploaded to the backend and
    // directly determines each photo's angle + position in the PPTX export.
    // DO NOT reorder this list — it must stay exactly as-is.
    final titles = [
      'Số serial container',
      'Ảnh sau khi lắp đặt',
      'Thông tin hàng hóa',
      'Số serial flexitank',
      'Ảnh lắp đặt bao (nhìn từ bên ngoài)',
      'Ảnh lắp đặt bao (nhìn từ bên trong)',
      'Sàn rìa trái',
      'Sàn rìa phải',
      'Cạnh trái container (bên ngoài)',
      'Cạnh phải container (bên ngoài)',
      'Ảnh sàn container',
      'Ảnh tổng thể container',
    ];

    slots = List.generate(
      titles.length,
      (index) => ImageSlot(
        angle: index + 1,
        title: titles[index],
      ),
    );

    // On-screen display order ONLY (grid rendering). Refers to slots above
    // by their original index (0-based), so upload order stays untouched.
    // Maps to original photo numbers: 9,10,11,12,7,8,4,5,6,3,2,1
    displayIndexOrder = const [8, 9, 10, 11, 6, 7, 3, 4, 5, 2, 1, 0];

    final fullName = AuthSession.user?.fullName ?? '';
    if (fullName.isNotEmpty) {
      _workerNameController.text = fullName;
    }
  }

  @override
  void dispose() {
    _containerNumberController.dispose();
    _flexitankNumberController.dispose();
    _bookingNumberController.dispose();
    _truckNumberController.dispose();
    _workerNameController.dispose();
    _portNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> captureImage(int index) async {
    if (slots[index].isCaptured) {
      final shouldReplace = await _confirmImageReplacement(slots[index].title);
      if (!shouldReplace) return;
    }

    final pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 60,
        maxWidth: 2048,
        maxHeight: 2048);

    if (pickedFile == null) return;

    setState(() {
      slots[index].image = pickedFile;
    });

    if (slots[index].title == 'Số serial container' &&
        slots[index].image != null) {
      await _performContainerScan(slots[index].image!);
    }

    if (slots[index].title == 'Số serial flexitank' &&
        slots[index].image != null) {
      await _performFlexitankScan(slots[index].image!);
    }
  }

  Future<bool> _confirmImageReplacement(String title) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Thay ảnh hiện tại?'),
          content: Text(
            'Thao tác này sẽ thay thế ảnh hiện tại của $title.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Thay thế'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<void> _performContainerScan(XFile imageFile) async {
    _showMessage('Scanning container number...');

    try {
      final scannedId = await _apiService.scanContainerId(imageFile);

      if (!mounted) return;

      setState(() {
        _containerNumberController.text = scannedId;
      });

      _showMessage('Đã nhận diện số container: $scannedId');
    } on TimeoutException {
      _showMessage('AI scan timed out. Please enter the number manually.');
    } catch (_) {
      _showMessage('AI could not read the number. Please enter it manually.');
    }
  }

  Future<void> _performFlexitankScan(XFile imageFile) async {
    _showMessage('Scanning flexitank serial...');

    try {
      final scannedId = await _apiService.scanFlexitankId(imageFile);

      if (!mounted) return;

      setState(() {
        _flexitankNumberController.text = scannedId;
      });

      _showMessage('Đã nhận diện số serial flexitank: $scannedId');
    } on TimeoutException {
      _showMessage('AI scan timed out. Please enter the serial manually.');
    } catch (_) {
      _showMessage('AI could not read the serial. Please enter it manually.');
    }
  }

  Future<void> submitInspection() async {
    if (_containerNumberController.text.trim().isEmpty) {
      _showMessage(
        'Container number is required',
        backgroundColor: const Color(0xFFE53935),
      );
      return;
    }

    final isFormValid = _formKey.currentState?.validate() ?? true;
    final images = slots
        .where((slot) => slot.image != null)
        .map((slot) => slot.image!)
        .toList();

    if (!isFormValid) {
      _showMessage('Vui lòng điền đầy đủ thông tin bắt buộc.');
      return;
    }
    if (images.length != slots.length) {
      _showMessage('Chụp đủ 12 ảnh. Hiện tại: ${images.length}/12.');
      return;
    }
    if (false) {
      _showMessage('Vui lòng điền đầy đủ thông tin và chụp đủ 12 ảnh.');
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      await _apiService.submitInspection(
        containerNumber: _containerNumberController.text.trim(),
        flexitankNumber: _flexitankNumberController.text.trim(),
        bookingNumber: _bookingNumberController.text.trim(),
        truckNumber: _truckNumberController.text.trim(),
        workerName: _workerNameController.text.trim(),
        portName: _portNameController.text.trim(),
        notes: _notesController.text.trim(),
        images: images,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã gửi phiếu kiểm tra thành công!'),
          backgroundColor: Color(0xFF437A22),
          duration: Duration(seconds: 2),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WorkerHistoryScreen()),
        (route) => route.isFirst,
      );
    } on TimeoutException {
      _showMessage('Upload timed out. Please try again.');
    } catch (_) {
      _showMessage('Không thể gửi. Vui lòng kiểm tra kết nối với backend.');
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  void _showMessage(String message, {Color? backgroundColor}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final completed = slots.where((slot) => slot.isCaptured).length;
    final progress = completed / slots.length;
    final canSubmit = completed == slots.length && !isSubmitting;

    return Scaffold(
      body: Column(
        children: [
          const _Header(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
              children: [
                _ProgressCard(
                  completed: completed,
                  total: slots.length,
                  progress: progress,
                ),
                const SizedBox(height: 10),
                Text(
                  '$_addedPhotoCount / 12 ảnh đã chụp',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _addedPhotoCount == 12
                        ? const Color(0xFF437A22)
                        : const Color(0xFF667085),
                  ),
                ),
                const SizedBox(height: 18),
                _ContainerInfoForm(
                  formKey: _formKey,
                  containerNumberController: _containerNumberController,
                  flexitankNumberController: _flexitankNumberController,
                  bookingNumberController: _bookingNumberController,
                  truckNumberController: _truckNumberController,
                  workerNameController: _workerNameController,
                  portNameController: _portNameController,
                  notesController: _notesController,
                ),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 720 ? 4 : 2;

                    return GridView.builder(
                      itemCount: displayIndexOrder.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 18,
                        mainAxisSpacing: 20,
                        childAspectRatio: 0.76,
                      ),
                      itemBuilder: (context, gridPosition) {
                        final slotIndex = displayIndexOrder[gridPosition];
                        return CameraCard(
                          slot: slots[slotIndex],
                          onTap: () => captureImage(slotIndex),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 58,
                  child: FilledButton.icon(
                    onPressed: canSubmit ? submitInspection : null,
                    icon: isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.cloud_upload_outlined),
                    label: Text(
                      isSubmitting ? 'Đang gửi...' : 'Gửi phiếu kiểm tra',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF075DCC),
            Color(0xFF0056D6),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 22, 18),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded),
                color: Colors.white,
              ),
              const Expanded(
                child: Text(
                  'Container Inspection',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Icon(
                Icons.assignment_outlined,
                color: Colors.white,
                size: 30,
              ),
            ],
          ),
        ),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                color: Color(0xFF075DCC),
                size: 32,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Inspection Progress',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '$completed / $total Captured',
                style: const TextStyle(
                  color: Color(0xFF075DCC),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
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

class _ContainerInfoForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController containerNumberController;
  final TextEditingController flexitankNumberController;
  final TextEditingController bookingNumberController;
  final TextEditingController truckNumberController;
  final TextEditingController workerNameController;
  final TextEditingController portNameController;
  final TextEditingController notesController;

  const _ContainerInfoForm({
    required this.formKey,
    required this.containerNumberController,
    required this.flexitankNumberController,
    required this.bookingNumberController,
    required this.truckNumberController,
    required this.workerNameController,
    required this.portNameController,
    required this.notesController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thông tin container',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),
            _InputField(
              controller: containerNumberController,
              label: 'Số container',
            ),
            _InputField(
              controller: flexitankNumberController,
              label: 'Số serial flexitank',
              required: false,
            ),
            _InputField(
              controller: bookingNumberController,
              label: 'Số booking',
              required: false,
            ),
            _InputField(
              controller: truckNumberController,
              label: 'Số xe',
            ),
            _InputField(
              controller: workerNameController,
              label: 'Tên nhân viên',
            ),
            _InputField(
              controller: portNameController,
              label: 'Cảng / Địa điểm',
            ),
            _InputField(
              controller: notesController,
              label: 'Ghi chú',
              required: false,
              maxLines: 3,
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool required;
  final int maxLines;
  final TextInputAction textInputAction;

  const _InputField({
    required this.controller,
    required this.label,
    this.required = true,
    this.maxLines = 1,
    this.textInputAction = TextInputAction.next,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        textInputAction: textInputAction,
        validator: (value) {
          if (!required) return null;
          if (value == null || value.trim().isEmpty) {
            return '$label is required';
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xFFF6F8FB),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
