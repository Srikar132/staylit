import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:staylit/core/constants/audios.dart';
import 'package:staylit/presentation/providers/audio_providers.dart';
import 'package:staylit/services/audio_service.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/core/theme/theme_context.dart';
import 'package:staylit/presentation/widgets/design/icon_circle_button.dart';
import 'package:staylit/widgets/bottom_sheet_darg_handler.dart';

class AudioBottomSheet extends ConsumerStatefulWidget {
  const AudioBottomSheet({super.key});

  @override
  ConsumerState<AudioBottomSheet> createState() => _AudioBottomSheetState();
}

class _AudioBottomSheetState extends ConsumerState<AudioBottomSheet> {
  Audio? selectedAudio;
  Timer? _stateCheckTimer;

  @override
  void initState() {
    super.initState();
    _stateCheckTimer = Timer.periodic(const Duration(milliseconds: 500), (
      timer,
    ) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _stateCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final screenHeight = MediaQuery.of(context).size.height;
    final audioService = ref.read(audioServiceProvider);

    return Container(
      height: screenHeight * 0.85,
      decoration: BoxDecoration(
        color: palette.canvas,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      child: Column(
        children: [
          const BottomSheetDragHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.sm,
              AppSpacing.xl,
              AppSpacing.lg,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Focus sounds', style: textTheme.displaySmall),
                      Text(
                        'Tap a card to play it while you focus',
                        style: textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                IconCircleButton(
                  icon: Icons.close_rounded,
                  semanticLabel: 'Close',
                  size: 40,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.xl,
                AppSpacing.xxxl,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: AppSpacing.lg,
                crossAxisSpacing: AppSpacing.lg,
                childAspectRatio: 0.9,
              ),
              itemCount: AudioConstants.audioList.length,
              itemBuilder: (context, index) {
                final audio = AudioConstants.audioList[index];
                final isSelected =
                    selectedAudio?.songAssetUrl == audio.songAssetUrl;
                return _buildAudioCard(audio, isSelected, audioService);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioCard(
    Audio audio,
    bool isSelected,
    AudioService audioService,
  ) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final isMusic = audio.songAssetUrl.endsWith('.mp3');
    final audioType = isMusic ? AudioType.song : AudioType.sound;
    final isPlaying = audioService.isPlaying(audioType) && isSelected;

    return Semantics(
      button: true,
      selected: isSelected,
      label:
          '${audio.name}, ${isMusic ? 'music' : 'sound'}'
          '${isPlaying ? ', playing' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () =>
            _handleAudioTap(audio, isSelected, isPlaying, audioType, isMusic),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: isSelected ? palette.accent : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card - 2),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  audio.image,
                  fit: BoxFit.cover,
                  cacheWidth: 400,
                  errorBuilder: (context, error, stackTrace) => ColoredBox(
                    color: palette.surface,
                    child: Icon(
                      isMusic
                          ? Icons.music_note_rounded
                          : Icons.graphic_eq_rounded,
                      color: palette.onCanvasMuted,
                      size: 40,
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        palette.ink.withValues(alpha: 0.05),
                        palette.ink.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Align(
                        alignment: Alignment.topRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: palette.ink.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            isMusic ? 'Music' : 'Sound',
                            style: textTheme.labelSmall?.copyWith(
                              color: palette.onInk,
                            ),
                          ),
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              audio.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleMedium?.copyWith(
                                color: palette.onInk,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? palette.accent
                                  : palette.onInk,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: isSelected
                                  ? palette.onAccent
                                  : palette.ink,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleAudioTap(
    Audio audio,
    bool isSelected,
    bool isCurrentlyPlaying,
    AudioType audioType,
    bool isMusic,
  ) async {
    if (isSelected && isCurrentlyPlaying) {
      await AudioServiceMethods.pause(ref, audioType);
      _showSnackBar('Paused ${audio.name}', Icons.pause_circle_rounded);
    } else if (isSelected && !isCurrentlyPlaying) {
      await AudioServiceMethods.resume(ref, audioType);
      _showSnackBar('Resumed ${audio.name}', Icons.play_circle_rounded);
    } else {
      setState(() {
        selectedAudio = audio;
      });

      await AudioServiceMethods.stopAll(ref);
      await AudioServiceMethods.playAsset(
        ref,
        assetPath: audio.songAssetUrl,
        type: audioType,
        trackName: audio.name,
        loop: isMusic,
      );

      _showSnackBar('Playing ${audio.name}', Icons.music_note_rounded);
    }
  }

  void _showSnackBar(String message, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(message)),
          ],
        ),
        duration: const Duration(milliseconds: 1500),
      ),
    );
  }
}
