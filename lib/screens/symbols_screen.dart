
import 'package:flutter/material.dart';

class SymbolsScreen extends StatelessWidget {
  const SymbolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Symbols'),
      ),
      body: const Center(
        child: Text('This is the Symbols screen.'),
      ),
    );
  }
}
