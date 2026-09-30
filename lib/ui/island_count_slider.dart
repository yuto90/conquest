import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/game_state.dart';
import 'tactical_theme.dart';

/// A one-island-per-step control using the rounded match-setup slider style.
///
/// The configuration remains owned by the caller. Only the endpoints are
/// labeled below the track so all fifteen choices remain usable on phones.
class IslandCountSlider extends StatefulWidget {
  const IslandCountSlider({
    super.key,
    required this.value,
    required this.onChanged,
    required this.title,
    required this.countLabel,
    this.focusNode,
  }) : assert(
         value >= GameConfiguration.minIslandCount &&
             value <= GameConfiguration.maxIslandCount,
       );

  final int value;
  final ValueChanged<int> onChanged;
  final String title;
  final String Function(int count) countLabel;
  final FocusNode? focusNode;

  @override
  State<IslandCountSlider> createState() => _IslandCountSliderState();
}

class _IslandCountSliderState extends State<IslandCountSlider> {
  static const _minimum = GameConfiguration.minIslandCount;
  static const _maximum = GameConfiguration.maxIslandCount;
  static const _divisions = _maximum - _minimum;

  late FocusNode _focusNode;
  late bool _ownsFocusNode;
  int? _lastDragValue;

  @override
  void initState() {
    super.initState();
    _attachFocusNode();
  }

  void _attachFocusNode() {
    _focusNode = widget.focusNode ?? FocusNode(debugLabel: 'island-count');
    _ownsFocusNode = widget.focusNode == null;
    _focusNode.addListener(_handleFocusChange);
  }

  void _detachFocusNode() {
    _focusNode.removeListener(_handleFocusChange);
    if (_ownsFocusNode) _focusNode.dispose();
  }

  @override
  void didUpdateWidget(covariant IslandCountSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode == widget.focusNode) return;
    _detachFocusNode();
    _attachFocusNode();
  }

  @override
  void dispose() {
    _detachFocusNode();
    super.dispose();
  }

  void _handleFocusChange() {
    if (mounted) setState(() {});
  }

  void _select(int count) {
    if (count != widget.value) widget.onChanged(count);
  }

  void _handleChanged(double position) {
    final count = position.round().clamp(_minimum, _maximum);
    // Several pointer events can arrive before the owner rebuilds. Emit at
    // most once for each newly reached integer during the same gesture.
    if (_lastDragValue == count) return;
    _lastDragValue = count;
    _select(count);
  }

  @override
  Widget build(BuildContext context) {
    final typography = TacticalTypography.of(context);
    final selectedLabel = widget.countLabel(widget.value);
    final increased = widget.value < _maximum ? widget.value + 1 : null;
    final decreased = widget.value > _minimum ? widget.value - 1 : null;
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                widget.title,
                style: typography.mono(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.9,
                ),
              ),
              Text(
                selectedLabel,
                key: const ValueKey('island-count-value'),
                style: typography.mono(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: TacticalPalette.seaDeep,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 48,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Flutter omits all ticks if their diameter is too large for
              // the divisions. Scale dots down on narrow screens instead.
              final tickRadius = math.min(
                3.0,
                math.max(0.5, (constraints.maxWidth - 80) / (_divisions * 6.1)),
              );
              return KeyedSubtree(
                // Never key by the selected count: rebuilding the Slider
                // during a reduced-motion drag would cancel its recognizer.
                key: animationsDisabled
                    ? const ValueKey('island-count-reduced-motion')
                    : null,
                child: Semantics(
                  key: const ValueKey('island-count-slider'),
                  container: true,
                  excludeSemantics: true,
                  slider: true,
                  focusable: true,
                  focused: _focusNode.hasFocus,
                  label: widget.title,
                  value: selectedLabel,
                  increasedValue: increased == null
                      ? null
                      : widget.countLabel(increased),
                  decreasedValue: decreased == null
                      ? null
                      : widget.countLabel(decreased),
                  onFocus: _focusNode.requestFocus,
                  onIncrease: increased == null
                      ? null
                      : () => _select(increased),
                  onDecrease: decreased == null
                      ? null
                      : () => _select(decreased),
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: TacticalPalette.seaDeep,
                      inactiveTrackColor: TacticalPalette.seaDeep.withValues(
                        alpha: 0.22,
                      ),
                      activeTickMarkColor: TacticalPalette.paper.withValues(
                        alpha: 0.88,
                      ),
                      inactiveTickMarkColor: TacticalPalette.seaDeep.withValues(
                        alpha: 0.72,
                      ),
                      thumbColor: TacticalPalette.paper,
                      showValueIndicator: ShowValueIndicator.never,
                      trackHeight: 32,
                      trackShape: const _IslandCountSliderTrackShape(),
                      tickMarkShape: RoundSliderTickMarkShape(
                        tickMarkRadius: tickRadius,
                      ),
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 20,
                        elevation: 1,
                        pressedElevation: 2,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 24,
                      ),
                    ),
                    child: Slider(
                      key: const ValueKey('island-count-slider-control'),
                      focusNode: _focusNode,
                      value: widget.value.toDouble(),
                      min: _minimum.toDouble(),
                      max: _maximum.toDouble(),
                      divisions: _divisions,
                      overlayColor: WidgetStateProperty.resolveWith<Color?>(
                        (states) => states.contains(WidgetState.focused)
                            ? TacticalPalette.seaDeep.withValues(alpha: 0.16)
                            : Colors.transparent,
                      ),
                      semanticFormatterCallback: (position) =>
                          widget.countLabel(position.round()),
                      onChangeStart: (_) {
                        _focusNode.requestFocus();
                        _lastDragValue = widget.value;
                      },
                      onChanged: _handleChanged,
                      onChangeEnd: (_) => _lastDragValue = null,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final count in [_minimum, _maximum])
                  SizedBox(
                    width: math.max(
                      24,
                      MediaQuery.textScalerOf(context).scale(11) * 1.5,
                    ),
                    child: Text(
                      '$count',
                      textAlign: TextAlign.center,
                      style: typography.mono(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: TacticalPalette.muted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Matches the pointer range to the inset centers of the rounded track's dots.
class _IslandCountSliderTrackShape extends RoundedRectSliderTrackShape {
  const _IslandCountSliderTrackShape();

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
