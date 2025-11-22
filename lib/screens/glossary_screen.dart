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
  int? editingIndex; // Currently editing row index
  bool showCanvas = false; // Toggle between table view and canvas view
  
  // Loading and error states
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  
  // Firestore service
  final GlossaryService _glossaryService = GlossaryService();
  
  // Canvas/Drawing controllers
  final GlobalKey _canvasKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  
  // Text input controller for editing cells
  final TextEditingController _editController = TextEditingController();

  // NEW: Stroke tracking for symbol detection
  List<Stroke> _currentStrokes = [];
  List<Offset> _currentStrokePoints = [];
  DateTime? _currentStrokeStartTime;

  @override
  void initState() {
    super.initState();
    // Use provided glossaryItem or create a new one if none provided
    if (widget.glossaryItem != null) {
      glossaryItem = widget.glossaryItem!;
      // Load entries from Firestore
      _loadEntries();
    } else {
      // Fallback: create a temporary glossary item (for backward compatibility)
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

  /// Save entry to Firestore
  Future<void> _saveEntryToFirestore(int index) async {
    if (index < 0 || index >= glossaryItem.entries.length) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final entry = glossaryItem.entries[index];
      await _glossaryService.saveEntry(glossaryItem.id, entry, index);
      setState(() {
        _isSaving = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save entry: $e';
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage!)),
        );
      }
    }
  }

  // Canvas/Symbol Methods
  
  /// Captures the current canvas drawing as an image
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

  /// Saves the drawn symbol to the current glossary entry
  /// UPDATED: Now saves both image and strokes
  void _saveSymbol() async {
    Uint8List? imageData = await _captureCanvas();
    
    if (editingIndex != null && imageData != null) {
      setState(() {
        // Save both image and strokes
        glossaryItem.entries[editingIndex!].symbolImage = imageData;
        glossaryItem.entries[editingIndex!].strokes = List.from(_currentStrokes);
        
        showCanvas = false;
        final index = editingIndex!;
        editingIndex = null;
        
        // Save to Firestore
        _saveEntryToFirestore(index);
      });
      
      // Clear everything
      _currentStrokes.clear();
      _currentStrokePoints.clear();
      _currentStrokeStartTime = null;
      
      print('Saved symbol with ${_currentStrokes.length} strokes');
    }
  }

  // Cell Interaction Methods
  
  /// Handles tap events on table cells
  void _onCellTap(int rowIndex, int columnIndex) {
    if (columnIndex == 4) {
      // Symbol column, show drawing canvas or symbol preview
      final entry = glossaryItem.entries[rowIndex];
      
      // If symbol already exists, show preview/replace dialog
      if (entry.symbolImage != null) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Current Symbol'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Display existing symbol image
                Image.memory(
                  entry.symbolImage!,
                  width: 600,
                  height: 400,
                  fit: BoxFit.contain,
                ),
                SizedBox(height: 16),
                // Show stroke count if available
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
              // Cancel button
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: Text('Cancel', style: TextStyle(fontSize: 15)),
              ),
              // Delete symbol button
              TextButton(
                onPressed: () {
                  setState(() {
                    entry.symbolImage = null;
                    entry.strokes = null; // Also clear strokes
                    // Save to Firestore
                    _saveEntryToFirestore(rowIndex);
                  });
                  Navigator.pop(context);
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: Text('Delete Symbol', style: TextStyle(fontSize: 15)),
              ),
              // Replace drawing button
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Open canvas to draw new symbol
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
        // No symbol yet, open canvas directly
        setState(() {
          editingIndex = rowIndex;
          showCanvas = true;
        });
      }
    } else {
      // Text columns - show text input dialog
      String currentValue = '';
      
      // Get current value based on column
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
      
      // Show text editing dialog
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
                  setDialogState(() {}); // Rebuild to show/hide clear button
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
                  // Clear button that appears when text is not empty
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
            // Cancel button
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(foregroundColor: Colors.black),
              child: Text('Cancel'),
            ),
            // Save button
            ElevatedButton(
              onPressed: () {
                setState(() {
                  // Update the appropriate field based on column
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
                  // Save to Firestore
                  _saveEntryToFirestore(rowIndex);
                });
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

  // Entry Management Methods
  
  /// Adds a new empty entry to the glossary
  void _addNewEntry() {
    setState(() {
      final newEntry = GlossaryEntry(
        english: '',
        spanish: '',
        definition: '',
        synonym: '',
      );
      glossaryItem.addEntry(newEntry);
      final index = glossaryItem.entries.length - 1;
      // Save to Firestore
      _saveEntryToFirestore(index);
    });

    // Scroll to the bottom of the list to show the newly added entry
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
          if (_isSaving)
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
      // Toggle between canvas view for drawing and table view for entries
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : showCanvas
              ? _buildCanvasView()
              : _buildTableView(),
    );
  }

  /// Builds the main table view showing all glossary entries
  Widget _buildTableView() {
    return Column(
      children: [
        // Header Row
        Container(
          color: Colors.black,
          child: Row(
            children: [
              _buildHeaderCell('English', flex: 2),
              _buildHeaderCell('Spanish', flex: 2),
              _buildHeaderCell('Definition', flex: 3),
              _buildHeaderCell('Synonym', flex: 2),
              _buildHeaderCell('Symbol', flex: 1),
              SizedBox(width: 48), // Space for delete button
            ],
          ),
        ),
        
        // Data Rows
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemCount: glossaryItem.entries.length,
            itemBuilder: (context, index) {
              final entry = glossaryItem.entries[index];
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
                    // Delete button for each row
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: _isSaving ? null : () async {
                        final entry = glossaryItem.entries[index];
                        if (entry.id != null) {
                          // Delete from Firestore
                          setState(() {
                            _isSaving = true;
                          });
                          try {
                            await _glossaryService.deleteEntry(glossaryItem.id, entry.id!);
                            setState(() {
                              glossaryItem.deleteEntry(index);
                              _isSaving = false;
                            });
                          } catch (e) {
                            setState(() {
                              _isSaving = false;
                            });
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to delete entry: $e')),
                              );
                            }
                          }
                        } else {
                          // Just remove from local list if not saved yet
                          setState(() {
                            glossaryItem.deleteEntry(index);
                          });
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        
        // Add Button
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: FloatingActionButton(
            onPressed: _isSaving ? null : _addNewEntry,
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            tooltip: 'Add new entry',
            child: _isSaving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  // Helper Widget Methods
  
  /// Builds a header cell for the table
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

  /// Builds a data cell for text content
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
            text.isEmpty ? '➕' : text, // Show plus icon if empty
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

  /// Builds a symbol cell that displays an image or draw icon
  Widget _buildSymbolCell(GlossaryEntry entry, int rowIndex, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () => _onCellTap(rowIndex, 4),
        child: Container(
          padding: EdgeInsets.all(8),
          height: 56,
          alignment: Alignment.center,
          // Display symbol image if exists, otherwise show draw icon
          child: entry.symbolImage != null
              ? Image.memory(entry.symbolImage!, width: 40, height: 40)
              : Icon(Icons.draw, color: Colors.grey),
        ),
      ),
    );
  }

  /// Builds the canvas view for drawing symbols
  /// UPDATED: Now captures strokes with GestureDetector
  Widget _buildCanvasView() {
    return Column(
      children: [
        // Toolbar
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

        // CANVAS — identical behavior to main_screen.dart
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
                child: CustomPaint(
                  painter: CanvasPainter(
                    strokes: _currentStrokes,
                    currentStroke: _currentStrokePoints,
                  ),
                ),
              ),
            ),
          ),
        ),

        // Buttons
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
    // Clean up controllers
    _scrollController.dispose();
    _editController.dispose();
    // Clear stroke tracking
    _currentStrokes.clear();
    _currentStrokePoints.clear();
    super.dispose();
  }
}