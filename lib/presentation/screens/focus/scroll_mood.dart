/// How bad today's scrolling is, from calm to meltdown. A pure function of the
/// count so the Home card, the explainer sheet and (later) the on-screen Lit
/// overlay all agree.
enum ScrollMood {
  calm('Calm', 'You are barely scrolling'),
  warmingUp('Warming up', 'A little scrolling so far'),
  hooked('Getting hooked', 'Time for a break soon'),
  doomscrolling('Doomscrolling', 'That is a lot of scrolling'),
  meltdown('Meltdown', 'Put the phone down');

  const ScrollMood(this.label, this.message);

  final String label;
  final String message;

  /// 1 (calm) to 5 (meltdown): how many meter segments to fill.
  int get level => index + 1;

  /// Upper bounds (exclusive) of each mood, in items scrolled in a day.
  static const thresholds = [20, 60, 120, 200];

  static ScrollMood forCount(int count) {
    final safe = count < 0 ? 0 : count;
    for (var i = 0; i < thresholds.length; i++) {
      if (safe < thresholds[i]) return ScrollMood.values[i];
    }
    return ScrollMood.meltdown;
  }
}
