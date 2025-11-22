import 'package:flutter/material.dart';

class DrawingSettings extends ChangeNotifier {
  double _penWidth = 10.0; // DEFAULT WIDTH

  double get penWidth => _penWidth;

  void setPenWidth(double newWidth) {
    _penWidth = newWidth;
    notifyListeners(); // tells all canvases to rebuild
  }
}

// GLOBAL instance
final drawingSettings = DrawingSettings();
