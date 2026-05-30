import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../models/app_user.dart';
import '../models/inspection.dart';
import 'auth_session.dart';

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api',
  );

  Map<String, String> get _jsonHeaders {
    final headers = {'Accept': 'application/json'};
    final token = AuthSession.token;
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
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

    if (response.statusCode != 200) {
      throw Exception('Failed to load inspections: ${response.body}');
    }

    final List data = jsonDecode(response.body);
    return data.map((item) => ContainerInspection.fromJson(item)).toList();
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

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Request failed: ${response.body}');
    }
  }

  Future<String> _postActionMessage(String url) async {
    final response = await http.post(
      Uri.parse(url),
      headers: _jsonHeaders,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Request failed: ${response.body}');
    }

    final Map<String, dynamic> data = jsonDecode(response.body);
    return data['message']?.toString() ?? 'Request completed.';
  }
}
