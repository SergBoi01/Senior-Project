import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:scribble/scribble.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import '../models/library_models.dart';

// =============================================================================
// GLOSSARY SCREEN
// =============================================================================

/// Screen for viewing and editing glossary entries.
/// 
/// Features:
/// - Display entries in a table format
/// - Edit text fields (English, Spanish, Definition, Synonym)
/// - Draw and save symbol images for entries
/// - Add and delete entries
class GlossaryScreen extends StatefulWidget {
  final GlossaryItem? glossaryItem;

  const GlossaryScreen({Key? key, this.glossaryItem}) : super(key: key);

  @override
  _GlossaryScreenState createState() => _GlossaryScreenState();
}

class _GlossaryScreenState extends State<GlossaryScreen> {
  // ===========================================================================
  // STATE
  // ===========================================================================

  /// The glossary being displayed/edited.
  late GlossaryItem glossaryItem;

  /// Index of the row currently being edited (for symbol drawing).
  int? editingIndex;

  /// Whether the canvas view is showing (vs table view).
  bool showCanvas = false;

  // ===========================================================================
  // CONTROLLERS
  // ===========================================================================

  /// Controller for the scribble drawing canvas.
  final ScribbleNotifier _notifier = ScribbleNotifier();

  /// Key for capturing the canvas as an image.
  final GlobalKey _canvasKey = GlobalKey();

  /// Scroll controller for the entries list.
  final ScrollController _scrollController = ScrollController();

  /// Text controller for cell editing dialogs.
  final TextEditingController _editController = TextEditingController();

  // ===========================================================================
  // LIFECYCLE
  // ===========================================================================

  @override
  void initState() {
    super.initState();
    // Use provided glossary or create a temporary one
    if (widget.glossaryItem != null) {
      glossaryItem = widget.glossaryItem!;
    } else {
      glossaryItem = GlossaryItem(id: 'temp', name: 'Glossary');
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _editController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // SYMBOL DRAWING
  // ===========================================================================

  /// Captures the current canvas drawing as PNG bytes.
  Future<Uint8List?> _captureCanvas() async {
    try {
      RenderRepaintBoundary boundary =
          _canvasKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturing canvas: $e');
      return null;
    }
  }

  /// Saves the drawn symbol to the current entry and returns to table view.
  void _saveSymbol() async {
    Uint8List? imageData = await _captureCanvas();

    if (editingIndex != null && imageData != null) {
      setState(() {
        glossaryItem.entries[editingIndex!].symbolImage = imageData;
        showCanvas = false;
        editingIndex = null;
      });
      _notifier.clear();
    }
  }

  // ===========================================================================
  // CELL INTERACTION
  // ===========================================================================

  /// Handles tap on a table cell.
  void _onCellTap(int rowIndex, int columnIndex) {
    if (columnIndex == 4) {
      // Symbol column - show drawing canvas or preview
      _handleSymbolTap(rowIndex);
    } else {
      // Text column - show edit dialog
      _handleTextCellTap(rowIndex, columnIndex);
    }
  }

  /// Handles tap on the symbol column.
  void _handleSymbolTap(int rowIndex) {
    final entry = glossaryItem.entries[rowIndex];

    if (entry.symbolImage != null) {
      // Show preview/replace dialog for existing symbol
      _showSymbolPreviewDialog(rowIndex, entry);
    } else {
      // No symbol yet - open canvas directly
      setState(() {
        editingIndex = rowIndex;
        showCanvas = true;
      });
    }
  }

  /// Shows a dialog to preview, replace, or delete an existing symbol.
  void _showSymbolPreviewDialog(int rowIndex, GlossaryEntry entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Current Symbol'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.memory(
              entry.symbolImage!,
              width: 600,
              height: 400,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 16),
            const Text(
              'What would you like to do?',
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          // Cancel
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Cancel', style: TextStyle(fontSize: 15)),
          ),
          // Delete symbol
          TextButton(
            onPressed: () {
              setState(() {
                entry.symbolImage = null;
              });
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Delete Symbol', style: TextStyle(fontSize: 15)),
          ),
          // Replace drawing
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Replace Drawing', style: TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
  }

  /// Handles tap on a text cell (English, Spanish, Definition, Synonym).
  void _handleTextCellTap(int rowIndex, int columnIndex) {
    // Get current value based on column
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
    final columnNames = ['English', 'Spanish', 'Definition', 'Synonym'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          columnNames[columnIndex],
          style: const TextStyle(color: Colors.black),
        ),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return TextField(
              controller: _editController,
              autofocus: true,
              style: const TextStyle(color: Colors.black),
              onChanged: (value) => setDialogState(() {}),
              decoration: InputDecoration(
                border: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black),
                ),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black, width: 2),
                ),
                suffixIcon: _editController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () => setDialogState(() => _editController.clear()),
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
            child: const Text('Cancel'),
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
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // ENTRY MANAGEMENT
  // ===========================================================================

  /// Adds a new empty entry to the glossary.
  void _addNewEntry() {
    setState(() {
      glossaryItem.addEntry(GlossaryEntry(
        english: '',
        spanish: '',
        definition: '',
        synonym: '',
      ));
    });

    // Scroll to show the new entry
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Deletes an entry at the specified index.
  void _deleteEntry(int index) {
    setState(() {
      glossaryItem.deleteEntry(index);
    });
  }

  // ===========================================================================
  // BUILD METHODS
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(glossaryItem.name),
        backgroundColor: Colors.grey[800],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: showCanvas ? _buildCanvasView() : _buildTableView(),
    );
  }

  /// Builds the main table view showing all entries.
  Widget _buildTableView() {
    return Column(
      children: [
        // Header row
        Container(
          color: Colors.black,
          child: Row(
            children: [
              _buildHeaderCell('English', flex: 2),
              _buildHeaderCell('Spanish', flex: 2),
              _buildHeaderCell('Definition', flex: 3),
              _buildHeaderCell('Synonym', flex: 2),
              _buildHeaderCell('Symbol', flex: 1),
              const SizedBox(width: 48), // Space for delete button
            ],
          ),
        ),

        // Data rows
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
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteEntry(index),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // Add button
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: FloatingActionButton(
            onPressed: _addNewEntry,
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            tooltip: 'Add new entry',
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  /// Builds a header cell for the table.
  Widget _buildHeaderCell(String title, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  /// Builds a data cell for text content.
  Widget _buildDataCell(String text, int rowIndex, int columnIndex, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () => _onCellTap(rowIndex, columnIndex),
        child: Container(
          padding: const EdgeInsets.all(12),
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

  /// Builds a symbol cell that displays an image or draw icon.
  Widget _buildSymbolCell(GlossaryEntry entry, int rowIndex, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () => _onCellTap(rowIndex, 4),
        child: Container(
          padding: const EdgeInsets.all(8),
          height: 56,
          alignment: Alignment.center,
          child: entry.symbolImage != null
              ? Image.memory(entry.symbolImage!, width: 40, height: 40)
              : const Icon(Icons.draw, color: Colors.grey),
        ),
      ),
    );
  }

  /// Builds the canvas view for drawing symbols.
  Widget _buildCanvasView() {
    return Column(
      children: [
        // Toolbar
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              const Text(
                'Draw Symbol:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.undo),
                onPressed: () => _notifier.undo(),
              ),
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => _notifier.clear(),
              ),
            ],
          ),
        ),

        // Drawing canvas
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              color: Colors.white,
            ),
            child: RepaintBoundary(
              key: _canvasKey,
              child: Scribble(notifier: _notifier),
            ),
          ),
        ),

        // Action buttons
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
                  _notifier.clear();
                },
                style: TextButton.styleFrom(foregroundColor: Colors.black),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _saveSymbol,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Save Symbol'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
