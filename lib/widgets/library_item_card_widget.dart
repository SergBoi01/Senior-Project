import 'package:flutter/material.dart';
import '../models/library_model.dart';

class LibraryItemCard extends StatelessWidget {
  final dynamic item;
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
    return GestureDetector(
      onTap: onTap,
      onLongPress: onRename,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: Offset(0,2))],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(isFolder ? Icons.folder : Icons.book, color: isFolder ? Colors.amber[700] : Colors.blue[700]),
                const SizedBox(width: 12),
                Flexible(child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500))),
              ],
            ),
            GestureDetector(
              onTap: () => onCheckboxChanged?.call(!isChecked),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isChecked ? Colors.green : Colors.white,
                  border: Border.all(color: isChecked ? Colors.green : Colors.black, width: 2),
                ),
                child: isChecked ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
