import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';
import '../services/subscription_service.dart';
import 'subscription_screen.dart';
import '../utils/errors.dart';

part 'template_management_screen_widgets.dart';
part 'template_question_dialog.dart';

class TemplateManagementScreen extends StatefulWidget {
  final User? user;
  
  const TemplateManagementScreen({super.key, this.user});

  @override
  State<TemplateManagementScreen> createState() => _TemplateManagementScreenState();
}

class _TemplateManagementScreenState extends State<TemplateManagementScreen> {
  User? get user => widget.user ?? FirebaseAuth.instance.currentUser;
  final _apiService = ApiService();
  final _subscriptionService = SubscriptionService();
  
  List<Map<String, dynamic>> _templates = [];
  bool _isLoading = true;
  String? _error;
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      print('🔄 Template Management: Initializing...');
      print('👤 User: ${user?.email ?? 'null'}');
      
      // Check premium status from API service (which checks backend)
      await _subscriptionService.refreshStatus();
      
      // Use ApiService.isPremiumUser() which checks the actual backend tier
      _isPremium = await _apiService.isPremiumUser();
      print('💎 Premium status: $_isPremium');
      
      // If not premium, don't load templates - show gate instead
      if (!_isPremium) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // Test basic connectivity first
      try {
        print('🏥 Testing backend connectivity...');
        await _apiService.healthCheck();
        print('✅ Backend connectivity confirmed');
      } catch (e) {
        print('❌ Backend connectivity failed: $e');
        setState(() {
          _error = 'Cannot connect to backend: ${friendlyError(e)}';
          _isLoading = false;
        });
        return;
      }
      
      if (user == null) {
        print('❌ No user found! Cannot authenticate API calls.');
        setState(() {
          _error = 'No authenticated user found';
          _isLoading = false;
        });
        return;
      }
      
      await _loadTemplates();
      print('✅ Template Management: Initialization complete');
    } catch (e) {
      print('❌ Template Management: Failed to initialize: $e');
      setState(() {
        _error = 'Failed to initialize: ${friendlyError(e)}';
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
        _error = 'Failed to load templates: ${friendlyError(e)}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show premium gate if not premium
    if (!_isPremium && !_isLoading) {
      return _buildPremiumGate();
    }
    
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
      _showMessage('Failed to create template: ${friendlyError(e)}', isError: true);
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
      _showMessage('Failed to load template details: ${friendlyError(e)}', isError: true);
      return;
    }

    List<Map<String, dynamic>> templateQuestions = List<Map<String, dynamic>>.from(fullTemplate['questions'] ?? []);

    if (!mounted) return;
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
      _showMessage('Failed to update template: ${friendlyError(e)}', isError: true);
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
        _showMessage('Failed to delete template: ${friendlyError(e)}', isError: true);
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
      _showMessage('Failed to clone template: ${friendlyError(e)}', isError: true);
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
        _showMessage('Failed to unpublish template: ${friendlyError(e)}', isError: true);
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
        String errorMessage = 'Failed to publish template: ${friendlyError(e)}';
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
