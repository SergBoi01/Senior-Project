import 'package:senior_project/screens/glossary_screen.dart';
import 'package:senior_project/screens/login_screen.dart';
import 'package:senior_project/screens/symbols_screen.dart';

import 'package:flutter/material.dart';
import 'package:scribble/scribble.dart';
import 'package:flutter/rendering.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class InputPreview extends StatelessWidget {
  final List<List<double>> grid;

  const InputPreview({super.key, required this.grid});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140, // scale it up for visibility
      height: 140,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 28,
        ),
        itemCount: 28 * 28,
        itemBuilder: (context, index) {
          final y = index ~/ 28;
          final x = index % 28;
          final v = grid[y][x];
          return Container(
            color: Color.lerp(
              Colors.white,
              Colors.black,
              v, // 0 → white, 1 → black
            ),
          );
        },
      ),
    );
  }
}

class SymbolData {
  final Uint8List thumbnail;  // small preview
  final Uint8List processed;  // 28x28 normalized image as bytes
  int? prediction;

  SymbolData({
    required this.thumbnail,
    required this.processed,
    this.prediction,
  });
}

class PredictionResult {
  final Uint8List imageBytes;
  final int? prediction; // null until ready

  PredictionResult({required this.imageBytes, this.prediction});
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with SingleTickerProviderStateMixin {
  
  late AnimationController _animationController;
  bool isMenuOpen = false;
  final ScribbleNotifier _notifier = ScribbleNotifier();
  final GlobalKey _repaintKey = GlobalKey();
  // Store all saved drawings here
  List<SymbolData> savedSymbols = [];
  // Stores the predictions for each saved drawing
  List<PredictionResult> results = [];
  // Interpreter reference
  late Interpreter _interpreter;
  List<List<double>>? lastInputGrid;

  @override
  void initState() {
    super.initState();
    _loadModel();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _notifier.setStrokeWidth(20); // make the pen thicker
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

  img.Image _normalizedToImage(List<List<double>> normalized) {
    img.Image image = img.Image(width: 28, height: 28);
    for (int y = 0; y < 28; y++) {
      for (int x = 0; x < 28; x++) {
        int value = (normalized[y][x] * 255).toInt();
        image.setPixelRgba( x, y, value, value, value, 255);
      }
    }
    return image;
  }

  Future<void> _saveAndPredict() async {
    try {
      // Capture canvas as image
      RenderRepaintBoundary boundary =
          _repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image captured = await boundary.toImage(pixelRatio: 1.0);
      ByteData? byteData =
          await captured.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      Uint8List pngBytes = byteData.buffer.asUint8List();

      // Preprocess to 28x28 and get normalized data
      final normalized = await _preprocessImage(pngBytes);

      // Convert 28x28 back to PNG for display
      img.Image processedImage = _normalizedToImage(normalized);
      Uint8List processedBytes = Uint8List.fromList(img.encodePng(processedImage));

      // Add new symbol placeholder
      int index = savedSymbols.length;
      savedSymbols.add(SymbolData(
        thumbnail: pngBytes,
        processed: processedBytes,
      ));
      setState(() {});

      // Run model on normalized data
      int prediction = await _runModel(normalized);
      setState(() {
        savedSymbols[index].prediction = prediction;
      });

      debugPrint("Saved drawing #${savedSymbols.length}, prediction $prediction");

    } catch (e) {
      debugPrint("Error saving and predicting: $e");
    }
  }

  Future<List<List<double>>> _preprocessImage(Uint8List pngBytes) async {
    // Decode PNG bytes to an image
    img.Image? original = img.decodeImage(pngBytes);
    if (original == null) return List.generate(28, (_) => List.filled(28, 0.0));

    // Convert to grayscale for easier processing
    img.Image gray = img.grayscale(original);

    // 1. Find bounding box of non-black pixels
    int minX = gray.width, minY = gray.height;
    int maxX = 0, maxY = 0;

    for (int y = 0; y < gray.height; y++) {
      for (int x = 0; x < gray.width; x++) {
        // Get pixel using getPixel method which returns a Color
        img.Color pixelColor = gray.getPixel(x, y);
        // Get luminance from the color
        num luminance = img.getLuminance(pixelColor);
        
        if (luminance > 0) { // Non-black
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }

    // If nothing drawn, return empty 28x28
    if (minX > maxX || minY > maxY) {
      return List.generate(28, (_) => List.filled(28, 0.0));
    }

    // 2. Crop the bounding box
    img.Image cropped = img.copyCrop(gray, 
      x: minX, 
      y: minY, 
      width: maxX - minX + 1, 
      height: maxY - minY + 1
    );

    // 3. Resize cropped image to 20x20
    img.Image resized = img.copyResize(cropped, width: 20, height: 20);

    // 4. Create 28x28 black canvas
    img.Image canvas28 = img.Image(width: 28, height: 28);
    // Fill with black color
    img.fill(canvas28, color: img.ColorRgb8(0, 0, 0));

    // Calculate center position
    int offsetX = ((28 - resized.width) / 2).floor();
    int offsetY = ((28 - resized.height) / 2).floor();
    
    // Copy resized image into center of canvas
    img.compositeImage(canvas28, resized, dstX: offsetX, dstY: offsetY);

    // 5. Normalize to 0..1 (white foreground)
    List<List<double>> normalized = List.generate(
      28,
      (y) => List.generate(28, (x) {
        // Get pixel color
        img.Color pixelColor = canvas28.getPixel(x, y);
        // Get luminance and normalize
        num luminance = img.getLuminance(pixelColor);
        return luminance / 255.0; // 0..1
      }),
    );

    return normalized;
  }

  Future<int> _runModel(List<List<double>> normalized) async {
    var input = List.generate(1, (_) =>
        List.generate(28, (y) =>
          List.generate(28, (x) => [normalized[y][x]])));

    var output = List.generate(1, (_) => List.filled(10, 0.0));

    _interpreter.run(input, output);

    int prediction = output[0].indexOf(
      output[0].reduce((a, b) => a > b ? a : b),
    );
    debugPrint("Predicted digit: $prediction");
    return prediction;
  }

  Future<Uint8List> _gridToImage(List<List<double>> grid) async {
    const size = 28;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();

    // Black background
    paint.color = Colors.black;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()), paint);

    // Draw each pixel (white intensity = value in grid[y][x])
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        double v = grid[y][x];
        paint.color = Color.fromARGB(255, (v * 255).toInt(), (v * 255).toInt(), (v * 255).toInt());
        canvas.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1), paint);
      }
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(size, size);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
  
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

  void _clearCanvas() {
    _notifier.clear();
  }

  void _undo() {
    _notifier.undo();
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
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  // LEFT: Canvas
                  Expanded(
                    child: RepaintBoundary(
                      key: _repaintKey,
                      child: Container(
                        color: Colors.white,
                        child: Scribble(notifier: _notifier),
                      ),
                    ),
                  ),

                  const VerticalDivider(width: 1),

                  // RIGHT: Predictions list
                  Expanded(
                    child: ListView.builder(
                      itemCount: savedSymbols.length,
                      itemBuilder: (context, index) {
                        final symbol = savedSymbols[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                Column(
                                  children: [
                                    Image.memory(symbol.thumbnail, width: 40, height: 40),
                                    const SizedBox(height: 4),
                                    Image.memory(symbol.processed, width: 40, height: 40),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    symbol.prediction != null
                                        ? "Prediction: ${symbol.prediction}"
                                        : "Predicting...",
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                ],
              ),
            ),

            // Bottom controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(onPressed: _undo, child: const Text("Undo")),
                ElevatedButton(onPressed: _clearCanvas, child: const Text("Clear")),
                ElevatedButton(onPressed: _saveAndPredict, child: const Text("Save Symbol")),
              ],
            ),
          ],
        ),
      ),
    );
  }
}