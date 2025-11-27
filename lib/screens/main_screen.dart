import 'dart:async';
import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'login_screen.dart';
import 'symbols_screen.dart';
import 'settings_screen.dart';
import 'library_screen.dart';

import 'package:senior_project/models/notebook_models.dart';
import 'package:senior_project/models/library_models.dart';
import 'package:senior_project/models/strokes_models.dart';
import 'package:senior_project/models/user_data_manager_models.dart';
import 'package:senior_project/services/drawing_settings.dart';

import 'dart:math' as math;
import 'dart:convert';

// ==================== MAIN PAGE ====================

class MainPage extends StatefulWidget {
  final String userID;
  final List<FolderItem>? libraryStructure;
  final List<UserCorrection>? userCorrections;

  const MainPage({
    super.key, 
    required this.userID,
    this.libraryStructure,
    this.userCorrections,
  });

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with SingleTickerProviderStateMixin {
  
  // final FirebaseAuth _auth = FirebaseAuth.instance;

  late String userID;
  // ==================== SETTINGS ====================
  
  // These are now loaded from user preferences instead of static constants
  double TIME_THRESHOLD_MS = 700;    // Strokes within this time = same symbol
  double SPATIAL_THRESHOLD_PX = 2500; // Squared distance (50px * 50px)
  double MIN_SYMBOL_SIZE = 100;       // Minimum area (px²) for valid symbol
  
  // ==================== STATE ====================
  Timer? _autoDetectTimer;
  bool _isDetecting = false;
  int _lastStrokeCount = 0;


  bool showSpanish = true; // true = Spanish, false = English


  List<FolderItem> libraryStructure = [];
  List<UserCorrection> userCorrections = [];
  var notebook = NotebookManager();

  List<DetectedSymbol> detectedSymbols = [];
  List<Offset> currentStrokePoints = [];
  DateTime? currentStrokeStartTime;
  
  late AnimationController _animationController;

  // ==================== HELPER METHODS ====================

  /// Recursively collect all checked glossaries from the folder structure
  List<GlossaryItem> _getCheckedGlossaries() {
    List<GlossaryItem> checkedGlossaries = [];
    
    void collectFromFolder(FolderItem folder) {
      // If folder is not checked, skip it and its children
      if (!folder.isChecked) return;
      
      for (var child in folder.children) {
        if (child is FolderItem) {
          // Recursively collect from subfolders
          collectFromFolder(child);
        } else if (child is GlossaryItem) {
          // Add checked glossaries
          if (child.isChecked) {
            checkedGlossaries.add(child);
          }
        }
      }
    }
    
    // Start collecting from all root folders
    for (var rootFolder in libraryStructure) {
      collectFromFolder(rootFolder);
    }
    
    return checkedGlossaries;
  }

  // ==================== AUTO-DETECTION ====================

  void _startAutoDetection() {
    _autoDetectTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) async {
      // Only detect if strokes changed and we're not already detecting
      if (!_isDetecting && notebook.currentPage.strokes.length != _lastStrokeCount) {
        _lastStrokeCount = notebook.currentPage.strokes.length;
        
        // Wait a bit to see if user is still drawing
        await Future.delayed(const Duration(milliseconds: 400));
        
        // If stroke count changed again, user is still drawing - skip detection
        if (notebook.currentPage.strokes.length != _lastStrokeCount) {
          return;
        }
        
        // User paused - run detection
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

      print('Stroke completed: ${stroke.points.length} points');
      
      currentStrokePoints = [];
      currentStrokeStartTime = null;
    }
  }

  // ==================== SYMBOL DETECTION ====================

  Future<void> detectSymbols() async {
    if (notebook.currentPage.strokes.isEmpty) {
      setState(() {
        detectedSymbols.clear();
      });
      print('No strokes to detect');
      return;
    }

    print('\nStarting detection with ${notebook.currentPage.strokes.length} strokes...');

    // Step 1: Cluster strokes into symbol groups
    List<SymbolCluster> clusters = _clusterStrokes(notebook.currentPage.strokes);
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

      print('Added detection: "$matchedLabel" (length: ${matchedLabel.length})'); // ADD THIS

    }

    setState(() {
      detectedSymbols = newDetections;
    });

    print('Detected ${newDetections.length} symbols');
  }

  // ==================== IMPROVED COMPARISON ALGORITHM ====================

  Future<String> comparingCheckedGlossaries(SymbolCluster cluster) async {

    // Get all checked glossaries from the folder structure
    final checkedGlossaries = _getCheckedGlossaries();

    if (checkedGlossaries.isEmpty) {
      print("No checked glossaries available.");
      return "??";
    }

    // Collect all entries from checked glossaries that have strokes
    List<GlossaryEntry> allEntries = [];
    for (var glossary in checkedGlossaries) {
      // Only include entries that have strokes data
      allEntries.addAll(glossary.entries.where((entry) => 
        entry.strokes != null && entry.strokes!.isNotEmpty
      ));
    }

    if (allEntries.isEmpty) {
      print("No glossary entries with strokes available in checked glossaries.");
      return "??";
    }

    final currentSymbolStrokes = cluster.strokes;

    // Normalize the input cluster
    final normalizedInput = _normalizeStrokeSet(currentSymbolStrokes);

    double bestScore = 0.0;
    String bestMatch = "??";
    String bestMatchEnglish = "";
    String bestMatchSpanish = "";  // Track both

    print('\nComparing against ${allEntries.length} entries from ${checkedGlossaries.length} checked glossaries...');

    // Check user corrections first (adaptive learning!)
    for (var correction in userCorrections) {
      final normalizedCorrection = _normalizeStrokeSet(correction.drawnStrokes);
      final similarity = _advancedStrokeComparison(normalizedInput, normalizedCorrection);
      
      if (similarity > bestScore) {
        bestScore = similarity;
        // Find the entry that matches this correction
        for (var entry in allEntries) {
          if (entry.spanish == correction.correctedLabel || entry.english == correction.correctedLabel) {
            bestMatch = entry.spanish;
            bestMatchEnglish = entry.english;
            print('Learned variation matched! ${entry.english} → ${entry.spanish} (score: ${similarity.toStringAsFixed(3)})');
            break;
          }
        }
      }
    }

    // Check glossary entries with strokes
    for (final entry in allEntries) {
      if (entry.strokes == null || entry.strokes!.isEmpty) continue;

      final normalizedEntry = _normalizeStrokeSet(entry.strokes!);
      final similarity = _advancedStrokeComparison(normalizedInput, normalizedEntry);

      if (similarity > bestScore) {
        bestScore = similarity;
        bestMatchSpanish = entry.spanish;
        bestMatchEnglish = entry.english;
      }
    }

    // Return based on switch state
    bestMatch = showSpanish ? bestMatchSpanish : bestMatchEnglish;

    print('Best match: $bestMatchEnglish → $bestMatchSpanish (score: ${bestScore.toStringAsFixed(3)})');
    print('Returning: ${showSpanish ? "Spanish" : "English"} → $bestMatch');

    return bestScore > 0.6 ? bestMatch : "??";
  }

  // ==================== NORMALIZATION ====================

  List<Stroke> _normalizeStrokeSet(List<Stroke> strokes) {
    if (strokes.isEmpty) return [];

    // Find overall bounding box
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (var stroke in strokes) {
      for (var point in stroke.points) {
        if (point.dx < minX) minX = point.dx;
        if (point.dy < minY) minY = point.dy;
        if (point.dx > maxX) maxX = point.dx;
        if (point.dy > maxY) maxY = point.dy;
      }
    }

    final width = maxX - minX;
    final height = maxY - minY;

    if (width == 0 || height == 0) return strokes;

    // Normalize to [0, 1] range
    return strokes.map((stroke) {
      final normalizedPoints = stroke.points.map((point) {
        return Offset(
          (point.dx - minX) / width,
          (point.dy - minY) / height,
        );
      }).toList();

      return Stroke(
        points: normalizedPoints,
        startTime: stroke.startTime,
        endTime: stroke.endTime,
      );
    }).toList();
  }

  // ==================== ADVANCED COMPARISON ====================

  double _advancedStrokeComparison(List<Stroke> set1, List<Stroke> set2) {
    // Feature 1: Stroke count similarity (0.15 weight)
    final strokeCountDiff = (set1.length - set2.length).abs();
    final maxStrokes = math.max(set1.length, set2.length);
    final strokeCountScore = 1.0 - (strokeCountDiff / maxStrokes);

    // Feature 2: Shape similarity (0.70 weight)
    double totalShapeSimilarity = 0.0;
    int comparisonCount = 0;

    for (var stroke1 in set1) {
      double bestMatch = 0.0;
      for (var stroke2 in set2) {
        final similarity = _compareIndividualStrokes(stroke1, stroke2);
        if (similarity > bestMatch) {
          bestMatch = similarity;
        }
      }
      totalShapeSimilarity += bestMatch;
      comparisonCount++;
    }

    final shapeSimilarity = comparisonCount > 0 ? totalShapeSimilarity / comparisonCount : 0.0;

    // Feature 3: Directional flow (0.15 weight)
    final directionScore = _compareDirectionalFlow(set1, set2);

    // Weighted combination
    final finalScore = (strokeCountScore * 0.15) + 
                      (shapeSimilarity * 0.70) + 
                      (directionScore * 0.15);

    return finalScore.clamp(0.0, 1.0);
  }

  double _compareIndividualStrokes(Stroke stroke1, Stroke stroke2) {
    // Resample both strokes to same number of points
    const targetPoints = 32; // Standard resampling size
    
    final resampled1 = _resampleStroke(stroke1.points, targetPoints);
    final resampled2 = _resampleStroke(stroke2.points, targetPoints);

    // Calculate average Euclidean distance
    double totalDistance = 0.0;
    for (int i = 0; i < targetPoints; i++) {
      final dx = resampled1[i].dx - resampled2[i].dx;
      final dy = resampled1[i].dy - resampled2[i].dy;
      totalDistance += math.sqrt(dx * dx + dy * dy);
    }

    final avgDistance = totalDistance / targetPoints;

    // Convert distance to similarity (exponential decay)
    // distance=0 → similarity=1.0, distance=1 → similarity≈0.01
    final similarity = math.exp(-avgDistance * 4.5);

    return similarity.clamp(0.0, 1.0);
  }

  List<Offset> _resampleStroke(List<Offset> points, int targetCount) {
    if (points.length <= 1) return points;
    if (targetCount <= 1) return [points.first];

    // Calculate path length
    double totalLength = 0.0;
    List<double> segmentLengths = [];
    
    for (int i = 1; i < points.length; i++) {
      final dx = points[i].dx - points[i-1].dx;
      final dy = points[i].dy - points[i-1].dy;
      final length = math.sqrt(dx * dx + dy * dy);
      segmentLengths.add(length);
      totalLength += length;
    }

    if (totalLength == 0) return points;

    // Resample at uniform intervals
    final segmentLength = totalLength / (targetCount - 1);
    List<Offset> resampled = [points.first];

    double accumulatedLength = 0.0;
    int currentSegment = 0;

    for (int i = 1; i < targetCount - 1; i++) {
      final targetLength = segmentLength * i;

      while (currentSegment < segmentLengths.length && 
            accumulatedLength + segmentLengths[currentSegment] < targetLength) {
        accumulatedLength += segmentLengths[currentSegment];
        currentSegment++;
      }

      if (currentSegment >= segmentLengths.length) break;

      // Interpolate point on current segment
      final remainingLength = targetLength - accumulatedLength;
      final t = remainingLength / segmentLengths[currentSegment];
      
      final p1 = points[currentSegment];
      final p2 = points[currentSegment + 1];
      
      final interpolated = Offset(
        p1.dx + (p2.dx - p1.dx) * t,
        p1.dy + (p2.dy - p1.dy) * t,
      );

      resampled.add(interpolated);
    }

    resampled.add(points.last);
    return resampled;
  }

  double _compareDirectionalFlow(List<Stroke> set1, List<Stroke> set2) {
    // Calculate average stroke direction for each set
    Offset avgDirection1 = _calculateAverageDirection(set1);
    Offset avgDirection2 = _calculateAverageDirection(set2);

    // Calculate similarity (dot product normalized)
    final dotProduct = avgDirection1.dx * avgDirection2.dx + 
                      avgDirection1.dy * avgDirection2.dy;
    
    return ((dotProduct + 1.0) / 2.0).clamp(0.0, 1.0); // Map [-1,1] to [0,1]
  }

  Offset _calculateAverageDirection(List<Stroke> strokes) {
    double totalDx = 0.0;
    double totalDy = 0.0;
    int count = 0;

    for (var stroke in strokes) {
      if (stroke.points.length < 2) continue;
      
      final start = stroke.points.first;
      final end = stroke.points.last;
      
      totalDx += end.dx - start.dx;
      totalDy += end.dy - start.dy;
      count++;
    }

    if (count == 0) return Offset.zero;

    final magnitude = math.sqrt(totalDx * totalDx + totalDy * totalDy);
    if (magnitude == 0) return Offset.zero;

    return Offset(totalDx / magnitude, totalDy / magnitude);
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
      notebook.currentPage.strokes.clear();
      currentStrokePoints = [];
      currentStrokeStartTime = null;
      _lastStrokeCount = 0; // RESET COUNTER
    });
    print("Canvas cleared");
  }

  void undoStroke() {
    if (notebook.currentPage.strokes.isNotEmpty) {
      setState(() {
        notebook.currentPage.strokes.removeLast();
      });
      print("Undo stroke");
    }
  }

  Future<void> _updateDetectionLanguage() async {
    if (detectedSymbols.isEmpty) return;

    print('\nUpdating ${detectedSymbols.length} detections to ${showSpanish ? "Spanish" : "English"}...');

    List<DetectedSymbol> updatedDetections = [];

    // Get all entries from checked glossaries
    final checkedGlossaries = _getCheckedGlossaries();
    print('[MainScreen] Checked glossaries:');
    for (var g in checkedGlossaries) {
      print('  - "${g.name}": ${g.entries.length} entries loaded');
    }

    List<GlossaryEntry> allEntries = [];
    for (var glossary in checkedGlossaries) {
      allEntries.addAll(glossary.entries);
    }

    for (var symbol in detectedSymbols) {
      // Find the matching glossary entry for this symbol
      String newLabel = symbol.label; // Default to current label
      
      for (var entry in allEntries) {
        // Check if this detection matches this glossary entry
        bool matches = false;
        
        if (showSpanish) {
          // Switching TO Spanish - check if current label is English
          if (entry.english == symbol.label) {
            matches = true;
            newLabel = entry.spanish;
          }
        } else {
          // Switching TO English - check if current label is Spanish
          if (entry.spanish == symbol.label) {
            matches = true;
            newLabel = entry.english;
          }
        }
        
        if (matches) {
          print('  ${symbol.label} → $newLabel');
          break;
        }
      }

      // Create updated detection with new label
      updatedDetections.add(DetectedSymbol(
        label: newLabel,
        confidence: symbol.confidence,
        x1: symbol.x1,
        y1: symbol.y1,
        x2: symbol.x2,
        y2: symbol.y2,
        strokes: symbol.strokes,
      ));
    }

    setState(() {
      detectedSymbols = updatedDetections;
    });

    print('Updated all detections');
  }

  // ==================== USER CORRECTION SYSTEM ====================

  void _showCorrectionDialog(DetectedSymbol symbol) async {
    // Get all entries from checked glossaries
    final checkedGlossaries = _getCheckedGlossaries();
    List<GlossaryEntry> allEntries = [];
    for (var glossary in checkedGlossaries) {
      allEntries.addAll(glossary.entries);
    }

    if (allEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No glossary entries available. Please check some glossaries.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Correct Detection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Detected as: ${symbol.label}'),
            const SizedBox(height: 16),
            const Text('What should it be?'),
            const SizedBox(height: 8),
            SizedBox(
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
                        const SnackBar(content: Text('Learned! Will remember this variation.')),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Call this when user manually corrects a detection
  void onUserCorrection(DetectedSymbol wrongDetection, String correctLabel) {
    final correction = UserCorrection(
      drawnStrokes: wrongDetection.strokes,
      correctedLabel: correctLabel,
      timestamp: DateTime.now(),
    );

    setState(() {
      userCorrections.add(correction);
    });

    _saveUserCorrections();
    
    print('Learned correction: ${wrongDetection.label} → $correctLabel');
    print('Total learned variations: ${userCorrections.length}');
  }
  
  // ==================== LIFECYCLE ====================

  @override
  void initState() {
    super.initState();

    // Initialize from widget parameters or load from manager
    userID = widget.userID;
    libraryStructure = widget.libraryStructure ?? UserDataManager().libraryRootFolders;
    userCorrections = widget.userCorrections ?? UserDataManager().corrections;
    notebook = UserDataManager().notebookManager;


    // If data wasn't provided and user is logged in, load it
    if ((libraryStructure.isEmpty || userCorrections.isEmpty) && userID != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await UserDataManager().loadUserData(userID!);
        setState(() {
          libraryStructure = UserDataManager().libraryRootFolders;
          userCorrections = UserDataManager().corrections;
          notebook = UserDataManager().notebookManager;

        });
      });
    }



    // Animation controller for any UI transitions
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _startAutoDetection(); // START AUTO-DETECTION

    // Check which glossaries are active
    final checkedGlossaries = _getCheckedGlossaries();
  

    print('MainPage initialized with ${checkedGlossaries.length} checked glossaries');
    print('MainPage initialized with ${userCorrections.length} corrections');

  }

  Future<void> _saveUserCorrections() async {
    final prefs = await SharedPreferences.getInstance();
    final serialized = userCorrections.map((c) => jsonEncode(c.toJson())).toList();
    await prefs.setStringList('user_corrections', serialized);
    print('Saved ${userCorrections.length} user corrections');

  }

  @override
  void dispose() {
    _animationController.dispose();
    _stopAutoDetection(); // STOP AUTO-DETECTION
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
          "Strokes: ${notebook.currentPage.strokes.length} | Symbols: ${detectedSymbols.length}", 
          style: const TextStyle(color: Colors.black, fontSize: 14),
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
              setState(() => notebook.deleteCurrentPage(userID));
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
                  MaterialPageRoute(builder: (context) => SettingsScreen(userID: userID)),
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
                      child: GestureDetector(
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
                              setState(() => notebook.prevPage(userID));
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
                              setState(() => notebook.nextPage(userID));
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
            
            // Right side - spatial visualization
            Expanded(
              flex: 50,
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
                              'Draw symbols to see\nthem detected here',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
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
      ..strokeWidth = drawingSettings.penWidth    // <<< HERE
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
