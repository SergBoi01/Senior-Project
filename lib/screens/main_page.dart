import 'package:flutter/material.dart';
import 'package:senior_project/screens/glossary_screen.dart';
import 'package:senior_project/screens/login_screen.dart';
import 'package:senior_project/screens/symbols_screen.dart';

import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:scribble/scribble.dart';
import 'dart:typed_data';
import 'dart:math';

import 'dart:io';
import 'dart:convert';

// TO SEE SAVED TXT FILE OF LIST INPUTS. 
// RUN PROGRAM THEN ON POWERSHELL VSCODE TERMINAL COPY 
// adb pull /storage/emulated/0/Download/saved_data.txt C:\Users\Kirit\Downloads\


// CLASS THAT HOLDS RIGHT SIDE OUTPUT
class SavedImage {
  final Uint8List thumbnail;  // original canvas thumbnail
  final String prediction;       // model prediction
  final Uint8List modelView;  // preprocessed input for display

  SavedImage({
    required this.thumbnail, 
    required this.prediction, 
    required this.modelView,
  });
}

// CLASS THAT HOLDS MODEL
class SaveModelInput {
  final List<List<List<List<double>>>> input;  // preprocessed input for display4
  final String label;

  SaveModelInput({
    required this.input, 
    required this.label,
  });

  Map<String, dynamic> toJson() => {
        'input': input,
        'label': label,
      };

  /// Build SaveModelInput from decoded JSON (dynamic nested lists).
  factory SaveModelInput.fromJson(Map<String, dynamic> json) {
    final rawInput = json['input'];
    if (rawInput == null) {
      throw FormatException('Missing "input" in JSON');
    }

    return SaveModelInput(
      input: _convertTo4DDoubleList(rawInput),
      label: json['label'] as String,
    );
  }

  /// Helper to convert dynamic nested lists to List<List<List<List<double>>>>
  static List<List<List<List<double>>>> _convertTo4DDoubleList(dynamic raw) {
    // Expect raw to be List (level 0)
    final List outer = raw as List;

    return outer.map<List<List<List<double>>>>((lvl1) {
      final List l1 = lvl1 as List;
      return l1.map<List<List<double>>>((lvl2) {
        final List l2 = lvl2 as List;
        return l2.map<List<double>>((lvl3) {
          final List l3 = lvl3 as List;
          return l3.map<double>((v) {
            // JSON numbers can be int or double -> cast to num then toDouble()
            if (v == null) return 0.0;
            if (v is num) return v.toDouble();
            // if it's a string, try parse (robustness)
            if (v is String) return double.tryParse(v) ?? 0.0;
            throw FormatException('Unexpected value type in input tensor: ${v.runtimeType}');
          }).toList();
        }).toList();
      }).toList();
    }).toList();
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with SingleTickerProviderStateMixin {
  
  // CHANGES THICKNESS AND SETS COLOR OF PEN
  final ScribbleNotifier _controller = ScribbleNotifier()
  ..setStrokeWidth(15.0)  // Set pen width
  ..setColor(Colors.black);

  // LIST OF SAVED IMAGES and SAVED INPUTS
  final List<SavedImage> saved = [];
  List<SaveModelInput> savedInputs = [];

  // LIST OF LABELS // 
  final List<String> labels = [
    'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z',
    'a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v','w','x','y','z',
  ];
  int round = 25;
  int index = 0; // current label index

  String getNextLabel() {
    String label = labels[index];
    print('Index : $index out of 52' );
    index++;
    if (index >= labels.length) {
      index = 0;
      round++;
      print('$round round completed out of 50');
    }
    return label;
  }
  String? currentLabel; // store the current label
  //////

  //MODEL INTERPRETER
  late Interpreter interpreter;

  // UI ITEMS
  late AnimationController _animationController;
  bool isMenuOpen = false;

  Future<void> _loadModel() async {
    interpreter = await Interpreter.fromAsset('assets/models/alphabet_25_50_trained.tflite');
    print('Interpreter initialized: $interpreter');
  }

  // SAVES IMAGE, CROPS IT, GRAYSCALES, SETS TO MODEL INPUT, GIVES TO MODEL, 
  // SAVES PREDICTIONS, SAVES ITEM IN CLASS
  Future<void> _handleSave () async {
    try {
      print(interpreter.hashCode);
      // 1. Render canvas as ByteData
      final ByteData byteData = await _controller.renderImage();
      final Uint8List thumbnail = byteData.buffer.asUint8List();

      // 2. Decode PNG for processing
      final img.Image? image = img.decodeImage(thumbnail);
      if (image == null) return;

      final int width = image.width;
      final int height = image.height;

      // 3. Find bounding box of non-white pixels
      int minX = width, minY = height, maxX = 0, maxY = 0;
      bool hasContent = false;

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        final int r = pixel.r.toInt();
        final int g = pixel.g.toInt();
        final int b = pixel.b.toInt();
        final gray = (0.299*r + 0.587*g + 0.114*b).toInt();

        if (gray < 240) { // non-white pixel
          hasContent = true;
          minX = x < minX ? x : minX;
          minY = y < minY ? y : minY;
          maxX = x > maxX ? x : maxX;
          maxY = y > maxY ? y : maxY;
          }
        }
      }

      // 4. Handle empty canvas
      if (!hasContent) {
        final emptyModelView = _createEmptyModelView();
        setState(() {
          saved.add(SavedImage(
            thumbnail: thumbnail,
            prediction: "",
            modelView: emptyModelView,
          ));
          _controller.clear();
        });
        return;
      }

      // 5. Crop to bounding box with some padding
      final padding = 5;
      final cropMinX = max(0, minX - padding);
      final cropMinY = max(0, minY - padding);
      final cropMaxX = min(width - 1, maxX + padding);
      final cropMaxY = min(height - 1, maxY + padding);
      
      final cropped = img.copyCrop(
        image,
        x: cropMinX,
        y: cropMinY,
        width: cropMaxX - cropMinX + 1,
        height: cropMaxY - cropMinY + 1,
      );
      

      // 6. Resize while preserving aspect ratio to fit 20x20
      final scale = 20 / max(cropped.width, cropped.height);
      final newWidth = (cropped.width * scale).round();
      final newHeight = (cropped.height * scale).round();
      final resized = img.copyResize(cropped, width: newWidth, height: newHeight);

      // 7. Center on 28x28 black canvas
      final canvas28 = img.Image(width: 28, height: 28);
      img.fill(canvas28, color: img.ColorRgb8(255, 255, 255));
      final xOffset = ((28 - newWidth) / 2).round();
      final yOffset = ((28 - newHeight) / 2).round();
      img.compositeImage(canvas28, resized, dstX: xOffset, dstY: yOffset);

      // 8. Convert to [1,28,28,1] with inverted grayscale
      final input = List.generate(1, (_) => List.generate(28, (y) {
        return List.generate(28, (x) {
          final pixel = canvas28.getPixel(x, y);
          final gray = (0.299*pixel.r + 0.587*pixel.g + 0.114*pixel.b)/255.0;
          return [1 - gray]; // invert: black background → 0, white strokes → 1
        });
      }));

      // 9. Run TFLite
      var output = List.generate(1, (_) => List.filled(52, 0.0));
      interpreter.run(input, output);

      // Find index of highest probability
      final outputList = output[0];
      final maxIndex = outputList.indexWhere(
        (v) => v == outputList.reduce((a, b) => a > b ? a : b),
      );

      // Get the corresponding label
      final predictedLabel = labels[maxIndex];

      

      // 11. Convert preprocessed input to image for display
      Uint8List modelView = modelInputToImage(input);
      
      // 12. Save and clear
      setState(() {
        saved.add(SavedImage(
          thumbnail: thumbnail,
          prediction: predictedLabel,
          modelView: modelView,
        ));
        _controller.clear();
      });

      print('Predicted digit: $predictedLabel');

    } catch (e) {
      print('Error in _handleSave: $e');
    }
  }
  
  // SAVES IMAGE, CROPS IT, GRAYSCALES, SETS TO MODEL INPUT, 
  // SAVES IN CLASS W/ LABEL
  Future<void> _saveModelInputList(String label) async {
    try {
      print(interpreter.hashCode);
      // 1. Render canvas as ByteData
      final ByteData byteData = await _controller.renderImage();
      final Uint8List thumbnail = byteData.buffer.asUint8List();

      // 2. Decode PNG for processing
      final img.Image? image = img.decodeImage(thumbnail);
      if (image == null) return;

      final int width = image.width;
      final int height = image.height;

      // 3. Find bounding box of non-white pixels
      int minX = width, minY = height, maxX = 0, maxY = 0;
      bool hasContent = false;

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        final int r = pixel.r.toInt();
        final int g = pixel.g.toInt();
        final int b = pixel.b.toInt();
        final gray = (0.299*r + 0.587*g + 0.114*b).toInt();

        if (gray < 240) { // non-white pixel
          hasContent = true;
          minX = x < minX ? x : minX;
          minY = y < minY ? y : minY;
          maxX = x > maxX ? x : maxX;
          maxY = y > maxY ? y : maxY;
          }
        }
      }

      // 4. Handle empty canvas
      if (!hasContent) {
        final emptyModelView = _createEmptyModelView();
        setState(() {
          saved.add(SavedImage(
            thumbnail: thumbnail,
            prediction: "",
            modelView: emptyModelView,
          ));
          _controller.clear();
        });
        return;
      }

      // 5. Crop to bounding box with some padding
      final padding = 5;
      final cropMinX = max(0, minX - padding);
      final cropMinY = max(0, minY - padding);
      final cropMaxX = min(width - 1, maxX + padding);
      final cropMaxY = min(height - 1, maxY + padding);
      
      final cropped = img.copyCrop(
        image,
        x: cropMinX,
        y: cropMinY,
        width: cropMaxX - cropMinX + 1,
        height: cropMaxY - cropMinY + 1,
      );

      // 6. Resize while preserving aspect ratio to fit 20x20
      final scale = 20 / max(cropped.width, cropped.height);
      final newWidth = (cropped.width * scale).round();
      final newHeight = (cropped.height * scale).round();
      final resized = img.copyResize(cropped, width: newWidth, height: newHeight);

      // 7. Center on 28x28 black canvas
      final canvas28 = img.Image(width: 28, height: 28);
      img.fill(canvas28, color: img.ColorRgb8(255, 255, 255));
      final xOffset = ((28 - newWidth) / 2).round();
      final yOffset = ((28 - newHeight) / 2).round();
      img.compositeImage(canvas28, resized, dstX: xOffset, dstY: yOffset);

      // 8. Convert to [1,28,28,1] with inverted grayscale
      final processedInput = List.generate(1, (_) => List.generate(28, (y) {
        return List.generate(28, (x) {
          final pixel = canvas28.getPixel(x, y);
          final gray = (0.299*pixel.r + 0.587*pixel.g + 0.114*pixel.b)/255.0;
          return [1 - gray]; // invert: black background → 0, white strokes → 1
        });
      }));

      // 2. Save and clear     
      final sample = SaveModelInput(
        input: processedInput,
        label: label,
      );
      _controller.clear();


      // 3. Add to the list
      savedInputs.add(sample);
      print('✅ Saved input with label $label. Total saved: ${savedInputs.length}');


    } catch (e) {
      print('Error in _handleSave: $e');
    }
  }

  // HELPER FOR HANDLESAVE FUNCTION
  Uint8List _createEmptyModelView() {
    final im = img.Image(width: 28, height: 28);
    img.fill(im, color: img.ColorRgb8(255, 255, 255)); // White for empty
    return Uint8List.fromList(img.encodePng(im));
  }

  // ALLOWS US TO SEE WHAT THE MODEL IS RECIEVING AS INPUT
  Uint8List modelInputToImage(List<List<List<List<double>>>> input) {
    // Create a 28x28 grayscale image
    final im = img.Image(width: 28, height: 28);

    for (int y = 0; y < 28; y++) {
      for (int x = 0; x < 28; x++) {
        // Retrieve the inverted grayscale value used by the model
        final val = input[0][y][x][0]; // 0..1
        final gray = ((1.0 - val) * 255).toInt(); // 1→0 (black), 0→255 (white)

        // Clamp to valid range
        final clampedGray = gray.clamp(0, 255);

      // Set pixel
      im.setPixelRgba(x, y, clampedGray, clampedGray, clampedGray, 255);
      }
    }

    // Encode as PNG for display
    return Uint8List.fromList(img.encodePng(im));
  }

  // Save all collected model inputs to a local file and clear current list
  // Fixed ultimateSave - APPEND to existing data instead of overwriting
  Future<void> ultimateSave() async {
    try {
      if (savedInputs.isEmpty) {
        print('ℹ️ No inputs to save');
        return;
      }

      // Path to the Download folder in the emulator
      final directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final file = File('${directory.path}/saved_data.txt');

      // Load existing data if file exists
      List<SaveModelInput> allInputs = [];
      if (await file.exists()) {
        try {
          final content = await file.readAsString();
          if (content.isNotEmpty) {
            final List<dynamic> decoded = jsonDecode(content);
            allInputs = decoded
                .map((e) => SaveModelInput.fromJson(e as Map<String, dynamic>))
                .toList();
            print('📂 Loaded ${allInputs.length} existing inputs from file');
          }
        } catch (e) {
          print('⚠️ Error loading existing data: $e');
        }
      }

      // Add new inputs to existing data
      allInputs.addAll(savedInputs);

      // Convert all data to JSON and save
      final jsonStr = jsonEncode(allInputs.map((e) => e.toJson()).toList());
      await file.writeAsString(jsonStr);

      print('✅ Saved ${savedInputs.length} new inputs. Total in file: ${allInputs.length}');
      print('📍 File location: ${file.path}');

      // Clear the in-memory list after successful save
      savedInputs.clear();

    } catch (e) {
      print('❌ Error during ultimateSave: $e');
    }
  }
  
  // Load previously saved data from the local file into memory
  Future<void> loadSavedData() async {
    try {
      final directory = Directory('/storage/emulated/0/Download');
      final file = File('${directory.path}/saved_data.txt');

      // Uncomment this to clear the file (use carefully!)
      // await file.writeAsString('');
      // print('🗑️ Cleared saved_data.txt');
      // return;

      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final List<dynamic> decoded = jsonDecode(content);
          final loaded = decoded
              .map((e) => SaveModelInput.fromJson(e as Map<String, dynamic>))
              .toList();

          // Don't overwrite savedInputs on load - it's for accumulating new data
          // savedInputs = loaded;  // DON'T do this

          print('📂 File contains ${loaded.length} saved inputs');
          print('📍 File location: ${file.path}');
        } else {
          print('ℹ️ Saved file exists but is empty');
        }
      } else {
        print('ℹ️ No saved data file found at ${file.path}');
      }
    } catch (e) {
      print('❌ Error during loadSavedData: $e');
    }
  }
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadModel();
    loadSavedData();
    currentLabel = getNextLabel(); // pick first label when app starts
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[500],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Please write "$currentLabel" and click save',
          style: const TextStyle(color: Colors.black),
        ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _animationController.value * 0.5 * 3.141592653589793,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 2,
                        width: 20,
                        color: Colors.black,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 2,
                        width: 15,
                        color: Colors.black,
                      ),
                    ],
                  ),
                );
              },
            ),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: Drawer(
        backgroundColor: Colors.black,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Your Media',
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.book, color: Colors.white),
              title: const Text('Glossary', style: TextStyle(color: Colors.white)),
              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const GlossaryScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.star, color: Colors.white),
              title: const Text('Symbols', style: TextStyle(color: Colors.white)),
              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SymbolsScreen()),
                );
              },
            ),
            const Spacer(),
            const Divider(color: Colors.white),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.white),
              title: const Text('Logout', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 15.0),
        child: Row(
          children: [
            Expanded(
              child: Material(
                elevation: 4,
                child: Column(
                  children: [
                    Container(
                      width: 400,
                      height: 400,
                      color: Colors.white,
                      child: Scribble(notifier: _controller, drawPen: true,),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(onPressed: _controller.undo, child: const Text("Undo")),
                        ElevatedButton(onPressed: _controller.clear, child: const Text("Clear")),
                        ElevatedButton(
                          onPressed: () async {
                            if (currentLabel == null) return;

                            //await _saveModelInputList(currentLabel!);
                            await _handleSave();
                            //await ultimateSave();

                            // Check if we've completed 50 rounds
                            if (round >= 50) {
                              // Optionally show a message
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('✅ Collection complete!')),
                              );
                              return; // stop here, don't pick a new label
                            }

                            // Pick a new label after saving
                            setState(() {
                              currentLabel = getNextLabel();
                              
                            });
                          },
                          child: const Text('Save'),
                        ),
                      ],
                    ),                  
                  ],
                ),
              ),
            ),
            const VerticalDivider(width: 1, color: Colors.grey),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: saved.length,
                      itemBuilder: (context, index) {
                        final item = saved[index];
                        return Row(
                          children: [
                            Image.memory(item.modelView, width: 50, height: 50), // shows model input
                            SizedBox(width: 8),
                            Image.memory(item.thumbnail, width: 50, height: 50),
                            SizedBox(width: 8),
                            Text('Prediction: ${item.prediction}'),
                          ],
                        );
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () => setState(() => saved.clear()),
                        child: const Text("Clear All"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}