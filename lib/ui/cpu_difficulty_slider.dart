import 'dart:math' as math;

import 'package:conquest/game/game_state.dart';
import 'package:flutter/material.dart';

import 'tactical_theme.dart';

/// A four-step CPU difficulty control shared by standard and spectator setup.
///
/// The value remains owned by [GameConfiguration]. This widget only maps the
/// four discrete positions to the supplied callback and presents them with a
/// track, ticks, labels, and a keyboard/screen-reader friendly slider.
class CpuDifficultySlider extends StatefulWidget {
  const CpuDifficultySlider({
    super.key,
    required this.value,
    required this.onChanged,
    required this.title,
    required this.labels,
    this.keyPrefix = 'cpu-difficulty',
    this.focusNode,
  });

  static const Color hardTrackColor = Color(0xFFAA7BF2);
  static const Color hardLabelColor = Color(0xFF5F348F);

  final CpuDifficulty value;
  final ValueChanged<CpuDifficulty> onChanged;
  final String title;
  final Map<CpuDifficulty, String> labels;
  final String keyPrefix;
  final FocusNode? focusNode;

  @override
  State<CpuDifficultySlider> createState() => _CpuDifficultySliderState();
}

class _CpuDifficultySliderState extends State<CpuDifficultySlider> {
  late FocusNode _focusNode;
  bool _ownsFocusNode = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode(debugLabel: widget.keyPrefix);
    _ownsFocusNode = widget.focusNode == null;
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant CpuDifficultySlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode == widget.focusNode) return;
    _focusNode.removeListener(_handleFocusChange);
    if (_ownsFocusNode) _focusNode.dispose();
    _focusNode = widget.focusNode ?? FocusNode(debugLabel: widget.keyPrefix);
    _ownsFocusNode = widget.focusNode == null;
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (mounted) setState(() {});
  }

  CpuDifficulty _difficultyForValue(double value) {
    final index = (value * (CpuDifficulty.values.length - 1)).round().clamp(
      0,
      CpuDifficulty.values.length - 1,
    );
    return CpuDifficulty.values[index];
  }

  void _select(CpuDifficulty difficulty) {
    if (difficulty != widget.value) widget.onChanged(difficulty);
  }

  @override
  Widget build(BuildContext context) {
    final animationsDisabled = MediaQuery.of(context).disableAnimations;
    final selectedLabel = widget.labels[widget.value] ?? widget.value.name;
    final increasedDifficulty = widget.value == CpuDifficulty.hard
        ? null
        : CpuDifficulty.values[widget.value.index + 1];
    final decreasedDifficulty = widget.value == CpuDifficulty.veryEasy
        ? null
        : CpuDifficulty.values[widget.value.index - 1];
    final activeColor = widget.value == CpuDifficulty.hard
        ? CpuDifficultySlider.hardTrackColor
        : TacticalPalette.seaDeep;
    final sliderKey = ValueKey('${widget.keyPrefix}-slider');
    final slider = SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: activeColor,
        inactiveTrackColor: TacticalPalette.seaDeep.withValues(alpha: 0.22),
        activeTickMarkColor: TacticalPalette.paper.withValues(alpha: 0.88),
        inactiveTickMarkColor: TacticalPalette.seaDeep.withValues(alpha: 0.72),
        thumbColor: TacticalPalette.paper,
        showValueIndicator: ShowValueIndicator.never,
        trackHeight: 32,
        trackShape: const _CpuDifficultySliderTrackShape(),
        tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 3),
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: 20,
          elevation: 1,
          pressedElevation: 2,
        ),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
      ),
      child: Slider(
        key: ValueKey('${widget.keyPrefix}-slider-control'),
        focusNode: _focusNode,
        value: widget.value.index / (CpuDifficulty.values.length - 1),
        divisions: CpuDifficulty.values.length - 1,
        overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.focused)) {
            return activeColor.withValues(alpha: 0.16);
          }
          return Colors.transparent;
        }),
        semanticFormatterCallback: (position) =>
            widget.labels[_difficultyForValue(position)] ??
            _difficultyForValue(position).name,
        onChanged: (position) => _select(_difficultyForValue(position)),
      ),
    );

    // Keep the reduced-motion subtree stable across value updates so a
    // multi-step drag retains the Slider element and gesture recognizer.
    final animatedSlider = KeyedSubtree(
      key: animationsDisabled
          ? ValueKey('${widget.keyPrefix}-reduced-motion')
          : null,
      child: Semantics(
        key: sliderKey,
        container: true,
        excludeSemantics: true,
        slider: true,
        focusable: true,
        focused: _focusNode.hasFocus,
        label: widget.title,
        value: selectedLabel,
        increasedValue: increasedDifficulty == null
            ? null
            : widget.labels[increasedDifficulty],
        decreasedValue: decreasedDifficulty == null
            ? null
            : widget.labels[decreasedDifficulty],
        onFocus: _focusNode.requestFocus,
        onIncrease: increasedDifficulty == null
            ? null
            : () => _select(increasedDifficulty),
        onDecrease: decreasedDifficulty == null
            ? null
            : () => _select(decreasedDifficulty),
        child: slider,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.title,
          style: TacticalTypography.of(
            context,
          ).mono(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.9),
        ),
        const SizedBox(height: 4),
        SizedBox(height: 48, child: animatedSlider),
        _DifficultyLabels(
          keyPrefix: widget.keyPrefix,
          labels: widget.labels,
          selected: widget.value,
          onSelected: _select,
        ),
      ],
    );
  }
}

/// Keeps pointer coordinates aligned with the visual centers of a discrete
/// rounded slider's ticks and thumb.
class _CpuDifficultySliderTrackShape extends RoundedRectSliderTrackShape {
  const _CpuDifficultySliderTrackShape();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final rect = super.getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    if (isDiscrete) return rect;

    final trackInset = (sliderTheme.trackHeight ?? 0) / 2;
    return Rect.fromLTRB(
      rect.left + trackInset,
      rect.top,
      rect.right - trackInset,
      rect.bottom,
    );
  }
}

class _DifficultyLabels extends StatelessWidget {
  const _DifficultyLabels({
    required this.keyPrefix,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  final String keyPrefix;
  final Map<CpuDifficulty, String> labels;
  final CpuDifficulty selected;
  final ValueChanged<CpuDifficulty> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Slider's rounded discrete track maps its ticks inside the 32dp
        // track ends and 24dp overlay bounds. Keep labels centered on those
        // same tick coordinates at every parent width.
        const tickInset = 40.0;
        final tickRange = math.max(0.0, constraints.maxWidth - tickInset * 2);
        final cellWidth = tickRange / (CpuDifficulty.values.length - 1);
        return SizedBox(
          height: 48,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var index = 0; index < CpuDifficulty.values.length; index++)
                Positioned(
                  left:
                      tickInset +
                      index * cellWidth -
                      _labelCellHalfWidth(
                        tickInset + index * cellWidth,
                        cellWidth,
                        constraints.maxWidth,
                      ),
                  width: math.max(
                    1.0,
                    _labelCellHalfWidth(
                          tickInset + index * cellWidth,
                          cellWidth,
                          constraints.maxWidth,
                        ) *
                        2,
                  ),
                  top: 0,
                  bottom: 0,
                  child: _DifficultyLabel(
                    key: ValueKey(
                      '$keyPrefix-${CpuDifficulty.values[index].name}',
                    ),
                    difficulty: CpuDifficulty.values[index],
                    label:
                        labels[CpuDifficulty.values[index]] ??
                        CpuDifficulty.values[index].name,
                    selected: selected == CpuDifficulty.values[index],
                    onTap: () => onSelected(CpuDifficulty.values[index]),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  double _labelCellHalfWidth(
    double tickCenter,
    double cellWidth,
    double parentWidth,
  ) {
    return math.max(
      0,
      math.min(cellWidth / 2, math.min(tickCenter, parentWidth - tickCenter)),
    );
  }
}

class _DifficultyLabel extends StatelessWidget {
  const _DifficultyLabel({
    super.key,
    required this.difficulty,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final CpuDifficulty difficulty;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = difficulty == CpuDifficulty.hard
        ? CpuDifficultySlider.hardLabelColor
        : TacticalPalette.muted;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.visible,
            style: TacticalTypography.of(context).body(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: color,
              height: 1.12,
            ),
          ),
        ),
      ),
    );
  }
}
