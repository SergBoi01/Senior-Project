import 'package:flutter/material.dart';
import '../models/library_models.dart';

class LibraryItemCard extends StatelessWidget {
  final dynamic item; // Can be FolderItem or GlossaryItem
  final VoidCallback onTap;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;
  final Function(bool)? onCheckboxChanged;

  const LibraryItemCard({
    Key? key,
    required this.item,
    required this.onTap,
    this.onRename,
    this.onDelete,
    this.onCheckboxChanged,
  }) : super(key: key);

  bool get isFolder => item is FolderItem;
  bool get isChecked => item.isChecked;
  String get name => item.name;

  // Show action popup on long press
  void _showActionPopup(BuildContext context) {
    // Determine item type text
    String itemTypeText;
    if (item is FolderItem) {
      itemTypeText = (item as FolderItem).parentId != null ? 'Subfolder' : 'Folder';
    } else {
      itemTypeText = 'Glossary';
    }
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with item info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isFolder 
                            ? Colors.amber.withOpacity(0.2) 
                            : Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isFolder ? Icons.folder : Icons.book,
                        color: isFolder ? Colors.amber[700] : Colors.blue[700],
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            itemTypeText,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // Action buttons
              _buildActionButton(
                context,
                icon: Icons.edit_outlined,
                label: 'Rename',
                color: Colors.grey[700]!,
                onTap: () {
                  Navigator.pop(context);
                  if (onRename != null) onRename!();
                },
              ),
              const SizedBox(height: 10),
              _buildActionButton(
                context,
                icon: Icons.delete_outline,
                label: 'Delete',
                color: Colors.red[400]!,
                onTap: () {
                  Navigator.pop(context);
                  if (onDelete != null) onDelete!();
                },
              ),
              const SizedBox(height: 16),
              
              // Cancel button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Card color changes based on checkbox state
    Color cardColor = isChecked ? Colors.green : Colors.white;
    Color textColor = Colors.black;

    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showActionPopup(context),
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
                  // Checkbox - just toggles check state
                  GestureDetector(
                    onTap: () {
                      // Simply toggle the checkbox state
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
