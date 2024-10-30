import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite/tflite.dart';
import 'dart:async';
import 'dart:io';

class CameraWidget extends StatefulWidget {
  const CameraWidget({Key? key}) : super(key: key);

  @override
  _CameraWidgetState createState() => _CameraWidgetState();
}

class _CameraWidgetState extends State<CameraWidget> {
  late ImagePicker _imagePicker;
  XFile? _pickedImage;
  List<dynamic>? _recognitions; // Recognitions for the model
  bool _isLoading = false;
  double _imageWidth = 0;
  double _imageHeight = 0;

  @override
  void initState() {
    super.initState();
    _imagePicker = ImagePicker();
    _initializeTflite();
  }

  Future<void> _initializeTflite() async {
    // Load the model and labels
    await Tflite.loadModel(
      model: "assets/model/myModel.tflite",
      labels: "assets/model/labels.txt",
    );
  }

  Future<void> _pickImageFromGallery() async {
    final XFile? pickedFile =
        await _imagePicker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _pickedImage = pickedFile;
        _recognitions = null; // Clear previous recognitions
        _isLoading = true;
      });
      await _processImage();
    }
  }

  Future<void> _captureImage() async {
    final XFile? pickedFile =
        await _imagePicker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      setState(() {
        _pickedImage = pickedFile;
        _recognitions = null; // Clear previous recognitions
        _isLoading = true;
      });
      await _processImage();
    }
  }

  Future<void> _processImage() async {
    if (_pickedImage != null) {
      final File imageFile = File(_pickedImage!.path);
      var decodedImage = await decodeImageFromList(imageFile.readAsBytesSync());

      setState(() {
        _imageWidth = decodedImage.width.toDouble();
        _imageHeight = decodedImage.height.toDouble();
      });

      final List<dynamic>? recognitions = await Tflite.detectObjectOnImage(
        path: _pickedImage!.path,
        model: "YOLO",
        numResultsPerClass: 1,
        threshold: 0.5, // Confidence threshold
      );

      // Update the recognitions
      setState(() {
        _recognitions = recognitions;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan/Upload Seeds Here"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const SizedBox(height: 20),
            if (!_isLoading && _pickedImage != null)
              Stack(
                children: [
                  Image.file(
                    File(_pickedImage!.path),
                    width: 300,
                    height: 300,
                    fit: BoxFit.cover,
                  ),
                  if (_recognitions != null)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: RecognitionPainter(
                          _recognitions!,
                          _imageWidth,
                          _imageHeight,
                          300,
                          300,
                        ),
                      ),
                    ),
                ],
              )
            else if (_isLoading)
              const Center(
                child: CircularProgressIndicator(),
              )
            else
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black),
                ),
              ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _pickImageFromGallery,
              icon: const Icon(Icons.photo),
              label: const Text(
                "Select from Gallery",
                style: TextStyle(color: Colors.black),
              ),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(Colors.white),
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _captureImage,
              icon: const Icon(Icons.camera_alt),
              label: const Text(
                "Take Photo",
                style: TextStyle(color: Colors.black),
              ),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(Colors.white),
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Dispose TFLite resources
    Tflite.close();
    super.dispose();
  }
}

// Custom painter to draw bounding boxes around recognized objects
class RecognitionPainter extends CustomPainter {
  final List<dynamic> recognitions;
  final double imageWidth;
  final double imageHeight;
  final double displayWidth;
  final double displayHeight;

  RecognitionPainter(
      this.recognitions, this.imageWidth, this.imageHeight, this.displayWidth, this.displayHeight);

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = displayWidth / imageWidth;
    final double scaleY = displayHeight / imageHeight;

    for (var recognition in recognitions) {
      final box = recognition['rect'];
      final double x = box['x'] * scaleX;
      final double y = box['y'] * scaleY;
      final double w = box['w'] * scaleX;
      final double h = box['h'] * scaleY;

      final rect = Rect.fromLTWH(x, y, w, h);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.red;

      final labelPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.red.withOpacity(0.5);

      canvas.drawRect(rect, paint);
      canvas.drawRect(Rect.fromLTWH(x, y - 20, w, 20), labelPaint);

      final textStyle = TextStyle(
        color: Colors.white,
        fontSize: 14,
      );

      final textSpan = TextSpan(
        text:
            "${recognition['detectedClass']} ${(recognition['confidenceInClass'] * 100).toStringAsFixed(0)}%",
        style: textStyle,
      );

      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr,
      );

      textPainter.layout(minWidth: 0, maxWidth: w);
      textPainter.paint(canvas, Offset(x, y - 20));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

void main() {
  runApp(const MaterialApp(
    home: CameraWidget(),
  ));
}
