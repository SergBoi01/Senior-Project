import 'package:flutter/material.dart';
import 'package:senior_project/screens/glossary_screen.dart';
import 'package:senior_project/screens/login_screen.dart';
import 'package:senior_project/screens/symbols_screen.dart';

import 'package:scribble/scribble.dart';
import 'package:flutter/rendering.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;

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
  List<List<List<double>>> savedDrawings = [];

  @override
  void initState() {
    super.initState();
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

  Future<void> _saveDrawing() async {
    try {
      RenderRepaintBoundary boundary =
          _repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 1.0);

      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return;

      Uint8List data = byteData.buffer.asUint8List();
      int width = image.width;
      int height = image.height;

      // Convert to grayscale
      List<List<int>> grayscale = List.generate(
        height,
        (_) => List.filled(width, 0),
      );

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          int byteOffset = (y * width + x) * 4;
          int r = data[byteOffset];
          int g = data[byteOffset + 1];
          int b = data[byteOffset + 2];
          int a = data[byteOffset + 3];

          int gray = ((0.3 * r + 0.59 * g + 0.11 * b) * (a / 255)).round();
          grayscale[y][x] = gray;
        }
      }

      // Resize to 28x28
      List<List<int>> resized = List.generate(
        28,
        (_) => List.filled(28, 0),
      );

      double xRatio = width / 28.0;
      double yRatio = height / 28.0;

      for (int y = 0; y < 28; y++) {
        for (int x = 0; x < 28; x++) {
          int nearestX = (x * xRatio).floor();
          int nearestY = (y * yRatio).floor();
          resized[y][x] = grayscale[nearestY][nearestX];
        }
      }

      // Normalize to [0,1]
      List<List<double>> normalized = resized
          .map((row) => row.map((val) => val / 255.0).toList())
          .toList();

      setState(() {
        savedDrawings.add(normalized);
      });

      debugPrint("✅ Saved drawing #${savedDrawings.length}");
    } catch (e) {
      debugPrint("❌ Error saving drawing: $e");
    }
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
                    // Drawing Area (wrapped in RepaintBoundary so we can capture it)
                    Expanded(
                      child: Container(
                        color: Colors.white,
                        child: RepaintBoundary(
                          key: _repaintKey,
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
                child: Container(
                  color: Colors.white,
                  child: const Center(
                    child: Text('Transcription Area'),
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
