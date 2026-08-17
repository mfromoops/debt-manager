import 'dart:convert';

import 'package:http/http.dart' as http;

import 'sync_config.dart';

class SyncDocument {
  const SyncDocument({
    required this.loans,
    required this.updatedAt,
    required this.rev,
    this.deviceId,
  });

  final List<dynamic> loans;
  final DateTime updatedAt;
  final String rev;
  final String? deviceId;

  factory SyncDocument.fromJson(Map<String, dynamic> json) {
    return SyncDocument(
      loans: json['loans'] as List<dynamic>? ?? [],
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      rev: json['rev'] as String,
      deviceId: json['deviceId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'loans': loans,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'rev': rev,
        'deviceId': deviceId,
      };
}

class SyncService {
  SyncService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  bool get isConfigured => SyncConfig.isConfigured;

  Future<SyncDocument?> fetchState(String accessToken) async {
    if (!isConfigured) return null;
    final response = await _client.get(
      SyncConfig.stateUri(),
      headers: {'authorization': 'Bearer $accessToken'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 404 || response.body == 'null') return null;
    if (response.statusCode == 401) {
      throw SyncUnauthorizedException(
        'Sync pull unauthorized: ${response.statusCode} ${response.body}',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SyncException('Sync pull failed: ${response.statusCode} ${response.body}');
    }

    final body = jsonDecode(response.body);
    if (body == null) return null;
    return SyncDocument.fromJson(body as Map<String, dynamic>);
  }

  Future<SyncDocument> pushState(
    String accessToken,
    SyncDocument document,
  ) async {
    if (!isConfigured) return document;
    final response = await _client.put(
      SyncConfig.stateUri(),
      headers: {
        'authorization': 'Bearer $accessToken',
        'content-type': 'application/json',
      },
      body: jsonEncode(document.toJson()),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 401) {
      throw SyncUnauthorizedException(
        'Sync push unauthorized: ${response.statusCode} ${response.body}',
      );
    }
    if (response.statusCode != 200 && response.statusCode != 409) {
      throw SyncException('Sync push failed: ${response.statusCode} ${response.body}');
    }

    return SyncDocument.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  void close() => _client.close();
}

class SyncException implements Exception {
  const SyncException(this.message);
  final String message;

  @override
  String toString() => message;
}

class SyncUnauthorizedException extends SyncException {
  const SyncUnauthorizedException(super.message);
}
