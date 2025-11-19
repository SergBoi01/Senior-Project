import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:senior_project/screens/glossary_backend.dart';
import 'package:senior_project/screens/main_page.dart';
import 'package:senior_project/screens/notebook_backend.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> saveGlossary(List<GlossaryEntry> entries) async {
    final user = _auth.currentUser;
    if (user == null) return;

    List<Map<String, dynamic>> serializedEntries = [];
    for (var e in entries) {
      List<Map<String, dynamic>> strokesJson = e.strokes.map((stroke) {
        return {
          'points': stroke.points.map((p) => {'dx': p.dx, 'dy': p.dy}).toList(),
          'startTime': stroke.startTime.millisecondsSinceEpoch,
          'endTime': stroke.endTime.millisecondsSinceEpoch,
        };
      }).toList();

      serializedEntries.add({
        'english': e.english,
        'spanish': e.spanish,
        'definition': e.definition,
        'synonym': e.synonym,
        'symbolImage': e.symbolImage != null ? base64Encode(e.symbolImage!) : null,
        'strokes': strokesJson,
      });
    }

    await _db.collection('glossaries').doc(user.uid).set({
      'entries': serializedEntries,
    });
  }

  Future<List<GlossaryEntry>> loadGlossary() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final doc = await _db.collection('glossaries').doc(user.uid).get();
    if (!doc.exists || doc.data() == null) {
      return [];
    }

    final data = doc.data()!;
    final storedEntries = data['entries'] as List<dynamic>? ?? [];

    List<GlossaryEntry> loadedEntries = [];
    for (var entryData in storedEntries) {
      List<Stroke> loadedStrokes = [];
      if (entryData['strokes'] != null) {
        for (var strokeJson in entryData['strokes']) {
          List<Offset> points = (strokeJson['points'] as List)
              .map((p) => Offset(p['dx'], p['dy']))
              .toList();

          loadedStrokes.add(Stroke(
            points: points,
            startTime: DateTime.fromMillisecondsSinceEpoch(strokeJson['startTime']),
            endTime: DateTime.fromMillisecondsSinceEpoch(strokeJson['endTime']),
          ));
        }
      }

      loadedEntries.add(GlossaryEntry(
        english: entryData['english'] ?? '',
        spanish: entryData['spanish'] ?? '',
        definition: entryData['definition'] ?? '',
        synonym: entryData['synonym'] ?? '',
        symbolImage: entryData['symbolImage'] != null ? base64Decode(entryData['symbolImage']) : null,
        strokes: loadedStrokes,
      ));
    }
    return loadedEntries;
  }

  Future<void> saveUserCorrections(List<UserCorrection> corrections) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final serialized = corrections.map((c) => c.toJson()).toList();
    await _db.collection('user_corrections').doc(user.uid).set({
      'corrections': serialized,
    });
  }

  Future<List<UserCorrection>> loadUserCorrections() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final doc = await _db.collection('user_corrections').doc(user.uid).get();
    if (!doc.exists || doc.data() == null) {
      return [];
    }

    final data = doc.data()!;
    final stored = data['corrections'] as List<dynamic>? ?? [];

    return stored.map((s) => UserCorrection.fromJson(s)).toList();
  }

  Future<void> saveNotebook(NotebookManager notebook) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final data = {
      'pages': notebook.pages.map((p) => p.toJson()).toList(),
      'currentIndex': notebook.currentIndex,
    };
    await _db.collection('notebooks').doc(user.uid).set(data);
  }

  Future<NotebookManager> loadNotebook() async {
    final user = _auth.currentUser;
    if (user == null) return NotebookManager();

    final doc = await _db.collection('notebooks').doc(user.uid).get();
    if (!doc.exists || doc.data() == null) {
      return NotebookManager();
    }

    final data = doc.data()!;
    final notebook = NotebookManager();
    notebook.pages = (data['pages'] as List)
        .map((p) => NotebookPage.fromJson(p))
        .toList();
    notebook.currentIndex = data['currentIndex'] ?? 0;
    
    if (notebook.pages.isEmpty) {
      notebook.pages.add(NotebookPage());
      notebook.currentIndex = 0;
    }

    return notebook;
  }
}