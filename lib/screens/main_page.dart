import 'package:flutter/material.dart';
import 'package:senior_project/screens/glossary_screen.dart';
import 'package:senior_project/screens/login_screen.dart';
import 'package:senior_project/screens/symbols_screen.dart';

import 'package:scribble/scribble.dart';
import 'package:flutter/rendering.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;

/////// MODEL TRY OUT STUFF
import 'package:tflite_flutter/tflite_flutter.dart';
///////

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class PredictionResult {
  final Uint8List imageBytes;
  final int? prediction; // null until ready

  PredictionResult({required this.imageBytes, this.prediction});
}


class _MainPageState extends State<MainPage> with SingleTickerProviderStateMixin {
  
  late AnimationController _animationController;
  bool isMenuOpen = false;
  final ScribbleNotifier _notifier = ScribbleNotifier();
  
  final GlobalKey _repaintKey = GlobalKey();
  

  // Store all saved drawings here
  List<Uint8List> savedImages = [];

  /////// MODEL TRY OUT STUFF /////////////////////////////
  // Stores the predictions for each saved drawing
  List<PredictionResult> results = [];

  // Interpreter reference
  late Interpreter _interpreter;

  @override
  void initState() {
    super.initState();
    _loadModel();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _notifier.setStrokeWidth(10); // make the pen thicker
    _notifier.setColor(Colors.black); // default color
  }

  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/mnist.tflite');
      debugPrint("MNIST model loaded!");
    } catch (e) {
      debugPrint("Error loading model: $e");
    }
  }

  Future<void> _runModel(List<List<double>> normalized, int index) async {
    var input = List.generate(1, (_) =>
        List.generate(28, (y) =>
          List.generate(28, (x) => [normalized[y][x].toDouble()])));

    var output = List.generate(1, (_) => List.filled(10, 0.0));

    // TESTING MODEL INPUT
    for (int y = 0; y < 28; y++) {
      debugPrint(input[0][y].map((e) => e[0].toStringAsFixed(2)).join(" "));
    }
    /////////////////////////
    
    _interpreter.run(input, output);

    int prediction = output[0].indexOf(
      output[0].reduce((a, b) => a > b ? a : b),
    );

    debugPrint("Predicted digit: $prediction");

    setState(() {
      results[index] = PredictionResult(
        imageBytes: results[index].imageBytes,
        prediction: prediction,
      );
    });
  }

  Future<List<List<double>>> _preprocessImage(Uint8List bytes) async {
  // 1. Decode full drawing to a large image
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;

  // 2. Extract RGBA bytes
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (byteData == null) return List.generate(28, (_) => List.filled(28, 0.0));
  final data = byteData.buffer.asUint8List();

  final w = image.width;
  final h = image.height;

  // 3. Compute bounding box of non-white pixels
  int minX = w, minY = h, maxX = 0, maxY = 0;
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final offset = (y * w + x) * 4;
      final r = data[offset];
      final g = data[offset + 1];
      final b = data[offset + 2];
      final a = data[offset + 3];
      final gray = (0.3 * r + 0.59 * g + 0.11 * b) * (a / 255.0);

      if (gray < 250) { // not pure white
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }
  }

  // Handle empty drawings
  if (minX > maxX || minY > maxY) {
    return List.generate(28, (_) => List.filled(28, 0.0));
  }

  final cropW = maxX - minX + 1;
  final cropH = maxY - minY + 1;

  // 4. Crop + scale to fit inside 20x20 box (like MNIST preprocessing)
  final scale = 20.0 / (cropW > cropH ? cropW : cropH);
  final newW = (cropW * scale).round();
  final newH = (cropH * scale).round();

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawColor(Colors.white, BlendMode.src);

  final src = Rect.fromLTWH(minX.toDouble(), minY.toDouble(), cropW.toDouble(), cropH.toDouble());
  final dst = Rect.fromLTWH(0, 0, newW.toDouble(), newH.toDouble());
  canvas.drawImageRect(image, src, dst, Paint());

  final cropped = await recorder.endRecording().toImage(newW, newH);

  // 5. Paste into center of 28x28 canvas
  final recorder2 = ui.PictureRecorder();
  final canvas2 = Canvas(recorder2);
  canvas2.drawColor(Colors.white, BlendMode.src);

  final dx = ((28 - newW) / 2).floorToDouble();
  final dy = ((28 - newH) / 2).floorToDouble();
  canvas2.drawImage(cropped, Offset(dx, dy), Paint());

  final finalImg = await recorder2.endRecording().toImage(28, 28);

  // 6. Extract grayscale normalized pixels
  final bd = await finalImg.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (bd == null) return List.generate(28, (_) => List.filled(28, 0.0));
  final arr = bd.buffer.asUint8List();

  final normalized = List.generate(
    28,
    (y) => List.generate(
      28,
      (x) {
        final off = (y * 28 + x) * 4;
        final r = arr[off];
        final g = arr[off + 1];
        final b = arr[off + 2];
        final a = arr[off + 3];
        
        double gray = ((0.3 * r + 0.59 * g + 0.11 * b) * (a / 255.0)) / 255.0;
        return gray - 1;
      },
    ),
  );

  return normalized;
}



  //////////////////////////////////////////////////////

  Future<void> _saveDrawings() async {
    try {
      // 1. Capture the Scribble widget as ainputn image
      RenderRepaintBoundary boundary =
          _repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 1.0);

      // 2. Convert to bytes
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      Uint8List pngBytes = byteData.buffer.asUint8List();

      // 3. Save the raw bytes for thumbnails
      setState(() {
        savedImages.add(pngBytes);
        results.add(PredictionResult(imageBytes: pngBytes));
      });

      debugPrint("Saved drawing #${savedImages.length}");

      // 4. Preprocess image for model
      final normalized = await _preprocessImage(pngBytes);

      // 5. Run model prediction
      await _runModel(normalized, results.length - 1);

    } catch (e) {
      debugPrint("Error saving drawing: $e");
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  void _toggleMenu() {
    if (isMenuOpen) {
      _animationController.reverse();
      Scaffold.of(context).openDrawer();
    } else {
      _animationController.forward();
      Scaffold.of(context).openDrawer();
    }
    setState(() {
      isMenuOpen = !isMenuOpen;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[500],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Hello user',
          style: TextStyle(color: Colors.black),
        ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _animationController.value * 0.5 * 3.141592653589793,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 2,
                        width: 20,
                        color: Colors.black,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 2,
                        width: 15,
                        color: Colors.black,
                      ),
                    ],
                  ),
                );
              },
            ),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: Drawer(
        backgroundColor: Colors.black,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Your Media',
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.book, color: Colors.white),
              title: const Text('Glossary', style: TextStyle(color: Colors.white)),
              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const GlossaryScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.star, color: Colors.white),
              title: const Text('Symbols', style: TextStyle(color: Colors.white)),
              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SymbolsScreen()),
                );
              },
            ),
            const Spacer(),
            const Divider(color: Colors.white),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.white),
              title: const Text('Logout', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 15.0),
        child: Row(
          children: [
            Expanded(
              child: Material(
                elevation: 4,
                child: Column(
                  children: [
                  // Toolbar (Undo + Clear + Save)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.undo),
                          onPressed: () => _notifier.undo(),
                        ),
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => _notifier.clear(),
                        ),
                        IconButton(
                          icon: const Icon(Icons.save),
                          onPressed: _saveDrawings,
                        ),
                      ],
                    ),
                  ),
                  // Drawing Area
                  Expanded(
                    child: RepaintBoundary(
                      key: _repaintKey,
                      child: Container(
                        color: Colors.white,
                        child: Scribble(
                          notifier: _notifier,
                          drawPen: true,
                          
                        ),
                      ),
                    ),
                  ),
                ],
                ),
              ),
            ),
            const VerticalDivider(width: 1, color: Colors.grey),
            Expanded(
              child: Material(
                elevation: 4,
                child: Container(
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          "Model Predictions",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: results.length,
                          itemBuilder: (context, index) {
                            final item = results[index];
                            return ListTile(
                              leading: Image.memory(item.imageBytes, width: 40, height: 40),
                              title: Text(
                                item.prediction != null
                                    ? "Prediction: ${item.prediction}"
                                    : "Predicting...",
                              ),
                            );
                          },
                        ),
                      ),
                    ],
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
