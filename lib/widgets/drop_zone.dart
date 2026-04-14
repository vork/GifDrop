import 'dart:io';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';

class DropZone extends StatefulWidget {
  final void Function(List<String> filePaths) onFilesDropped;

  const DropZone({super.key, required this.onFilesDropped});

  @override
  State<DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<DropZone> {
  bool _isDragging = false;

  static const _supportedExtensions = [
    'mp4',
    'mov',
    'avi',
    'mkv',
    'webm',
    'flv',
    'wmv',
    'm4v',
    'mpg',
    'mpeg',
    'gif',
  ];

  bool _isSupportedFile(String path) {
    final ext = path.split('.').last.toLowerCase();
    return _supportedExtensions.contains(ext);
  }

  /// Recursively collects all supported file paths under [dirPath].
  List<String> _collectSupportedFilesFromDirectory(String dirPath) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return [];
    final list = <String>[];
    try {
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is File && _isSupportedFile(entity.path)) {
          list.add(entity.path);
        }
      }
    } catch (_) {
      // Skip directories we can't read (permissions, symlinks, etc.)
    }
    return list;
  }

  /// Expands paths: directories become supported files inside (recursive).
  List<String> _expandPathsToSupportedFiles(List<String> paths) {
    final out = <String>{};
    for (final path in paths) {
      final entity = File(path);
      final dir = Directory(path);
      if (dir.existsSync()) {
        out.addAll(_collectSupportedFilesFromDirectory(path));
      } else if (entity.existsSync() && _isSupportedFile(path)) {
        out.add(path);
      }
    }
    return out.toList();
  }

  Future<void> _pickFiles() async {
    // Defer so the window is ready and native dialog can appear on top (desktop).
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    final isDesktop = Platform.isMacOS || Platform.isWindows || Platform.isLinux;
    final result = await FilePicker.platform.pickFiles(
      type: isDesktop ? FileType.any : FileType.custom,
      allowedExtensions: isDesktop ? null : _supportedExtensions,
      allowMultiple: true,
      dialogTitle: 'Select video or GIF files',
      lockParentWindow: true,
    );
    if (!mounted) return;
    if (result != null) {
      final paths = result.files
          .where((f) => f.path != null)
          .map((f) => f.path!)
          .where(_isSupportedFile)
          .toList();
      if (paths.isNotEmpty) {
        widget.onFilesDropped(_expandPathsToSupportedFiles(paths));
      }
    }
  }

  Future<void> _pickFolder() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    final dirPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select folder with videos or GIFs',
      lockParentWindow: true,
    );
    if (!mounted) return;
    if (dirPath != null) {
      final files = _collectSupportedFilesFromDirectory(dirPath);
      if (files.isNotEmpty) {
        widget.onFilesDropped(files);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = _isDragging
        ? theme.colorScheme.primary
        : theme.colorScheme.outline.withValues(alpha: 0.4);
    final bgColor = _isDragging
        ? theme.colorScheme.primary.withValues(alpha: 0.08)
        : theme.colorScheme.surfaceContainerLow;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropTarget(
          onDragEntered: (_) => setState(() => _isDragging = true),
          onDragExited: (_) => setState(() => _isDragging = false),
          onDragDone: (details) {
            setState(() => _isDragging = false);
            final paths = details.files.map((f) => f.path).toList();
            final files = _expandPathsToSupportedFiles(paths);
            if (files.isNotEmpty) {
              widget.onFilesDropped(files);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 160,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 2),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.video_file_outlined,
                    size: 48,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Drop video/GIF files or a folder here',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton.icon(
              onPressed: _pickFiles,
              icon: const Icon(Icons.folder_open, size: 18),
              label: const Text('Browse Files'),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: _pickFolder,
              icon: const Icon(Icons.folder, size: 18),
              label: const Text('Add Folder'),
            ),
          ],
        ),
      ],
    );
  }
}
