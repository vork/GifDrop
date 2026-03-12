import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/conversion_settings.dart';

class SettingsPanel extends StatelessWidget {
  final ConversionSettings settings;
  final void Function(ConversionSettings) onSettingsChanged;
  final bool enabled;

  const SettingsPanel({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(theme, 'Resolution (width)'),
            const SizedBox(height: 8),
            _buildResolutionSelector(theme),
            const SizedBox(height: 16),
            _buildSectionTitle(theme, 'Frame Rate (FPS)'),
            const SizedBox(height: 8),
            _buildFpsSelector(theme),
            const SizedBox(height: 16),
            _buildSectionTitle(theme, 'Loop Mode'),
            const SizedBox(height: 8),
            _buildLoopModeSelector(theme),
            const SizedBox(height: 8),
            ExpansionTile(
              initiallyExpanded: true,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: 8),
              title: Text(
                'Optimization',
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              children: [
                _buildOptimizationSection(theme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: GoogleFonts.dmSans(
        fontWeight: FontWeight.w700,
        fontSize: 14,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildResolutionSelector(ThemeData theme) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: ConversionSettings.widthPresets.map((width) {
        final isSelected = settings.width == width;
        final label = width == null ? 'Original' : '$width';

        return ChoiceChip(
          label: Text(label),
          selected: isSelected,
          onSelected: enabled
              ? (_) =>
                  onSettingsChanged(settings.copyWith(width: () => width))
              : null,
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }

  Widget _buildFpsSelector(ThemeData theme) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: ConversionSettings.fpsPresets.map((fps) {
        final isSelected = settings.fps == fps;

        return ChoiceChip(
          label: Text('$fps'),
          selected: isSelected,
          onSelected: enabled
              ? (_) => onSettingsChanged(settings.copyWith(fps: fps))
              : null,
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }

  Widget _buildLoopModeSelector(ThemeData theme) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: LoopMode.values.map((mode) {
        final isSelected = settings.loopMode == mode;

        return ChoiceChip(
          label: Text(ConversionSettings.loopModeLabel(mode)),
          selected: isSelected,
          onSelected: enabled
              ? (_) => onSettingsChanged(settings.copyWith(loopMode: mode))
              : null,
          visualDensity: VisualDensity.compact,
          tooltip: ConversionSettings.loopModeDescription(mode),
        );
      }).toList(),
    );
  }

  Widget _buildOptimizationSection(ThemeData theme) {
    final boldLabel = GoogleFonts.dmSans(
      fontWeight: FontWeight.w700,
      fontSize: 14,
      color: theme.colorScheme.onSurface,
    );
    final subtitleStyle = GoogleFonts.dmSans(
      fontSize: 12,
      color: theme.colorScheme.onSurfaceVariant,
    );
    final interactiveStyle = GoogleFonts.staatliches(
      fontSize: 14,
      color: theme.colorScheme.onSurface,
    );

    return Column(
      children: [
        SwitchListTile(
          title: Text('Local color tables', style: boldLabel),
          subtitle: Text('Per-frame palettes (better quality, larger)',
              style: subtitleStyle),
          value: settings.useLocalColorTables,
          onChanged: enabled
              ? (v) => onSettingsChanged(
                  settings.copyWith(useLocalColorTables: v))
              : null,
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text('Dither:', style: boldLabel),
            ),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: settings.ditherMode,
                style: interactiveStyle,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(),
                ),
                items: ConversionSettings.ditherModes.map((mode) {
                  return DropdownMenuItem(
                    value: mode,
                    child: Text(ConversionSettings.ditherModeLabel(mode)),
                  );
                }).toList(),
                onChanged: enabled
                    ? (v) {
                        if (v != null) {
                          onSettingsChanged(
                              settings.copyWith(ditherMode: v));
                        }
                      }
                    : null,
              ),
            ),
          ],
        ),
        if (settings.ditherMode == 'bayer') ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text('Bayer scale:', style: boldLabel),
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: settings.bayerScale.toDouble(),
                        min: 0,
                        max: 5,
                        divisions: 5,
                        label: '${settings.bayerScale}',
                        onChanged: enabled
                            ? (v) => onSettingsChanged(
                                settings.copyWith(bayerScale: v.toInt()))
                            : null,
                      ),
                    ),
                    SizedBox(
                      width: 24,
                      child: Text(
                        '${settings.bayerScale}',
                        style: interactiveStyle,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 4),
        SwitchListTile(
          title: Text('Lossy compression', style: boldLabel),
          subtitle:
              Text('Reduce file size with gifsicle', style: subtitleStyle),
          value: settings.enableLossyCompression,
          onChanged: enabled
              ? (v) => onSettingsChanged(
                  settings.copyWith(enableLossyCompression: v))
              : null,
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        if (settings.enableLossyCompression) ...[
          Row(
            children: [
              Expanded(
                child: Text('Level:', style: boldLabel),
              ),
              Expanded(
                child: Row(
                  children: [
                    Text('Light', style: subtitleStyle),
                    Expanded(
                      child: Slider(
                        value: settings.lossyLevel.toDouble(),
                        min: 30,
                        max: 200,
                        divisions: 17,
                        label: '${settings.lossyLevel}',
                        onChanged: enabled
                            ? (v) => onSettingsChanged(
                                settings.copyWith(lossyLevel: v.toInt()))
                            : null,
                      ),
                    ),
                    Text('Heavy', style: subtitleStyle),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 32,
                      child: Text(
                        '${settings.lossyLevel}',
                        style: interactiveStyle,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
