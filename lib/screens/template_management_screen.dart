import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';

class TemplateManagementScreen extends StatefulWidget {
  final User? user;
  
  const TemplateManagementScreen({super.key, this.user});

  @override
  State<TemplateManagementScreen> createState() => _TemplateManagementScreenState();
}

class _TemplateManagementScreenState extends State<TemplateManagementScreen> {
  User? get user => widget.user ?? FirebaseAuth.instance.currentUser;
  final _apiService = ApiService();
  
  List<Map<String, dynamic>> _templates = [];
  List<Map<String, dynamic>> _questions = [];
  bool _isLoading = true;
  bool _isLoadingQuestions = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      print('🔄 Template Management: Initializing...');
      print('👤 User: ${user?.email ?? 'null'}');
      
      // Test basic connectivity first
      try {
        print('🏥 Testing backend connectivity...');
        await _apiService.healthCheck();
        print('✅ Backend connectivity confirmed');
      } catch (e) {
        print('❌ Backend connectivity failed: $e');
        setState(() {
          _error = 'Cannot connect to backend: $e';
          _isLoading = false;
        });
        return;
      }
      
      if (user != null) {
        final token = await user!.getIdToken();
        print('🔑 Token obtained: ${token?.substring(0, 20) ?? 'null'}...');
        _apiService.bearerToken = token;
        print('🔗 API Base URL: ${_apiService.baseUrlOverride ?? 'http://127.0.0.1:8000'}');
      } else {
        print('❌ No user found! Cannot authenticate API calls.');
        setState(() {
          _error = 'No authenticated user found';
          _isLoading = false;
        });
        return;
      }
      
      await Future.wait([
        _loadTemplates(),
        _loadQuestions(),
      ]);
      print('✅ Template Management: Initialization complete');
    } catch (e) {
      print('❌ Template Management: Failed to initialize: $e');
      setState(() {
        _error = 'Failed to initialize: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTemplates() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      print('🔄 Loading templates...');
      final templates = await _apiService.getAllTemplates();
      print('✅ Loaded ${templates.length} templates');
      
      setState(() {
        _templates = templates.cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Failed to load templates: $e');
      setState(() {
        _error = 'Failed to load templates: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadQuestions() async {
    try {
      setState(() {
        _isLoadingQuestions = true;
      });

      final questions = await _apiService.getQuestions();
      setState(() {
        _questions = questions.cast<Map<String, dynamic>>();
        _isLoadingQuestions = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingQuestions = false;
      });
      print('Failed to load questions: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Template Management',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _showCreateTemplateDialog,
            icon: const Icon(Icons.add, color: Colors.amber),
            tooltip: 'Create New Template',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.amber),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Connection Error',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontFamily: 'Poppins',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadTemplates,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                        ),
                        child: const Text('Retry'),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _showCreateTemplateDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Create Template Anyway'),
                      ),
                    ],
                  ),
                )
              : _buildTemplatesList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateTemplateDialog,
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text(
          'Create Template',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildTemplatesList() {
    if (_templates.isEmpty) {
      return Center(
        child: Card(
          elevation: 2,
          color: Colors.grey[900],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.assignment_outlined,
                  size: 64,
                  color: Colors.grey[600],
                ),
                const SizedBox(height: 16),
                Text(
                  'No templates yet',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create your first assessment template',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                    fontFamily: 'Poppins',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _showCreateTemplateDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Create Template',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        print('🧪 Testing template creation dialog');
                        _showCreateTemplateDialog();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Test Dialog',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView.builder(
        itemCount: _templates.length,
        itemBuilder: (context, index) {
          return _buildTemplateCard(_templates[index]);
        },
      ),
    );
  }

  Widget _buildTemplateCard(Map<String, dynamic> template) {
    final name = template['name'] ?? 'Untitled Template';
    final description = template['description'] ?? '';
    final isPublished = template['is_published'] ?? false;
    final isMaster = template['is_master_assessment'] == true;
    final createdAt = template['created_at'] as String?;
    
    return Card(
      elevation: 2,
      color: isMaster ? Colors.amber[900] : Colors.grey[850],
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isMaster)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.star, size: 14, color: Colors.black),
                        SizedBox(width: 4),
                        Text(
                          'OFFICIAL',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color: isMaster ? Colors.amber[100] : Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      if (description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            description,
                            style: TextStyle(
                              color: isMaster ? Colors.amber[200] : Colors.grey[400],
                              fontSize: 14,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isPublished ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    isPublished ? 'Published' : 'Draft',
                    style: TextStyle(
                      color: isPublished ? Colors.green : Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ],
            ),
            
            if (createdAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Created: ${_formatDateString(createdAt)}',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isMaster ? null : () => _editTemplate(template),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isMaster ? Colors.grey[600] : Colors.blue[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.edit, size: 16),
                    label: Text(
                      isMaster ? 'Admin Only' : 'Edit',
                      style: const TextStyle(fontFamily: 'Poppins'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _cloneTemplate(template),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text(
                      'Clone',
                      style: TextStyle(fontFamily: 'Poppins'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isMaster ? null : () => _publishTemplate(template),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isMaster 
                        ? Colors.grey[600] 
                        : (isPublished ? Colors.orange[700] : Colors.green[700]),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: Icon(
                      isMaster 
                        ? Icons.lock 
                        : (isPublished ? Icons.unpublished : Icons.publish),
                      size: 16,
                    ),
                    label: Text(
                      isMaster 
                        ? 'Always Published'
                        : (isPublished ? 'Unpublish' : 'Publish'),
                      style: const TextStyle(fontFamily: 'Poppins'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isMaster ? null : () => _deleteTemplate(template),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isMaster ? Colors.grey[600] : Colors.red[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: Icon(
                      isMaster ? Icons.shield : Icons.delete, 
                      size: 16,
                    ),
                    label: Text(
                      isMaster ? 'Protected' : 'Delete',
                      style: const TextStyle(fontFamily: 'Poppins'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateTemplateDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Create New Template',
          style: TextStyle(
            color: Colors.amber,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
              decoration: InputDecoration(
                labelText: 'Template Name',
                labelStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[600]!),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.amber),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description',
                labelStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[600]!),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.amber),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey, fontFamily: 'Poppins'),
            ),
          ),
          ElevatedButton(
            onPressed: () => _createTemplate(nameController.text, descriptionController.text),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            child: const Text(
              'Create',
              style: TextStyle(color: Colors.black, fontFamily: 'Poppins'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createTemplate(String name, String description) async {
    if (name.trim().isEmpty) {
      _showMessage('Template name is required', isError: true);
      return;
    }

    try {
      Navigator.pop(context); // Close dialog
      
      print('🔄 Creating template: $name');
      final payload = {
        'name': name.trim(),
        'description': description.trim(),
        'is_published': false,
      };

      final result = await _apiService.createTemplate(payload);
      print('✅ Template created: $result');
      
      await _loadTemplates();
      _showMessage('Template created successfully!');
      
    } catch (e) {
      print('❌ Failed to create template: $e');
      _showMessage('Failed to create template: $e', isError: true);
    }
  }

  Future<void> _editTemplate(Map<String, dynamic> template) async {
    final nameController = TextEditingController(text: template['name'] ?? '');
    final descriptionController = TextEditingController(text: template['description'] ?? '');
    bool isPublished = template['is_published'] ?? false;

    // Load the full template with questions
    Map<String, dynamic> fullTemplate;
    try {
      fullTemplate = await _apiService.getTemplate(template['id'] as String);
    } catch (e) {
      _showMessage('Failed to load template details: $e', isError: true);
      return;
    }

    List<Map<String, dynamic>> templateQuestions = List<Map<String, dynamic>>.from(fullTemplate['questions'] ?? []);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Edit Template',
            style: TextStyle(
              color: Colors.amber,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.height * 0.7,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                    decoration: InputDecoration(
                      labelText: 'Template Name',
                      labelStyle: TextStyle(color: Colors.grey[400]),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[600]!),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.amber),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      labelStyle: TextStyle(color: Colors.grey[400]),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[600]!),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.amber),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: isPublished,
                        onChanged: (value) {
                          setDialogState(() {
                            isPublished = value ?? false;
                          });
                        },
                        activeColor: Colors.amber,
                      ),
                      const Text(
                        'Published',
                        style: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Text(
                        'Questions',
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () => _showAddQuestionDialog(
                          template['id'] as String,
                          templateQuestions,
                          setDialogState,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Question'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...templateQuestions.asMap().entries.map((entry) {
                    final index = entry.key;
                    final question = entry.value;
                    return _buildQuestionCard(question, index, templateQuestions, setDialogState, template['id'] as String);
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey, fontFamily: 'Poppins'),
              ),
            ),
            ElevatedButton(
              onPressed: () => _updateTemplate(
                template['id'] as String,
                nameController.text,
                descriptionController.text,
                isPublished,
              ),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
              child: const Text(
                'Update',
                style: TextStyle(color: Colors.black, fontFamily: 'Poppins'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateTemplate(String templateId, String name, String description, bool isPublished) async {
    Navigator.pop(context); // Close dialog
    
    try {
      print('🔄 Updating template: $templateId');
      final payload = {
        'name': name.trim(),
        'description': description.trim().isNotEmpty ? description.trim() : null,
        'is_published': isPublished,
      };
      
      print('📤 Update payload: $payload');
      await _apiService.updateTemplate(templateId, payload);
      await _loadTemplates();
      _showMessage('Template updated successfully!');
    } catch (e) {
      print('❌ Template update failed: $e');
      _showMessage('Failed to update template: $e', isError: true);
    }
  }

  Future<void> _deleteTemplate(Map<String, dynamic> template) async {
    final templateName = template['name'] ?? 'Unknown Template';
    
    // Show confirmation dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Delete Template',
          style: TextStyle(
            color: Colors.red,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "$templateName"?\n\nThis action cannot be undone.',
          style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey, fontFamily: 'Poppins'),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        print('🗑️ Deleting template: ${template['id']}');
        await _apiService.deleteTemplate(template['id'] as String);
        await _loadTemplates();
        _showMessage('Template deleted successfully!');
      } catch (e) {
        print('❌ Template deletion failed: $e');
        _showMessage('Failed to delete template: $e', isError: true);
      }
    }
  }

  Future<void> _cloneTemplate(Map<String, dynamic> template) async {
    try {
      final templateId = template['id'] as String;
      await _apiService.cloneTemplate(templateId);
      await _loadTemplates();
      _showMessage('Template cloned successfully!');
    } catch (e) {
      _showMessage('Failed to clone template: $e', isError: true);
    }
  }

  Future<void> _publishTemplate(Map<String, dynamic> template) async {
    final isPublished = template['is_published'] ?? false;
    final templateName = template['name'] ?? 'Unknown Template';
    
    if (isPublished) {
      // Unpublish the template
      final confirmed = await _showConfirmDialog(
        'Unpublish Template?',
        'Are you sure you want to unpublish "$templateName"? It will no longer be available to apprentices.',
      );
      
      if (!confirmed) return;

      try {
        final templateId = template['id'] as String;
        await _apiService.unpublishTemplate(templateId);
        await _loadTemplates();
        _showMessage('Template unpublished successfully!');
      } catch (e) {
        _showMessage('Failed to unpublish template: $e', isError: true);
      }
    } else {
      // Publish the template
      final confirmed = await _showConfirmDialog(
        'Publish Template?',
        'Are you sure you want to publish "$templateName"? It will become available to all apprentices.',
      );
      
      if (!confirmed) return;

      try {
        final templateId = template['id'] as String;
        await _apiService.publishTemplate(templateId);
        await _loadTemplates();
        _showMessage('Template published successfully!');
      } catch (e) {
        String errorMessage = 'Failed to publish template: $e';
        if (e.toString().contains('Cannot publish template without questions')) {
          errorMessage = 'Cannot publish template without questions. Please add at least one question first.';
        }
        _showMessage(errorMessage, isError: true);
      }
    }
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.amber,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          content,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Poppins',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey, fontFamily: 'Poppins'),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            child: const Text(
              'Confirm',
              style: TextStyle(color: Colors.black, fontFamily: 'Poppins'),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showMessage(String message, {bool isError = false}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          isError ? 'Error' : 'Success',
          style: TextStyle(
            color: isError ? Colors.red : Colors.amber,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Poppins',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(
                color: Colors.amber,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateString(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildQuestionCard(
    Map<String, dynamic> question, 
    int index, 
    List<Map<String, dynamic>> templateQuestions, 
    StateSetter setDialogState,
    String templateId
  ) {
    final questionText = question['text'] ?? 'Unknown Question';
    final questionType = question['question_type'] ?? 'open_ended';
    final questionId = question['id'] ?? '';
    
    return Card(
      color: Colors.grey[800],
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: questionType == 'multiple_choice' ? Colors.blue[700] : Colors.green[700],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    questionType == 'multiple_choice' ? 'Multiple Choice' : 'Open Ended',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () async {
                    try {
                      // Remove from template on backend
                      await _apiService.removeQuestionFromTemplate(
                        templateId,
                        questionId,
                      );
                      
                      // Remove from local list
                      setDialogState(() {
                        templateQuestions.removeAt(index);
                      });
                    } catch (e) {
                      _showMessage('Failed to remove question: $e', isError: true);
                    }
                  },
                  icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              questionText,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
              ),
            ),
            if (questionType == 'multiple_choice' && question['options'] != null)
              ...((question['options'] as List).map((option) => Padding(
                padding: const EdgeInsets.only(left: 16, top: 4),
                child: Row(
                  children: [
                    Icon(
                      option['is_correct'] ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: option['is_correct'] ? Colors.green : Colors.grey,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      option['option_text'] ?? '',
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontFamily: 'Poppins',
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ))),
          ],
        ),
      ),
    );
  }

  void _showAddQuestionDialog(
    String templateId, 
    List<Map<String, dynamic>> templateQuestions, 
    StateSetter setDialogState
  ) {
    showDialog(
      context: context,
      builder: (context) => _QuestionCreationDialog(
        templateId: templateId,
        onQuestionCreated: (question) {
          setDialogState(() {
            templateQuestions.add(question);
          });
        },
      ),
    );
  }
}

class _QuestionCreationDialog extends StatefulWidget {
  final String templateId;
  final Function(Map<String, dynamic>) onQuestionCreated;

  const _QuestionCreationDialog({
    required this.templateId,
    required this.onQuestionCreated,
  });

  @override
  State<_QuestionCreationDialog> createState() => _QuestionCreationDialogState();
}

class _QuestionCreationDialogState extends State<_QuestionCreationDialog> {
  final _questionController = TextEditingController();
  String _questionType = 'open_ended';
  String? _selectedCategoryId;
  List<Map<String, dynamic>> _options = [];
  List<Map<String, dynamic>> _categories = [];
  bool _isLoadingCategories = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final apiService = ApiService();
      final categories = await apiService.getCategories();
      setState(() {
        _categories = categories;
        _isLoadingCategories = false;
        // Select first category by default if available
        if (_categories.isNotEmpty) {
          _selectedCategoryId = _categories.first['id'];
        }
      });
    } catch (e) {
      print('Failed to load categories: $e');
      setState(() {
        _isLoadingCategories = false;
      });
    }
  }

  void _showCreateCategoryDialog() {
    final categoryController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Create New Category',
          style: TextStyle(
            color: Colors.amber,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: categoryController,
          style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
          decoration: InputDecoration(
            labelText: 'Category Name',
            labelStyle: TextStyle(color: Colors.grey[400]),
            border: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey[600]!),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.amber),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = categoryController.text.trim();
              if (name.isEmpty) return;
              
              try {
                final apiService = ApiService();
                final newCategory = await apiService.createCategory(name);
                setState(() {
                  _categories.add(newCategory);
                  _selectedCategoryId = newCategory['id'];
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Category "$name" created successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to create category: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text(
        'Add Question',
        style: TextStyle(
          color: Colors.amber,
          fontFamily: 'Poppins',
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.6,
        height: MediaQuery.of(context).size.height * 0.6,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _questionController,
                style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Question Text',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[600]!),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.amber),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Category Selection
              Row(
                children: [
                  Text(
                    'Category',
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _showCreateCategoryDialog,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.amber,
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('New Category'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _isLoadingCategories
                  ? const CircularProgressIndicator(color: Colors.amber)
                  : DropdownButtonFormField<String>(
                      value: _selectedCategoryId,
                      dropdownColor: Colors.grey[800],
                      style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey[600]!),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.amber),
                        ),
                      ),
                      items: _categories.map((category) {
                        return DropdownMenuItem<String>(
                          value: category['id'],
                          child: Text(
                            category['name'],
                            style: const TextStyle(color: Colors.white),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategoryId = value;
                        });
                      },
                      hint: const Text(
                        'Select a category',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
              const SizedBox(height: 16),
              Text(
                'Question Type',
                style: TextStyle(
                  color: Colors.grey[300],
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text(
                        'Open Ended',
                        style: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                      ),
                      value: 'open_ended',
                      groupValue: _questionType,
                      onChanged: (value) {
                        setState(() {
                          _questionType = value!;
                          if (_questionType == 'open_ended') {
                            _options.clear();
                          }
                        });
                      },
                      activeColor: Colors.amber,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text(
                        'Multiple Choice',
                        style: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                      ),
                      value: 'multiple_choice',
                      groupValue: _questionType,
                      onChanged: (value) {
                        setState(() {
                          _questionType = value!;
                          if (_questionType == 'multiple_choice' && _options.isEmpty) {
                            _options = [
                              {'option_text': '', 'is_correct': false, 'order': 1},
                              {'option_text': '', 'is_correct': false, 'order': 2},
                            ];
                          }
                        });
                      },
                      activeColor: Colors.amber,
                    ),
                  ),
                ],
              ),
              if (_questionType == 'multiple_choice') ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Answer Options',
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _options.add({
                            'option_text': '',
                            'is_correct': false,
                            'order': _options.length + 1,
                          });
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Option'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._options.asMap().entries.map((entry) {
                  final index = entry.key;
                  final option = entry.value;
                  return _buildOptionInput(index, option);
                }),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.grey, fontFamily: 'Poppins'),
          ),
        ),
        ElevatedButton(
          onPressed: _createQuestion,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
          child: const Text(
            'Add Question',
            style: TextStyle(color: Colors.black, fontFamily: 'Poppins'),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionInput(int index, Map<String, dynamic> option) {
    return Card(
      color: Colors.grey[800],
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                decoration: InputDecoration(
                  hintText: 'Option ${index + 1}',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[600]!),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.amber),
                  ),
                ),
                onChanged: (value) {
                  option['option_text'] = value;
                },
              ),
            ),
            const SizedBox(width: 12),
            Column(
              children: [
                const Text(
                  'Correct',
                  style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 12),
                ),
                Checkbox(
                  value: option['is_correct'],
                  onChanged: (value) {
                    setState(() {
                      // Only one option can be correct
                      for (var opt in _options) {
                        opt['is_correct'] = false;
                      }
                      option['is_correct'] = value ?? false;
                    });
                  },
                  activeColor: Colors.amber,
                ),
              ],
            ),
            IconButton(
              onPressed: _options.length > 2 ? () {
                setState(() {
                  _options.removeAt(index);
                  // Update order numbers
                  for (int i = 0; i < _options.length; i++) {
                    _options[i]['order'] = i + 1;
                  }
                });
              } : null,
              icon: Icon(
                Icons.delete,
                color: _options.length > 2 ? Colors.red : Colors.grey,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _createQuestion() async {
    if (_questionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Question text is required')),
      );
      return;
    }

    if (_questionType == 'multiple_choice') {
      // Validate options
      final validOptions = _options.where((opt) => opt['option_text'].toString().trim().isNotEmpty).toList();
      if (validOptions.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('At least 2 options are required for multiple choice questions')),
        );
        return;
      }

      final hasCorrectAnswer = validOptions.any((opt) => opt['is_correct'] == true);
      if (!hasCorrectAnswer) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please mark one option as correct')),
        );
        return;
      }

      _options = validOptions;
    }

    try {
      final payload = {
        'text': _questionController.text.trim(),
        'question_type': _questionType,
        'category_id': _selectedCategoryId,
        'options': _questionType == 'multiple_choice' ? _options : [],
      };

      final apiService = ApiService();
      final question = await apiService.createQuestion(payload);
      
      // Add the question to the template
      await apiService.addQuestionToTemplate(
        widget.templateId,
        question['id'] as String,
        1, // Default order
      );
      
      widget.onQuestionCreated(question);
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create question: $e')),
      );
    }
  }
}
