import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'iai_service.dart';
import '../models/ai_config.dart';
import '../models/ai_exception.dart';

class OpenAiCompatibleService implements IAiService {
  final String _apiKey;
  final String _baseUrl;
  final String _modelName;
  final int _maxOutputTokens;
  final Duration _requestTimeout;
  final Duration _streamChunkTimeout;
  final http.Client _client;
  final bool _ownsClient;

  OpenAiCompatibleService(
    AiConfig config, {
    http.Client? client,
    int maxOutputTokens = IAiService.defaultMaxOutputTokens,
    Duration requestTimeout = IAiService.defaultRequestTimeout,
    Duration streamChunkTimeout = IAiService.defaultStreamChunkTimeout,
  })  : _apiKey = config.apiKey?.trim() ?? '',
        _baseUrl = config.baseUrl?.isNotEmpty == true
            ? config.baseUrl!.trim().replaceAll(RegExp(r'/+$'), '')
            : 'https://api.openai.com/v1',
        _modelName = config.modelName?.isNotEmpty == true
            ? config.modelName!.trim()
            : 'gpt-4o-mini',
        _maxOutputTokens = maxOutputTokens,
        _requestTimeout = requestTimeout,
        _streamChunkTimeout = streamChunkTimeout,
        _client = client ?? http.Client(),
        _ownsClient = client == null;

  /// Validates that the configured endpoint never transmits the Bearer API key
  /// over unencrypted HTTP to a non-loopback remote host.
  Uri _buildValidatedEndpoint() {
    final Uri uri;
    try {
      uri = Uri.parse('$_baseUrl/chat/completions');
    } catch (_) {
      throw const AiException('Geçersiz Base URL formatı.');
    }

    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    final isLoopback =
        host == 'localhost' || host == '127.0.0.1' || host == '::1';

    if (scheme != 'https' && !(scheme == 'http' && isLoopback)) {
      throw const AiException(
        'Güvenlik ihlali engellendi: API anahtarınızın ağda düz metin olarak sızmaması için uzak sunucularda yalnızca HTTPS bağlantısına izin verilir (yerel modeller için localhost hariç).',
      );
    }
    return uri;
  }

  AiException _mapStatusError(int statusCode, List<int> bodyBytes) {
    if (statusCode == 401 || statusCode == 403) {
      return AiException.invalidApiKey(statusCode);
    } else if (statusCode == 429) {
      return AiException.rateLimited(statusCode);
    } else if (statusCode >= 500) {
      return AiException.server(statusCode);
    } else {
      String serverMessage = '';
      try {
        final errData = jsonDecode(utf8.decode(bodyBytes));
        serverMessage = errData['error']?['message'] ?? '';
      } catch (_) {}
      return AiException.server(
        statusCode,
        serverMessage.isNotEmpty ? serverMessage : null,
      );
    }
  }

  AiException _mapTransportError(Object e) {
    if (e is AiException) return e;
    if (e is SocketException) return AiException.network(e.message);
    if (e is TimeoutException) {
      return AiException(
        'İstek zaman aşımına uğradı (${_requestTimeout.inSeconds} saniye). Lütfen ağ bağlantınızı veya yerel modelinizin durumunu kontrol edin.',
      );
    }
    if (e is FormatException) {
      return const AiException('Sunucudan geçersiz veri formatı alındı.');
    }
    final errStr = e.toString();
    if (errStr.contains('SocketException') ||
        errStr.contains('ClientException') ||
        errStr.contains('Failed host lookup')) {
      return AiException.network();
    }
    return AiException('AI servisi ile iletişim kurulurken bir hata oluştu: $e');
  }

  Future<String> _makeRequest(String prompt, {int? maxTokens}) async {
    if (_apiKey.isEmpty) {
      throw AiException.missingApiKey();
    }

    final url = _buildValidatedEndpoint();

    try {
      final response = await _client
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode({
              'model': _modelName,
              'messages': [
                {'role': 'user', 'content': prompt}
              ],
              'max_tokens': maxTokens ?? _maxOutputTokens,
            }),
          )
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        String decodedBody;
        try {
          decodedBody = utf8.decode(response.bodyBytes);
        } catch (_) {
          decodedBody = response.body;
        }
        final Map<String, dynamic> data = jsonDecode(decodedBody);
        final choices = data['choices'] as List?;
        if (choices == null || choices.isEmpty) {
          throw const AiException(
            'AI servisinden geçerli bir yanıt içeriği alınamadı.',
          );
        }
        final content = choices[0]['message']?['content'] as String?;
        if (content == null || content.trim().isEmpty) {
          throw const AiException('AI servisi boş yanıt döndürdü.');
        }
        return content.trim();
      } else {
        throw _mapStatusError(response.statusCode, response.bodyBytes);
      }
    } catch (e) {
      throw _mapTransportError(e);
    }
  }

  /// Streams Server-Sent Events (`data: {...}`) from an OpenAI-compatible
  /// `/chat/completions` endpoint, falling back gracefully to standard JSON
  /// parsing if the server returns a non-streamed 200 payload.
  Stream<String> _makeStreamRequest(String prompt, {int? maxTokens}) async* {
    if (_apiKey.isEmpty) {
      throw AiException.missingApiKey();
    }

    final url = _buildValidatedEndpoint();
    final request = http.Request('POST', url);
    request.headers.addAll({
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream',
      'Authorization': 'Bearer $_apiKey',
    });
    request.body = jsonEncode({
      'model': _modelName,
      'stream': true,
      'messages': [
        {'role': 'user', 'content': prompt}
      ],
      'max_tokens': maxTokens ?? _maxOutputTokens,
    });

    try {
      final streamedResponse =
          await _client.send(request).timeout(_requestTimeout);

      if (streamedResponse.statusCode != 200) {
        final errorBytes = await streamedResponse.stream.toBytes();
        throw _mapStatusError(streamedResponse.statusCode, errorBytes);
      }

      var emittedAny = false;
      final lineStream = streamedResponse.stream
          .timeout(_streamChunkTimeout)
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      final rawLinesBuffer = StringBuffer();

      await for (final rawLine in lineStream) {
        final line = rawLine.trim();
        if (line.isEmpty) continue;

        if (line.startsWith('data:')) {
          final dataPayload = line.substring(5).trim();
          if (dataPayload == '[DONE]') break;

          try {
            final Map<String, dynamic> json = jsonDecode(dataPayload);
            final choices = json['choices'] as List?;
            if (choices != null && choices.isNotEmpty) {
              final delta = choices[0]['delta']?['content'] as String? ??
                  choices[0]['message']?['content'] as String?;
              if (delta != null && delta.isNotEmpty) {
                emittedAny = true;
                yield delta;
              }
            }
          } catch (_) {
            // Ignore partial/comment SSE frames
          }
        } else {
          rawLinesBuffer.writeln(line);
        }
      }

      // Fallback if mock/server returned a single non-SSE JSON body
      if (!emittedAny && rawLinesBuffer.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(rawLinesBuffer.toString());
        final choices = data['choices'] as List?;
        final String? content = (choices != null && choices.isNotEmpty)
            ? (choices[0]['message']?['content'] as String?)
            : null;
        if (content != null && content.trim().isNotEmpty) {
          emittedAny = true;
          yield content.trim();
        }
      }

      if (!emittedAny) {
        throw const AiException('AI servisi boş yanıt döndürdü.');
      }
    } catch (e) {
      throw _mapTransportError(e);
    }
  }

  @override
  Future<String> generateSummary(String text) async {
    final compacted = IAiService.compactContextWindow(text);
    final prompt =
        "Aşağıdaki teknik notu/dokümanı ana noktalarını ve kod/mimari bağlamını koruyarak net şekilde özetle:\n\n$compacted";
    return await _makeRequest(prompt);
  }

  @override
  Stream<String> streamSummary(String text) {
    final compacted = IAiService.compactContextWindow(text);
    final prompt =
        "Aşağıdaki teknik notu/dokümanı ana noktalarını ve kod/mimari bağlamını koruyarak net şekilde özetle:\n\n$compacted";
    return _makeStreamRequest(prompt);
  }

  @override
  Future<List<String>> suggestTags(String text) async {
    final compacted = IAiService.compactContextWindow(text);
    final prompt =
        "Aşağıdaki metin için sadece virgülle ayrılmış tek kelimelik etiketler öner. Markdown veya başka açıklama kullanma:\n\n$compacted";
    final raw = await _makeRequest(prompt, maxTokens: 256);
    return raw
        .split(',')
        .map((e) => e.trim().replaceAll('#', ''))
        .where((e) => e.isNotEmpty)
        .toList();
  }

  @override
  Future<String> customPrompt(String prompt, String content) async {
    final compacted = IAiService.compactContextWindow(content);
    return await _makeRequest("$prompt\n\n$compacted");
  }

  @override
  Stream<String> streamCustomPrompt(String prompt, String content) {
    final compacted = IAiService.compactContextWindow(content);
    return _makeStreamRequest("$prompt\n\n$compacted");
  }

  @override
  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }
}
