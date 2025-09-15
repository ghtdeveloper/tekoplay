import 'package:flutter_dotenv/flutter_dotenv.dart';

class Environment {
  static String get currentEnvironment =>
      dotenv.env['ENVIRONMENT'] ?? 'development';

  static bool get isProduction =>
      currentEnvironment == 'production';

  static bool get isDevelopment =>
      currentEnvironment == 'development';

  static String get apiBaseUrl =>
      isProduction
          ? dotenv.env['API_BASE_URL_PROD'] ?? ''
          : dotenv.env['API_BASE_URL_DEV'] ?? '';

  static String get apiKey =>
      dotenv.env['API_KEY'] ?? '';

  static String get secretKey =>
      dotenv.env['SECRET_KEY'] ?? '';

  static Future<void> load() async {
    final envFile = isProduction ? '.env.production' : '.env';
    await dotenv.load(fileName: envFile);
  }
}