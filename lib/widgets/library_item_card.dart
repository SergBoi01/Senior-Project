import 'package:flutter/material.dart';
import '../models/library_models.dart';

class LibraryItemCard extends StatelessWidget {
  // Design colors matching the app theme
  static const Color primaryGreen = Color(0xFF5B8A51);
  static const Color backgroundColor = Color(0xFFE8E8E8);
  static const Color cardColor = Colors.white;
  static const Color darkText = Color(0xFF2D2D2D);
  static const Color subtleText = Color(0xFF6B6B6B);

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
  bool get isSubfolder => item is FolderItem && (item as FolderItem).parentId != null;
  bool get isChecked => item.isChecked;
  String get name => item.name;
  
  // Get the appropriate icon for the item type
  IconData get itemIcon {
    if (!isFolder) return Icons.book;
    return isSubfolder ? Icons.folder_copy : Icons.folder;
  }

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
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with item info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isFolder 
                            ? Colors.amber.withOpacity(0.15) 
                            : Colors.blue.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        itemIcon,
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
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: darkText,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            itemTypeText,
                            style: const TextStyle(
                              fontSize: 12,
                              color: subtleText,
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
                color: darkText,
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
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: subtleText,
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
    Color bgColor = isChecked ? primaryGreen.withOpacity(0.15) : cardColor;
    Color textColor = darkText;

    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showActionPopup(context),
      child: Container(
        alignment: Alignment.topCenter,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: isChecked 
              ? Border.all(color: primaryGreen, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon and item name
              Expanded(
                child: Row(
                  children: [
                    // Folder or Glossary icon with background
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isFolder 
                            ? Colors.amber.withOpacity(0.15)
                            : Colors.blue.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        itemIcon,
                        color: isFolder ? Colors.amber[700] : Colors.blue[700],
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Item name
                    Flexible(
                      child: Text(
                        name,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
                    color: isChecked ? primaryGreen : cardColor,
                    border: Border.all(
                      color: isChecked ? primaryGreen : subtleText,
                      width: 2,
                    ),
                  ),
                  child: isChecked
                      ? const Icon(
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
      ),
    );
  }
}
