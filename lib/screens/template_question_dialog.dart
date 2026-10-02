part of 'template_management_screen.dart';

// Question creation dialog used by TemplateManagementScreen.

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
                if (!context.mounted) return;
                Navigator.pop(context);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Category "$name" created successfully')),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to create category: ${friendlyError(e)}')),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isPhone = screenWidth < 600;
    
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isPhone ? 16 : 40,
        vertical: 24,
      ),
      title: const Text(
        'Add Question',
        style: TextStyle(
          color: Colors.amber,
          fontFamily: 'Poppins',
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: isPhone ? screenWidth - 64 : 450,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
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
                  TextButton(
                    onPressed: _showCreateCategoryDialog,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.amber,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 14),
                        SizedBox(width: 2),
                        Text('New', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _isLoadingCategories
                  ? const CircularProgressIndicator(color: Colors.amber)
                  : DropdownButtonFormField<String>(
                      initialValue: _selectedCategoryId,
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
              // Radio buttons in a more compact layout
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[700]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    RadioListTile<String>(
                      title: const Text(
                        'Open Ended',
                        style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 14),
                      ),
                      value: 'open_ended',
                      groupValue: _questionType,
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
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
                    Divider(height: 1, color: Colors.grey[700]),
                    RadioListTile<String>(
                      title: const Text(
                        'Multiple Choice',
                        style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 14),
                      ),
                      value: 'multiple_choice',
                      groupValue: _questionType,
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
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
                  ],
                ),
              ),
              if (_questionType == 'multiple_choice') ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(child: Text(
                      'Answer Options',
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.bold,
                      ),
                    )),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _options.add({
                            'option_text': '',
                            'is_correct': false,
                            'order': _options.length + 1,
                          });
                        });
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add', style: TextStyle(fontSize: 13)),
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
            IconButton(tooltip: 'Delete', 
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
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create question: ${friendlyError(e)}')),
      );
    }
  }
}
