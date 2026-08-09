import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_backend.dart';
import 'wp_config.dart';

/// Thin HTTP client for `/wp-json/alf/v1/`.
class WpApiClient {
  WpApiClient({http.Client? httpClient, String? baseApi})
      : _http = httpClient ?? http.Client(),
        apiRoot = baseApi ?? WpConfig.apiRoot;

  final http.Client _http;
  final String apiRoot;

  String? accessToken;

  Uri _uri(String path, [Map<String, String>? query]) {
    final clean = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$apiRoot$clean').replace(queryParameters: query);
  }

  Map<String, String> _headers({bool jsonBody = false}) {
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    if (jsonBody) {
      headers['Content-Type'] = 'application/json';
    }
    final token = accessToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    final response = await _http.get(_uri(path, query), headers: _headers());
    return _decode(response);
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    final response = await _http.post(
      _uri(path),
      headers: _headers(jsonBody: true),
      body: jsonEncode(body ?? const {}),
    );
    return _decode(response);
  }

  Future<dynamic> put(String path, {Map<String, dynamic>? body}) async {
    final response = await _http.put(
      _uri(path),
      headers: _headers(jsonBody: true),
      body: jsonEncode(body ?? const {}),
    );
    return _decode(response);
  }

  Future<dynamic> patch(String path, {Map<String, dynamic>? body}) async {
    final response = await _http.patch(
      _uri(path),
      headers: _headers(jsonBody: true),
      body: jsonEncode(body ?? const {}),
    );
    return _decode(response);
  }

  dynamic _decode(http.Response response) {
    final raw = response.body.isEmpty ? '{}' : response.body;
    dynamic data;
    try {
      data = jsonDecode(raw);
    } catch (_) {
      throw BackendException(
        'Invalid response from server (${response.statusCode}).',
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    final message = _errorMessage(data) ??
        'Request failed (${response.statusCode}).';
    throw BackendException(message);
  }

  String? _errorMessage(dynamic data) {
    if (data is Map) {
      if (data['message'] is String) return data['message'] as String;
      if (data['code'] is String && data['message'] is String) {
        return data['message'] as String;
      }
      final err = data['data'];
      if (err is Map && err['message'] is String) {
        return err['message'] as String;
      }
    }
    return null;
  }

  void dispose() => _http.close();
}
