import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:connected_notebook/features/ai/models/ai_config.dart';
import 'package:connected_notebook/features/ai/models/ai_exception.dart';
import 'package:connected_notebook/features/ai/models/ai_provider_type.dart';
import 'package:connected_notebook/features/ai/providers/ai_provider.dart';
import 'package:connected_notebook/features/ai/services/openai_compatible_service.dart';

void main() {
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
