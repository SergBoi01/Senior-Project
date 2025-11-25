import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../screens/main_screen.dart';
import '../models/library_models.dart';
import '../models/strokes_models.dart';
import '../services/glossary_service.dart';

class GlossaryScreen extends StatefulWidget {
  final GlossaryItem? glossaryItem;

  const GlossaryScreen({super.key, this.glossaryItem});

  @override
  _GlossaryScreenState createState() => _GlossaryScreenState();
}

class _GlossaryScreenState extends State<GlossaryScreen> {
  // State Variables
  late GlossaryItem glossaryItem;
  int? editingIndex;
  bool showCanvas = false;
  
  // Loading and error states - SEPARATED
  bool _isLoading = false;
  Set<int> _savingIndices = {}; // Track which entries are being saved
  Set<int> _deletingIndices = {}; // Track which entries are being deleted
  String? _errorMessage;
  
  // Firestore service
  final GlossaryService _glossaryService = GlossaryService();
  
  // Canvas/Drawing controllers
  final GlobalKey _canvasKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _editController = TextEditingController();

  // Stroke tracking for symbol detection
  List<Stroke> _currentStrokes = [];
  List<Offset> _currentStrokePoints = [];
  DateTime? _currentStrokeStartTime;

  @override
  void initState() {
    super.initState();
    if (widget.glossaryItem != null) {
      glossaryItem = widget.glossaryItem!;
      _loadEntries();
    } else {
      glossaryItem = GlossaryItem(
        id: 'temp',
        name: 'Glossary',
      );
    }
  }

  /// Load entries from Firestore
  Future<void> _loadEntries() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final entries = await _glossaryService.loadEntries(glossaryItem.id);
      setState(() {
        glossaryItem.entries = entries;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load entries: $e';
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage!)),
        );
      }
    }
  }

  /// Save entry to Firestore - NON-BLOCKING
  Future<void> _saveEntryToFirestore(int index) async {
    if (index < 0 || index >= glossaryItem.entries.length) return;

    setState(() {
      _savingIndices.add(index);
      _errorMessage = null;
    });

    try {
      // If the glossary has a temporary ID, it's a new glossary that needs to be created first.
      if (glossaryItem.id == 'temp') {
        // The parentId is not available on this screen, so new glossaries are created at the root.
        // The name may also be the default 'Glossary'. This is a limitation of the current architecture.
        final newId = await _glossaryService.createGlossary(glossaryItem);
        setState(() {
          glossaryItem = GlossaryItem(
            id: newId,
            name: glossaryItem.name,
            isChecked: glossaryItem.isChecked,
            parentId: glossaryItem.parentId,
            entries: glossaryItem.entries,
          );
        });
      }

      final entry = glossaryItem.entries[index];
      await _glossaryService.saveEntry(glossaryItem.id, entry, index);
      if (mounted) {
        setState(() {
          _savingIndices.remove(index);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to save entry: $e';
          _savingIndices.remove(index);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage!)),
        );
      }
    }
  }

  /// Delete entry - INDEPENDENT OPERATION
  Future<void> _deleteEntry(int index) async {
    final entry = glossaryItem.entries[index];
    
    setState(() {
      _deletingIndices.add(index);
    });

    try {
      if (entry.id != null) {
        await _glossaryService.deleteEntry(glossaryItem.id, entry.id!);
      }
      
      if (mounted) {
        setState(() {
          glossaryItem.deleteEntry(index);
          _deletingIndices.remove(index);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _deletingIndices.remove(index);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete entry: $e')),
        );
      }
    }
  }

  // Canvas/Symbol Methods
  
  Future<Uint8List?> _captureCanvas() async {
    try {
      RenderRepaintBoundary boundary =
          _canvasKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint("Error capturing canvas: $e");
      return null;
    }
  }

  void _saveSymbol() async {
    Uint8List? imageData = await _captureCanvas();
    
    if (editingIndex != null && imageData != null) {
      final index = editingIndex!;
      
      setState(() {
        glossaryItem.entries[index].symbolImage = imageData;
        glossaryItem.entries[index].strokes = List.from(_currentStrokes);
        showCanvas = false;
        editingIndex = null;
      });
      
      print('Saved symbol with ${_currentStrokes.length} strokes');
      
      // Clear everything
      _currentStrokes.clear();
      _currentStrokePoints.clear();
      _currentStrokeStartTime = null;
      
      // Save to Firestore in background
      _saveEntryToFirestore(index);
    }
  }

  // Cell Interaction Methods
  
  void _onCellTap(int rowIndex, int columnIndex) {
    if (columnIndex == 4) {
      final entry = glossaryItem.entries[rowIndex];
      
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
                if (entry.strokes != null && entry.strokes!.isNotEmpty)
                  Text(
                    '${entry.strokes!.length} stroke(s)',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                SizedBox(height: 8),
                Text(
                  'What would you like to do?',
                  style: TextStyle(fontSize: 18),
                ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.spaceEvenly,
            actionsPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: Text('Cancel', style: TextStyle(fontSize: 15)),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    entry.symbolImage = null;
                    entry.strokes = null;
                  });
                  Navigator.pop(context);
                  _saveEntryToFirestore(rowIndex);
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: Text('Delete Symbol', style: TextStyle(fontSize: 15)),
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
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: Text('Replace Drawing', style: TextStyle(fontSize: 15)),
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
      String currentValue = '';
      
      switch (columnIndex) {
        case 0:
          currentValue = glossaryItem.entries[rowIndex].english;
          break;
        case 1:
          currentValue = glossaryItem.entries[rowIndex].spanish;
          break;
        case 2:
          currentValue = glossaryItem.entries[rowIndex].definition;
          break;
        case 3:
          currentValue = glossaryItem.entries[rowIndex].synonym;
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
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
              return TextField(
                controller: _editController,
                autofocus: true,
                style: TextStyle(color: Colors.black),
                onChanged: (value) {
                  setDialogState(() {});
                },
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black, width: 2),
                  ),
                  suffixIcon: _editController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            setDialogState(() {
                              _editController.clear();
                            });
                          },
                        )
                      : null,
                ),
              );
            },
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
                      glossaryItem.entries[rowIndex].english = _editController.text;
                      break;
                    case 1:
                      glossaryItem.entries[rowIndex].spanish = _editController.text;
                      break;
                    case 2:
                      glossaryItem.entries[rowIndex].definition = _editController.text;
                      break;
                    case 3:
                      glossaryItem.entries[rowIndex].synonym = _editController.text;
                      break;
                  }
                });
                Navigator.pop(context);
                _saveEntryToFirestore(rowIndex);
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

  // Entry Management Methods
  
  void _addNewEntry() {
    final newEntry = GlossaryEntry(
      english: '',
      spanish: '',
      definition: '',
      synonym: '',
    );
    
    setState(() {
      glossaryItem.addEntry(newEntry);
    });
    
    final index = glossaryItem.entries.length - 1;
    _saveEntryToFirestore(index);

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

  // Build Methods
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(glossaryItem.name),
        backgroundColor: Colors.grey[800],
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          // Show indicator if ANY entry is being saved
          if (_savingIndices.isNotEmpty)
            Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : showCanvas
              ? _buildCanvasView()
              : _buildTableView(),
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
            itemCount: glossaryItem.entries.length,
            itemBuilder: (context, index) {
              final entry = glossaryItem.entries[index];
              final isDeleting = _deletingIndices.contains(index);
              
              return Container(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey[400]!)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildDataCell(entry.english, index, 0, flex: 2),
                    _buildDataCell(entry.spanish, index, 1, flex: 2),
                    _buildDataCell(entry.definition, index, 2, flex: 3),
                    _buildDataCell(entry.synonym, index, 3, flex: 2),
                    _buildSymbolCell(entry, index, flex: 1),
                    // Delete button - shows loading only for this row
                    isDeleting
                        ? Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                              ),
                            ),
                          )
                        : IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteEntry(index),
                          ),
                  ],
                ),
              );
            },
          ),
        ),
        
        // Add Button - ALWAYS ENABLED
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: FloatingActionButton(
            onPressed: _addNewEntry,
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            tooltip: 'Add new entry',
            child: Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCell(String title, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: EdgeInsets.all(12),
        child: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildDataCell(String text, int rowIndex, int columnIndex, {int flex = 1}) {
    return Expanded(
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
              fontSize: 13,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildSymbolCell(GlossaryEntry entry, int rowIndex, {int flex = 1}) {
    return Expanded(
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
  }

  Widget _buildCanvasView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Text(
                'Draw Symbol:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Spacer(),
              Text(
                '${_currentStrokes.length} stroke(s)',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              SizedBox(width: 16),
              IconButton(
                icon: Icon(Icons.undo),
                onPressed: () {
                  if (_currentStrokes.isNotEmpty) {
                    setState(() => _currentStrokes.removeLast());
                  }
                },
              ),
              IconButton(
                icon: Icon(Icons.clear),
                onPressed: () {
                  setState(() {
                    _currentStrokes.clear();
                    _currentStrokePoints.clear();
                  });
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              color: Colors.white,
            ),
            child: GestureDetector(
              onPanStart: (details) {
                setState(() {
                  _currentStrokePoints = [details.localPosition];
                  _currentStrokeStartTime = DateTime.now();
                });
              },
              onPanUpdate: (details) {
                setState(() {
                  _currentStrokePoints.add(details.localPosition);
                });
              },
              onPanEnd: (details) {
                if (_currentStrokePoints.isNotEmpty &&
                    _currentStrokeStartTime != null) {
                  setState(() {
                    _currentStrokes.add(
                      Stroke(
                        points: List.from(_currentStrokePoints),
                        startTime: _currentStrokeStartTime!,
                        endTime: DateTime.now(),
                      ),
                    );
                    _currentStrokePoints = [];
                    _currentStrokeStartTime = null;
                  });
                }
              },
              child: SizedBox.expand(
                child: RepaintBoundary(
                  key: _canvasKey,
                  child: CustomPaint(
                    painter: CanvasPainter(
                      strokes: _currentStrokes,
                      currentStroke: _currentStrokePoints,
                    ),
                  ),
                )
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
                    _currentStrokes.clear();
                    _currentStrokePoints.clear();
                  });
                },
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _currentStrokes.isNotEmpty ? _saveSymbol : null,
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
    _currentStrokes.clear();
    _currentStrokePoints.clear();
    super.dispose();
  }
}