import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'login_screen.dart';
import 'symbols_screen.dart';
import 'settings_screen.dart';
import 'library_screen.dart';

import 'package:senior_project/models/notebook_model.dart';
import 'package:senior_project/models/library_model.dart';
import 'package:senior_project/models/strokes_model.dart';
import 'package:senior_project/services/backend_manager.dart';
import 'package:senior_project/widgets/lined_paper_widget.dart';

import 'dart:math' as math;

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with SingleTickerProviderStateMixin {

  
  // ==================== STATE ====================
  Timer? _autoDetectTimer;
  bool _isDetecting = false;
  int _lastStrokeCount = 0;

  bool showSpanish = true; // true = Spanish, false = English

  late List<FolderItem> libraryStructure;
  late List<UserCorrection> userCorrections;
  late NotebookManager notebook;

  List<DetectedSymbol> detectedSymbols = [];
  List<Offset> currentStrokePoints = [];
  DateTime? currentStrokeStartTime;
  
  late AnimationController _animationController;

  // Transcript lines
  List<String> transcriptLines = [];
  bool isMuted = false;

  // Get user's display name
  String get _userName {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        return user.displayName!;
      } else if (user.email != null) {
        // Extract name from email (part before @)
        return user.email!.split('@')[0];
      }
    }
    return 'User';
  }

  // ==================== HELPER METHODS ====================
  List<GlossaryItem> _getCheckedGlossaries() {
    final List<GlossaryItem> checked = [];

    void traverseFolder(FolderItem folder, String indent) {
      debugPrint('$indent Folder: ${folder.name}, isChecked: ${folder.isChecked}');

      for (var child in folder.children) {
        if (child is FolderItem) {
          traverseFolder(child, '$indent  ');
        } else if (child is GlossaryItem) {
          debugPrint('$indent  Glossary: ${child.name}, isChecked: ${child.isChecked}');
          if (child.isChecked) {
            checked.add(child);
          }
        }
      }
    }

    final rootFolders = BackendManager().libraryService.rootFolders;

    debugPrint('Loaded root folders: ${rootFolders.map((f) => f.name).toList()}');

    for (var root in rootFolders) {
      traverseFolder(root, '');
    }

    debugPrint('Total checked glossaries: ${checked.length}');
    return checked;
  }

  // ==================== AUTO-DETECTION ====================
  void _startAutoDetection() {
    _autoDetectTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) async {
      if (!_isDetecting && notebook.currentPage.strokes.length != _lastStrokeCount) {
        _lastStrokeCount = notebook.currentPage.strokes.length;
        await Future.delayed(const Duration(milliseconds: 400));
        if (notebook.currentPage.strokes.length != _lastStrokeCount) return;
        _isDetecting = true;
        await detectSymbols();
        _isDetecting = false;
      }
    });
  }

  void _stopAutoDetection() {
    _autoDetectTimer?.cancel();
    _autoDetectTimer = null;
  }

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
        notebook.currentPage.strokes.add(stroke);
      });
      currentStrokePoints = [];
      currentStrokeStartTime = null;
    }
  }

  // ==================== SYMBOL DETECTION ====================
  Future<void> detectSymbols() async {
    if (notebook.currentPage.strokes.isEmpty) {
      setState(() => detectedSymbols.clear());
      return;
    }

    List<SymbolCluster> clusters = _clusterStrokes(notebook.currentPage.strokes);
    List<DetectedSymbol> newDetections = [];
    
    for (final cluster in clusters) {
      final matchedLabel = await comparingCheckedGlossaries(cluster);
      newDetections.add(DetectedSymbol(
        label: matchedLabel,
        confidence: 0.0,
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
  }

  // ==================== ADVANCED COMPARISON ====================
  Future<String> comparingCheckedGlossaries(SymbolCluster cluster) async {
    final checkedGlossaries = _getCheckedGlossaries();
    print("Checked glossaries: ${checkedGlossaries.length}");

    if (checkedGlossaries.isEmpty) return "??";

    List<GlossaryEntry> allEntries = [];
    for (var glossary in checkedGlossaries) {
      allEntries.addAll(glossary.entries.where((entry) => entry.strokes != null && entry.strokes!.isNotEmpty));
    }
    if (allEntries.isEmpty) return "??";

    final normalizedInput = _normalizeStrokeSet(cluster.strokes);

    double bestScore = 0.0;
    String bestMatch = "??";
    String bestMatchEnglish = "";
    String bestMatchSpanish = "";

    // Check user corrections first
    for (var correction in userCorrections) {
      final normalizedCorrection = _normalizeStrokeSet(correction.drawnStrokes);
      final similarity = _advancedStrokeComparison(normalizedInput, normalizedCorrection);
      if (similarity > bestScore) {
        bestScore = similarity;
        for (var entry in allEntries) {
          if (entry.spanish == correction.correctedLabel || entry.english == correction.correctedLabel) {
            bestMatch = entry.spanish;
            bestMatchEnglish = entry.english;
            break;
          }
        }
      }
    }

    // Compare against glossary entries
    for (var entry in allEntries) {
      final normalizedEntry = _normalizeStrokeSet(entry.strokes!);
      final similarity = _advancedStrokeComparison(normalizedInput, normalizedEntry);
      if (similarity > bestScore) {
        bestScore = similarity;
        bestMatchSpanish = entry.spanish;
        bestMatchEnglish = entry.english;
      }
    }

    bestMatch = showSpanish ? bestMatchSpanish : bestMatchEnglish;
    return bestScore > 0.6 ? bestMatch : "??";
  }

  List<Stroke> _normalizeStrokeSet(List<Stroke> strokes) {
    if (strokes.isEmpty) return [];
    double minX = double.infinity, minY = double.infinity, maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (var stroke in strokes) {
      for (var point in stroke.points) {
        minX = math.min(minX, point.dx);
        minY = math.min(minY, point.dy);
        maxX = math.max(maxX, point.dx);
        maxY = math.max(maxY, point.dy);
      }
    }
    final width = maxX - minX;
    final height = maxY - minY;
    if (width == 0 || height == 0) return strokes;

    return strokes.map((stroke) {
      return Stroke(
        points: stroke.points.map((p) => Offset((p.dx - minX)/width, (p.dy - minY)/height)).toList(),
        startTime: stroke.startTime,
        endTime: stroke.endTime,
      );
    }).toList();
  }

  double _advancedStrokeComparison(List<Stroke> set1, List<Stroke> set2) {
    final strokeCountDiff = (set1.length - set2.length).abs();
    final maxStrokes = math.max(set1.length, set2.length);
    final strokeCountScore = 1.0 - (strokeCountDiff / maxStrokes);

    double totalShapeSimilarity = 0.0;
    int comparisonCount = 0;
    for (var stroke1 in set1) {
      double bestMatch = 0.0;
      for (var stroke2 in set2) {
        final similarity = _compareIndividualStrokes(stroke1, stroke2);
        if (similarity > bestMatch) bestMatch = similarity;
      }
      totalShapeSimilarity += bestMatch;
      comparisonCount++;
    }

    final shapeSimilarity = comparisonCount > 0 ? totalShapeSimilarity / comparisonCount : 0.0;
    final directionScore = _compareDirectionalFlow(set1, set2);

    return ((strokeCountScore*0.15) + (shapeSimilarity*0.7) + (directionScore*0.15)).clamp(0.0,1.0);
  }

  double _compareIndividualStrokes(Stroke s1, Stroke s2) {
    const targetPoints = 32;
    final r1 = _resampleStroke(s1.points, targetPoints);
    final r2 = _resampleStroke(s2.points, targetPoints);

    double totalDistance = 0.0;
    for (int i=0; i<targetPoints; i++) {
      final dx = r1[i].dx - r2[i].dx;
      final dy = r1[i].dy - r2[i].dy;
      totalDistance += math.sqrt(dx*dx + dy*dy);
    }

    final avgDistance = totalDistance / targetPoints;
    return math.exp(-avgDistance*4.5).clamp(0.0,1.0);
  }

  List<Offset> _resampleStroke(List<Offset> points, int targetCount) {
    if (points.length <= 1) return points;
    if (targetCount <= 1) return [points.first];

    double totalLength = 0.0;
    List<double> segLengths = [];
    for (int i=1; i<points.length; i++) {
      final dx = points[i].dx - points[i-1].dx;
      final dy = points[i].dy - points[i-1].dy;
      final length = math.sqrt(dx*dx + dy*dy);
      segLengths.add(length);
      totalLength += length;
    }
    if (totalLength == 0) return points;

    final segmentLength = totalLength / (targetCount - 1);
    List<Offset> resampled = [points.first];
    double accLength = 0.0;
    int currentSegment = 0;

    for (int i=1; i<targetCount-1; i++) {
      final targetLength = segmentLength * i;
      while (currentSegment < segLengths.length && accLength + segLengths[currentSegment] < targetLength) {
        accLength += segLengths[currentSegment];
        currentSegment++;
      }
      if (currentSegment >= segLengths.length) break;
      final remaining = targetLength - accLength;
      final t = remaining / segLengths[currentSegment];
      final p1 = points[currentSegment];
      final p2 = points[currentSegment+1];
      resampled.add(Offset(p1.dx + (p2.dx-p1.dx)*t, p1.dy + (p2.dy-p1.dy)*t));
    }
    resampled.add(points.last);
    return resampled;
  }

  double _compareDirectionalFlow(List<Stroke> s1, List<Stroke> s2) {
    Offset avg1 = _calculateAverageDirection(s1);
    Offset avg2 = _calculateAverageDirection(s2);
    final dot = avg1.dx*avg2.dx + avg1.dy*avg2.dy;
    return ((dot+1)/2).clamp(0.0,1.0);
  }

  Offset _calculateAverageDirection(List<Stroke> strokes) {
    double totalDx=0, totalDy=0; int count=0;
    for (var stroke in strokes) {
      if (stroke.points.length < 2) continue;
      final start = stroke.points.first;
      final end = stroke.points.last;
      totalDx += end.dx-start.dx;
      totalDy += end.dy-start.dy;
      count++;
    }
    if (count == 0) return Offset.zero;
    final mag = math.sqrt(totalDx*totalDx + totalDy*totalDy);
    return mag==0 ? Offset.zero : Offset(totalDx/mag, totalDy/mag);
  }

  // ==================== CLUSTERING ====================
  List<SymbolCluster> _clusterStrokes(List<Stroke> strokes) {
    if (strokes.isEmpty) return [];
    List<SymbolCluster> clusters = [];
    List<Stroke> currentCluster = [strokes[0]];

    for (int i=1; i<strokes.length; i++) {
      final prev = strokes[i-1];
      final curr = strokes[i];
      final timeDiff = curr.startTime.difference(prev.endTime).inMilliseconds;
      final prevCenter = prev.center;
      final currCenter = curr.center;
      final dx = prevCenter.dx - currCenter.dx;
      final dy = prevCenter.dy - currCenter.dy;
      final distSq = dx*dx + dy*dy;

      bool sameSymbol = timeDiff < BackendManager().settingsService.detectionSettings.timeThreshold || distSq < BackendManager().settingsService.detectionSettings.spatialThreshold;
      if (sameSymbol) {
        currentCluster.add(curr);
      } else {
        clusters.add(_createCluster(currentCluster));
        currentCluster = [curr];
      }
    }
    if (currentCluster.isNotEmpty) clusters.add(_createCluster(currentCluster));

    // Remove tiny clusters
    clusters = clusters.where((c) => c.boundingBox.width*c.boundingBox.height >= BackendManager().settingsService.detectionSettings.minSymbolSize).toList();
    return clusters;
  }

  SymbolCluster _createCluster(List<Stroke> strokes) {
    double minX=double.infinity, minY=double.infinity, maxX=double.negativeInfinity, maxY=double.negativeInfinity;
    for (var s in strokes) {
      final box = s.getBoundingBox();
      minX = math.min(minX, box.left);
      minY = math.min(minY, box.top);
      maxX = math.max(maxX, box.right);
      maxY = math.max(maxY, box.bottom);
    }
    return SymbolCluster(strokes: strokes, boundingBox: Rect.fromLTRB(minX, minY, maxX, maxY));
  }

  // ==================== UI ACTIONS ====================
  void clearCanvas() {
    setState(() {
      detectedSymbols.clear();
      notebook.currentPage.strokes.clear();
      currentStrokePoints = [];
      currentStrokeStartTime = null;
      _lastStrokeCount = 0;
    });
  }

  void undoStroke() {
    if (notebook.currentPage.strokes.isNotEmpty) {
      setState(() => notebook.currentPage.strokes.removeLast());
    }
  }

  Future<void> _updateDetectionLanguage() async {
    if (detectedSymbols.isEmpty) return;
    final checkedGlossaries = _getCheckedGlossaries();
    List<GlossaryEntry> allEntries = [];
    for (var g in checkedGlossaries) allEntries.addAll(g.entries);

    List<DetectedSymbol> updated = [];
    for (var symbol in detectedSymbols) {
      String newLabel = symbol.label;
      for (var entry in allEntries) {
        if (showSpanish && entry.english == symbol.label) newLabel = entry.spanish;
        else if (!showSpanish && entry.spanish == symbol.label) newLabel = entry.english;
      }
      updated.add(DetectedSymbol(
        label: newLabel,
        confidence: symbol.confidence,
        x1: symbol.x1,
        y1: symbol.y1,
        x2: symbol.x2,
        y2: symbol.y2,
        strokes: symbol.strokes,
      ));
    }
    setState(() => detectedSymbols = updated);
  }

  void _showCorrectionDialog(DetectedSymbol symbol) async {
    final checkedGlossaries = _getCheckedGlossaries();
    List<GlossaryEntry> allEntries = [];
    for (var g in checkedGlossaries) allEntries.addAll(g.entries);

    if (allEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No glossary entries available.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Correct Detection'),
        content: SizedBox(
          height: 300,
          width: 300,
          child: ListView.builder(
            itemCount: allEntries.length,
            itemBuilder: (context, i) {
              final entry = allEntries[i];
              return ListTile(
                title: Text('${entry.english} → ${entry.spanish}'),
                onTap: () {
                  onUserCorrection(symbol, entry.spanish);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Learned!')),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void onUserCorrection(DetectedSymbol wrongDetection, String correctLabel) {
    final correction = UserCorrection(
      drawnStrokes: wrongDetection.strokes,
      correctedLabel: correctLabel,
      timestamp: DateTime.now(),
    );
    setState(() => userCorrections.add(correction));

    // Save immediately via the correction service
    BackendManager().correctionService.saveCorrections();
  }

  // ==================== LIFECYCLE ====================
  @override
  void initState() {
    super.initState();

    // Access all services through BackendManager
    final backend = BackendManager();

    libraryStructure = backend.libraryService.rootFolders;
    notebook = backend.notebookService.notebookManager;
    userCorrections = backend.correctionService.corrections;


    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _startAutoDetection();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _stopAutoDetection();
    super.dispose();
  }


  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {    
    return Scaffold(
      backgroundColor: Colors.grey[300],
      appBar: AppBar(
        backgroundColor: Colors.grey[300],
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Hello, $_userName!',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: Colors.black),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        // Switches between returning Spanish and English
        actions: [
          // Delete page button in top right
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () {
              setState(() => notebook.deleteCurrentPage());
            },
            tooltip: 'Delete Page',
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                Text(
                  'EN',
                  style: TextStyle(
                    color: showSpanish ? Colors.grey : Colors.black,
                    fontWeight: showSpanish ? FontWeight.normal : FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Switch(
                  value: showSpanish,
                  onChanged: (value) {
                    setState(() {
                      showSpanish = value;
                    });
                    print('Switched to: ${showSpanish ? "Spanish" : "English"}');

                    // UPDATE EXISTING DETECTIONS
                    _updateDetectionLanguage();
                  },
                  activeThumbColor: Colors.blue,
                  inactiveThumbColor: Colors.blue,
                ),
                Text(
                  'ES',
                  style: TextStyle(
                    color: showSpanish ? Colors.black : Colors.grey,
                    fontWeight: showSpanish ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
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
              title: const Text('Library', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LibraryScreen()
                  ),
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
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.white),
              title: const Text('Settings', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SettingsScreen()),
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
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                ); 
              }
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
              flex: 50,
              child: Material(
                elevation: 4,
                child: Column(
                  children: [
                    
                    // Canvas
                    Expanded(
                      child: Stack(
                        children: [
                          // Lined paper background
                          CustomPaint(
                            painter: LinedPaperPainter(),
                            child: Container(), // required to give it size
                          ),

                          // Your existing canvas on top
                          GestureDetector(
                            onPanStart: _onPanStart,
                            onPanUpdate: _onPanUpdate,
                            onPanEnd: _onPanEnd,
                            child: SizedBox.expand(
                              child: CustomPaint(
                                painter: CanvasPainter(
                                  strokes: notebook.currentPage.strokes,
                                  currentStroke: currentStrokePoints,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Navigation buttons and page counter
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Previous page arrow
                          IconButton(
                            icon: const Icon(Icons.arrow_back, size: 28),
                            onPressed: () {
                              setState(() => notebook.prevPage());
                            },
                            tooltip: 'Previous Page',
                          ),
                          const SizedBox(width: 20),
                          // Page counter
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Page ${notebook.currentIndex + 1}/${notebook.pages.length}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          // Next page arrow
                          IconButton(
                            icon: const Icon(Icons.arrow_forward, size: 28),
                            onPressed: () {
                              setState(() => notebook.nextPage());
                            },
                            tooltip: 'Next Page',
                          ),
                        ],
                      ),
                    ),

                    // Canvas Edit Buttons
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const VerticalDivider(width: 1, color: Colors.grey),
            
            // Right side - transcript
            Expanded(
              flex: 50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Transcript Header
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Transcript',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // Transcript Content
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(16),
                      child: detectedSymbols.isEmpty
                          ? Center(
                              child: Text(
                                'Draw symbols to see\nthem detected here',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            )
                          : DetectionVisualizer(
                              detectedSymbols: detectedSymbols,
                              canvasSize: Size(
                                MediaQuery.of(context).size.width * 0.6,
                                MediaQuery.of(context).size.height - 200,
                              ),
                              onSymbolTap: (symbol) {
                                _showCorrectionDialog(symbol);
                              },
                            ),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

// ==================== DETECTION VISUALIZER ====================
class DetectionVisualizer extends StatelessWidget {
  final List<DetectedSymbol> detectedSymbols;
  final Size canvasSize;
  final Function(DetectedSymbol) onSymbolTap;

  const DetectionVisualizer({
    super.key,
    required this.detectedSymbols,
    required this.canvasSize,
    required this.onSymbolTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final visualizerSize = Size(constraints.maxWidth, constraints.maxHeight);
        
        return GestureDetector(
          onTapUp: (details) {
            _handleTap(details.localPosition, visualizerSize);
          },
          child: CustomPaint(
            size: visualizerSize,
            painter: DetectionPainter(
              detectedSymbols: detectedSymbols,
              canvasSize: canvasSize,
              visualizerSize: visualizerSize,
            ),
          ),
        );
      },
    );
  }

  void _handleTap(Offset tapPosition, Size visualizerSize) {
    // Convert tap position to canvas coordinates
    final scaleX = canvasSize.width / visualizerSize.width;
    final scaleY = canvasSize.height / visualizerSize.height;
    
    final canvasX = tapPosition.dx * scaleX;
    final canvasY = tapPosition.dy * scaleY;

    // Find which symbol was tapped
    for (var symbol in detectedSymbols) {
      if (canvasX >= symbol.x1 && 
          canvasX <= symbol.x2 && 
          canvasY >= symbol.y1 && 
          canvasY <= symbol.y2) {
        onSymbolTap(symbol);
        break;
      }
    }
  }
}

class DetectionPainter extends CustomPainter {
  final List<DetectedSymbol> detectedSymbols;
  final Size canvasSize;
  final Size visualizerSize;

  DetectionPainter({
    required this.detectedSymbols,
    required this.canvasSize,
    required this.visualizerSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate scale factors
    final scaleX = visualizerSize.width / canvasSize.width;
    final scaleY = visualizerSize.height / canvasSize.height;

    // Draw background grid (optional, for reference)
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.1)
      ..strokeWidth = 1;

    for (int i = 0; i < 10; i++) {
      final x = (visualizerSize.width / 10) * i;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, visualizerSize.height),
        gridPaint,
      );
    }

    for (int i = 0; i < 10; i++) {
      final y = (visualizerSize.height / 10) * i;
      canvas.drawLine(
        Offset(0, y),
        Offset(visualizerSize.width, y),
        gridPaint,
      );
    }

    // Draw each detected symbol
    for (var symbol in detectedSymbols) {
      // Scale coordinates to visualizer space
      final x1 = symbol.x1 * scaleX;
      final y1 = symbol.y1 * scaleY;
      final x2 = symbol.x2 * scaleX;
      final y2 = symbol.y2 * scaleY;

      final rect = Rect.fromLTRB(x1, y1, x2, y2);

      // Calculate font size based on the actual symbol dimensions
      // Use the smaller dimension to ensure text fits
      final minDimension = rect.width < rect.height ? rect.width : rect.height;
      final fontSize = (minDimension * 0.7).clamp(8.0, 32.0);

      // Draw label
      final textPainter = TextPainter(
        text: TextSpan(
          text: symbol.label,
          style: TextStyle(
            color: Colors.black,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      // Center text in bounding box
      final textX = x1 + (rect.width - textPainter.width) / 2;
      final textY = y1 + (rect.height - textPainter.height) / 2;

      textPainter.paint(canvas, Offset(textX, textY));
    }
  }

  @override
  bool shouldRepaint(DetectionPainter oldDelegate) {
    return oldDelegate.detectedSymbols != detectedSymbols ||
           oldDelegate.canvasSize != canvasSize ||
           oldDelegate.visualizerSize != visualizerSize;
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
      ..strokeWidth = BackendManager().settingsService.penWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Draw saved strokes
    for (final stroke in strokes) {
      for (int i = 0; i < stroke.points.length - 1; i++) {
        canvas.drawLine(stroke.points[i], stroke.points[i + 1], paint);
      }
    }

    // Draw current stroke
    for (int i = 0; i < currentStroke.length - 1; i++) {
      canvas.drawLine(currentStroke[i], currentStroke[i + 1], paint);
    }
  }

  @override
  bool shouldRepaint(CanvasPainter oldDelegate) => true;
}
