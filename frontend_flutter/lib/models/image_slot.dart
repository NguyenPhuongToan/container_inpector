import 'package:image_picker/image_picker.dart';

class ImageSlot {
  final int angle;
  final String title;

  XFile? image;

  ImageSlot({
    required this.angle,
    required this.title,
    this.image,
  });

  bool get isCaptured => image != null;
}
