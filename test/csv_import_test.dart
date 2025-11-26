import 'package:flutter_test/flutter_test.dart';
import 'package:senior_project/models/library_models.dart';

/// Helper function to simulate CSV column mapping
/// This mirrors the logic in CsvColumnMappingScreen._buildEntriesFromMapping()
List<GlossaryEntry> buildEntriesFromMapping(
  List<List<dynamic>> csvData,
  List<String?> columnMappings,
) {
  List<GlossaryEntry> entries = [];
  
  int englishCol = columnMappings.indexOf('English');
  int spanishCol = columnMappings.indexOf('Spanish');
  int definitionCol = columnMappings.indexOf('Definition');
  int synonymCol = columnMappings.indexOf('Synonym');

  /// Safely get a cell value from a row, handling mismatched column lengths
  String safeGetCell(List<dynamic> row, int columnIndex) {
    if (columnIndex < 0 || columnIndex >= row.length) {
      return '';
    }
    final value = row[columnIndex];
    if (value == null) {
      return '';
    }
    return value.toString().trim();
  }

  for (int i = 1; i < csvData.length; i++) {
    List<dynamic> row = csvData[i];
    
    if (row.isEmpty || row.every((cell) => cell.toString().trim().isEmpty)) {
      continue;
    }

    // Use safe cell access to handle mismatched row lengths
    String english = safeGetCell(row, englishCol);
    String spanish = safeGetCell(row, spanishCol);
    String definition = safeGetCell(row, definitionCol);
    String synonym = safeGetCell(row, synonymCol);

    if (english.isNotEmpty || spanish.isNotEmpty || definition.isNotEmpty || synonym.isNotEmpty) {
      entries.add(GlossaryEntry(
        english: english,
        spanish: spanish,
        definition: definition,
        synonym: synonym,
      ));
    }
  }

  return entries;
}

void main() {
  group('CSV Import - Basic Functionality', () {
    test('Should parse valid CSV with all columns mapped', () {
      // Arrange
      final csvData = [
        ['English', 'Spanish', 'Definition', 'Synonym'],
        ['Hello', 'Hola', 'A greeting', 'Hi'],
        ['Goodbye', 'Adiós', 'A farewell', 'Bye'],
      ];
      final mappings = ['English', 'Spanish', 'Definition', 'Synonym'];

      // Act
      final entries = buildEntriesFromMapping(csvData, mappings);

      // Assert
      expect(entries.length, 2);
      expect(entries[0].english, 'Hello');
      expect(entries[0].spanish, 'Hola');
      expect(entries[0].definition, 'A greeting');
      expect(entries[0].synonym, 'Hi');
      expect(entries[1].english, 'Goodbye');
      expect(entries[1].spanish, 'Adiós');
    });

    test('Should parse CSV with some columns ignored', () {
      // Arrange
      final csvData = [
        ['Word', 'Translation', 'Extra', 'Info'],
        ['Cat', 'Gato', 'Ignored1', 'Ignored2'],
        ['Dog', 'Perro', 'Ignored3', 'Ignored4'],
      ];
      final mappings = ['English', 'Spanish', 'Ignore', 'Ignore'];

      // Act
      final entries = buildEntriesFromMapping(csvData, mappings);

      // Assert
      expect(entries.length, 2);
      expect(entries[0].english, 'Cat');
      expect(entries[0].spanish, 'Gato');
      expect(entries[0].definition, '');
      expect(entries[0].synonym, '');
    });

    test('Should parse CSV with only one column mapped', () {
      // Arrange
      final csvData = [
        ['Words', 'Extra', 'More'],
        ['Apple', 'x', 'y'],
        ['Banana', 'a', 'b'],
      ];
      final mappings = ['English', 'Ignore', 'Ignore'];

      // Act
      final entries = buildEntriesFromMapping(csvData, mappings);

      // Assert
      expect(entries.length, 2);
      expect(entries[0].english, 'Apple');
      expect(entries[0].spanish, '');
      expect(entries[1].english, 'Banana');
    });
  });

  group('CSV Import - Edge Cases', () {
    test('Should handle empty rows', () {
      // Arrange
      final csvData = [
        ['English', 'Spanish'],
        ['Hello', 'Hola'],
        ['', ''], // Empty row
        ['Goodbye', 'Adiós'],
      ];
      final mappings = ['English', 'Spanish'];

      // Act
      final entries = buildEntriesFromMapping(csvData, mappings);

      // Assert
      expect(entries.length, 2); // Empty row should be skipped
      expect(entries[0].english, 'Hello');
      expect(entries[1].english, 'Goodbye');
    });

    test('Should handle rows with whitespace only', () {
      // Arrange
      final csvData = [
        ['English', 'Spanish'],
        ['Hello', 'Hola'],
        ['   ', '  '], // Whitespace only
        ['Goodbye', 'Adiós'],
      ];
      final mappings = ['English', 'Spanish'];

      // Act
      final entries = buildEntriesFromMapping(csvData, mappings);

      // Assert
      expect(entries.length, 2); // Whitespace-only row should be skipped
    });

    test('Should handle mismatched column lengths - row too short', () {
      // Arrange
      final csvData = [
        ['English', 'Spanish', 'Definition', 'Synonym'],
        ['Hello', 'Hola', 'A greeting', 'Hi'],
        ['Goodbye', 'Adiós'], // Missing columns
        ['Good', 'Bueno', 'Positive'], // Missing one column
      ];
      final mappings = ['English', 'Spanish', 'Definition', 'Synonym'];

      // Act
      final entries = buildEntriesFromMapping(csvData, mappings);

      // Assert
      expect(entries.length, 3);
      expect(entries[0].english, 'Hello');
      expect(entries[0].synonym, 'Hi');
      // Row with missing columns
      expect(entries[1].english, 'Goodbye');
      expect(entries[1].spanish, 'Adiós');
      expect(entries[1].definition, ''); // Should be empty, not crash
      expect(entries[1].synonym, ''); // Should be empty, not crash
      // Row with one missing column
      expect(entries[2].english, 'Good');
      expect(entries[2].synonym, ''); // Should be empty
    });

    test('Should handle mismatched column lengths - row too long', () {
      // Arrange
      final csvData = [
        ['English', 'Spanish'],
        ['Hello', 'Hola'],
        ['Goodbye', 'Adiós', 'Extra1', 'Extra2'], // Extra columns
      ];
      final mappings = ['English', 'Spanish'];

      // Act
      final entries = buildEntriesFromMapping(csvData, mappings);

      // Assert
      expect(entries.length, 2);
      expect(entries[1].english, 'Goodbye');
      expect(entries[1].spanish, 'Adiós');
      // Extra columns should be ignored
    });

    test('Should handle null values in cells', () {
      // Arrange
      final csvData = [
        ['English', 'Spanish'],
        ['Hello', null],
        [null, 'Adiós'],
      ];
      final mappings = ['English', 'Spanish'];

      // Act
      final entries = buildEntriesFromMapping(csvData, mappings);

      // Assert
      expect(entries.length, 2);
      expect(entries[0].english, 'Hello');
      expect(entries[0].spanish, '');
      expect(entries[1].english, '');
      expect(entries[1].spanish, 'Adiós');
    });

    test('Should handle special characters and Unicode', () {
      // Arrange
      final csvData = [
        ['English', 'Spanish'],
        ['Hello 😊', 'Hola'],
        ['Café', 'Café'],
        ['Quote"Test', 'Test\'Quote'],
        ['Line\nBreak', 'Salto\nDe\nLínea'],
      ];
      final mappings = ['English', 'Spanish'];

      // Act
      final entries = buildEntriesFromMapping(csvData, mappings);

      // Assert
      expect(entries.length, 4);
      expect(entries[0].english, 'Hello 😊');
      expect(entries[1].english, 'Café');
      expect(entries[2].english, 'Quote"Test');
    });

    test('Should skip rows where all mapped columns are empty', () {
      // Arrange
      final csvData = [
        ['English', 'Spanish', 'Extra'],
        ['Hello', 'Hola', 'Data'],
        ['', '', 'OnlyExtraData'], // All mapped columns empty
        ['Goodbye', 'Adiós', 'Data'],
      ];
      final mappings = ['English', 'Spanish', 'Ignore'];

      // Act
      final entries = buildEntriesFromMapping(csvData, mappings);

      // Assert
      expect(entries.length, 2); // Middle row should be skipped
      expect(entries[0].english, 'Hello');
      expect(entries[1].english, 'Goodbye');
    });

    test('Should trim whitespace from cell values', () {
      // Arrange
      final csvData = [
        ['English', 'Spanish'],
        ['  Hello  ', '  Hola  '],
        ['Goodbye\t', '\tAdiós'],
      ];
      final mappings = ['English', 'Spanish'];

      // Act
      final entries = buildEntriesFromMapping(csvData, mappings);

      // Assert
      expect(entries.length, 2);
      expect(entries[0].english, 'Hello');
      expect(entries[0].spanish, 'Hola');
      expect(entries[1].english, 'Goodbye');
      expect(entries[1].spanish, 'Adiós');
    });
  });

  group('CSV Import - Column Mapping', () {
    test('Should handle all columns mapped to Ignore', () {
      // Arrange
      final csvData = [
        ['Col1', 'Col2', 'Col3'],
        ['Data1', 'Data2', 'Data3'],
      ];
      final mappings = ['Ignore', 'Ignore', 'Ignore'];

      // Act
      final entries = buildEntriesFromMapping(csvData, mappings);

      // Assert
      expect(entries.length, 0); // No entries should be created
    });

    test('Should handle columns mapped in different order', () {
      // Arrange
      final csvData = [
        ['Spanish', 'English', 'Synonym', 'Definition'],
        ['Hola', 'Hello', 'Hi', 'A greeting'],
      ];
      final mappings = ['Spanish', 'English', 'Synonym', 'Definition'];

      // Act
      final entries = buildEntriesFromMapping(csvData, mappings);

      // Assert
      expect(entries.length, 1);
      expect(entries[0].spanish, 'Hola');
      expect(entries[0].english, 'Hello');
      expect(entries[0].synonym, 'Hi');
      expect(entries[0].definition, 'A greeting');
    });

    test('Should handle only Definition and Synonym mapped', () {
      // Arrange
      final csvData = [
        ['Def', 'Syn', 'Extra'],
        ['A word', 'Similar word', 'Ignored'],
      ];
      final mappings = ['Definition', 'Synonym', 'Ignore'];

      // Act
      final entries = buildEntriesFromMapping(csvData, mappings);

      // Assert
      expect(entries.length, 1);
      expect(entries[0].english, '');
      expect(entries[0].spanish, '');
      expect(entries[0].definition, 'A word');
      expect(entries[0].synonym, 'Similar word');
    });
  });

  group('CSV Import - Large Dataset', () {
    test('Should handle CSV with many rows', () {
      // Arrange
      final csvData = [['English', 'Spanish']];
      for (int i = 0; i < 1000; i++) {
        csvData.add(['Word$i', 'Palabra$i']);
      }
      final mappings = ['English', 'Spanish'];

      // Act
      final entries = buildEntriesFromMapping(csvData, mappings);

      // Assert
      expect(entries.length, 1000);
      expect(entries[0].english, 'Word0');
      expect(entries[999].spanish, 'Palabra999');
    });

    test('Should handle CSV with many columns', () {
      // Arrange
      final csvData = [
        ['Col0', 'English', 'Col2', 'Spanish', 'Col4', 'Col5', 'Definition'],
        ['X', 'Hello', 'Y', 'Hola', 'Z', 'W', 'A greeting'],
      ];
      final mappings = ['Ignore', 'English', 'Ignore', 'Spanish', 'Ignore', 'Ignore', 'Definition'];

      // Act
      final entries = buildEntriesFromMapping(csvData, mappings);

      // Assert
      expect(entries.length, 1);
      expect(entries[0].english, 'Hello');
      expect(entries[0].spanish, 'Hola');
      expect(entries[0].definition, 'A greeting');
    });
  });

  group('GlossaryEntry Model', () {
    test('Should create GlossaryEntry with all fields', () {
      // Act
      final entry = GlossaryEntry(
        english: 'Hello',
        spanish: 'Hola',
        definition: 'A greeting',
        synonym: 'Hi',
      );

      // Assert
      expect(entry.english, 'Hello');
      expect(entry.spanish, 'Hola');
      expect(entry.definition, 'A greeting');
      expect(entry.synonym, 'Hi');
      expect(entry.symbolImage, null);
    });

    test('Should create GlossaryEntry with short constructor', () {
      // Act
      final entry = GlossaryEntry.short(word: 'Hello');

      // Assert
      expect(entry.english, 'Hello');
      expect(entry.spanish, '');
      expect(entry.definition, '');
      expect(entry.synonym, '');
      expect(entry.symbolImage, null);
    });
  });

  group('GlossaryItem Model', () {
    test('Should create empty GlossaryItem', () {
      // Act
      final glossary = GlossaryItem(
        id: '1',
        name: 'Test Glossary',
      );

      // Assert
      expect(glossary.id, '1');
      expect(glossary.name, 'Test Glossary');
      expect(glossary.entries.length, 0);
      expect(glossary.isChecked, false);
      expect(glossary.parentId, null);
    });

    test('Should add and delete entries', () {
      // Arrange
      final glossary = GlossaryItem(id: '1', name: 'Test');
      final entry1 = GlossaryEntry.short(word: 'Hello');
      final entry2 = GlossaryEntry.short(word: 'Goodbye');

      // Act
      glossary.addEntry(entry1);
      glossary.addEntry(entry2);

      // Assert
      expect(glossary.entries.length, 2);
      expect(glossary.entries[0].english, 'Hello');
      expect(glossary.entries[1].english, 'Goodbye');

      // Act - delete
      glossary.deleteEntry(0);

      // Assert
      expect(glossary.entries.length, 1);
      expect(glossary.entries[0].english, 'Goodbye');
    });

    test('Should handle invalid delete index gracefully', () {
      // Arrange
      final glossary = GlossaryItem(id: '1', name: 'Test');
      glossary.addEntry(GlossaryEntry.short(word: 'Hello'));

      // Act & Assert - should not throw
      glossary.deleteEntry(-1);
      expect(glossary.entries.length, 1);
      
      glossary.deleteEntry(10);
      expect(glossary.entries.length, 1);
    });
  });

  group('FolderItem Model', () {
    test('Should create empty FolderItem', () {
      // Act
      final folder = FolderItem(id: '1', name: 'Test Folder');

      // Assert
      expect(folder.id, '1');
      expect(folder.name, 'Test Folder');
      expect(folder.children.length, 0);
      expect(folder.isChecked, false);
      expect(folder.parentId, null);
    });

    test('Should add folders and glossaries as children', () {
      // Arrange
      final parentFolder = FolderItem(id: '1', name: 'Parent');
      final childFolder = FolderItem(id: '2', name: 'Child Folder', parentId: '1');
      final glossary = GlossaryItem(id: '3', name: 'Glossary', parentId: '1');

      // Act
      parentFolder.addChild(childFolder);
      parentFolder.addChild(glossary);

      // Assert
      expect(parentFolder.children.length, 2);
      expect(parentFolder.folders.length, 1);
      expect(parentFolder.glossaries.length, 1);
      expect(parentFolder.folders[0].name, 'Child Folder');
      expect(parentFolder.glossaries[0].name, 'Glossary');
    });

    test('Should remove child by id', () {
      // Arrange
      final parent = FolderItem(id: '1', name: 'Parent');
      final child1 = FolderItem(id: '2', name: 'Child1');
      final child2 = GlossaryItem(id: '3', name: 'Child2');
      parent.addChild(child1);
      parent.addChild(child2);

      // Act
      parent.removeChild('2');

      // Assert
      expect(parent.children.length, 1);
      expect(parent.children[0].id, '3');
    });
  });
}

