import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Thin HTTP wrapper shared by every Rest*Service in the app.
///
/// Centralizes:
/// - Base URL
/// - Bearer token authentication
/// - JSON encoding/decoding
/// - HTTP methods
/// - Error handling
/// - APIResponse formatting
class CoreService {
  CoreService({
    http.Client? client,
    FlutterSecureStorage? storage,
  })  : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  final http.Client _client;
  final FlutterSecureStorage _storage;

  String get baseUrl =>
      dotenv.env['BASE_URL'] ?? 'http://localhost:3000/api';

  /// Builds headers for every request.
  ///
  /// When [withAuth] is true, the access token stored in secure storage
  /// is automatically attached as:
  ///
  /// Authorization: Bearer <token>
  Future<Map<String, String>> _headers({
    bool withAuth = true,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (withAuth) {
      final token = await _storage.read(key: 'accessToken');

      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  /// GET request.
  ///
  /// Example:
  ///
  /// final response = await fetch('/courses');
  Future<APIResponse> fetch(
    String path, {
    Map<String, dynamic>? query,
    bool withAuth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: query?.map(
        (key, value) => MapEntry(
          key,
          value.toString(),
        ),
      ),
    );

    try {
      final response = await _client
          .get(
            uri,
            headers: await _headers(
              withAuth: withAuth,
            ),
          )
          .timeout(
            const Duration(seconds: 15),
          );

      return _parse(response);
    } catch (e) {
      return APIResponse(
        success: false,
        message: 'Could not reach the server. Check your connection.',
        data: {},
      );
    }
  }

  /// POST / PATCH / PUT / DELETE request.
  ///
  /// Authentication is enabled by default.
  Future<APIResponse> send(
    String path, {
    Map<String, dynamic>? body,
    String method = 'POST',
    bool withAuth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path');

    final headers = await _headers(
      withAuth: withAuth,
    );

    final encodedBody = body != null
        ? jsonEncode(body)
        : null;

    const timeoutDuration = Duration(seconds: 15);

    try {
      late http.Response response;

      switch (method.toUpperCase()) {
        case 'PATCH':
          response = await _client
              .patch(
                uri,
                headers: headers,
                body: encodedBody,
              )
              .timeout(timeoutDuration);
          break;

        case 'PUT':
          response = await _client
              .put(
                uri,
                headers: headers,
                body: encodedBody,
              )
              .timeout(timeoutDuration);
          break;

        case 'DELETE':
          response = await _client
              .delete(
                uri,
                headers: headers,
                body: encodedBody,
              )
              .timeout(timeoutDuration);
          break;

        case 'POST':
        default:
          response = await _client
              .post(
                uri,
                headers: headers,
                body: encodedBody,
              )
              .timeout(timeoutDuration);
      }

      return _parse(response);
    } catch (e) {
      return APIResponse(
        success: false,
        message: 'Could not reach the server. Check your connection.',
        data: {},
      );
    }
  }

  /// Downloads a file while automatically attaching the Bearer token.
  ///
  /// Useful for authenticated CSV/Excel/PDF endpoints.
  Future<http.Response> download(
    String path, {
    Map<String, dynamic>? query,
    bool withAuth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: query?.map(
        (key, value) => MapEntry(
          key,
          value.toString(),
        ),
      ),
    );

    return _client.get(
      uri,
      headers: await _headers(
        withAuth: withAuth,
      ),
    );
  }

  /// Converts an HTTP response into the application's APIResponse format.
  APIResponse _parse(http.Response response) {
    dynamic decoded;

    try {
      decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
    } catch (_) {
      decoded = <String, dynamic>{};
    }

    /*
     * Bare arrays are wrapped inside "items".
     *
     * Example:
     *
     * API:
     * [
     *   {...},
     *   {...}
     * ]
     *
     * Becomes:
     *
     * {
     *   "items": [
     *     {...},
     *     {...}
     *   ]
     * }
     */
    final Map<String, dynamic> data = decoded is List
        ? {
            'items': decoded,
          }
        : decoded is Map<String, dynamic>
            ? decoded
            : {};

    final isSuccess =
        response.statusCode >= 200 &&
        response.statusCode < 300;

    if (!isSuccess) {
      final rawMessage = data['message'];

      final message = rawMessage is List
          ? rawMessage.join(' ')
          : rawMessage?.toString() ??
              'Something went wrong (${response.statusCode}).';

      return APIResponse(
        success: false,
        message: message,
        data: data,
      );
    }

    return APIResponse(
      success: true,
      message: 'OK',
      data: data,
    );
  }
}

class APIResponse {
  bool success;
  String message;
  Map<String, dynamic> data;

  APIResponse({
    required this.success,
    required this.message,
    required this.data,
  });
}
