part of 'template_management_screen.dart';

// Widget builders for _TemplateManagementScreenState. State and logic live in template_management_screen.dart.
extension _TemplateManagementScreenStateWidgets on _TemplateManagementScreenState {
  Widget _buildPremiumGate() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Template Management',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            color: Colors.amber,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.amber),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Lock icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: Colors.amber,
                ),
              ),
              const SizedBox(height: 24),
              
              // Title
              const Text(
                'Premium Feature',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 12),
              
              // Description
              Text(
                'Create custom assessment templates to guide your apprentices on their spiritual journey.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 16,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 32),
              
              // Features list
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[800]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'With Premium you can:',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildFeatureRow(Icons.edit_document, 'Create custom assessment templates'),
                    _buildFeatureRow(Icons.category, 'Organize questions by category'),
                    _buildFeatureRow(Icons.publish, 'Publish templates for apprentices'),
                    _buildFeatureRow(Icons.people, 'Mentor unlimited apprentices'),
                    _buildFeatureRow(Icons.insights, 'Access detailed AI-powered insights'),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Upgrade button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Upgrade to Premium',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              // Back button
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Maybe Later',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.amber, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
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
                            fontSize: 11,
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
                    color: isPublished ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
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
                      fontSize: 11,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(tooltip: 'Delete', 
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
                      _showMessage('Failed to remove question: ${friendlyError(e)}', isError: true);
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
}
