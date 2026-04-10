import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class APIHelper {
  static Future<String?> post(String url, {Object? body, int? timeout, void Function(Object? error)? callback, Map<String, String>? headers}) async {
    Completer<String?> completer = Completer();
    try {
      await http
          .post(Uri.parse(url), body: body != null ? jsonEncode(body) : null, headers: {"Content-Type": "application/json", ...(headers ?? {})})
          .then((value) {
            if (value.statusCode == 200 && value.body.isNotEmpty && value.body != "null" && value.body != "nothing!") {
              completer.complete(value.body);
            } else {
              if (callback != null) {
                callback("value null: ${value.statusCode} - ${value.body}");
              }
              completer.complete(null);
            }
          })
          .catchError((err) {
            if (callback != null) {
              callback(err);
            }
            completer.complete(null);
          })
          .timeout(Duration(milliseconds: timeout ?? 20000))
          .onError((error, stackTrace) {
            if (callback != null) {
              callback(error);
            }
            completer.complete(null);
          });
    } on SocketException catch (e) {
      if (callback != null) {
        callback(e);
      }
      completer.complete(null);
    } catch (e) {
      if (callback != null) {
        callback(e);
      }
      completer.complete(null);
    }
    return completer.future;
  }

  static Future<String?> get(String url, {int? timeout, void Function(Object? error)? callback, Map<String, String>? query, Map<String, String>? headers}) async {
    Completer<String?> completer = Completer();
    try {
      await http
          .get(Uri.parse(url + (query != null ? "?${encodeQueryParameters(query)}" : "")), headers: headers ?? {})
          .then((value) {
            if (value.statusCode == 200 && value.body.isNotEmpty && value.body != "null" && value.body != "nothing!") {
              completer.complete(value.body);
            } else {
              if (callback != null) {
                callback("value null");
              }
              completer.complete(null);
            }
          })
          .catchError((err) {
            if (callback != null) {
              callback(err);
            }
            completer.complete(null);
          })
          .timeout(Duration(milliseconds: timeout ?? 20000))
          .onError((error, stackTrace) {
            if (callback != null) {
              callback(error);
            }
            completer.complete(null);
          });
    } on SocketException catch (e) {
      if (callback != null) {
        callback(e);
      }
      completer.complete(null);
    } catch (e) {
      if (callback != null) {
        callback(e);
      }
      completer.complete(null);
    }
    return completer.future;
  }

  static String encodeQueryParameters(Map<String, String> query) {
    return query.entries.map((e) => "${e.key}=${e.value}").join("&");
  }

  /// [stream] is non-null only when the HTTP status is 200.
  static Future<({Stream<String>? stream, int? statusCode, String? detail})> postStream(
    String url, {
    Object? body,
    int? timeout,
    String? token,
    void Function(Object? error)? callback,
    Map<String, String>? headers,
  }) async {
    try {
      final client = HttpClient();
      final request = await client.postUrl(Uri.parse(url));
      request.headers.set('Content-Type', 'application/json; charset=utf-8');
      request.headers.set('Accept', 'text/event-stream');
      request.headers.set('ngrok-skip-browser-warning', 'true');
      if (token != null) {
        request.headers.set('Authorization', 'Bearer $token');
      }
      if (headers != null) {
        headers.forEach((key, value) => request.headers.set(key, value));
      }
      if (body != null) {
        request.write(jsonEncode(body));
      }

      final response = await request.close().timeout(Duration(milliseconds: timeout ?? 20000));

      if (response.statusCode == 200) {
        final stream = response
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .where((line) => line.startsWith('data: '))
            .map((line) => line.substring(6)); // Remove 'data: ' prefix
        return (stream: stream, statusCode: 200, detail: null);
      }

      String detail;
      try {
        detail = await response.transform(utf8.decoder).join();
        if (detail.length > 2000) {
          detail = '${detail.substring(0, 2000)}...';
        }
        if (detail.isEmpty) {
          detail = 'HTTP ${response.statusCode}';
        }
      } catch (_) {
        detail = 'HTTP ${response.statusCode}';
      }
      if (callback != null) {
        callback('status error: ${response.statusCode}');
      }
      log('postStream status error: ${response.statusCode} - $detail');
      return (stream: null, statusCode: response.statusCode, detail: detail);
    } on SocketException catch (e) {
      if (callback != null) {
        callback(e);
      }
      debugPrint('postStream socket error: $e - $url');
      return (stream: null, statusCode: null, detail: e.message);
    } catch (e) {
      if (callback != null) {
        callback(e);
      }
      debugPrint('postStream error: $e - $url');
      return (stream: null, statusCode: null, detail: e.toString());
    }
  }
}
