import 'dart:io';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

class ImageLabelService {
  final ImageLabeler _labeler = ImageLabeler(
    options: ImageLabelerOptions(confidenceThreshold: 0.7),
  );

  Future<List<String>> labelImage(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final labels = await _labeler.processImage(inputImage);

      return labels.map((label) => label.label).toList();
    } catch (e) {
      print('Image labeling failed: $e');
      return ['Uncategorized'];
    }
  }

  void dispose() {
    _labeler.close();
  }
}
