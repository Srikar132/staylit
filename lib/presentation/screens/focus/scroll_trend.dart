/// The small "down 12% vs yesterday" tag on the Scroll damage card.
class ScrollTrend {
  const ScrollTrend(this.text, {required this.good});

  final String text;

  /// Less scrolling than yesterday (or the same) is good news.
  final bool good;

  /// Today so far against all of yesterday. Null when yesterday has no data
  /// to compare with.
  static ScrollTrend? compare({required int today, required int yesterday}) {
    if (yesterday <= 0) return null;
    final t = today < 0 ? 0 : today;
    final percent = ((t - yesterday) / yesterday * 100).round().abs();
    if (percent == 0) return const ScrollTrend('Same as yesterday', good: true);
    return t < yesterday
        ? ScrollTrend('↓ $percent% vs yesterday', good: true)
        : ScrollTrend('↑ $percent% vs yesterday', good: false);
  }
}
