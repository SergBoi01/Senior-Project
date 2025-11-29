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
    // Card color changes based on checked state (green when checked, white when not)
    Color cardColor = isChecked ? Colors.green : Colors.white;
    Color textColor = isChecked ? Colors.white : Colors.black;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onRename,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Item name
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 8),
              // Checkbox (right side)
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
                    color: isChecked ? Colors.white : Colors.transparent,
                    border: Border.all(
                      color: isChecked ? Colors.white : Colors.green,
                      width: 2,
                    ),
                  ),
                  child: isChecked
                      ? Icon(
                          Icons.check,
                          size: 16,
                          color: Colors.green,
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

