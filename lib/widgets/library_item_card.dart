import 'package:flutter/material.dart';
import '../models/library_models.dart';

class LibraryItemCard extends StatelessWidget {
  final dynamic item; // Can be FolderItem or GlossaryItem
  final VoidCallback onTap;
  final VoidCallback? onRename;
  final Function(bool)? onCheckboxChanged;

  const LibraryItemCard({
    super.key,
    required this.item,
    required this.onTap,
    this.onRename,
    this.onCheckboxChanged,
  });

  bool get isFolder => item is FolderItem;
  bool get isChecked => item.isChecked;
  String get name => item.name;

  @override
  Widget build(BuildContext context) {
    // Card always stays white, only checkbox changes
    Color cardColor = Colors.white;
    Color textColor = Colors.black;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onRename,
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Folder tab indicator (top-left corner)
            if (isFolder)
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  width: 40,
                  height: 20,
                  decoration: BoxDecoration(
                    color: cardColor.withOpacity(0.8),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                ),
              ),
            // Content - horizontal layout
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icon and item name
                  Expanded(
                    child: Row(
                      children: [
                        // Folder or Glossary icon
                        Icon(
                          isFolder ? Icons.folder : Icons.book,
                          color: isFolder ? Colors.amber[700] : Colors.blue[700],
                          size: 24,
                        ),
                        SizedBox(width: 12),
                        // Item name
                        Flexible(
                          child: Text(
                            name,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                  // Checkbox (right side) - only this changes color
                  GestureDetector(
                    onTap: () {
                      if (onCheckboxChanged != null) {
                        onCheckboxChanged!(!isChecked);
                      }
                    },
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isChecked ? Colors.green : Colors.white,
                        border: Border.all(
                          color: isChecked ? Colors.green : Colors.black,
                          width: 2,
                        ),
                      ),
                      child: isChecked
                          ? Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            )
                          : null,
                    ),
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

