import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'glossary_backend.dart';
import 'main_page.dart'; // For Stroke and CanvasPainter

class GlossaryScreen extends StatefulWidget {
  @override
  _GlossaryScreenState createState() => _GlossaryScreenState();
}

class _GlossaryScreenState extends State<GlossaryScreen> {
  // State Variables
  final Glossary glossary = Glossary();
  int? editingIndex;
  bool showCanvas = false;

  // Canvas state
  final GlobalKey _canvasKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  List<Stroke> currentSymbolStrokes = [];
  List<Offset> currentStrokePoints = [];
  DateTime? currentStrokeStartTime;

  // Text input controller for editing cells
  final TextEditingController _editController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadGlossary(); // Add this
    glossary.printAllEntries(); // This should show spanish values
  }

  Future<void> _loadGlossary() async {
    await glossary.loadFromPrefs();
    setState(() {}); // Refresh UI
    glossary.printAllEntries(); // Debug: see what loaded
  }

  // ===================== CANVAS LOGIC =====================
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
        currentSymbolStrokes.add(stroke);
        currentStrokePoints = [];
        currentStrokeStartTime = null;
      });
    }
  }

  void _clearCanvas() {
    setState(() {
      currentSymbolStrokes.clear();
      currentStrokePoints.clear();
      currentStrokeStartTime = null;
    });
  }

  void _undoStroke() {
    if (currentSymbolStrokes.isNotEmpty) {
      setState(() {
        currentSymbolStrokes.removeLast();
      });
    }
  }

  Future<Uint8List?> _captureCanvas() async {
    try {
      RenderRepaintBoundary boundary =
          _canvasKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint("Error capturing canvas: $e");
      return null;
    }
  }

  void _saveSymbol() async {
    Uint8List? imageData = await _captureCanvas();
    if (editingIndex != null && imageData != null) {
      setState(() {
        glossary.entries[editingIndex!].symbolImage = imageData;
        glossary.entries[editingIndex!].strokes =
            List.from(currentSymbolStrokes);
        showCanvas = false;
        editingIndex = null;
      });
      _clearCanvas();
      glossary.saveToPrefs();
    }
  }

  // ===================== CELL LOGIC =====================
  void _onCellTap(int rowIndex, int columnIndex) {
    if (columnIndex == 4) {
      final entry = glossary.entries[rowIndex];
      if (entry.symbolImage != null) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Current Symbol'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.memory(
                  entry.symbolImage!,
                  width: 600,
                  height: 400,
                  fit: BoxFit.contain,
                ),
                SizedBox(height: 16),
                Text('What would you like to do?',
                    style: TextStyle(fontSize: 18)),
              ],
            ),
            actionsAlignment: MainAxisAlignment.spaceEvenly,
            actionsPadding:
                EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(foregroundColor: Colors.black),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    entry.symbolImage = null;
                    entry.strokes = [];
                  });
                  Navigator.pop(context);
                  glossary.saveToPrefs();
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text('Delete Symbol'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    editingIndex = rowIndex;
                    showCanvas = true;
                  });
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black),
                child: Text('Replace Drawing'),
              ),
            ],
          ),
        );
      } else {
        setState(() {
          editingIndex = rowIndex;
          showCanvas = true;
        });
      }
    } else {
      // Text editing (same as before)
      String currentValue = '';
      switch (columnIndex) {
        case 0:
          currentValue = glossary.entries[rowIndex].english;
          break;
        case 1:
          currentValue = glossary.entries[rowIndex].spanish;
          break;
        case 2:
          currentValue = glossary.entries[rowIndex].definition;
          break;
        case 3:
          currentValue = glossary.entries[rowIndex].synonym;
          break;
      }
      _editController.text = currentValue;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text(
            ['English', 'Spanish', 'Definition', 'Synonym'][columnIndex],
            style: TextStyle(color: Colors.black),
          ),
          content: TextField(
            controller: _editController,
            autofocus: true,
            style: TextStyle(color: Colors.black),
            decoration: InputDecoration(
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(foregroundColor: Colors.black),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  switch (columnIndex) {
                    case 0:
                      glossary.entries[rowIndex].english = _editController.text;
                      break;
                    case 1:
                      glossary.entries[rowIndex].spanish = _editController.text;
                      break;
                    case 2:
                      glossary.entries[rowIndex].definition =
                          _editController.text;
                      break;
                    case 3:
                      glossary.entries[rowIndex].synonym =
                          _editController.text;
                      break;
                  }
                });
                glossary.saveToPrefs();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              child: Text('Save'),
            ),
          ],
        ),
      );
    }
  }

  // ===================== ENTRY MANAGEMENT =====================
  void _addNewEntry() {
    setState(() {
      glossary.addEntry('', '', '', '');
    });
    glossary.saveToPrefs();
    Future.delayed(Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ===================== BUILD =====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Glossary"),
        backgroundColor: Colors.grey[800],
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: showCanvas ? _buildCanvasView() : _buildTableView(),
    );
  }

  Widget _buildTableView() {
    return Column(
      children: [
        Container(
          color: Colors.black,
          child: Row(
            children: [
              _buildHeaderCell('English', flex: 2),
              _buildHeaderCell('Spanish', flex: 2),
              _buildHeaderCell('Definition', flex: 3),
              _buildHeaderCell('Synonym', flex: 2),
              _buildHeaderCell('Symbol', flex: 1),
              SizedBox(width: 48),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemCount: glossary.entries.length,
            itemBuilder: (context, index) {
              final entry = glossary.entries[index];
              return Container(
                decoration: BoxDecoration(
                  border:
                      Border(bottom: BorderSide(color: Colors.grey[400]!)),
                ),
                child: Row(
                  children: [
                    _buildDataCell(entry.english, index, 0, flex: 2),
                    _buildDataCell(entry.spanish, index, 1, flex: 2),
                    _buildDataCell(entry.definition, index, 2, flex: 3),
                    _buildDataCell(entry.synonym, index, 3, flex: 2),
                    _buildSymbolCell(entry, index, flex: 1),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          glossary.deleteEntry(index);
                        });
                        glossary.saveToPrefs();
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: FloatingActionButton(
            onPressed: _addNewEntry,
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            child: Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCell(String title, {int flex = 1}) => Expanded(
        flex: flex,
        child: Container(
          padding: EdgeInsets.all(12),
          child: Text(title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.white)),
        ),
      );

  Widget _buildDataCell(String text, int rowIndex, int columnIndex,
          {int flex = 1}) =>
      Expanded(
        flex: flex,
        child: InkWell(
          onTap: () => _onCellTap(rowIndex, columnIndex),
          child: Container(
            padding: EdgeInsets.all(12),
            height: 56,
            alignment: Alignment.center,
            child: Text(
              text.isEmpty ? '➕' : text,
              style: TextStyle(
                  color: text.isEmpty ? Colors.grey : Colors.black,
                  fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );

  Widget _buildSymbolCell(GlossaryEntry entry, int rowIndex,
          {int flex = 1}) =>
      Expanded(
        flex: flex,
        child: InkWell(
          onTap: () => _onCellTap(rowIndex, 4),
          child: Container(
            padding: EdgeInsets.all(8),
            height: 56,
            alignment: Alignment.center,
            child: entry.symbolImage != null
                ? Image.memory(entry.symbolImage!, width: 40, height: 40)
                : Icon(Icons.draw, color: Colors.grey),
          ),
        ),
      );

  Widget _buildCanvasView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Text('Draw Symbol:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Spacer(),
              IconButton(icon: Icon(Icons.undo), onPressed: _undoStroke),
              IconButton(icon: Icon(Icons.clear), onPressed: _clearCanvas),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              color: Colors.white,
            ),
            child: RepaintBoundary(
              key: _canvasKey,
              child: GestureDetector(
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: CustomPaint(
                  painter: CanvasPainter(
                    strokes: currentSymbolStrokes,
                    currentStroke: currentStrokePoints,
                  ),
                  child: Container(),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    showCanvas = false;
                    editingIndex = null;
                  });
                  _clearCanvas();
                },
                style: TextButton.styleFrom(foregroundColor: Colors.black),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _saveSymbol,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
                child: Text('Save Symbol'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _editController.dispose();
    super.dispose();
  }
}
