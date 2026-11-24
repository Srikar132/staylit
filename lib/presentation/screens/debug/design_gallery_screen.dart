import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pace/core/theme/app_dimens.dart';
import 'package:pace/core/theme/theme_context.dart';
import 'package:pace/presentation/widgets/appearance_sheet.dart';

/// Debug-only route. Registered and linked only when `kDebugMode` is true.
const designGalleryRoute = '/debug/design-gallery';

/// Profile row that opens the gallery (debug builds only).
class DesignGalleryTile extends StatelessWidget {
  const DesignGalleryTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => GoRouter.of(context).push(designGalleryRoute),
      leading: Icon(Icons.palette_outlined, color: context.palette.accentText),
      title: const Text('Design gallery (debug)'),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

/// Shows every palette token, the type scale and the themed Material
/// components so a theme change can be reviewed on a device in one place.
class DesignGalleryScreen extends StatelessWidget {
  const DesignGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Design gallery')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: const [
          AppearanceTile(),
          _Section('Palette', child: _PaletteGrid()),
          _Section('Typography', child: _TypeScale()),
          _Section('Buttons', child: _Buttons()),
          _Section('Inputs and controls', child: _Controls()),
          _Section('Surfaces', child: _Surfaces()),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, {required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _PaletteGrid extends StatelessWidget {
  const _PaletteGrid();

  static String _hex(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    // (token name, token color, swatch background, swatch foreground)
    final entries = <(String, Color, Color, Color)>[
      ('canvas', p.canvas, p.canvas, p.onCanvas),
      ('surface', p.surface, p.surface, p.onCanvas),
      ('surfaceRaised', p.surfaceRaised, p.surfaceRaised, p.onCanvas),
      ('surfaceTrack', p.surfaceTrack, p.surfaceTrack, p.onCanvas),
      ('accent', p.accent, p.accent, p.onAccent),
      ('accentSoft', p.accentSoft, p.accentSoft, p.ink),
      ('accentStrong', p.accentStrong, p.accentStrong, p.onAccent),
      ('accentText', p.accentText, p.canvas, p.accentText),
      ('ink', p.ink, p.ink, p.onInk),
      ('onCanvasSecondary', p.onCanvasSecondary, p.canvas, p.onCanvasSecondary),
      ('onCanvasMuted', p.onCanvasMuted, p.canvas, p.onCanvasMuted),
      ('onCanvasDisabled', p.onCanvasDisabled, p.canvas, p.onCanvasDisabled),
      ('chartAlt', p.chartAlt, p.chartAlt, p.onInk),
      ('badge', p.badge, p.badge, p.onInk),
      ('success', p.success, p.canvas, p.success),
      ('warning', p.warning, p.canvas, p.warning),
      ('error', p.error, p.error, p.onError),
      ('info', p.info, p.canvas, p.info),
      ('premium', p.premium, p.canvas, p.premium),
    ];

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final (name, token, background, foreground) in entries)
          _Swatch(
            name: name,
            hex: _hex(token),
            background: background,
            foreground: foreground,
          ),
        for (var i = 0; i < p.categorical.length; i++)
          _Swatch(
            name: 'categorical[$i]',
            hex: _hex(p.categorical[i]),
            background: p.categorical[i],
            foreground: p.onScrim,
          ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.name,
    required this.hex,
    required this.background,
    required this.foreground,
  });

  final String name;
  final String hex;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 156,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
          ),
          Text(
            hex,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

class _TypeScale extends StatelessWidget {
  const _TypeScale();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final styles = <(String, TextStyle?)>[
      ('displayLarge 44', t.displayLarge),
      ('displayMedium 36', t.displayMedium),
      ('displaySmall 28', t.displaySmall),
      ('headlineSmall 20', t.headlineSmall),
      ('titleLarge 20', t.titleLarge),
      ('titleMedium 16', t.titleMedium),
      ('bodyLarge 16', t.bodyLarge),
      ('bodyMedium 14', t.bodyMedium),
      ('bodySmall 12', t.bodySmall),
      ('labelLarge 16', t.labelLarge),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (name, style) in styles)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(name, style: style),
          ),
      ],
    );
  }
}

class _Buttons extends StatelessWidget {
  const _Buttons();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        ElevatedButton(onPressed: () {}, child: const Text('Elevated')),
        const ElevatedButton(onPressed: null, child: Text('Disabled')),
        FilledButton(onPressed: () {}, child: const Text('Filled')),
        OutlinedButton(onPressed: () {}, child: const Text('Outlined')),
        TextButton(onPressed: () {}, child: const Text('Text')),
        IconButton(onPressed: () {}, icon: const Icon(Icons.more_horiz)),
      ],
    );
  }
}

class _Controls extends StatefulWidget {
  const _Controls();

  @override
  State<_Controls> createState() => _ControlsState();
}

class _ControlsState extends State<_Controls> {
  bool _switchOn = true;
  double _slider = 0.4;
  bool _chipSelected = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TextField(
          decoration: InputDecoration(
            labelText: 'Label',
            hintText: 'Type something',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            FilterChip(
              label: const Text('Selected'),
              selected: _chipSelected,
              onSelected: (value) => setState(() => _chipSelected = value),
            ),
            const Chip(label: Text('Chip')),
          ],
        ),
        SwitchListTile(
          value: _switchOn,
          onChanged: (value) => setState(() => _switchOn = value),
          title: const Text('Switch'),
        ),
        Slider(
          value: _slider,
          onChanged: (value) => setState(() => _slider = value),
        ),
        LinearProgressIndicator(value: _slider),
        const SizedBox(height: AppSpacing.md),
        const Align(
          alignment: Alignment.centerLeft,
          child: CircularProgressIndicator(value: 0.65),
        ),
      ],
    );
  }
}

class _Surfaces extends StatelessWidget {
  const _Surfaces();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(
              'Card on canvas',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.md,
          children: [
            ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Dialog'),
                  content: const Text('Raised surface, large radius.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
              child: const Text('Dialog'),
            ),
            OutlinedButton(
              onPressed: () =>
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Snackbar'))),
              child: const Text('Snackbar'),
            ),
            OutlinedButton(
              onPressed: () => showAppearanceSheet(context),
              child: const Text('Sheet'),
            ),
          ],
        ),
      ],
    );
  }
}
