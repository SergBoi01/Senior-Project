import 'package:flutter/material.dart';
import 'package:senior_project/screens/glossary_screen.dart';
import 'package:senior_project/screens/login_screen.dart';
import 'package:senior_project/screens/symbols_screen.dart';

import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:scribble/scribble.dart';
import 'dart:typed_data';
import 'dart:async';
import 'dart:math' as math;


// Saves Label, ConfidenceScore, Coordinates, Thumbnail of Image
// Class to hold all information for each detected symbol
class DetectedSymbol {
  final String label;           // The symbol ("A", "l_z")
  final double confidence;      // Confidence score (0.0 to 1.0)
  final int x1, y1, x2, y2;    // Bounding box coordinates
  final Uint8List? thumbnail;   // Cropped image of the symbol

  DetectedSymbol({
    required this.label,
    required this.confidence,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    this.thumbnail,
  });

  // Helper to get bbox center
  double get centerX => (x1 + x2) / 2;
  double get centerY => (y1 + y2) / 2;
  
  // Helper to get bbox dimensions
  int get width => x2 - x1;
  int get height => y2 - y1;
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with SingleTickerProviderStateMixin {
  
  // Model constants
  static const int INPUT_SIZE = 128;
  static const int MAX_DETECTIONS = 20;
  static const int NUM_CLASSES = 52;
  // static const double CONFIDENCE_THRESHOLD = 0.3;
  static const double CONFIDENCE_THRESHOLD = 0.50;
  
  // Model Interpreter
  late Interpreter interpreter;

  // List that hold info for EACH symbol
  List<DetectedSymbol> detectedSymbols = [];

  // Lables list l_a - l_z and A - Z
  final List<String> labels = [
    ...List.generate(26, (i) => 'l_${String.fromCharCode(97 + i)}'), // l_a to l_z
    ...List.generate(26, (i) => String.fromCharCode(65 + i)),        // A to Z
  ];

  // Canvas pen settings
  final ScribbleNotifier _controller = ScribbleNotifier()
  ..setStrokeWidth(10.0)  
  ..setColor(Colors.black);

  // UI Variables
  late AnimationController _animationController;
  bool isMenuOpen = false;

  // -------------------------- FUNCTIONS START --------------------------//

  // Loads model
  Future<void> _loadModel() async {
    try {
      interpreter = await Interpreter.fromAsset('assets/models/symbol_detector.tflite');
      print('Model loaded successfully');
      print('Input shape: ${interpreter.getInputTensor(0).shape}');
      print('Output shape: ${interpreter.getOutputTensor(0).shape}');
    } catch (e) {
      print('Error loading model: $e');
    }
  }

  // Preprocesses ENTIRE canvas, feeds to model, save detections to Detected list for output
  Future<void> multiple() async {
    try {
      // Step 1: Get canvas as image
      final ByteData byteData = await _controller.renderImage();
      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final img.Image? fullImage = img.decodeImage(pngBytes);
      if (fullImage == null) return;

      // Step 2: Check if canvas is empty
      bool hasContent = false;
      outerLoop: for (int y = 0; y < fullImage.height; y++) {
        for (int x = 0; x < fullImage.width; x++) {
          final pixel = fullImage.getPixel(x, y);
          final gray = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b).toInt();
          if (gray < 240) {
            hasContent = true;
            break outerLoop;
          }
        }
      }
      if (!hasContent) {
        // Canvas is empty, clear detections
        if (detectedSymbols.isNotEmpty) {
          setState(() {
            detectedSymbols.clear();
          });
        }
        return;
      }

      // Step 3: Preprocess image to 128x128 grayscale normalized
      final grayscale = img.grayscale(fullImage);
      final resized = img.copyResize(grayscale, width: INPUT_SIZE, height: INPUT_SIZE);

      // Convert to model input format: [1, 128, 128, 1]
      final input = List.generate(1, (_) =>
        List.generate(INPUT_SIZE, (y) =>
          List.generate(INPUT_SIZE, (x) {
            final pixel = resized.getPixel(x, y);
            return [pixel.r.toDouble() / 255.0];
          })
        )
      );

      // Step 4: Prepare output buffer: [1, 20, 57]
      // 57 = 1 objectness + 52 classes + 4 bbox coords
      var output = List.generate(
        1,
        (_) => List.generate(
          MAX_DETECTIONS,
          (_) => List.filled(1 + NUM_CLASSES + 4, 0.0),
        ),
      );

      // Step 5: Run inference
      interpreter.run(input, output);

      // Step 6: Parse detections
      List<DetectedSymbol> newDetections = [];

      
      for (int i = 0; i < MAX_DETECTIONS; i++) {
        final detection = output[0][i];

        // Extract objectness score (apply sigmoid)
        final objectness = _sigmoid(detection[0]);

        if (objectness > CONFIDENCE_THRESHOLD) {
          // Extract class probabilities (apply softmax)
          final classLogits = detection.sublist(1, 1 + NUM_CLASSES);
          final classProbs = _softmax(classLogits);
          
          // Get predicted class
          int classId = 0;
          double maxProb = classProbs[0];
          for (int j = 1; j < NUM_CLASSES; j++) {
            if (classProbs[j] > maxProb) {
              maxProb = classProbs[j];
              classId = j;
            }
          }

          // Extract bbox coordinates (normalized [0, 1])
          final xCenter = detection[1 + NUM_CLASSES];
          final yCenter = detection[1 + NUM_CLASSES + 1];
          final width = detection[1 + NUM_CLASSES + 2];
          final height = detection[1 + NUM_CLASSES + 3];

          // Convert to pixel coordinates relative to ORIGINAL canvas size
          final scaleX = fullImage.width / INPUT_SIZE;
          final scaleY = fullImage.height / INPUT_SIZE;
          
          final x1 = ((xCenter - width / 2) * INPUT_SIZE * scaleX).clamp(0, fullImage.width).toInt();
          final y1 = ((yCenter - height / 2) * INPUT_SIZE * scaleY).clamp(0, fullImage.height).toInt();
          final x2 = ((xCenter + width / 2) * INPUT_SIZE * scaleX).clamp(0, fullImage.width).toInt();
          final y2 = ((yCenter + height / 2) * INPUT_SIZE * scaleY).clamp(0, fullImage.height).toInt();

          // Calculate combined confidence
          final confidence = objectness * maxProb;

          // Optional: Extract thumbnail of detected symbol
          Uint8List? thumbnail;
          try {
            final cropped = img.copyCrop(fullImage, 
              x: x1, y: y1, 
              width: x2 - x1, 
              height: y2 - y1
            );
            thumbnail = Uint8List.fromList(img.encodePng(cropped));
          } catch (e) {
            print('Could not crop thumbnail: $e');
          }

          newDetections.add(DetectedSymbol(
            label: labels[classId],
            confidence: confidence,
            x1: x1,
            y1: y1,
            x2: x2,
            y2: y2,
            thumbnail: thumbnail,
          ));
        }
      }

      // Step 7: Sort by confidence (highest first)
      newDetections.sort((a, b) => b.confidence.compareTo(a.confidence));

      // Step 8: Update the detectedSymbols list
      setState(() {
        detectedSymbols = newDetections;

      });

      // Step 9: Print results
      if (newDetections.isNotEmpty) {
        print('\nDetected ${newDetections.length} symbols:');
        for (var symbol in newDetections) {
          print('  ${symbol.label}: [${symbol.x1}, ${symbol.y1}, ${symbol.x2}, ${symbol.y2}] '
                '(${(symbol.confidence * 100).toStringAsFixed(1)}%)');
        }
      }

    } catch (e) {
      print("Error in multiple(): $e");
    }
  }
  
  // Sigmoid activation - for multiple()
  double _sigmoid(double x) {
    return 1.0 / (1.0 + math.exp(-x));
  }

  // Softmax activation - for multiple()
  List<double> _softmax(List<double> logits) {
    final maxLogit = logits.reduce((a, b) => a > b ? a : b);
    final expValues = logits.map((x) => math.exp(x - maxLogit)).toList();
    final sumExp = expValues.reduce((a, b) => a + b);
    return expValues.map((x) => x / sumExp).toList();
  }

  // Clear canvas and Detected list
  void clearCanvas() {
    setState(() {
      _controller.clear();
      detectedSymbols.clear();
    });
    print("Canvas and detections cleared.");
  }

  // -------------------------- FUNCTIONS END --------------------------//
  
  @override
  void initState() {
    super.initState();

    _loadModel(); // always stays

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );  
  }

  @override
  void dispose() {
    _animationController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {    
    return Scaffold(
      backgroundColor: Colors.grey[500],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        // This changes depending if we are gathering training data or verifying model prediction, ModelView
        
        // If gathering data use
        //title: Text(
        //  'Please write "$currentLabel" and click save',
        //  style: const TextStyle(color: Colors.black),
        //),

        // If verifying use
        title: Text(
          "Welcome User", 
          style: const TextStyle(color: Colors.black),
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
        padding: const EdgeInsets.all(15.0),
        child: Row(
          children: [
            // left side - canvas and buttons
            Expanded(
              flex: 80,
              child: Material(
                elevation: 4,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Calculate canvas size based on available height
                    final availableWidth = constraints.maxWidth - 40;
                    final availableHeight = constraints.maxHeight;
                    final buttonAreaHeight = 80.0; // Space for buttons and spacing
                    final maxCanvasHeight = availableHeight - buttonAreaHeight;

                    // Use full available width and height (rectangle)
                    final canvasWidth = availableWidth.clamp(200.0, double.infinity);
                    final canvasHeight = maxCanvasHeight.clamp(200.0, double.infinity);


                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [

                        // canvas
                        Container(
                          width: canvasWidth, 
                          height: canvasHeight,
                          color: Colors.white,
                          child: Scribble(notifier: _controller, drawPen: true,),
                        ),
                        const SizedBox(height: 14),

                        // Buttons - under canvas
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                  child: ElevatedButton(
                                    onPressed: _controller.undo, 
                                    child: const Text("Undo")
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                  child: ElevatedButton(
                                    onPressed: clearCanvas,
                                    child: const Text("Clear")
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                  child: ElevatedButton(
                                    onPressed: multiple,
                                    child: const Text("Detect")
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ), 

                        const SizedBox(height: 16),               
                      ],
                    );
                  },
                ),
              ),
            ),
            
            // Divider                  
            const VerticalDivider(width: 1, color: Colors.grey, thickness: 1),
            
            // right side - predictions
            Expanded(
              flex: 20,
              child: Container(
                color: Colors.grey[400],
                child: Column(
                  children: [

                    // title
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        'Detected Symbols',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // if empty
                    Expanded(
                      child: detectedSymbols.isEmpty
                        ? const Center(
                            child: Text(
                              'No symbols detected yet.\nDraw something!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(8.0),
                            itemCount: detectedSymbols.length,
                            itemBuilder: (context, index) {
                              final symbol = detectedSymbols[index];
                              return Card(
                                elevation: 2,
                                margin: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          // Thumbnail if available
                                          if (symbol.thumbnail != null)
                                            Container(
                                              width: 50,
                                              height: 50,
                                              decoration: BoxDecoration(
                                                border: Border.all(color: Colors.grey),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Image.memory(
                                                symbol.thumbnail!,
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                          const SizedBox(width: 8),
                                          // Label and confidence
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  symbol.label,
                                                  style: const TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  '${(symbol.confidence * 100).toStringAsFixed(1)}% confident',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[700],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      // coordinates
                                      const SizedBox(height: 4),
                                      Text(
                                        'Position: (${symbol.x1}, ${symbol.y1}) → (${symbol.x2}, ${symbol.y2})',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[600],
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
            ),
          ],
        ),
      ),
    );
  }
}