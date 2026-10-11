class AiException implements Exception {
  final String message;
  final int? statusCode;

  const AiException(this.message, [this.statusCode]);

  factory AiException.unconfigured([String? message]) =>
      AiException(message ?? 'AI servisi etkinleştirilmemiş veya yapılandırılmamış.');

  factory AiException.missingApiKey([String? message]) =>
      AiException(message ?? 'API anahtarı eksik. Lütfen Ayarlar > Yapay Zeka bölümünden geçerli bir anahtar girin.');

  factory AiException.invalidApiKey([int? statusCode]) =>
      AiException('API anahtarı geçersiz veya yetkisiz. Lütfen anahtarınızı kontrol edin.', statusCode);

  factory AiException.rateLimited([int? statusCode]) =>
      AiException('İstek kotası veya hız sınırı aşıldı. Lütfen bir süre sonra tekrar deneyin.', statusCode ?? 429);

  factory AiException.network([String? detail]) =>
      AiException(detail != null && detail.isNotEmpty
          ? 'Bağlantı hatası: $detail'
          : 'İnternet bağlantısı kurulamadı veya sunucuya erişilemiyor.');

  factory AiException.server(int statusCode, [String? serverMessage]) =>
      AiException(serverMessage != null && serverMessage.isNotEmpty
          ? 'Sunucu hatası ($statusCode): $serverMessage'
          : 'AI sunucusunda bir hata oluştu (HTTP $statusCode). Lütfen daha sonra tekrar deneyin.', statusCode);

  @override
  String toString() => message;
}
