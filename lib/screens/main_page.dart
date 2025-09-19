import 'package:senior_project/screens/glossary_screen.dart';
import 'package:senior_project/screens/login_screen.dart';
import 'package:senior_project/screens/symbols_screen.dart';

import 'package:flutter/material.dart';
import 'package:scribble/scribble.dart';
import 'package:flutter/rendering.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:tflite_flutter/tflite_flutter.dart';

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
  final Uint8List thumbnail;   // what user drew
  final int? prediction;       // model’s result
  final Uint8List processed;   // what the model actually sees (28x28)

  SymbolData({
    required this.thumbnail,
    required this.processed,
    this.prediction,
  });

  SymbolData copyWith({int? prediction}) {
    return SymbolData(
      thumbnail: thumbnail,
      processed: processed,
      prediction: prediction ?? this.prediction,
    );
  }
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

  Future<void> _saveDrawings() async {
    try {
      RenderRepaintBoundary boundary =
          _repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 1.0);

      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      Uint8List pngBytes = byteData.buffer.asUint8List();

      // Preprocess
      final normalized = await _preprocessImage(pngBytes);
      final processedBytes = await _gridToImage(normalized);
      final prediction = await _runModel(normalized);

      setState(() {
        savedSymbols.add(
          SymbolData(
            thumbnail: pngBytes,
            processed: processedBytes,
            prediction: prediction,
          ),
        );
      });

      debugPrint("Saved drawing #${savedSymbols.length}, prediction $prediction");
    } catch (e) {
      debugPrint("Error saving drawing: $e");
    }
  }

  Future<List<List<double>>> _preprocessImage(Uint8List bytes) async {
  // 1. Resize to 28x28
  final codec =
      await ui.instantiateImageCodec(bytes, targetWidth: 28, targetHeight: 28);
  final frame = await codec.getNextFrame();
  final image = frame.image;

  // 2. Convert to grayscale
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (byteData == null) return List.generate(28, (_) => List.filled(28, 0.0));

  final data = byteData.buffer.asUint8List();
  final List<List<double>> normalized = List.generate(
    28,
    (y) => List.generate(
      28,
      (x) {
        final offset = (y * 28 + x) * 4;
        final r = data[offset];
        final g = data[offset + 1];
        final b = data[offset + 2];
        final a = data[offset + 3];

        // Grayscale with alpha applied
        final gray = (0.3 * r + 0.59 * g + 0.11 * b) * (a / 255.0);

        // Normalize to [0,1], invert so black=1, white=0
        return (255.0 - gray) / 255.0;
      },
    ),
  );

  return normalized;
}

  Future<int> _runModel(List<List<double>> normalized) async {
    // 1. Prepare input as 1x28x28x1 tensor
    var input = List.generate(
      1,
      (_) => List.generate(
        28,
        (y) => List.generate(28, (x) => [normalized[y][x]]),
      ),
    );

    // 2. Prepare output as 1x10
    var output = List.generate(1, (_) => List.filled(10, 0.0));

    // 3. Run inference
    _interpreter.run(input, output);

    // 4. Find prediction
    int prediction = output[0].indexOf(output[0].reduce((a, b) => a > b ? a : b));

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
                                Text(
                                  symbol.prediction != null
                                      ? "Prediction: ${symbol.prediction}"
                                      : "Predicting...",
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
                ElevatedButton(onPressed: _saveDrawings, child: const Text("Save Symbol")),
              ],
            ),
          ],
        ),
      ),
    );
  }
}