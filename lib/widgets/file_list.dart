import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import '../models/conversion_job.dart';

class FileList extends StatelessWidget {
  final List<ConversionJob> jobs;
  final int? selectedIndex;
  final void Function(int index) onSelect;
  final void Function(int index) onRemove;
  final VoidCallback onClearAll;

  const FileList({
    super.key,
    required this.jobs,
    required this.selectedIndex,
    required this.onSelect,
    required this.onRemove,
    required this.onClearAll,
  });

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Files (${jobs.length})',
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            if (jobs.isNotEmpty)
              TextButton.icon(
                onPressed: onClearAll,
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('Clear All'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: jobs.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              color: theme.colorScheme.outline.withValues(alpha: 0.15),
            ),
            itemBuilder: (context, index) {
              final job = jobs[index];
              final isSelected = selectedIndex == index;

              return Material(
                color: isSelected
                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
                    : Colors.transparent,
                child: InkWell(
                  onTap: job.status == ConversionJobStatus.done
                      ? () => onSelect(index)
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        _buildStatusIcon(job, theme),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.basename(job.inputPath),
                                style: theme.textTheme.bodyMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (job.status ==
                                  ConversionJobStatus.converting ||
                                  job.status ==
                                      ConversionJobStatus.optimizing)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: LinearProgressIndicator(
                                    value: job.progress,
                                    minHeight: 3,
                                  ),
                                ),
                              if (job.status == ConversionJobStatus.error)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    job.errorMessage ?? 'Error',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.error,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (job.status == ConversionJobStatus.converting ||
                            job.status == ConversionJobStatus.optimizing)
                          Text(
                            '${(job.progress * 100).toInt()}%',
                            style: theme.textTheme.bodySmall,
                          ),
                        if (job.status == ConversionJobStatus.done &&
                            job.outputFileSize != null)
                          Text(
                            _formatFileSize(job.outputFileSize!),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        if (job.status == ConversionJobStatus.pending)
                          Text(
                            'Pending',
                            style: GoogleFonts.staatliches(
                              fontSize: 13,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => onRemove(index),
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          padding: EdgeInsets.zero,
                          splashRadius: 14,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIcon(ConversionJob job, ThemeData theme) {
    switch (job.status) {
      case ConversionJobStatus.pending:
        return Icon(
          Icons.schedule,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        );
      case ConversionJobStatus.converting:
      case ConversionJobStatus.optimizing:
        return SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            value: job.progress > 0 ? job.progress : null,
          ),
        );
      case ConversionJobStatus.done:
        return Icon(
          Icons.check_circle,
          size: 18,
          color: theme.colorScheme.primary,
        );
      case ConversionJobStatus.error:
        return Icon(
          Icons.error,
          size: 18,
          color: theme.colorScheme.error,
        );
    }
  }
}
