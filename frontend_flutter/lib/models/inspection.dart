enum InspectionStatus {
  draft,
  submitted,
  accepted,
  rejected,
}

class InspectionImage {
  final int angle;
  final String label;
  final String url;

  const InspectionImage({
    required this.angle,
    required this.label,
    required this.url,
  });

  factory InspectionImage.fromJson(Map<String, dynamic> json) {
    return InspectionImage(
      angle: int.tryParse(json['angle']?.toString() ?? '') ?? 0,
      label: json['label']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'angle': angle,
      'label': label,
      'url': url,
    };
  }
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
  final DateTime updatedAt;
  final List<String> imageUrls;
  final List<InspectionImage> images;

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
    required this.updatedAt,
    required this.imageUrls,
    required this.images,
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
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
      imageUrls: (json['image_urls'] as List? ?? [])
          .map((item) => item.toString())
          .toList(),
      images: (json['images'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(InspectionImage.fromJson)
          .toList(),
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
      'updated_at': updatedAt.toIso8601String(),
      'image_urls': imageUrls,
      'images': images.map((image) => image.toJson()).toList(),
    };
  }

  String get formattedDate {
    final day = createdAt.day.toString().padLeft(2, '0');
    final month = createdAt.month.toString().padLeft(2, '0');
    return '$day/$month/${createdAt.year}';
  }

  int get photoCount => images.isNotEmpty ? images.length : imageUrls.length;

  String? get thumbnail {
    if (images.isNotEmpty) return images.first.url;
    if (imageUrls.isNotEmpty) return imageUrls.first;
    return null;
  }
}
