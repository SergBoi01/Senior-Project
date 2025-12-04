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
  // Design colors matching the library and CSV import screens
  static const Color primaryGreen = Color(0xFF5B8A51);
  static const Color backgroundColor = Color(0xFFE8E8E8);
  static const Color cardColor = Colors.white;
  static const Color darkText = Color(0xFF2D2D2D);
  static const Color subtleText = Color(0xFF6B6B6B);

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
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: primaryGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.draw_outlined, color: primaryGreen, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Current Symbol',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: darkText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Symbol image
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        entry.symbolImage!,
                        width: 400,
                        height: 250,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  if (entry.strokes != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${entry.strokes?.length} stroke(s)',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: primaryGreen,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'What would you like to do?',
                    style: TextStyle(fontSize: 14, color: subtleText),
                  ),
                  const SizedBox(height: 20),
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: subtleText, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              entry.symbolImage = null;
                              entry.strokes = [];
                              _hasUnsavedChanges = true;
                            });
                            Navigator.pop(context);
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: Colors.red.withOpacity(0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Delete',
                            style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              editingIndex = rowIndex;
                              showCanvas = true;
                            });
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Replace',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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

      final fieldNames = ['English', 'Spanish', 'Definition', 'Synonym'];
      final fieldIcons = [Icons.translate, Icons.language, Icons.menu_book_outlined, Icons.swap_horiz];

      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: primaryGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(fieldIcons[columnIndex], color: primaryGreen, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Edit ${fieldNames[columnIndex]}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: darkText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Text field
                  TextField(
                    controller: _editController,
                    autofocus: true,
                    style: const TextStyle(fontSize: 16, color: darkText),
                    maxLines: columnIndex == 2 ? 3 : 1, // Definition gets more lines
                    decoration: InputDecoration(
                      hintText: 'Enter ${fieldNames[columnIndex].toLowerCase()}...',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      filled: true,
                      fillColor: backgroundColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: primaryGreen, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: subtleText, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
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
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Save',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
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
            builder: (context) => Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Warning icon
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Unsaved Changes',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: darkText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'You have unsaved changes. Would you like to save before leaving?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: subtleText,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                            child: const Text(
                              'Discard',
                              style: TextStyle(color: subtleText, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: Colors.orange.withOpacity(0.1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              await _saveAllGlossaryEntries();
                              Navigator.of(context).pop(true);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Save',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
          return discard ?? false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: Text(
            glossaryItem.name,
            style: const TextStyle(
              color: darkText,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: darkText),
          actions: [
            if (_hasUnsavedChanges)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Unsaved',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.save, color: primaryGreen, size: 20),
              ),
              onPressed: _isLoading ? null : _saveAllGlossaryEntries,
              tooltip: 'Save All Entries',
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    CircularProgressIndicator(color: primaryGreen),
                    SizedBox(height: 16),
                    Text(
                      'Loading entries...',
                      style: TextStyle(fontSize: 16, color: subtleText),
                    ),
                  ],
                ),
              )
            : showCanvas
                ? _buildCanvasView()
                : _buildTableView(),
        floatingActionButton: !_isLoading && !showCanvas
            ? FloatingActionButton(
                onPressed: _addNewEntry,
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                child: const Icon(Icons.add),
              )
            : null,
      ),
    );
  }

  Widget _buildTableView() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Header row
            Container(
              color: primaryGreen,
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
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: primaryGreen.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.book_outlined,
                              size: 48,
                              color: primaryGreen.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'No entries yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: darkText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Tap the + button to add an entry',
                            style: TextStyle(
                              fontSize: 14,
                              color: subtleText,
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
                            color: index.isEven ? Colors.grey.shade50 : cardColor,
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade200),
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
                                  icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
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
        ),
      ),
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
          child: text.isEmpty
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.add, color: primaryGreen, size: 16),
                )
              : Text(
                  text,
                  style: const TextStyle(
                    color: darkText,
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
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryGreen.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.draw_outlined, color: primaryGreen, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Draw Symbol',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: darkText,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Draw your symbol in the canvas below',
                        style: TextStyle(fontSize: 12, color: subtleText),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: primaryGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_currentStrokes.length} stroke(s)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: primaryGreen,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.undo, color: Colors.orange, size: 18),
                  ),
                  onPressed: () {
                    if (_currentStrokes.isNotEmpty) {
                      setState(() => _currentStrokes.removeLast());
                    }
                  },
                  tooltip: 'Undo Last Stroke',
                ),
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.clear, color: Colors.red.shade400, size: 18),
                  ),
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
          // Canvas
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: primaryGreen.withOpacity(0.3), width: 2),
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
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
          ),
          // Action buttons
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        showCanvas = false;
                        editingIndex = null;
                        _currentStrokes.clear();
                        _currentStrokePoints.clear();
                      });
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: subtleText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _currentStrokes.isNotEmpty ? _saveSymbol : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Save Symbol',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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