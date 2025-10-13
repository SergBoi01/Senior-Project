// glossary_screen.dart

import 'package:flutter/material.dart';
import 'glossary.dart';

class GlossaryScreen extends StatefulWidget {
  @override
  _GlossaryScreenState createState() => _GlossaryScreenState();
}

class _GlossaryScreenState extends State<GlossaryScreen> {
  final Glossary glossary = Glossary();

  final TextEditingController _englishController = TextEditingController();
  final TextEditingController _spanishController = TextEditingController();
  final TextEditingController _definitionController = TextEditingController();
  final TextEditingController _symbolController = TextEditingController();

  void _addEntry() {
    if (_englishController.text.isNotEmpty &&
        _spanishController.text.isNotEmpty &&
        _definitionController.text.isNotEmpty &&
        _symbolController.text.isNotEmpty) {
      setState(() {
        glossary.addEntry(
          _englishController.text,
          _spanishController.text,
          _definitionController.text,
          _symbolController.text,
        );
      });
      _englishController.clear();
      _spanishController.clear();
      _definitionController.clear();
      _symbolController.clear();
    }
  }

  void _deleteEntry(int index) {
    setState(() {
      glossary.deleteEntry(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Glossary")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: glossary.entries.length,
              itemBuilder: (context, index) {
                final entry = glossary.entries[index];
                return Card(
                  margin: EdgeInsets.all(8),
                  child: ListTile(
                    title: Text("${entry.english} / ${entry.spanish}"),
                    subtitle: Text(entry.definition),
                    leading: Text(entry.symbol, style: TextStyle(fontSize: 24)),
                    trailing: IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteEntry(index),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextField(
                  controller: _englishController,
                  decoration: InputDecoration(labelText: "English"),
                ),
                TextField(
                  controller: _spanishController,
                  decoration: InputDecoration(labelText: "Spanish"),
                ),
                TextField(
                  controller: _definitionController,
                  decoration: InputDecoration(labelText: "Definition"),
                ),
                TextField(
                  controller: _symbolController,
                  decoration: InputDecoration(labelText: "Symbol"),
                ),
                SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _addEntry,
                  child: Text("Add Entry"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}