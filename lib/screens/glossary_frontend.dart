import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:scribble/scribble.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'glossary_backend.dart';

class GlossaryScreen extends StatefulWidget {
  @override
  _GlossaryScreenState createState() => _GlossaryScreenState();
}

class _GlossaryScreenState extends State<GlossaryScreen> {
  // State Variables
  final Glossary glossary = Glossary();
  int? editingIndex; // Currently editing row index
  bool showCanvas = false; // Toggle between table view and canvas view
  
  // Canvas/Drawing controllers
  final ScribbleNotifier _notifier = ScribbleNotifier();
  final GlobalKey _canvasKey = GlobalKey();
  
  // Text input controller for editing cells
  final TextEditingController _editController = TextEditingController();

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
  void _saveSymbol() async {
    Uint8List? imageData = await _captureCanvas();
    
    if (editingIndex != null && imageData != null) {
      setState(() {
        glossary.entries[editingIndex!].symbolImage = imageData;
        showCanvas = false;
        editingIndex = null;
      });
      _notifier.clear();
    }
  }

  // Cell Interaction Methods
  
  /// Handles tap events on table cells
  void _onCellTap(int rowIndex, int columnIndex) {
    if (columnIndex == 4) {
      // Symbol column, show drawing canvas or symbol preview
      final entry = glossary.entries[rowIndex];
      
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
                    entry.symbolImage = null; // Remove the image
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
                      glossary.entries[rowIndex].english = _editController.text;
                      break;
                    case 1:
                      glossary.entries[rowIndex].spanish = _editController.text;
                      break;
                    case 2:
                      glossary.entries[rowIndex].definition = _editController.text;
                      break;
                    case 3:
                      glossary.entries[rowIndex].synonym = _editController.text;
                      break;
                  }
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
    glossary.addEntry('', '', '', '');
    print("ADDED NEW ENTRY:");
    glossary.printAllEntries();
  });
}

  // Build Methods
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Glossary"),
        backgroundColor: Colors.grey[800],
        iconTheme: IconThemeData(color: Colors.white),
      ),
      // Toggle between canvas view for drawing and table view for entries
      body: showCanvas ? _buildCanvasView() : _buildTableView(),
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
            itemCount: glossary.entries.length,
            itemBuilder: (context, index) {
              final entry = glossary.entries[index];
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
                      onPressed: () {
                        setState(() {
                          print("DELETING ENTRY AT INDEX $index:");
                          glossary.deleteEntry(index);
                          glossary.printAllEntries();
                        });
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
            onPressed: _addNewEntry,
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            child: Icon(Icons.add),
            tooltip: 'Add new entry',
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
  Widget _buildCanvasView() {
    return Column(
      children: [
        // Canvas toolbar
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Text(
                'Draw Symbol:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Spacer(),
              // Undo button
              IconButton(
                icon: Icon(Icons.undo),
                onPressed: () => _notifier.undo(),
              ),
              // Clear canvas button
              IconButton(
                icon: Icon(Icons.clear),
                onPressed: () => _notifier.clear(),
              ),
            ],
          ),
        ),
        
        // Drawing canvas
        Expanded(
          child: Container(
            margin: EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              color: Colors.white,
            ),
            child: RepaintBoundary(
              key: _canvasKey,
              child: Scribble(
                notifier: _notifier,
              ),
            ),
          ),
        ),
        
        // Action buttons
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Cancel button
              TextButton(
                onPressed: () {
                  setState(() {
                    showCanvas = false;
                    editingIndex = null;
                  });
                  _notifier.clear();
                },
                style: TextButton.styleFrom(foregroundColor: Colors.black),
                child: Text('Cancel'),
              ),
              // Save symbol button
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
}