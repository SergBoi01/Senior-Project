import 'package:flutter/material.dart';
import 'package:senior_project/screens/glossary_frontend.dart';
import 'package:senior_project/screens/glossary_backend.dart';

import 'package:senior_project/screens/login_screen.dart';
import 'package:senior_project/screens/symbols_screen.dart';
import 'dart:math' as math;

// ==================== DATA CLASSES ====================

// Represents a single stroke (pen down → pen up)
class Stroke {
  final List<Offset> points;
  final DateTime startTime;
  final DateTime endTime;

  Stroke({
    required this.points,
    required this.startTime,
    required this.endTime,
  });

  // Get bounding box of this stroke
  Rect getBoundingBox() {
    if (points.isEmpty) return Rect.zero;
    
    double minX = points.first.dx;
    double minY = points.first.dy;
    double maxX = points.first.dx;
    double maxY = points.first.dy;

    for (var point in points) {
      if (point.dx < minX) minX = point.dx;
      if (point.dy < minY) minY = point.dy;
      if (point.dx > maxX) maxX = point.dx;
      if (point.dy > maxY) maxY = point.dy;
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  // Get center point
  Offset get center {
    final box = getBoundingBox();
    return box.center;
  }
}

// Represents a detected symbol (group of strokes)
class SymbolCluster {
  final List<Stroke> strokes;
  final Rect boundingBox;

  SymbolCluster({
    required this.strokes,
    required this.boundingBox,
  });
}

// Represents a detected symbol with match info
class DetectedSymbol {
  final String label;           // Matched label from glossary
  final double confidence;      // Confidence score (0.0 to 1.0)
  final int x1, y1, x2, y2;    // Bounding box coordinates
  final List<Stroke> strokes;   // The actual strokes

  DetectedSymbol({
    required this.label,
    required this.confidence,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.strokes,
  });

  double get centerX => (x1 + x2) / 2;
  double get centerY => (y1 + y2) / 2;
  int get width => x2 - x1;
  int get height => y2 - y1;
}

// ==================== MAIN PAGE ====================

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with SingleTickerProviderStateMixin {
  
  // ==================== SETTINGS ====================
  
  static const double TIME_THRESHOLD_MS = 500;    // Strokes within 500ms = same symbol
  static const double SPATIAL_THRESHOLD_PX = 2500; // Squared distance (50px * 50px)
  static const double MIN_SYMBOL_SIZE = 100;      // Minimum area (px²) for valid symbol
  
  // ==================== STATE ====================
  
  List<DetectedSymbol> detectedSymbols = [];
  List<Stroke> allStrokes = [];
  List<Offset> currentStrokePoints = [];
  DateTime? currentStrokeStartTime;
  
  late AnimationController _animationController;

  // ==================== STROKE TRACKING ====================

  void _onPanStart(DragStartDetails details) {
    setState(() {
      currentStrokePoints = [details.localPosition];
      currentStrokeStartTime = DateTime.now();
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      currentStrokePoints.add(details.localPosition);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (currentStrokePoints.isNotEmpty && currentStrokeStartTime != null) {
      final stroke = Stroke(
        points: List.from(currentStrokePoints),
        startTime: currentStrokeStartTime!,
        endTime: DateTime.now(),
      );
      
      setState(() {
        allStrokes.add(stroke);
      });

      print('✏️ Stroke completed: ${stroke.points.length} points');
      
      currentStrokePoints = [];
      currentStrokeStartTime = null;
    }
  }

  // ==================== SYMBOL DETECTION ====================

  Future<void> detectSymbols() async {
    if (allStrokes.isEmpty) {
      setState(() {
        detectedSymbols.clear();
      });
      print('No strokes to detect');
      return;
    }

    print('\nStarting detection with ${allStrokes.length} strokes...');

    // Step 1: Cluster strokes into symbol groups
    List<SymbolCluster> clusters = _clusterStrokes(allStrokes);
    print('Found ${clusters.length} symbol clusters');

    // Step 2: For each cluster, match to glossary
    List<DetectedSymbol> newDetections = [];
    
    for (int i = 0; i < clusters.length; i++) {
      final cluster = clusters[i];
      
      // Match this cluster to glossaries
      final matchedLabel = await comparingCheckedGlossaries(cluster);
      
      newDetections.add(DetectedSymbol(
        label: matchedLabel,
        confidence: 0.0, // Will be set by glossary comparison
        x1: cluster.boundingBox.left.toInt(),
        y1: cluster.boundingBox.top.toInt(),
        x2: cluster.boundingBox.right.toInt(),
        y2: cluster.boundingBox.bottom.toInt(),
        strokes: cluster.strokes,
      ));
    }

    setState(() {
      detectedSymbols = newDetections;
    });

    print('Detected ${newDetections.length} symbols');
  }

  // ==================== GLOSSARY COMPARISON ====================

  Future<String> comparingCheckedGlossaries(SymbolCluster cluster) async {
    // Load saved glossary (the one we already have in backend)
    final glossary = Glossary();
    await glossary.loadFromPrefs();

    // Get all entries (no isChecked filtering)
    final entries = glossary.entries;

    if (entries.isEmpty) {
      print("No glossary entries available.");
      return "??";
    }

    // Get the symbol strokes from this detected cluster
    final currentSymbolStrokes = cluster.strokes;

    double bestScore = 0.0;
    String bestMatch = "??";

    for (final entry in entries) {
      if (entry.strokes == null || entry.strokes!.isEmpty) continue;

      // Compare the stored strokes with the current cluster strokes
      final similarity = _compareStrokes(
        entry.strokes!.map((s) => s.points).toList(),
        currentSymbolStrokes.map((s) => s.points).toList(),
      );

      print("Compared with ${entry.english} → similarity: $similarity");

      if (similarity > bestScore) {
        bestScore = similarity;
        bestMatch = entry.spanish; // or .english depending on translation direction
      }
    }

    // Only return a match if similarity is above threshold
    return bestScore > 0.5 ? bestMatch : "??";
  }

  // ==================== BASIC STROKE COMPARISON ====================

  double _compareStrokes(List<List<Offset>> stored, List<List<Offset>> input) {
    // Simple heuristic comparison — counts how many strokes are “similar” in length and shape
    int matches = 0;

    for (var stroke1 in input) {
      for (var stroke2 in stored) {
        final sim = _strokeSimilarity(stroke1, stroke2);
        if (sim > 0.7) matches++;
      }
    }

    return matches / (stored.length + input.length - matches);
  }

  double _strokeSimilarity(List<Offset> a, List<Offset> b) {
    if (a.isEmpty || b.isEmpty) return 0.0;

    // Compare by normalized path length and average shape
    final lenA = a.length.toDouble();
    final lenB = b.length.toDouble();

    final minLen = lenA < lenB ? lenA : lenB;
    double total = 0;

    for (int i = 0; i < minLen; i++) {
      final pA = a[(i / lenA * a.length).floor()];
      final pB = b[(i / lenB * b.length).floor()];
      total += 1.0 - ((pA - pB).distance / 100.0).clamp(0.0, 1.0);
    }

    return total / minLen;
  }

  // ==================== CLUSTERING ALGORITHM ====================

  List<SymbolCluster> _clusterStrokes(List<Stroke> strokes) {
    if (strokes.isEmpty) return [];

    List<SymbolCluster> clusters = [];
    List<Stroke> currentCluster = [strokes[0]];

    for (int i = 1; i < strokes.length; i++) {
      final prevStroke = strokes[i - 1];
      final currentStroke = strokes[i];

      // Calculate time gap
      final timeDiff = currentStroke.startTime.difference(prevStroke.endTime).inMilliseconds;

      // Calculate spatial distance (squared, to avoid sqrt)
      final prevCenter = prevStroke.center;
      final currentCenter = currentStroke.center;
      final dx = prevCenter.dx - currentCenter.dx;
      final dy = prevCenter.dy - currentCenter.dy;
      final distanceSquared = dx * dx + dy * dy;

      // Decision: Same symbol or new symbol?
      bool sameSymbol = false;

      if (timeDiff < TIME_THRESHOLD_MS) {
        sameSymbol = true; // Recent stroke = same symbol
      } else if (distanceSquared < SPATIAL_THRESHOLD_PX) {
        sameSymbol = true; // Close together = same symbol (handles i, j, !)
      }

      if (sameSymbol) {
        currentCluster.add(currentStroke);
      } else {
        // Save previous cluster and start new one
        clusters.add(_createCluster(currentCluster));
        currentCluster = [currentStroke];
      }
    }

    // Don't forget the last cluster
    if (currentCluster.isNotEmpty) {
      clusters.add(_createCluster(currentCluster));
    }

    // Filter out tiny clusters (noise)
    clusters = clusters.where((cluster) {
      final area = cluster.boundingBox.width * cluster.boundingBox.height;
      return area >= MIN_SYMBOL_SIZE;
    }).toList();

    return clusters;
  }

  SymbolCluster _createCluster(List<Stroke> strokes) {
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (var stroke in strokes) {
      final box = stroke.getBoundingBox();
      if (box.left < minX) minX = box.left;
      if (box.top < minY) minY = box.top;
      if (box.right > maxX) maxX = box.right;
      if (box.bottom > maxY) maxY = box.bottom;
    }

    return SymbolCluster(
      strokes: strokes,
      boundingBox: Rect.fromLTRB(minX, minY, maxX, maxY),
    );
  }

  // ==================== UI ACTIONS ====================

  void clearCanvas() {
    setState(() {
      detectedSymbols.clear();
      allStrokes.clear();
      currentStrokePoints = [];
      currentStrokeStartTime = null;
    });
    print("Canvas cleared");
  }

  void undoStroke() {
    if (allStrokes.isNotEmpty) {
      setState(() {
        allStrokes.removeLast();
      });
      print("Undo stroke");
    }
  }

  // ==================== LIFECYCLE ====================

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

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {    
    return Scaffold(
      backgroundColor: Colors.grey[500],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          "Strokes: ${allStrokes.length} | Symbols: ${detectedSymbols.length}", 
          style: const TextStyle(color: Colors.black, fontSize: 14),
        ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: Colors.black),
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
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => GlossaryScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.star, color: Colors.white),
              title: const Text('Symbols', style: TextStyle(color: Colors.white)),
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
            // Left side - canvas
            Expanded(
              flex: 80,
              child: Material(
                elevation: 4,
                child: Column(
                  children: [
                    // Canvas
                    Expanded(
                      child: GestureDetector(
                        onPanStart: _onPanStart,
                        onPanUpdate: _onPanUpdate,
                        onPanEnd: _onPanEnd,
                        child: SizedBox.expand(
                          child: CustomPaint(
                            painter: CanvasPainter(
                              strokes: allStrokes,
                              currentStroke: currentStrokePoints,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Buttons
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: undoStroke,
                              icon: const Icon(Icons.undo, size: 18),
                              label: const Text("Undo"),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: clearCanvas,
                              icon: const Icon(Icons.clear, size: 18),
                              label: const Text("Clear"),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: detectSymbols,
                              icon: const Icon(Icons.search, size: 18),
                              label: const Text("Detect"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const VerticalDivider(width: 1, color: Colors.grey),
            
            // Right side - results
            Expanded(
              flex: 20,
              child: Container(
                color: Colors.grey[400],
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        'Detected Symbols',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: detectedSymbols.isEmpty
                        ? const Center(
                            child: Text(
                              'Draw symbols and\npress Detect',
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
                                          Icon(
                                            Icons.help_outline,
                                            color: Colors.orange,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  symbol.label,
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  'Position: (${symbol.x1}, ${symbol.y1})',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
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

// ==================== CUSTOM PAINTER ====================

class CanvasPainter extends CustomPainter {
  final List<Stroke> strokes;
  final List<Offset> currentStroke;

  CanvasPainter({
    required this.strokes,
    required this.currentStroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 10.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Draw completed strokes
    for (var stroke in strokes) {
      if (stroke.points.length > 1) {
        final path = Path();
        path.moveTo(stroke.points[0].dx, stroke.points[0].dy);
        for (int i = 1; i < stroke.points.length; i++) {
          path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
        }
        canvas.drawPath(path, paint);
      }
    }

    // Draw current stroke being drawn
    if (currentStroke.length > 1) {
      final path = Path();
      path.moveTo(currentStroke[0].dx, currentStroke[0].dy);
      for (int i = 1; i < currentStroke.length; i++) {
        path.lineTo(currentStroke[i].dx, currentStroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(CanvasPainter oldDelegate) {
    return true;
  }
}