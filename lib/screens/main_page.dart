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

class _MainPageState extends State<MainPage> with SingleTickerProviderStateMixin {
  
  late AnimationController _animationController;
  bool isMenuOpen = false;
  final ScribbleNotifier _notifier = ScribbleNotifier();
  final GlobalKey _repaintKey = GlobalKey();

  // Store all saved drawings here
  List<Uint8List> savedImages = [];

  /////// MODEL TRY OUT STUFF /////////////////////////////
  // Stores the predictions for each saved drawing
  List<int> predictions = [];

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
  }

  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/mnist.tflite');
      debugPrint("MNIST model loaded!");
    } catch (e) {
      debugPrint("Error loading model: $e");
    }
  }

  Future<void> _runModel(List<List<double>> normalized) async {
    // 1. Prepare input as 1x28x28x1 tensor
    var input = List.generate(1, (_) => 
        List.generate(28, (y) => 
          List.generate(28, (x) => [normalized[y][x]])));

    // 2. Prepare output as 1x10 (digits 0–9)
    var output = List.generate(1, (_) => List.filled(10, 0.0));

    // 3. Run inference
    _interpreter.run(input, output);

    // 4. Find predicted digit
    int prediction = output[0].indexOf(output[0].reduce((a, b) => a > b ? a : b));

    debugPrint("Predicted digit: $prediction");

    setState(() {
      predictions.add(prediction); // store alongside savedImages
    });
  }
  //////////////////////////////////////////////////////

  Future<void> _saveDrawing() async {
    try {
      RenderRepaintBoundary boundary =
          _repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

      // Capture canvas as image
      ui.Image image = await boundary.toImage(pixelRatio: 1.0);

      // Convert to PNG bytes for storage
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      Uint8List pngBytes = byteData.buffer.asUint8List();

      setState(() {
        savedImages.add(pngBytes);
      });

      debugPrint("Saved image #${savedImages.length}");
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
                          onPressed: _saveDrawing,
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
                child: Expanded(
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
                              itemCount: savedImages.length,
                              itemBuilder: (context, index) {
                                return ListTile(
                                  leading: Image.memory(
                                    savedImages[index], // thumbnail bytes
                                    width: 40,
                                    height: 40,
                                  ),
                                  title: Text("Prediction: ${predictions[index]}"),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              ),
            ),
          ],
        ),
      ),
    );
  }
}
