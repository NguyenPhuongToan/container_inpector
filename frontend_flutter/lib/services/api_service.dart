import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../models/app_user.dart';
import '../models/inspection.dart';
import 'auth_session.dart';

class SessionExpiredException implements Exception {
  const SessionExpiredException();

  @override
  String toString() => 'Session expired. Please log in again.';
}

class ApiService {
  static String get baseUrl {
    const env = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (env.isNotEmpty) return env;
    if (kIsWeb) return 'http://127.0.0.1:8000/api';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000/api';
    return 'http://127.0.0.1:8000/api';
  }

  Map<String, String> get _jsonHeaders {
    final headers = {'Accept': 'application/json'};
    final token = AuthSession.token;
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  void _checkUnauthorized(http.Response response) {
    if (response.statusCode == 401) {
      AuthSession.clear();
      throw const SessionExpiredException();
    }
  }

  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Login failed: ${response.body}');
    }

    final Map<String, dynamic> data = jsonDecode(response.body);
    final token = data['access_token']?.toString() ?? '';
    final userData = data['user'];

    if (token.isEmpty || userData is! Map<String, dynamic>) {
      throw Exception('Invalid login response');
    }

    final user = AppUser.fromJson(userData);
    await AuthSession.save(token: token, user: user);
    return user;
  }

  Future<AppUser> registerWorker({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register-worker'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'full_name': fullName.trim(),
        'email': email.trim(),
        'password': password,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Registration failed: ${response.body}');
    }

    final Map<String, dynamic> data = jsonDecode(response.body);
    final token = data['access_token']?.toString() ?? '';
    final userData = data['user'];

    if (token.isEmpty || userData is! Map<String, dynamic>) {
      throw Exception('Invalid registration response');
    }

    final user = AppUser.fromJson(userData);
    await AuthSession.save(token: token, user: user);
    return user;
  }

  Future<void> submitInspection({
    required String containerNumber,
    required String bookingNumber,
    required String truckNumber,
    required String workerName,
    required String portName,
    required String notes,
    required List<XFile> images,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/inspections'),
    );
    request.headers.addAll(_jsonHeaders);

    request.fields.addAll({
      'container_number': containerNumber,
      'booking_number': bookingNumber,
      'truck_number': truckNumber,
      'worker_name': workerName,
      'port_name': portName,
      'notes': notes,
    });

    for (int i = 0; i < images.length; i++) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'image_$i',
          await images[i].readAsBytes(),
          filename: images[i].name,
        ),
      );
    }

    final streamedResponse = await request.send().timeout(
          const Duration(seconds: 45),
        );
    final response = await http.Response.fromStream(streamedResponse);
    _checkUnauthorized(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to submit inspection: ${response.body}');
    }
  }

  Future<String> scanContainerId(XFile image) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/ai/scan-container-id'),
    );
    request.headers.addAll(_jsonHeaders);

    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        await image.readAsBytes(),
        filename: image.name,
      ),
    );

    final streamedResponse = await request.send().timeout(
          const Duration(seconds: 25),
        );
    final response = await http.Response.fromStream(streamedResponse);
    _checkUnauthorized(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to scan container ID: ${response.body}');
    }

    final Map<String, dynamic> data = jsonDecode(response.body);
    final containerNumber = data['container_number']?.toString().trim() ?? '';

    if (containerNumber.isEmpty) {
      throw Exception('Container ID not found');
    }

    return containerNumber;
  }

  Future<List<ContainerInspection>> getInspections({
    String? status,
    String? containerNumber,
    String? workerName,
    String? portName,
  }) async {
    final query = <String, String>{};
    if (status != null && status.isNotEmpty) query['status'] = status;
    if (containerNumber != null && containerNumber.isNotEmpty) {
      query['container_number'] = containerNumber;
    }
    if (workerName != null && workerName.isNotEmpty) {
      query['worker_name'] = workerName;
    }
    if (portName != null && portName.isNotEmpty) {
      query['port_name'] = portName;
    }

    final uri = Uri.parse('$baseUrl/inspections').replace(
      queryParameters: query.isEmpty ? null : query,
    );
    final response = await http.get(
      uri,
      headers: _jsonHeaders,
    );
    _checkUnauthorized(response);

    if (response.statusCode != 200) {
      throw Exception('Failed to load inspections: ${response.body}');
    }

    final List data = jsonDecode(response.body);
    return data
        .whereType<Map<String, dynamic>>()
        .map(ContainerInspection.fromJson)
        .toList();
  }

  Future<ContainerInspection> getInspectionById(String id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/inspections/$id'),
      headers: _jsonHeaders,
    );
    _checkUnauthorized(response);

    if (response.statusCode != 200) {
      throw Exception('Failed to load inspection: ${response.body}');
    }

    final Map<String, dynamic> data = jsonDecode(response.body);
    return ContainerInspection.fromJson(data);
  }

  Future<void> updateInspectionStatus(String id, String status) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/inspections/$id/status'),
      headers: {
        ..._jsonHeaders,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'status': status}),
    );
    _checkUnauthorized(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to update status: ${response.body}');
    }
  }

  Future<List<ContainerInspection>> getSubmittedInspections() {
    return getInspections(status: 'submitted');
  }

  Future<void> acceptInspection(String inspectionId) {
    return _postAction('$baseUrl/inspections/$inspectionId/accept');
  }

  Future<void> rejectInspection(String inspectionId) {
    return _postAction('$baseUrl/inspections/$inspectionId/reject');
  }

  Future<String> exportExcelAndEmail(String inspectionId) {
    return _postActionMessage(
      '$baseUrl/inspections/$inspectionId/export-excel-email',
    );
  }

  Future<String> generateReportAndEmail(String inspectionId) {
    return _postActionMessage(
      '$baseUrl/inspections/$inspectionId/generate-report-email',
    );
  }

  Future<void> _postAction(String url) async {
    final response = await http.post(
      Uri.parse(url),
      headers: _jsonHeaders,
    );
    _checkUnauthorized(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Request failed: ${response.body}');
    }
  }

  Future<String> _postActionMessage(String url) async {
    final response = await http.post(
      Uri.parse(url),
      headers: _jsonHeaders,
    );
    _checkUnauthorized(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Request failed: ${response.body}');
    }

    final Map<String, dynamic> data = jsonDecode(response.body);
    return data['message']?.toString() ?? 'Request completed.';
  }
}
