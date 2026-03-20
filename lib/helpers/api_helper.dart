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
          .post(Uri.parse(url), body: body, headers: {"Content-Type": "application/json", ...(headers ?? {})})
          .then((value) {
            if (value.statusCode == 200 && value.body.isNotEmpty && value.body != "null" && value.body != "nothing!") {
              completer.complete(value.body);
            } else {
              debugPrint('body: $body');
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

  static Future<Stream<String>?> postStream(String url, {Object? body, int? timeout, String? token, void Function(Object? error)? callback, Map<String, String>? headers}) async {
    Completer<Stream<String>?> completer = Completer();
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

      await request
          .close()
          .then((response) {
            print('xxx response: $response');
            if (response.statusCode == 200) {
              final stream = response
                  .transform(utf8.decoder)
                  .transform(const LineSplitter())
                  .where((line) => line.startsWith('data: '))
                  .map((line) => line.substring(6)); // Remove 'data: ' prefix
              completer.complete(stream);
            } else {
              if (callback != null) {
                callback("status error");
              }
              log('postStream status error: ${response.statusCode} - ${response.reasonPhrase}');
              completer.complete(null);
            }
          })
          .catchError((err) {
            if (callback != null) {
              callback(err);
            }
            log('postStream catch error: $err - $url');
            completer.complete(null);
          })
          .timeout(Duration(milliseconds: timeout ?? 20000))
          .onError((error, stackTrace) {
            if (callback != null) {
              callback(error);
            }
            debugPrint('postStream onError: $error - $url');
            completer.complete(null);
          });
    } on SocketException catch (e) {
      if (callback != null) {
        callback(e);
      }
      debugPrint('postStream socket error: $e - $url');
      completer.complete(null);
    } catch (e) {
      if (callback != null) {
        callback(e);
      }
      debugPrint('postStream error: $e - $url');
      completer.complete(null);
    }
    return completer.future;
  }
}
