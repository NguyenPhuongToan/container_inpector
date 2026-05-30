enum InspectionStatus {
  draft,
  submitted,
  accepted,
  rejected,
}

class ContainerInspection {
  final String id;
  final String containerNumber;
  final String bookingNumber;
  final String truckNumber;
  final String workerName;
  final String portName;
  final String notes;
  final InspectionStatus status;
  final DateTime createdAt;
  final List<String> imageUrls;

  const ContainerInspection({
    required this.id,
    required this.containerNumber,
    required this.bookingNumber,
    required this.truckNumber,
    required this.workerName,
    required this.portName,
    required this.notes,
    required this.status,
    required this.createdAt,
    required this.imageUrls,
  });

  factory ContainerInspection.fromJson(Map<String, dynamic> json) {
    return ContainerInspection(
      id: json['id']?.toString() ?? '',
      containerNumber: json['container_number']?.toString() ?? '',
      bookingNumber: json['booking_number']?.toString() ?? '',
      truckNumber: json['truck_number']?.toString() ?? '',
      workerName: json['worker_name']?.toString() ?? '',
      portName: json['port_name']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      status: InspectionStatus.values.firstWhere(
        (status) => status.name == json['status']?.toString().toLowerCase(),
        orElse: () => InspectionStatus.submitted,
      ),
      createdAt: DateTime.tryParse(
            json['created_at']?.toString() ?? '',
          ) ??
          DateTime.now(),
      imageUrls: List<String>.from(json['image_urls'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'container_number': containerNumber,
      'booking_number': bookingNumber,
      'truck_number': truckNumber,
      'worker_name': workerName,
      'port_name': portName,
      'notes': notes,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'image_urls': imageUrls,
    };
  }

  String get formattedDate {
    final day = createdAt.day.toString().padLeft(2, '0');
    final month = createdAt.month.toString().padLeft(2, '0');
    return '$day/$month/${createdAt.year}';
  }

  String? get thumbnail => imageUrls.isNotEmpty ? imageUrls.first : null;

  int get photoCount => imageUrls.length;
}
