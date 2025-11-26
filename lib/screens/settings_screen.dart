import 'package:flutter/material.dart';

import 'package:senior_project/models/strokes_models.dart';
import 'package:senior_project/models/library_models.dart';
import 'package:senior_project/models/detection_settings_models.dart';
import 'package:senior_project/models/user_data_manager_models.dart';

import 'package:senior_project/services/drawing_settings.dart';

class SettingsScreen extends StatefulWidget {
  final String? userID;

  const SettingsScreen({super.key, this.userID});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<UserCorrection> userCorrections = [];
  DetectionSettings detectionSettings = DetectionSettings();
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// Load all settings from SharedPreferences via UserDataManager
  Future<void> _loadSettings() async {
    if (widget.userID == null) {
      setState(() => isLoading = false);
      return;
    }

    setState(() => isLoading = true);

    try {
      print('[Settings] Loading settings for user: ${widget.userID}');
      
      // Load from SharedPreferences
      await UserDataManager().loadUserData(widget.userID!);

      if (mounted) {
        setState(() {
          userCorrections = UserDataManager().corrections;
          detectionSettings = UserDataManager().detectionSettings;
          isLoading = false;
        });
        
        print('[Settings] Loaded ${userCorrections.length} corrections');
        print('[Settings] Time threshold: ${detectionSettings.timeThreshold}');
        print('[Settings] Spatial threshold: ${detectionSettings.spatialThreshold}');
      }
    } catch (e) {
      print('[Settings] Failed to load settings: $e');
      
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load settings: $e')),
        );
      }
    }
  }

  /// Save corrections to SharedPreferences
  Future<void> _saveCorrections() async {
    if (widget.userID == null) return;
    
    try {
      print('[Settings] Saving ${userCorrections.length} corrections');
      
      UserDataManager().corrections = userCorrections;
      await UserDataManager().saveUserData(widget.userID!);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Corrections saved')),
        );
      }
    } catch (e) {
      print('[Settings] Failed to save corrections: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  /// Save detection settings to SharedPreferences
  Future<void> _saveDetectionSettings() async {
    if (widget.userID == null) return;
    
    try {
      print('[Settings] Saving detection settings');
      
      UserDataManager().detectionSettings = detectionSettings;
      await UserDataManager().saveUserData(widget.userID!);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Detection settings saved')),
        );
      }
    } catch (e) {
      print('[Settings] Failed to save detection settings: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  /// Delete a user correction
  Future<void> _deleteCorrection(int index) async {
    setState(() => userCorrections.removeAt(index));
    await _saveCorrections();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Correction deleted')),
      );
    }
  }

  /// Edit a correction - load entries from SharedPreferences
  Future<void> _editCorrection(int index) async {
    if (widget.userID == null) return;
    
    try {
      print('[Settings] Loading library structure for correction edit');
      
      // Load library structure from SharedPreferences
      final libraryStructure = await UserDataManager().loadLibraryStructure(widget.userID!);
      
      // Collect all entries from checked glossaries
      List<Map<String, dynamic>> allEntries = [];
      
      void collectEntries(dynamic item, String glossaryName) {
        if (item is FolderItem) {
          if (!item.isChecked) return; // Skip unchecked folders
          
          for (var child in item.children) {
            collectEntries(child, glossaryName);
          }
        } else if (item is GlossaryItem) {
          if (!item.isChecked) return; // Skip unchecked glossaries
          
          for (var entry in item.entries) {
            allEntries.add({
              'entry': entry,
              'glossaryName': item.name,
            });
          }
        }
      }
      
      // Collect from all root folders
      for (var rootFolder in libraryStructure) {
        collectEntries(rootFolder, '');
      }

      print('[Settings] Found ${allEntries.length} entries from checked glossaries');

      if (!mounted) return;

      // Show search dialog
      showDialog(
        context: context,
        builder: (context) => _SearchCorrectionDialog(
          allEntries: allEntries,
          onEntrySelected: (entry, glossaryName) async {
            setState(() {
              userCorrections[index] = UserCorrection(
                drawnStrokes: userCorrections[index].drawnStrokes,
                correctedLabel: entry.spanish,
                timestamp: DateTime.now(),
              );
            });
            await _saveCorrections();
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Correction updated')),
            );
          },
        ),
      );
    } catch (e) {
      print('[Settings] Failed to load library for edit: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load library: $e')),
        );
      }
    }
  }

  /// Reset detection settings to defaults
  void _resetToDefaults() async {
    setState(() => detectionSettings = DetectionSettings());
    await _saveDetectionSettings();
  }

  /// Clear all corrections
  void _clearAllCorrections() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Corrections?'),
        content: Text(
          'This will delete all ${userCorrections.length} learned correction(s). This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => userCorrections.clear());
              await _saveCorrections();
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All corrections cleared')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  /// Show information dialog for settings
  void _showSettingInfo(String title, String description) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.grey[300],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Detection Settings Header
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    color: Colors.blue[50],
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Detection Settings',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _resetToDefaults,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Reset'),
                        ),
                      ],
                    ),
                  ),

                  // Time Grouping Setting
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Time Grouping',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.info_outline, color: Colors.blue),
                                  onPressed: () => _showSettingInfo(
                                    'Time Grouping',
                                    'How long to wait (in milliseconds) before considering strokes as separate symbols.\n\n'
                                    'Lower values = faster separation\n'
                                    'Higher values = more strokes grouped together\n\n'
                                    'Recommended: 800-1200ms for normal writing speed',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${detectionSettings.timeThreshold.round()} ms',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.blue[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Slider(
                              value: detectionSettings.timeThreshold,
                              min: 200,
                              max: 2000,
                              divisions: 18,
                              label: '${detectionSettings.timeThreshold.round()} ms',
                              onChanged: (value) {
                                setState(() {
                                  detectionSettings.timeThreshold = value;
                                });
                              },
                              onChangeEnd: (value) => _saveDetectionSettings(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Spatial Grouping Setting
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Spatial Grouping',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.info_outline, color: Colors.blue),
                                  onPressed: () => _showSettingInfo(
                                    'Spatial Grouping',
                                    'Maximum distance (in pixels) between strokes to be considered part of the same symbol.\n\n'
                                    'Lower values = strokes must be closer\n'
                                    'Higher values = strokes can be further apart\n\n'
                                    'Recommended: 40-60 pixels for normal symbol spacing',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${detectionSettings.spatialThreshold.round()} pixels',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.blue[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Slider(
                              value: detectionSettings.spatialThreshold,
                              min: 10,
                              max: 100,
                              divisions: 18,
                              label: '${detectionSettings.spatialThreshold.round()} px',
                              onChanged: (value) {
                                setState(() {
                                  detectionSettings.spatialThreshold = value;
                                });
                              },
                              onChangeEnd: (value) => _saveDetectionSettings(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Minimum Symbol Size Setting
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Minimum Symbol Size',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.info_outline, color: Colors.blue),
                                  onPressed: () => _showSettingInfo(
                                    'Minimum Symbol Size',
                                    'Minimum area (in pixels²) for a group of strokes to be detected as a valid symbol.\n\n'
                                    'Lower values = detect smaller marks\n'
                                    'Higher values = ignore tiny accidental marks\n\n'
                                    'Recommended: 50-150 pixels² to filter noise',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${detectionSettings.minSymbolSize.round()} px²',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.blue[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Slider(
                              value: detectionSettings.minSymbolSize,
                              min: 10,
                              max: 300,
                              divisions: 29,
                              label: '${detectionSettings.minSymbolSize.round()} px²',
                              onChanged: (value) {
                                setState(() {
                                  detectionSettings.minSymbolSize = value;
                                });
                              },
                              onChangeEnd: (value) => _saveDetectionSettings(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Pen Width Setting
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pen Size',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${drawingSettings.penWidth.toInt()} px',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.blue[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Slider(
                              value: drawingSettings.penWidth,
                              min: 1,
                              max: 30,
                              divisions: 29,
                              label: "${drawingSettings.penWidth.toInt()}",
                              // REAL-TIME update for canvas
                              onChanged: (value) {
                                setState(() {
                                  drawingSettings.setPenWidth(value);
                                });
                              },
                              // SAVE to SharedPreferences only on release
                              onChangeEnd: (value) async {
                                if (widget.userID == null) return;

                                try {
                                  print('[Settings] Saving pen width: $value');
                                  
                                  UserDataManager().penWidth = value;
                                  await UserDataManager().saveUserData(widget.userID!);

                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Pen size saved')),
                                    );
                                  }
                                } catch (e) {
                                  print('[Settings] Failed to save pen width: $e');
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const Divider(thickness: 2, height: 32),

                  // User Corrections Header
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    color: Colors.grey[200],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'User Corrections',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You have ${userCorrections.length} learned correction(s)',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (userCorrections.isNotEmpty)
                          ElevatedButton.icon(
                            onPressed: _clearAllCorrections,
                            icon: const Icon(Icons.delete_forever, color: Colors.white),
                            label: const Text('Clear All Corrections'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // List of corrections
                  if (userCorrections.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No corrections yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Corrections you make will appear here',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...userCorrections.asMap().entries.map((entry) {
                      final index = entry.key;
                      final correction = entry.value;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 4.0,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue[100],
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                          title: Text(
                            'Corrected to: ${correction.correctedLabel}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                'Strokes: ${correction.drawnStrokes.length}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                _formatDate(correction.timestamp),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _editCorrection(index),
                                tooltip: 'Edit',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteCorrection(index),
                                tooltip: 'Delete',
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),

                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}

// Search Dialog Widget for editing corrections
class _SearchCorrectionDialog extends StatefulWidget {
  final List<Map<String, dynamic>> allEntries;
  final Function(GlossaryEntry entry, String glossaryName) onEntrySelected;

  const _SearchCorrectionDialog({
    required this.allEntries,
    required this.onEntrySelected,
  });

  @override
  State<_SearchCorrectionDialog> createState() => _SearchCorrectionDialogState();
}

class _SearchCorrectionDialogState extends State<_SearchCorrectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  bool searchInSpanish = true;
  List<Map<String, dynamic>> _filteredEntries = [];

  @override
  void initState() {
    super.initState();
    _filteredEntries = widget.allEntries;
    _searchController.addListener(_filterEntries);
  }

  void _filterEntries() {
    final query = _searchController.text.toLowerCase().trim();

    if (query.isEmpty) {
      setState(() => _filteredEntries = widget.allEntries);
      return;
    }

    setState(() {
      _filteredEntries = widget.allEntries.where((item) {
        final entry = item['entry'] as GlossaryEntry;
        final searchField = searchInSpanish ? entry.spanish : entry.english;
        return searchField.toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Expanded(child: Text('Search Entry')),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'EN',
                style: TextStyle(
                  color: searchInSpanish ? Colors.grey : Colors.black,
                  fontWeight: searchInSpanish ? FontWeight.normal : FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Switch(
                value: searchInSpanish,
                onChanged: (value) {
                  setState(() {
                    searchInSpanish = value;
                    _filterEntries();
                  });
                },
                activeThumbColor: Colors.blue,
                inactiveThumbColor: Colors.blue,
              ),
              Text(
                'ES',
                style: TextStyle(
                  color: searchInSpanish ? Colors.black : Colors.grey,
                  fontWeight: searchInSpanish ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        height: 500,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search in ${searchInSpanish ? "Spanish" : "English"}...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_filteredEntries.length} result(s)',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _filteredEntries.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            'No entries found',
                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredEntries.length,
                      itemBuilder: (context, i) {
                        final item = _filteredEntries[i];
                        final entry = item['entry'] as GlossaryEntry;
                        final glossaryName = item['glossaryName'] as String;

                        return ListTile(
                          title: Text(
                            '${entry.english} → ${entry.spanish}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            '($glossaryName)',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          onTap: () => widget.onEntrySelected(entry, glossaryName),
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue[100],
                            child: Text(
                              entry.english.isNotEmpty ? entry.english[0].toUpperCase() : '?',
                              style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}