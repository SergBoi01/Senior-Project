
import 'package:flutter/material.dart';

class GlossaryScreen extends StatelessWidget {
  const GlossaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Glossary'),
      ),
      body: const Center(
        child: Text('This is the Glossary screen.'),
      ),
    );
  }
}
