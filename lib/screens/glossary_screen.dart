import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'main_screen.dart';
import '../models/library_model.dart';
import '../models/strokes_model.dart';
import '../services/library_services.dart';

class GlossaryScreen extends StatefulWidget {
  final GlossaryItem glossaryItem;

  const GlossaryScreen({super.key, required this.glossaryItem});

  @override
  _GlossaryScreenState createState() => _GlossaryScreenState();
}

class _GlossaryScreenState extends State<GlossaryScreen> {
  late GlossaryItem glossaryItem;
  bool showCanvas = false;
  int? editingIndex;
  bool _isLoading = false;
  bool _hasUnsavedChanges = false;

  final LibraryService _libraryService = LibraryService();
  final GlobalKey _canvasKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _editController = TextEditingController();

  List<Stroke> _currentStrokes = [];
  List<Offset> _currentStrokePoints = [];
  DateTime? _currentStrokeStartTime;

  @override
  void initState() {
    super.initState();
    glossaryItem = widget.glossaryItem;
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    setState(() => _isLoading = true);
    try {
      final entries = await _libraryService.loadEntries(glossaryItem.id);
      if (mounted) {
        setState(() {
          glossaryItem.entries = entries;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load entries: $e')),
        );
      }
    }
  }

  Future<void> _saveAllGlossaryEntries() async {
    if (!_hasUnsavedChanges) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No changes to save')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _libraryService.saveEntries(glossaryItem.id, glossaryItem.entries);
      setState(() {
        _isLoading = false;
        _hasUnsavedChanges = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Glossary saved successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save glossary: $e')),
        );
      }
    }
  }

  void _addNewEntry() {
    setState(() {
      glossaryItem.addEntry(GlossaryEntry(
        english: '',
        spanish: '',
        definition: '',
        synonym: '',
        strokes: [],
        symbolImage: null,
      ));
      _hasUnsavedChanges = true;
    });

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

  void _deleteEntry(int index) {
    if (index < 0 || index >= glossaryItem.entries.length) return;
    setState(() {
      glossaryItem.deleteEntry(index);
      _hasUnsavedChanges = true;
    });
  }

  Future<Uint8List?> _captureCanvas() async {
    try {
      final boundary = _canvasKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint("Error capturing canvas: $e");
      return null;
    }
  }

  void _saveSymbol() async {
    final imageData = await _captureCanvas();
    if (editingIndex != null && imageData != null) {
      setState(() {
        glossaryItem.entries[editingIndex!].symbolImage = imageData;
        glossaryItem.entries[editingIndex!].strokes = List.from(_currentStrokes);
        showCanvas = false;
        editingIndex = null;
        _currentStrokes.clear();
        _currentStrokePoints.clear();
        _currentStrokeStartTime = null;
        _hasUnsavedChanges = true;
      });
    }
  }

  void _onCellTap(int rowIndex, int columnIndex) {
    final entry = glossaryItem.entries[rowIndex];
    if (columnIndex == 4) {
    if (entry.symbolImage != null && entry.symbolImage!.isNotEmpty) {
      // Show dialog with current symbol
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
              if (entry.strokes != null)
                Text(
                  '${entry.strokes?.length} stroke(s)',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              const SizedBox(height: 8),
              const Text('What would you like to do?', style: TextStyle(fontSize: 18)),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                setState(() {
                  entry.symbolImage = null; // <-- now properly null
                  entry.strokes = [];
                  _hasUnsavedChanges = true;
                });
                Navigator.pop(context);
              },
              child: const Text('Delete Symbol', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  editingIndex = rowIndex;
                  showCanvas = true;
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              child: const Text('Replace Drawing'),
            ),
          ],
        ),
      );
    } else {
      // No current symbol, just open canvas
      setState(() {
        editingIndex = rowIndex;
        showCanvas = true;
      });
    }
  } else {
      _editController.text = [
        entry.english,
        entry.spanish,
        entry.definition,
        entry.synonym
      ][columnIndex];

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(['English', 'Spanish', 'Definition', 'Synonym'][columnIndex]),
          content: TextField(controller: _editController, autofocus: true, decoration: const InputDecoration(border: OutlineInputBorder())),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  switch (columnIndex) {
                    case 0: entry.english = _editController.text; break;
                    case 1: entry.spanish = _editController.text; break;
                    case 2: entry.definition = _editController.text; break;
                    case 3: entry.synonym = _editController.text; break;
                  }
                  _hasUnsavedChanges = true;
                });
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        debugPrint("GlossaryScreen built: ${glossaryItem.name}");
        if (_hasUnsavedChanges) {
          final discard = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Unsaved Changes'),
              content: const Text('You have unsaved changes. Save before leaving?'),
              actions: [
                TextButton(child: const Text('Discard'), onPressed: () => Navigator.of(context).pop(true)),
                TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop(false)),
                ElevatedButton(
                  child: const Text('Save'),
                  onPressed: () async {
                    await _saveAllGlossaryEntries();
                    Navigator.of(context).pop(true);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                ),
              ],
            ),
          );
          return discard ?? false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(glossaryItem.name),
          backgroundColor: Colors.grey[800],
          actions: [
            if (_hasUnsavedChanges)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4)),
                    child: const Text('Unsaved', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _isLoading ? null : _saveAllGlossaryEntries,
              tooltip: 'Save All Entries',
            ),
          ],
        ),
        body: _isLoading
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [CircularProgressIndicator(), SizedBox(height: 16), Text('Loading entries...', style: TextStyle(fontSize: 16))]))
            : showCanvas
                ? _buildCanvasView()
                : _buildTableView(),
        floatingActionButton: !_isLoading && !showCanvas
            ? FloatingActionButton(
                onPressed: _addNewEntry,
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                child: const Icon(Icons.add),
              )
            : null,
      ),
    );
  }

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
              _buildHeaderCell('Delete', flex: 1),
            ],
          ),
        ),
        
        // Data rows
        Expanded(
          child: glossaryItem.entries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.book_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No entries yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap the + button to add an entry',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  itemCount: glossaryItem.entries.length,
                  itemBuilder: (context, index) {
                    final entry = glossaryItem.entries[index];
                    return Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey[400]!),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildDataCell(entry.english, index, 0, flex: 2),
                          _buildDataCell(entry.spanish, index, 1, flex: 2),
                          _buildDataCell(entry.definition, index, 2, flex: 3),
                          _buildDataCell(entry.synonym, index, 3, flex: 2),
                          _buildSymbolCell(entry, index, flex: 1),
                          Expanded(
                            flex: 1,
                            child: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteEntry(index),
                              tooltip: 'Delete Entry',
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

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

  Widget _buildSymbolCell(GlossaryEntry entry, int rowIndex, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () => _onCellTap(rowIndex, 4),
        child: Container(
          padding: const EdgeInsets.all(8),
          height: 56,
          alignment: Alignment.center,
          child: (entry.symbolImage != null && entry.symbolImage!.isNotEmpty)
              ? Image.memory(entry.symbolImage!, width: 40, height: 40)
              : Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.green),
                    color: Colors.green[50],
                  ),
                  child: const Center(
                    child: Icon(Icons.add, color: Colors.green),
                  ),
                ),
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
              const Text(
                'Draw Symbol:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '${_currentStrokes.length} stroke(s)',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.undo),
                onPressed: () {
                  if (_currentStrokes.isNotEmpty) {
                    setState(() => _currentStrokes.removeLast());
                  }
                },
                tooltip: 'Undo Last Stroke',
              ),
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  setState(() {
                    _currentStrokes.clear();
                    _currentStrokePoints.clear();
                  });
                },
                tooltip: 'Clear Canvas',
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
                setState(() => _currentStrokePoints.add(details.localPosition));
              },
              onPanEnd: (details) {
                if (_currentStrokePoints.isNotEmpty && _currentStrokeStartTime != null) {
                  setState(() {
                    _currentStrokes.add(
                      Stroke(
                        points: List.from(_currentStrokePoints),
                        startTime: _currentStrokeStartTime!,
                        endTime: DateTime.now(),
                      ),
                    );
                    _currentStrokePoints.clear();
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
                    _currentStrokes.clear();
                    _currentStrokePoints.clear();
                  });
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _currentStrokes.isNotEmpty ? _saveSymbol : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Save Symbol'),
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