import 'package:flutter/material.dart';
import 'package:senior_project/screens/glossary_screen.dart';
import 'package:senior_project/screens/login_screen.dart';
import 'package:senior_project/screens/symbols_screen.dart';

import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:scribble/scribble.dart';
import 'dart:typed_data';
import 'dart:math';

// CLASS THAT HOLDS RIGHT SIDE OUTPUT
class SavedImage {
  final Uint8List thumbnail;  // original canvas thumbnail
  final int prediction;       // model prediction
  final Uint8List modelView;  // preprocessed input for display

  SavedImage({
    required this.thumbnail, 
    required this.prediction, 
    required this.modelView,
  });
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with SingleTickerProviderStateMixin {
  
  // CHANGES THICKNESS AND SETS COLOR OF PEN
  final ScribbleNotifier _controller = ScribbleNotifier()
  ..setStrokeWidth(18.0)  // Set pen width
  ..setColor(Colors.black);


  // CLASS OF SAVED IMAGES
  final List<SavedImage> saved = [];

  //MODEL INTERPRETER
  late Interpreter interpreter;

  late AnimationController _animationController;
  bool isMenuOpen = false;

  Future<void> _loadModel() async {
    interpreter = await Interpreter.fromAsset('assets/models/mnist.tflite');
    print('Interpreter initialized: $interpreter');
  }
  
  // SAVES IMAGE, CROPS IT, GRAYSCALES, SETS TO MODEL INPUT, GIVES TO MODEL, 
  //SAVES PREDICTIONS, SAVES ITEM IN CLASS
  Future<void> _handleSave() async {
    try {
      print(interpreter.hashCode);
      // 1. Render canvas as ByteData
      final ByteData byteData = await _controller.renderImage();
      final Uint8List thumbnail = byteData.buffer.asUint8List();

      // 2. Decode PNG for processing
      final img.Image? image = img.decodeImage(thumbnail);
      if (image == null) return;

      final int width = image.width;
      final int height = image.height;

      // 3. Find bounding box of non-white pixels
      int minX = width, minY = height, maxX = 0, maxY = 0;
      bool hasContent = false;

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        final int r = pixel.r.toInt();
        final int g = pixel.g.toInt();
        final int b = pixel.b.toInt();
        final gray = (0.299*r + 0.587*g + 0.114*b).toInt();

        if (gray < 240) { // non-white pixel
          hasContent = true;
          minX = x < minX ? x : minX;
          minY = y < minY ? y : minY;
          maxX = x > maxX ? x : maxX;
          maxY = y > maxY ? y : maxY;
          }
        }
      }

      // 4. Handle empty canvas
      if (!hasContent) {
        final emptyModelView = _createEmptyModelView();
        setState(() {
          saved.add(SavedImage(
            thumbnail: thumbnail,
            prediction: -1,
            modelView: emptyModelView,
          ));
          _controller.clear();
        });
        return;
      }

      // 5. Crop to bounding box with some padding
      final padding = 5;
      final cropMinX = max(0, minX - padding);
      final cropMinY = max(0, minY - padding);
      final cropMaxX = min(width - 1, maxX + padding);
      final cropMaxY = min(height - 1, maxY + padding);
      
      final cropped = img.copyCrop(
        image,
        x: cropMinX,
        y: cropMinY,
        width: cropMaxX - cropMinX + 1,
        height: cropMaxY - cropMinY + 1,
      );
      

      // 6. Resize while preserving aspect ratio to fit 20x20
      final scale = 20 / max(cropped.width, cropped.height);
      final newWidth = (cropped.width * scale).round();
      final newHeight = (cropped.height * scale).round();
      final resized = img.copyResize(cropped, width: newWidth, height: newHeight);

      // 7. Center on 28x28 black canvas
      final canvas28 = img.Image(width: 28, height: 28);
      img.fill(canvas28, color: img.ColorRgb8(255, 255, 255));
      final xOffset = ((28 - newWidth) / 2).round();
      final yOffset = ((28 - newHeight) / 2).round();
      img.compositeImage(canvas28, resized, dstX: xOffset, dstY: yOffset);

      // 8. Convert to [1,28,28,1] with inverted grayscale
      final input = List.generate(1, (_) => List.generate(28, (y) {
        return List.generate(28, (x) {
          final pixel = canvas28.getPixel(x, y);
          final gray = (0.299*pixel.r + 0.587*pixel.g + 0.114*pixel.b)/255.0;
          return [1 - gray]; // invert: black background → 0, white strokes → 1
        });
      }));

      // 9. Run TFLite
      var output = List.generate(1, (_) => List.filled(10, 0.0));
      interpreter.run(input, output);

      // 10. Get predicted digit
      final prediction = output[0].indexWhere(
        (v) => v == output[0].reduce((a, b) => a > b ? a : b),
      );

      // 11. Convert preprocessed input to image for display
      Uint8List modelView = modelInputToImage(input);
      
      // 12. Save and clear
      setState(() {
        saved.add(SavedImage(
          thumbnail: thumbnail,
          prediction: prediction,
          modelView: modelView,
        ));
        _controller.clear();
      });

      print('Predicted digit: $prediction');

    } catch (e) {
      print('Error in _handleSave: $e');
    }
  }

  // HELPER FOR HANDLESAVE FUNCTION
  Uint8List _createEmptyModelView() {
    final im = img.Image(width: 28, height: 28);
    img.fill(im, color: img.ColorRgb8(255, 255, 255)); // White for empty
    return Uint8List.fromList(img.encodePng(im));
  }

  // ALLOWS US TO SEE WHAT THE MODEL IS RECIEVING AS INPUT
  Uint8List modelInputToImage(List<List<List<List<double>>>> input) {
    // Create a 28x28 grayscale image
    final im = img.Image(width: 28, height: 28);

    for (int y = 0; y < 28; y++) {
      for (int x = 0; x < 28; x++) {
        // Retrieve the inverted grayscale value used by the model
        final val = input[0][y][x][0]; // 0..1
        final gray = ((1.0 - val) * 255).toInt(); // 1→0 (black), 0→255 (white)

        // Clamp to valid range
        final clampedGray = gray.clamp(0, 255);

      // Set pixel
      im.setPixelRgba(x, y, clampedGray, clampedGray, clampedGray, 255);
      }
    }

    // Encode as PNG for display
    return Uint8List.fromList(img.encodePng(im));
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadModel();
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
                    Container(
                      width: 280,
                      height: 280,
                      color: Colors.white,
                      child: Scribble(notifier: _controller, drawPen: true,),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(onPressed: _controller.undo, child: const Text("Undo")),
                        ElevatedButton(onPressed: _controller.clear, child: const Text("Clear")),
                        ElevatedButton(onPressed: _handleSave, child: const Text("Save")),
                      ],
                    ),                  
                  ],
                ),
              ),
            ),
            const VerticalDivider(width: 1, color: Colors.grey),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: saved.length,
                      itemBuilder: (context, index) {
                        final item = saved[index];
                        return Row(
                          children: [
                            Image.memory(item.modelView, width: 50, height: 50), // shows model input
                            SizedBox(width: 8),
                            Text('Prediction: ${item.prediction}'),
                          ],
                        );
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () => setState(() => saved.clear()),
                        child: const Text("Clear All"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}