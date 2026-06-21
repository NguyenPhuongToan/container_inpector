import 'package:image_picker/image_picker.dart';

class ImageSlot {
  final int angle;
  final String title;

  /// Purely cosmetic position number shown on the card badge.
  /// Does NOT affect upload order, angle, or PPTX export — display only.
  final int displayNumber;

  XFile? image;

  ImageSlot({
    required this.angle,
    required this.title,
    int? displayNumber,
    this.image,
  }) : displayNumber = displayNumber ?? angle;

  bool get isCaptured => image != null;
}
