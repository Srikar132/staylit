import 'package:flutter_test/flutter_test.dart';
import 'package:staylit/data/models/blocked_content_model.dart';

void main() {
  group('normalizeBlockedHost', () {
    test('strips scheme, www, path, port and case', () {
      expect(
        normalizeBlockedHost('https://www.YouTube.com/watch?v=1'),
        'youtube.com',
      );
      expect(normalizeBlockedHost('  Reddit.com:8080/r/x '), 'reddit.com');
      expect(normalizeBlockedHost('m.facebook.com'), 'm.facebook.com');
      expect(normalizeBlockedHost(''), '');
    });
  });

  group('isWebsiteBlocked', () {
    final model = BlockedContentModel(
      blockedWebsites: [
        BlockedWebsite(url: 'youtube.com', name: 'YouTube'),
        BlockedWebsite(url: 'x.com', name: 'X', isActive: false),
      ],
    );

    test('matches the host and its subdomains', () {
      expect(model.isWebsiteBlocked('youtube.com'), isTrue);
      expect(model.isWebsiteBlocked('https://m.youtube.com/shorts/1'), isTrue);
    });

    test('does not match look-alike or substring hosts', () {
      expect(model.isWebsiteBlocked('notyoutube.com'), isFalse);
      expect(model.isWebsiteBlocked('youtube.com.evil.io'), isFalse);
      expect(model.isWebsiteBlocked('tube'), isFalse);
    });

    test('ignores inactive entries and empty input', () {
      expect(model.isWebsiteBlocked('x.com'), isFalse);
      expect(model.isWebsiteBlocked(''), isFalse);
    });
  });

  group('fromMap', () {
    test('reads the legacy array shape', () {
      final model = BlockedContentModel.fromMap({
        'blockedWebsites': [
          {
            'url': 'https://www.reddit.com/',
            'name': 'Reddit',
            'isActive': true,
          },
        ],
      });
      expect(model.blockedWebsites.single.url, 'reddit.com');
    });

    test('reads the map shape and writes it back keyed by host', () {
      final model = BlockedContentModel.fromMap({
        'blockedWebsites': {
          'reddit.com': {'url': 'reddit.com', 'name': 'Reddit'},
        },
      });
      expect(model.blockedWebsites.single.name, 'Reddit');
      final out = model.toFirestore()['blockedWebsites'] as Map;
      expect(out.keys, ['reddit.com']);
    });
  });
}
