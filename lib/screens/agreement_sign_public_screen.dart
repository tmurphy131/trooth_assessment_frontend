import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// Screen that allows an apprentice or parent to sign via a deep link token.
/// Expect navigation with: AgreementSignPublicScreen(token: 'uuid', tokenType: 'apprentice'|'parent')
class AgreementSignPublicScreen extends StatefulWidget {
  final String token;
  final String tokenType; // apprentice | parent
  const AgreementSignPublicScreen({super.key, required this.token, required this.tokenType});

  @override
  State<AgreementSignPublicScreen> createState() => _AgreementSignPublicScreenState();
}

class _AgreementSignPublicScreenState extends State<AgreementSignPublicScreen> {
  final _api = ApiService();
  bool _loading = true;
  bool _signing = false;
  String? _error;
  Map<String, dynamic>? _agreement;
  final _typedNameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Using public endpoints directly (no auth required); not yet exposed in ApiService
      final uri = Uri.parse('${_api.baseUrlOverride ?? ''}/agreements/public/${widget.token}');
      final r = await ApiServiceHttpShim.get(uri); // see shim below
      if (r.statusCode == 200) {
        setState(() { _agreement = r.jsonBody; _loading = false; });
      } else {
        setState(() { _error = 'Failed (${r.statusCode})'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Network error: $e'; _loading = false; });
    }
  }

  Future<void> _sign() async {
    if (_typedNameCtrl.text.trim().isEmpty) return;
    setState(() { _signing = true; _error = null; });
    try {
      final uri = Uri.parse('${_api.baseUrlOverride ?? ''}/agreements/public/${widget.token}/sign');
      final r = await ApiServiceHttpShim.post(uri, {'typed_name': _typedNameCtrl.text.trim()});
      if (r.statusCode == 200) {
        setState(() { _agreement = r.jsonBody; });
        _showSnack('Signed successfully');
      } else {
        setState(() { _error = 'Sign failed (${r.statusCode}): ${r.bodySnippet}'; });
      }
    } catch (e) {
      setState(() { _error = 'Network error: $e'; });
    } finally {
      setState(() { _signing = false; });
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.grey[850],
        title: Text('Sign Agreement (${widget.tokenType})', style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : _error != null
              ? _buildError()
              : _agreement == null
                  ? _buildError(msg: 'Agreement not found')
                  : _buildContent(),
    );
  }

  Widget _buildError({String? msg}) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
        const SizedBox(height: 16),
        Text(msg ?? _error ?? 'Error', style: const TextStyle(color: Colors.white, fontFamily: 'Poppins')),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _fetch,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
          child: const Text('Retry'),
        ),
      ],
    ),
  );

  Widget _buildContent() {
    final status = _agreement!['status'];
    final apprenticeEmail = _agreement!['apprentice_email'];
    final parentEmail = _agreement!['parent_email'];
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.description, color: Colors.amber),
                const SizedBox(width: 8),
                const Text('Agreement', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: _statusColor(status).withOpacity(.2), borderRadius: BorderRadius.circular(12)),
                  child: Text(status, style: TextStyle(color: _statusColor(status), fontFamily: 'Poppins')),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Apprentice: $apprenticeEmail', style: const TextStyle(color: Colors.white, fontFamily: 'Poppins')),
            if (parentEmail != null) Text('Parent: $parentEmail', style: const TextStyle(color: Colors.white, fontFamily: 'Poppins')),
            const SizedBox(height: 24),
            if (_canSign(status)) _buildSignForm(status),
            if (!_canSign(status))
              Text('This agreement can no longer be signed with this link.', style: TextStyle(color: Colors.grey[400], fontFamily: 'Poppins')),
          ],
        ),
      ),
    );
  }

  bool _canSign(String status) {
    if (widget.tokenType == 'apprentice') return status == 'awaiting_apprentice' || status == 'awaiting_parent';
    if (widget.tokenType == 'parent') return status == 'awaiting_parent';
    return false;
  }

  Widget _buildSignForm(String status) {
    return Card(
      color: Colors.grey[850],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sign Agreement', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
            const SizedBox(height: 12),
            TextField(
              controller: _typedNameCtrl,
              decoration: const InputDecoration(labelText: 'Type your full name'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.edit),
                onPressed: _signing ? null : _sign,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                label: Text(_signing ? 'Signing...' : 'Sign'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'awaiting_apprentice': return Colors.orange;
      case 'awaiting_parent': return Colors.purple;
      case 'fully_signed': return Colors.green;
      case 'revoked': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  void dispose() {
    _typedNameCtrl.dispose();
    super.dispose();
  }
}

// Minimal HTTP shim using dart:io/http to avoid polluting ApiService with unauth endpoints

class ApiServiceHttpShimResponse {
  final int statusCode; final String body; Map<String, dynamic>? _json; ApiServiceHttpShimResponse(this.statusCode, this.body);
  Map<String, dynamic>? get jsonBody { _json ??= body.isEmpty ? null : jsonDecode(body); return _json; }
  String get bodySnippet => body.length > 120 ? body.substring(0, 120) + '...' : body;
}

class ApiServiceHttpShim {
  static Future<ApiServiceHttpShimResponse> get(Uri uri) async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(uri);
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      return ApiServiceHttpShimResponse(res.statusCode, body);
    } finally { client.close(); }
  }
  static Future<ApiServiceHttpShimResponse> post(Uri uri, Map<String, dynamic> payload) async {
    final client = HttpClient();
    try {
      final req = await client.postUrl(uri);
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      req.add(utf8.encode(jsonEncode(payload)));
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      return ApiServiceHttpShimResponse(res.statusCode, body);
    } finally { client.close(); }
  }
}
