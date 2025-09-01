
import 'package:flutter/material.dart';
import 'package:senior_project/screens/glossary_screen.dart';
import 'package:senior_project/screens/symbols_screen.dart';

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Main Page'),
      ),
      drawer: Drawer(
        child: ListView(
          // Important: Remove any padding from the ListView.
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text('Menu'),
            ),
            ListTile(
              leading: const Icon(Icons.book),
              title: const Text('Glossary'),
              onTap: () {
                // Close the drawer
                Navigator.pop(context);
                // Navigate to the glossary screen
                Navigator.push(context, MaterialPageRoute(builder: (context) => const GlossaryScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.star),
              title: const Text('Symbols'),
              onTap: () {
                // Close the drawer
                Navigator.pop(context);
                // Navigate to the symbols screen
                Navigator.push(context, MaterialPageRoute(builder: (context) => const SymbolsScreen()));
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                // Close the drawer
                Navigator.pop(context);
                // Navigate back to login screen
                Navigator.pushReplacementNamed(context, '/');
              },
            ),
          ],
        ),
      ),
      body: const Center(
        child: Text('Welcome to the Main Page!'),
      ),
    );
  }
}
