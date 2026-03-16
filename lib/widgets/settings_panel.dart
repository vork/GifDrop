import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/conversion_settings.dart';

class SettingsPanel extends StatefulWidget {
  final ConversionSettings settings;
  final void Function(ConversionSettings) onSettingsChanged;
  final bool enabled;

  /// Minimum source video fps across loaded files (null if no files or unknown).
  final double? minSourceFps;

  const SettingsPanel({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
    this.enabled = true,
    this.minSourceFps,
  });

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  bool _showAdvanced = false;

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
            const SizedBox(height: 16),
            _buildSectionTitle(theme, 'Quality Preset'),
            const SizedBox(height: 8),
            _buildQualityPresetSelector(theme),
            const SizedBox(height: 8),
            _buildAdvancedSection(theme),
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
        final isSelected = widget.settings.width == width;
        final label = width == null ? 'Original' : '$width';

        return ChoiceChip(
          label: Text(label),
          selected: isSelected,
          onSelected: widget.enabled
              ? (_) => widget
                  .onSettingsChanged(widget.settings.copyWith(width: () => width))
              : null,
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }

  Widget _buildFpsSelector(ThemeData theme) {
    final isCapped = widget.minSourceFps != null &&
        widget.settings.fps > widget.minSourceFps!.round();
    final cappedFps = widget.minSourceFps?.round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: ConversionSettings.fpsPresets.map((fps) {
            final isSelected = widget.settings.fps == fps;

            return ChoiceChip(
              label: Text('$fps'),
              selected: isSelected,
              onSelected: widget.enabled
                  ? (_) =>
                      widget.onSettingsChanged(widget.settings.copyWith(fps: fps))
                  : null,
              visualDensity: VisualDensity.compact,
            );
          }).toList(),
        ),
        if (isCapped) ...[
          const SizedBox(height: 6),
          Text(
            'Will use $cappedFps fps (source video limit)',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLoopModeSelector(ThemeData theme) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: LoopMode.values.map((mode) {
        final isSelected = widget.settings.loopMode == mode;

        return ChoiceChip(
          label: Text(ConversionSettings.loopModeLabel(mode)),
          selected: isSelected,
          onSelected: widget.enabled
              ? (_) => widget
                  .onSettingsChanged(widget.settings.copyWith(loopMode: mode))
              : null,
          visualDensity: VisualDensity.compact,
          tooltip: ConversionSettings.loopModeDescription(mode),
        );
      }).toList(),
    );
  }

  Widget _buildQualityPresetSelector(ThemeData theme) {
    final activePreset = widget.settings.matchingPreset;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        ...QualityPreset.values.map((preset) {
          final isSelected = activePreset == preset;
          return ChoiceChip(
            label: Text(ConversionSettings.qualityPresetLabel(preset)),
            selected: isSelected,
            onSelected: widget.enabled
                ? (_) => widget
                    .onSettingsChanged(widget.settings.applyPreset(preset))
                : null,
            visualDensity: VisualDensity.compact,
            tooltip: ConversionSettings.qualityPresetDescription(preset),
          );
        }),
        if (activePreset == null)
          const ChoiceChip(
            label: Text('Custom'),
            selected: true,
            onSelected: null,
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }

  Widget _buildAdvancedSection(ThemeData theme) {
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

    return ExpansionTile(
      initiallyExpanded: _showAdvanced,
      onExpansionChanged: (expanded) {
        setState(() => _showAdvanced = expanded);
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(top: 8),
      title: Text(
        'Advanced',
        style: GoogleFonts.dmSans(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      children: [
        // Quality slider
        Row(
          children: [
            Expanded(
              child: Text('Quality:', style: boldLabel),
            ),
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Text('Small', style: subtitleStyle),
                  Expanded(
                    child: Slider(
                      value: widget.settings.quality.toDouble(),
                      min: 1,
                      max: 100,
                      divisions: 99,
                      label:
                          '${widget.settings.quality} (${ConversionSettings.qualityLabel(widget.settings.quality)})',
                      onChanged: widget.enabled
                          ? (v) => widget.onSettingsChanged(
                              widget.settings.copyWith(quality: v.toInt()))
                          : null,
                    ),
                  ),
                  Text('Best', style: subtitleStyle),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 32,
                    child: Text(
                      '${widget.settings.quality}',
                      style: interactiveStyle,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // Motion quality override — match the Quality slider row height
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: widget.settings.motionQuality != null,
                        onChanged: widget.enabled
                            ? (checked) {
                                if (checked == true) {
                                  widget.onSettingsChanged(
                                      widget.settings.copyWith(
                                          motionQuality: () =>
                                              widget.settings.quality));
                                } else {
                                  widget.onSettingsChanged(
                                      widget.settings.copyWith(
                                          motionQuality: () => null));
                                }
                              }
                            : null,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('Motion quality:', style: boldLabel),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: widget.settings.motionQuality != null
                    ? Row(
                        children: [
                          Text('Low', style: subtitleStyle),
                          Expanded(
                            child: Slider(
                              value:
                                  widget.settings.motionQuality!.toDouble(),
                              min: 1,
                              max: 100,
                              divisions: 99,
                              label: '${widget.settings.motionQuality}',
                              onChanged: widget.enabled
                                  ? (v) => widget.onSettingsChanged(
                                      widget.settings.copyWith(
                                          motionQuality: () => v.toInt()))
                                  : null,
                            ),
                          ),
                          Text('Best', style: subtitleStyle),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 32,
                            child: Text(
                              '${widget.settings.motionQuality}',
                              style: interactiveStyle,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        'Uses quality value',
                        style: subtitleStyle,
                      ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Speed mode
        Row(
          children: [
            Expanded(child: Text('Speed:', style: boldLabel)),
            Expanded(
              flex: 2,
              child: SegmentedButton<SpeedMode>(
                segments: SpeedMode.values.map((mode) {
                  return ButtonSegment(
                    value: mode,
                    label: Text(ConversionSettings.speedModeLabel(mode)),
                    tooltip: ConversionSettings.speedModeDescription(mode),
                  );
                }).toList(),
                selected: {widget.settings.speedMode},
                onSelectionChanged: widget.enabled
                    ? (v) => widget.onSettingsChanged(
                        widget.settings.copyWith(speedMode: v.first))
                    : null,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStatePropertyAll(
                    GoogleFonts.dmSans(fontSize: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
