import 'package:flutter/material.dart';

// ==================== ADAPTIVE LEARNING SYSTEM ====================

// Store user corrections for adaptive learning
class UserCorrection {
  final List<Stroke> drawnStrokes;
  final String correctedLabel;
  final DateTime timestamp;

  UserCorrection({
    required this.drawnStrokes,
    required this.correctedLabel,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'drawnStrokes': drawnStrokes.map((s) => {
      'points': s.points.map((p) => {'dx': p.dx, 'dy': p.dy}).toList(),
      'startTime': s.startTime.millisecondsSinceEpoch,
      'endTime': s.endTime.millisecondsSinceEpoch,
    }).toList(),
    'correctedLabel': correctedLabel,
    'timestamp': timestamp.millisecondsSinceEpoch,
  };

  factory UserCorrection.fromJson(Map<String, dynamic> json) {
    return UserCorrection(
      drawnStrokes: (json['drawnStrokes'] as List).map((strokeJson) {
        return Stroke(
          points: (strokeJson['points'] as List)
              .map((p) => Offset(p['dx'], p['dy']))
              .toList(),
          startTime: DateTime.fromMillisecondsSinceEpoch(strokeJson['startTime']),
          endTime: DateTime.fromMillisecondsSinceEpoch(strokeJson['endTime']),
        );
      }).toList(),
      correctedLabel: json['correctedLabel'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
    );
  }
}


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

  /// Convert Stroke to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'points': points
          .map((p) => {'dx': p.dx, 'dy': p.dy})
          .toList(),
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime.millisecondsSinceEpoch,
    };
  }

  /// Construct Stroke from JSON
  factory Stroke.fromJson(Map<String, dynamic> json) {
    List<Offset> points = (json['points'] as List)
        .map((p) => Offset(p['dx'], p['dy']))
        .toList();
    return Stroke(
      points: points,
      startTime: DateTime.fromMillisecondsSinceEpoch(json['startTime']),
      endTime: DateTime.fromMillisecondsSinceEpoch(json['endTime']),
    );
  }

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
