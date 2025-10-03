import 'package:flutter/material.dart';
import 'package:senior_project/screens/glossary_screen.dart';
import 'package:senior_project/screens/login_screen.dart';
import 'package:senior_project/screens/symbols_screen.dart';

import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:scribble/scribble.dart';
import 'dart:typed_data';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:async';
import 'dart:io';
import 'dart:convert';

// This code can be divided INTO gathering training data for model AND verifying model prediction, ModelView

// For gathering
// TO SEE SAVED TXT FILE OF LIST INPUTS. 
// RUN PROGRAM THEN ON POWERSHELL VSCODE TERMINAL COPY 
// adb pull /storage/emulated/0/Download/saved_data.txt C:\Users\Kirit\Downloads\

// For gathering
// Saves input and label needed to train a model and save to seperate file
// Called save input/label and save to file to save in between runs
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

// For verifying
// Saves thumbnail, model prediction, and modelView to display on the right-hand side
// Called to verify the model it predicting and seeing input correctly
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

// For verifying
// Holds boundariy lines
class BoundingBox {
  int minX, minY, maxX, maxY;
  BoundingBox(this.minX, this.minY, this.maxX, this.maxY);
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with SingleTickerProviderStateMixin {
  
  ///////////////////////////////////////////////////////////////////////////////
  /// ALWAYS

  // Always stays
  // Change thickness/color of pen in canvas
  final ScribbleNotifier _controller = ScribbleNotifier()
  ..setStrokeWidth(10.0)  
  ..setColor(Colors.black);

  // Always stays
  late Interpreter interpreter;

  // UI ITEMS
  late AnimationController _animationController;
  bool isMenuOpen = false;

  // Always stays
  Future<void> _loadModel() async {
    // Dependings on the model I want to run
    interpreter = await Interpreter.fromAsset('assets/models/alphabet_25_50_trained.tflite');
    print('Interpreter initialized: $interpreter');
  }

  // adds timer to check symbols automatically 
  Timer? _autoProcessTimer;
  bool _isProcessing = false; // Prevent overlapping calls
  // functions for automatic symbol check
  void _startAutoProcessing() {
    _autoProcessTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!_isProcessing) {
        _isProcessing = true;
        await multiple();
        _isProcessing = false;
      }
    });
  }
  void _stopAutoProcessing() {
    _autoProcessTimer?.cancel();
    _autoProcessTimer = null;
  }
  
  ////GATHERING///////////////////////////////////////////////////////////////////////////
  /// GATHERING
  
  // For gathering
  // Created to hold list of model inputs from user
  List<SaveModelInput> savedInputs = [];

  // For gathering
  // Labels for Alphabet_25 model
  final List<String> labels = [
    'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z',
    'a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v','w','x','y','z',
  ];

  // Loops List<String> labels
  int round = 25; // completed rounds. is updated manually every run
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
  String? currentLabel;

  // For gathering
  // Load previously saved training data from the emulator file into app memory
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
  
  // For gathering
  // Preprocess drawing, 
  // Saves in List<SaveModelInput> savedInputs
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

  // For gathering
  // Saves all items in List<SaveModelInput> savedInputs to an emulator file and clear current list
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
  
  ///////////////////////////////////////////////////////////////////////////////
  /// VERIFYING - WORKS
  
  // For verifying
  // Created to hold list of process symbols from user with prediction - for right right
  final List<SavedImage> saved = [];

  // For verifying
  // Preprocess drawing, runs model, 
  // Saves prediction in List<SavedImage> saved - for right side
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

  // For verifying
  // Lets the testers/creaters see what the model is seeing
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

  // For both
  // Called to creates an empty 28x28 canvas
  // Helper for functions: _handleSave and _saveModelInputList
  Uint8List _createEmptyModelView() {
    final im = img.Image(width: 28, height: 28);
    img.fill(im, color: img.ColorRgb8(255, 255, 255)); // White for empty
    return Uint8List.fromList(img.encodePng(im));
  }

  ///////////////////////////////////////////////////////////////////////////////
  /// VERIFYING MULTIPLE INPUTS CANVAS- TESTING
  
  // For verifying
  // Turns entire canvas Uint8List
  Future<Uint8List> getCanvasBytes(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return byteData!.buffer.asUint8List();
  }
  
  // For verifying
  // BFS through canvas to make bound boxes in symbols
  List<BoundingBox> detectSymbols(Uint8List rgba, int width, int height) {
    final visited = List<bool>.filled(width * height, false);
    final boxes = <BoundingBox>[];

    bool isBlack(int x, int y) {
      final i = (y * width + x) * 4;
      final r = rgba[i], g = rgba[i + 1], b = rgba[i + 2], a = rgba[i + 3];
      // Treat opaque dark pixels as “black”
      return a > 0 && (r < 50 && g < 50 && b < 50);
    }

    void floodFill(int startX, int startY) {
      final stack = <List<int>>[];
      stack.add([startX, startY]);
      visited[startY * width + startX] = true;

      int minX = startX, maxX = startX;
      int minY = startY, maxY = startY;

      while (stack.isNotEmpty) {
        final point = stack.removeLast();
        final x = point[0], y = point[1];

        // Track bounding box
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;

        for (var dx = -1; dx <= 1; dx++) {
          for (var dy = -1; dy <= 1; dy++) {
            if (dx == 0 && dy == 0) continue;
            final nx = x + dx, ny = y + dy;
            if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue;
            final idx = ny * width + nx;
            if (!visited[idx] && isBlack(nx, ny)) {
              visited[idx] = true;
              stack.add([nx, ny]);
            }
          }
        }
      }

      boxes.add(BoundingBox(minX, minY, maxX, maxY));
    }

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final idx = y * width + x;
        if (!visited[idx] && isBlack(x, y)) {
          floodFill(x, y);
        }
      }
    }

    return boxes;
  }
  
  // For verifying
  // Goes through List<BoundingBox>, preprocess, runs model
  Future<void> multiple() async {
    try {
      // Step 1: Render canvas to ui.Image
      final ByteData byteData = await _controller.renderImage();
      final Uint8List pngBytes = byteData.buffer.asUint8List();
      
      // Decode to get dimensions
      final ui.Codec codec = await ui.instantiateImageCodec(pngBytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image uiImage = frameInfo.image;

      // Step 2: Convert to raw RGBA bytes
      final Uint8List rgba = await getCanvasBytes(uiImage);
      
      // Step 3: Detect all symbol bounding boxes
      final List<BoundingBox> boxes = detectSymbols(rgba, uiImage.width, uiImage.height);
      print('Detected ${boxes.length} symbols');

      if (boxes.isEmpty) {
        print('No symbols detected on canvas');
        return;
      }

      // Step 4: Decode PNG for image processing
      final img.Image? fullImage = img.decodeImage(pngBytes);
      if (fullImage == null) {
        print('Failed to decode canvas image');
        return;
      }

      // Step 5: Process each detected symbol
      for (int i = 0; i < boxes.length; i++) {
        final box = boxes[i];
        print('Processing symbol ${i + 1}/${boxes.length}');

        // Skip if box is too small (noise)
        final boxWidth = box.maxX - box.minX + 1;
        final boxHeight = box.maxY - box.minY + 1;
        if (boxWidth < 5 || boxHeight < 5) {
          print('Skipping small box: ${boxWidth}x${boxHeight}');
          continue;
        }

        // Crop to bounding box with padding
        final padding = 5;
        final cropMinX = max(0, box.minX - padding);
        final cropMinY = max(0, box.minY - padding);
        final cropMaxX = min(fullImage.width - 1, box.maxX + padding);
        final cropMaxY = min(fullImage.height - 1, box.maxY + padding);
        
        final cropped = img.copyCrop(
          fullImage,
          x: cropMinX,
          y: cropMinY,
          width: cropMaxX - cropMinX + 1,
          height: cropMaxY - cropMinY + 1,
        );

        // Resize while preserving aspect ratio to fit 20x20
        final scale = 20 / max(cropped.width, cropped.height);
        final newWidth = (cropped.width * scale).round();
        final newHeight = (cropped.height * scale).round();
        final resized = img.copyResize(cropped, width: newWidth, height: newHeight);

        // Center on 28x28 white canvas
        final canvas28 = img.Image(width: 28, height: 28);
        img.fill(canvas28, color: img.ColorRgb8(255, 255, 255));
        final xOffset = ((28 - newWidth) / 2).round();
        final yOffset = ((28 - newHeight) / 2).round();
        img.compositeImage(canvas28, resized, dstX: xOffset, dstY: yOffset);

        // Convert to [1,28,28,1] with inverted grayscale
        final input = List.generate(1, (_) => List.generate(28, (y) {
          return List.generate(28, (x) {
            final pixel = canvas28.getPixel(x, y);
            final gray = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b) / 255.0;
            return [1 - gray]; // white background → 0, black strokes → 1
          });
        }));

        // Run TFLite model
        var output = List.generate(1, (_) => List.filled(52, 0.0));
        interpreter.run(input, output);

        // Find predicted label
        final outputList = output[0];
        final maxIndex = outputList.indexWhere(
          (v) => v == outputList.reduce((a, b) => a > b ? a : b),
        );
        final predictedLabel = labels[maxIndex];
        final confidence = outputList[maxIndex];
        
        print('Symbol ${i + 1}: "$predictedLabel" (${(confidence * 100).toStringAsFixed(1)}% confidence)');

        // Convert preprocessed input to image for display
        final Uint8List modelView = modelInputToImage(input);
        final Uint8List symbolThumbnail = Uint8List.fromList(img.encodePng(canvas28));

        // Add to saved list
        setState(() {
          saved.add(SavedImage(
            thumbnail: symbolThumbnail,
            prediction: predictedLabel,
            modelView: modelView,
          ));
        });
      }

      // Clear canvas after processing all symbols
      
      print('✅ Processed ${boxes.length} symbols');

    } catch (e) {
      print('❌ Error in multiple(): $e');
    }
  }

  ///// END FUNCTIONS /////
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadModel(); // always stays
    // starts timer - always stays
    _loadModel().then((_) { // always stays
      _startAutoProcessing();
    });

    // Only called if gathering training data
    // loadSavedData();
    // currentLabel = getNextLabel(); 
  }

  @override
  void dispose() {
    _animationController.dispose();
    _stopAutoProcessing();
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
        // This changes depending if we are gathering training data or verifying model prediction, ModelView
        
        // If gathering data use
        //title: Text(
        //  'Please write "$currentLabel" and click save',
        //  style: const TextStyle(color: Colors.black),
        //),

        // If verifying use
        title: Text(
          "Welcome User", 
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
        padding: const EdgeInsets.all(15.0),
        child: Row(
          children: [
            // left side - canvas
            Expanded(
              flex: 80,
              child: Material(
                elevation: 4,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Calculate canvas size based on available height
                    final availableWidth = constraints.maxWidth - 40;
                    final availableHeight = constraints.maxHeight;
                    final buttonAreaHeight = 80.0; // Space for buttons and spacing
                    final maxCanvasHeight = availableHeight - buttonAreaHeight;

                    // Use full available width and height (rectangle)
                    final canvasWidth = availableWidth.clamp(200.0, double.infinity);
                    final canvasHeight = maxCanvasHeight.clamp(200.0, double.infinity);
                
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // canvas
                        Container(
                          width: canvasWidth, 
                          height: canvasHeight,
                          color: Colors.white,
                          child: Scribble(notifier: _controller, drawPen: true,),
                        ),
                        const SizedBox(height: 14),
                        // Buttons - under canvas
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              // If narrow, stack vertically; otherwise horizontal
                              if (constraints.maxWidth < 400) {
                                return Column(
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: _controller.undo, 
                                        child: const Text("Undo")
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: _controller.clear, 
                                        child: const Text("Clear")
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        // This changes depending if we are gathering training data or verifying model prediction, ModelView

                                        // If gathering training data use this 
                                        //if (currentLabel == null) return;
                                        //await _saveModelInputList(currentLabel!);
                                        //await ultimateSave();

                                        // Check if we've completed 50 rounds
                                        //if (round >= 50) {
                                        //  // Optionally show a message
                                        //  ScaffoldMessenger.of(context).showSnackBar(
                                        //   const SnackBar(content: Text('Collection complete!')),
                                        //  );
                                        //  return; // stop here, don't pick a new label
                                        //}
                                          
                                        // Pick a new label after saving
                                        //setState(() {
                                        //  currentLabel = getNextLabel();                              
                                        //});

                                        // If verifying model prediction, ModelView use this 
                                        onPressed: multiple, 
                                        child: const Text('Save'),
                                      ),
                                    ),
                                  ],
                                );
                              } else {
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                        child: ElevatedButton(
                                          onPressed: _controller.undo, 
                                          child: const Text("Undo")
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                        child: ElevatedButton(
                                          onPressed: _controller.clear, 
                                          child: const Text("Clear")
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                        child: ElevatedButton(
                                          // This changes depending if we are gathering training data or verifying model prediction, ModelView

                                          // If gathering training data use this 
                                          //if (currentLabel == null) return;
                                          //await _saveModelInputList(currentLabel!);
                                          //await ultimateSave();

                                          // Check if we've completed 50 rounds
                                          //if (round >= 50) {
                                          //  // Optionally show a message
                                          //  ScaffoldMessenger.of(context).showSnackBar(
                                          //   const SnackBar(content: Text('Collection complete!')),
                                          //  );
                                          //  return; // stop here, don't pick a new label
                                          //}
                                          
                                          // Pick a new label after saving
                                          //setState(() {
                                          //  currentLabel = getNextLabel();                              
                                          //});

                                          // If verifying model prediction, ModelView use this 
                                          onPressed: multiple, 
                                          child: const Text('Save'),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }
                            },
                          ),
                        ), 
                        const SizedBox(height: 16),               
                      ],
                    );
                  },
                ),
              ),
            ),
            // side divider                  
            const VerticalDivider(width: 1, color: Colors.grey, thickness: 1),
            
            // right side - predictions
            Expanded(
              flex: 20,
              child: Container(
                color: Colors.grey[400],
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8.0),
                        itemCount: saved.length,
                        itemBuilder: (context, index) {
                          final item = saved[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    // Works if we are verifying model prediction, ModelView
                                    Image.memory(
                                      item.modelView, 
                                      width: 40, height: 40, 
                                      fit: BoxFit.contain,
                                    ), 
                                    const SizedBox(width: 4),
                                    Image.memory(
                                      item.thumbnail, 
                                      width: 40, height: 40, 
                                      fit: BoxFit.contain,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4,),
                                Text(
                                  'Prediction: ${item.prediction}',
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const Divider(),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton (
                          onPressed: () => setState(() => saved.clear()),
                          child: const Text("Clear All"),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}