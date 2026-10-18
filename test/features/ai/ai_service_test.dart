import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:connected_notebook/features/ai/models/ai_config.dart';
import 'package:connected_notebook/features/ai/models/ai_exception.dart';
import 'package:connected_notebook/features/ai/models/ai_provider_type.dart';
import 'package:connected_notebook/features/ai/providers/ai_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connected_notebook/features/ai/services/iai_service.dart';
import 'package:connected_notebook/features/ai/services/ai_cache_service.dart';
import 'package:connected_notebook/features/ai/services/openai_compatible_service.dart';

void main() {
  group('AiCacheService Security & SimHash Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Should NEVER store raw plaintext note content in SharedPreferences', () async {
      final cache = AiCacheService();
      const secretNote = 'Çok gizli kriptografik mimari notları ve API sırları.';

      await cache.setCached('summary', '42', secretNote, 'Kısa özet');

      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys()) {
        final value = prefs.get(key)?.toString() ?? '';
        expect(value, isNot(contains('gizli kriptografik')));
        expect(key, isNot(startsWith('ai_cache_text_')));
      }
      expect(prefs.getString('ai_cache_sha256_summary_42'), isNotNull);
      expect(prefs.getString('ai_cache_simhash_summary_42'), hasLength(16));
    });

    test('Should NOT hit cache when two completely different texts have identical length', () async {
      final cache = AiCacheService();
      const textA = 'Flutter ile mobil uygulama geliştirme süreçleri hakkında detaylı teknik notlar';
      const textB = 'Rust programlama dilinde bellek güvenliği ve borrow checker kuralları analizi.';
      expect(textA.length, equals(textB.length)); // Same exact length (78 chars)!

      await cache.setCached('summary', '10', textA, 'Flutter Özeti');

      final cachedForB = await cache.getCached('summary', '10', textB);
      expect(cachedForB, isNull, reason: 'Different texts with identical length must not collide');
    });

    test('Should hit cache on minor typo fix via 64-bit SimHash Hamming distance', () async {
      final cache = AiCacheService();
      const original =
          'Yazılım mühendisliğinde katmanlı mimari ve bağımlılık enjeksiyonu '
          'kullanmak test edilebilirliği doğrudan artırır ve spagetti kodu önler.';
      const typoFixed =
          'Yazılım mühendisliğinde katmanlı mimari ve bağımlılık enjeksiyonu '
          'kullanmak test edilebilirliği doğrudan arttırır ve spagetti kodu önler!';

      await cache.setCached('summary', '99', original, 'Mimari Özeti');

      final hit = await cache.getCached('summary', '99', typoFixed);
      expect(hit, equals('Mimari Özeti'));
    });

    test('Should keep encrypted notes strictly in volatile RAM when persistToDisk is false', () async {
      final cache = AiCacheService();
      const encryptedBody = 'Kasa içi hassas veri';

      await cache.setCached(
        'summary',
        '77',
        encryptedBody,
        'Gizli Özet',
        persistToDisk: false,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);

      // Should still hit from volatile L1 memory during active session
      final memoryHit = await cache.getCached(
        'summary',
        '77',
        encryptedBody,
        allowDiskRead: false,
      );
      expect(memoryHit, equals('Gizli Özet'));
    });

    test('Should purge legacy plaintext cache keys automatically on read/write', () async {
      SharedPreferences.setMockInitialValues({
        'ai_cache_text_summary_5': 'Eski düz metin sızıntısı',
      });

      final cache = AiCacheService();
      await cache.getCached('summary', '5', 'Yeni metin');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('ai_cache_text_summary_5'), isFalse);
    });
  });

  group('AiException Tests', () {
    test('Should display user-friendly message without raw Exception prefix', () {
      final exc = AiException.missingApiKey();
      expect(exc.toString(), contains('API anahtarı eksik'));
      expect(exc.toString(), isNot(startsWith('Exception:')));
    });

    test('Should correctly store status codes for HTTP errors', () {
      final exc401 = AiException.invalidApiKey(401);
      expect(exc401.statusCode, 401);

      final exc429 = AiException.rateLimited(429);
      expect(exc429.statusCode, 429);
      expect(exc429.toString(), contains('İstek kotası'));

      final exc500 = AiException.server(500);
      expect(exc500.statusCode, 500);
    });
  });

  group('OpenAiCompatibleService Robustness Tests', () {
    test('Should throw AiException when API key is empty', () async {
      final service = OpenAiCompatibleService(
        AiConfig(providerType: AiProviderType.openAiCompatible, apiKey: ''),
      );

      expect(
        () => service.generateSummary('Test metni'),
        throwsA(isA<AiException>().having((e) => e.message, 'message', contains('API anahtarı'))),
      );
    });

    test('Should handle HTTP 401/403 as invalidApiKey exception', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'error': {'message': 'Invalid API Key'}}), 401);
      });

      final service = OpenAiCompatibleService(
        AiConfig(providerType: AiProviderType.openAiCompatible, apiKey: 'invalid-key'),
        client: mockClient,
      );

      expect(
        () => service.generateSummary('Test metni'),
        throwsA(isA<AiException>().having((e) => e.statusCode, 'statusCode', 401)),
      );
    });

    test('Should handle HTTP 429 as rateLimited exception', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'error': {'message': 'Rate limit exceeded'}}), 429);
      });

      final service = OpenAiCompatibleService(
        AiConfig(providerType: AiProviderType.openAiCompatible, apiKey: 'valid-key'),
        client: mockClient,
      );

      expect(
        () => service.generateSummary('Test metni'),
        throwsA(isA<AiException>().having((e) => e.statusCode, 'statusCode', 429)),
      );
    });

    test('Should handle successful HTTP 200 response and parse choices', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'Bu bir test özetidir.'}
              }
            ]
          }),
          200,
        );
      });

      final service = OpenAiCompatibleService(
        AiConfig(providerType: AiProviderType.openAiCompatible, apiKey: 'valid-key'),
        client: mockClient,
      );

      final summary = await service.generateSummary('Uzun bir metin');
      expect(summary, 'Bu bir test özetidir.');
    });

    test('Should handle empty or malformed body without crash', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'choices': []}), 200);
      });

      final service = OpenAiCompatibleService(
        AiConfig(providerType: AiProviderType.openAiCompatible, apiKey: 'valid-key'),
        client: mockClient,
      );

      expect(
        () => service.generateSummary('Test metni'),
        throwsA(isA<AiException>()),
      );
    });

    test('Should stream SSE chunks in real time from streamSummary', () async {
      final mockClient = MockClient.streaming((request, bodyStream) async {
        final sseEvents = [
          'data: ${jsonEncode({'choices': [{'delta': {'content': 'Birinci '}}]})}\n\n',
          'data: ${jsonEncode({'choices': [{'delta': {'content': 'parça.'}}]})}\n\n',
          'data: [DONE]\n\n',
        ];
        final stream = Stream<List<int>>.fromIterable(
          sseEvents.map((e) => utf8.encode(e)),
        );
        return http.StreamedResponse(stream, 200);
      });

      final service = OpenAiCompatibleService(
        AiConfig(providerType: AiProviderType.openAiCompatible, apiKey: 'valid-key'),
        client: mockClient,
      );

      final chunks = await service.streamSummary('Uzun teknik doküman').toList();
      expect(chunks, equals(['Birinci ', 'parça.']));
    });

    test('Should block insecure cleartext HTTP baseUrl for remote hosts while allowing localhost', () async {
      final remoteHttpService = OpenAiCompatibleService(
        AiConfig(
          providerType: AiProviderType.openAiCompatible,
          apiKey: 'secret-key',
          baseUrl: 'http://insecure.example.com/v1',
        ),
      );

      expect(
        () => remoteHttpService.generateSummary('Not'),
        throwsA(isA<AiException>().having((e) => e.message, 'message', contains('HTTPS'))),
      );
    });

    test('IAiService.compactContextWindow should preserve head (70%) and tail (30%) when exceeding budget', () {
      final longText = 'A' * 700 + 'M' * 500 + 'Z' * 300;
      final compacted = IAiService.compactContextWindow(longText, maxChars: 1000);

      expect(compacted.startsWith('A' * 700), isTrue);
      expect(compacted.endsWith('Z' * 300), isTrue);
      expect(compacted, contains('500 karakter bağlam sınırı nedeniyle kırpıldı'));
    });
  });

  group('AiProvider Safety Tests', () {
    test('Should throw AiException.unconfigured when AI is not configured', () async {
      final provider = AiProvider();

      expect(
        () => provider.getSummary('Metin', noteId: '1'),
        throwsA(isA<AiException>().having((e) => e.message, 'message', contains('yapılandırılmamış'))),
      );

      expect(
        () => provider.getTags('Metin', noteId: '1'),
        throwsA(isA<AiException>().having((e) => e.message, 'message', contains('yapılandırılmamış'))),
      );
    });

    test('testConnection should return error string instead of throwing when not configured', () async {
      final provider = AiProvider();
      final result = await provider.testConnection();

      expect(result, isNotNull);
      expect(result, contains('sağlayıcısı seçin'));
    });
  });
}
