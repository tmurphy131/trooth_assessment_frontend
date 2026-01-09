import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';
import 'assessment_results_screen.dart';

class AssessmentScreen extends StatefulWidget {
  final String? templateId;
  final String? draftId;

  const AssessmentScreen({
    super.key,
    this.templateId,
    this.draftId,
  });

  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final _apiService = ApiService();
  final PageController _pageController = PageController();
  
  Map<String, dynamic>? _currentDraft;
  List<Map<String, dynamic>> _questions = [];
  Map<String, String> _answers = {};
  final Map<String, TextEditingController> _textControllers = {}; // Add controllers map
  int _currentQuestionIndex = 0;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isCreatingDraft = false; // Add flag to prevent multiple draft creation
  String? _error;

  // Sample questions if backend doesn't have any yet
  final List<Map<String, dynamic>> _sampleQuestions = [
    {
      'id': '1',
      'text': 'How would you describe your current relationship with God?',
      'category': 'Spiritual Foundation',
    },
    {
      'id': '2', 
      'text': 'What does daily prayer mean to you in your spiritual journey?',
      'category': 'Prayer Life',
    },
    {
      'id': '3',
      'text': 'How do you apply biblical teachings in your everyday decisions?',
      'category': 'Biblical Application',
    },
    {
      'id': '4',
      'text': 'Describe a time when your faith was challenged and how you responded.',
      'category': 'Faith Challenges',
    },
    {
      'id': '5',
      'text': 'How do you serve others in your community as an expression of your faith?',
      'category': 'Service & Community',
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeAssessment();
  }

  @override
  void dispose() {
    // Dispose of all text controllers
    for (var controller in _textControllers.values) {
      controller.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  // Get or create a text controller for a specific question
  TextEditingController _getControllerForQuestion(String questionId) {
    if (!_textControllers.containsKey(questionId)) {
      _textControllers[questionId] = TextEditingController(
        text: _answers[questionId] ?? '',
      );
    }
    return _textControllers[questionId]!;
  }

  // Update all text controllers with current answers
  void _updateTextControllers() {
    for (String questionId in _answers.keys) {
      if (_textControllers.containsKey(questionId)) {
        _textControllers[questionId]!.text = _answers[questionId] ?? '';
      }
    }
  }

  Future<void> _initializeAssessment() async {
    try {
      if (user != null) {
        final token = await user!.getIdToken();
        if (token != null && token.isNotEmpty) {
          print('🔐 Assessment Screen - Got Firebase token: ${token.substring(0, 20)}... (length: ${token.length})');
        } else {
          print('❌ Assessment Screen - Empty or null token received');
        }
        _apiService.bearerToken = token;
      } else {
        print('❌ Assessment Screen - No user found');
      }

      await _loadOrCreateDraft();
      
      // Only load questions if they weren't already loaded from the draft
      if (_questions.isEmpty) {
        await _loadQuestions();
      }
      
    } catch (e) {
      print('Error initializing assessment: $e');
      // Use sample questions if backend fails
      setState(() {
        _questions = _sampleQuestions;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadOrCreateDraft() async {
    try {
      // If we have a draftId, load that specific draft
      if (widget.draftId != null) {
        try {
          final draft = await _apiService.getDraftById(widget.draftId!);
          setState(() {
            _currentDraft = draft;
            // Load existing answers
            final existingAnswers = draft['answers'] as Map<String, dynamic>? ?? {};
            _answers = existingAnswers.map((key, value) => MapEntry(key, value.toString()));
            // Load questions from the draft response
            final questionsFromDraft = draft['questions'] as List<dynamic>? ?? [];
            _questions = questionsFromDraft.cast<Map<String, dynamic>>();
            _isLoading = false; // Set loading to false since we loaded questions from draft
            print('📝 Loaded ${_questions.length} questions from draft ${widget.draftId}');
            // Debug: Print first question to see structure
            if (_questions.isNotEmpty) {
              print('🔍 First question structure: ${_questions[0]}');
            }
            // Update text controllers with existing answers
            _updateTextControllers();
            // Set to first unanswered question
            int firstUnanswered = 0;
            for (int i = 0; i < _questions.length; i++) {
              final qid = _questions[i]['id'].toString();
              if (!_answers.containsKey(qid) || (_answers[qid]?.trim().isEmpty ?? true)) {
                firstUnanswered = i;
                break;
              }
            }
            _currentQuestionIndex = firstUnanswered;
            // Animate to the correct page if the PageController is ready
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_pageController.hasClients) {
                _pageController.jumpToPage(_currentQuestionIndex);
              }
            });
          });
          return;
        } catch (e) {
          print('Failed to load draft ${widget.draftId}: $e');
          rethrow; // Re-throw to show error to user
        }
      }
      
      // If we have a templateId, try to start/resume a draft for that template
      if (widget.templateId != null) {
        try {
          print('🔄 Starting draft for template: ${widget.templateId}');
          final draft = await _apiService.startDraft(widget.templateId!);
          print('✅ Draft started successfully: ${draft['id']}');
          setState(() {
            _currentDraft = draft;
            // Load existing answers
            final existingAnswers = draft['answers'] as Map<String, dynamic>? ?? {};
            _answers = existingAnswers.map((key, value) => MapEntry(key, value.toString()));
            // Load questions from the draft response
            final questionsFromDraft = draft['questions'] as List<dynamic>? ?? [];
            _questions = questionsFromDraft.cast<Map<String, dynamic>>();
            _isLoading = false; // Set loading to false since we loaded questions from draft
            print('📝 Loaded ${_questions.length} questions from draft for template ${widget.templateId}');
            
            // Debug: Print first question to see structure
            if (_questions.isNotEmpty) {
              print('🔍 First question structure: ${_questions[0]}');
            }
            
            // Update text controllers with existing answers
            _updateTextControllers();
          });
          return;
        } catch (e) {
          print('❌ Failed to start/resume draft for template: $e');
          // Continue to fallback but log the issue
        }
      }
      
      // Try to get existing draft (fallback for legacy behavior)
      final draft = await _apiService.getCurrentDraft();
      setState(() {
        _currentDraft = draft;
        // Load existing answers
        final existingAnswers = draft['answers'] as Map<String, dynamic>? ?? {};
        _answers = existingAnswers.map((key, value) => MapEntry(key, value.toString()));
        // Update text controllers with existing answers
        _updateTextControllers();
      });
    } catch (e) {
      print('No existing draft found, will create new one when saving: $e');
      // No existing draft, will create one when saving
    }
  }

  Future<void> _loadQuestions() async {
    try {
      final questions = await _apiService.getQuestions();
      if (questions.isNotEmpty) {
        setState(() {
          _questions = questions.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      } else {
        // Use sample questions if no questions in backend
        setState(() {
          _questions = _sampleQuestions;
          _isLoading = false;
        });
      }
      
      // If we have a draft with a last_question_id, position user at that question
      _restoreQuestionPosition();
      
    } catch (e) {
      print('Failed to load questions: $e');
      // Use sample questions as fallback
      setState(() {
        _questions = _sampleQuestions;
        _isLoading = false;
      });
      
      // Still try to restore position even with sample questions
      _restoreQuestionPosition();
    }
  }

  void _restoreQuestionPosition() {
    if (_currentDraft != null && 
        _currentDraft!['last_question_id'] != null && 
        _questions.isNotEmpty) {
      final lastQuestionId = _currentDraft!['last_question_id'];
      
      // Find the index of the last question
      for (int i = 0; i < _questions.length; i++) {
        if (_questions[i]['id'] == lastQuestionId) {
          setState(() {
            _currentQuestionIndex = i;
          });
          
          // Animate to the correct page if the PageController is ready
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_pageController.hasClients) {
              _pageController.animateToPage(
                i,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          });
          break;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text('Loading Assessment...', style: TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.amber),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text('Assessment Error', style: TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _error!,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                child: const Text('Go Back', style: TextStyle(color: Colors.black)),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'Spiritual Assessment (${_currentQuestionIndex + 1}/${_questions.length})',
          style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.amber,
                  strokeWidth: 2,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar
          LinearProgressIndicator(
            value: (_currentQuestionIndex + 1) / _questions.length,
            backgroundColor: Colors.grey[800],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
          ),
          
          // Question content
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentQuestionIndex = index;
                });
              },
              itemCount: _questions.length,
              itemBuilder: (context, index) {
                return _buildQuestionPage(_questions[index]);
              },
            ),
          ),
          
          // Navigation buttons
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildQuestionPage(Map<String, dynamic> question) {
    final questionId = question['id'] as String;
    final questionText = question['text'] as String;
    final category = question['category'] as String? ?? 'General';
    final questionType = question['question_type'] as String? ?? 'open_ended';
    final options = question['options'] as List<dynamic>? ?? [];
    
    // Use different layout for open-ended vs multiple choice
    if (questionType == 'open_ended' || options.isEmpty) {
      // Open-ended: Use scrollable layout so keyboard doesn't hide text field
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                category,
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 12,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Question text
            Text(
              questionText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
                height: 1.4,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Open-ended text input
            _buildOpenEndedInput(questionId),
            
            // Extra padding at bottom for keyboard
            const SizedBox(height: 120),
          ],
        ),
      );
    }
    
    // Multiple choice: Use fixed layout with expanded list
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              category,
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 12,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Question text
          Text(
            questionText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
              height: 1.4,
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Multiple choice options
          Expanded(
            child: _buildMultipleChoiceInput(questionId, options),
          ),
        ],
      ),
    );
  }

  Widget _buildMultipleChoiceInput(String questionId, List<dynamic> options) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: ListView.builder(
        itemCount: options.length,
        itemBuilder: (context, index) {
          final option = options[index] as Map<String, dynamic>;
          final optionId = option['id'] as String;
          final optionText = option['text'] as String;
          final currentAnswer = _answers[questionId];
          
          return RadioListTile<String>(
            title: Text(
              optionText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontFamily: 'Poppins',
              ),
            ),
            value: optionId,
            groupValue: currentAnswer,
            activeColor: Colors.amber,
            onChanged: (value) {
              setState(() {
                _answers[questionId] = value!;
              });
              // Do not save while selecting; we'll persist on Next or explicit Save Draft
            },
          );
        },
      ),
    );
  }

  Widget _buildOpenEndedInput(String questionId) {
    return Container(
      constraints: const BoxConstraints(minHeight: 200),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: TextField(
        maxLines: null,
        minLines: 6,
        textDirection: TextDirection.ltr,
        textCapitalization: TextCapitalization.sentences, // Auto-capitalize after periods
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontFamily: 'Poppins',
        ),
        decoration: const InputDecoration(
          hintText: 'Share your thoughts...',
          hintStyle: TextStyle(color: Colors.grey),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16),
        ),
        controller: _getControllerForQuestion(questionId),
        onChanged: (value) {
          setState(() {
            _answers[questionId] = value;
          });
          // Do not save while typing; we'll persist on Next or explicit Save Draft
        },
      ),
    );
  }

  Widget _buildNavigationButtons() {
    final hasAnswers = _answers.values.any((answer) => answer.isNotEmpty);
    
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Save Draft button (only show if there are answers)
          if (hasAnswers)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveDraft,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSaving 
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Save as Draft',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
              ),
            ),
          
          if (hasAnswers) const SizedBox(height: 12),
          
          // Navigation buttons row
          Row(
            children: [
              // Previous button
              if (_currentQuestionIndex > 0)
                Expanded(
                  child: ElevatedButton(
                    onPressed: _previousQuestion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Previous',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              
              if (_currentQuestionIndex > 0) const SizedBox(width: 16),
              
              // Next/Submit button
              Expanded(
                child: ElevatedButton(
                  onPressed: _currentQuestionIndex == _questions.length - 1
                      ? _submitAssessment
                      : _nextQuestion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _currentQuestionIndex == _questions.length - 1 
                        ? Colors.green  // Different color for submit
                        : Colors.amber,
                    foregroundColor: _currentQuestionIndex == _questions.length - 1 
                        ? Colors.white 
                        : Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _currentQuestionIndex == _questions.length - 1 
                        ? 'Submit Final Assessment' 
                        : 'Next',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      // Dismiss keyboard when navigating
      FocusScope.of(context).unfocus();
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      // Dismiss keyboard when navigating
      FocusScope.of(context).unfocus();
      // Persist draft silently on navigation to Next
      _persistDraftSilently();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _persistDraftSilently() async {
    if (_isSaving) return;
    try {
      setState(() {
        _isSaving = true;
      });

      // Prepare payload
      final payload = {
        'answers': _answers,
        'last_question_id': _questions.isNotEmpty ? _questions[_currentQuestionIndex]['id'] : null,
      };

      if (_currentDraft != null && _currentDraft!['id'] != null) {
        await _apiService.updateDraft(payload, draftId: _currentDraft!['id']);
      } else {
        // Create or fetch a draft first
        String? templateId = widget.templateId;
        if (templateId == null) {
          final templates = await _apiService.getPublishedTemplates();
          if (templates.isNotEmpty) {
            templateId = templates.first['id'] as String;
          }
        }
        if (templateId == null) return; // cannot create without template id
        final newDraft = await _apiService.startDraft(templateId);
        await _apiService.updateDraft(payload, draftId: newDraft['id']);
        setState(() {
          _currentDraft = newDraft;
        });
      }
    } catch (e) {
      // Silent failure; avoid disrupting the user while navigating
      // Optionally log: print('Silent draft save failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // Removed auto-save progress; draft persists only on Next or explicit Save Draft

  Future<void> _saveDraft() async {
    if (_answers.isEmpty) {
      _showMessage('Please answer at least one question before saving.', isError: true);
      return;
    }

    try {
      setState(() {
        _isSaving = true;
      });

      // Prepare the payload
      final payload = {
        'answers': _answers,
        'last_question_id': _questions.isNotEmpty ? _questions[_currentQuestionIndex]['id'] : null,
      };

      // If we have an existing draft, update it
      if (_currentDraft != null && _currentDraft!['id'] != null) {
        print('💾 Updating existing draft: ${_currentDraft!['id']}');
        await _apiService.updateDraft(payload, draftId: _currentDraft!['id']);
      } else {
        print('⚠️  No current draft found, creating new one. _currentDraft: $_currentDraft');
        // Prevent multiple simultaneous draft creation
        if (_isCreatingDraft) {
          _showMessage('Already creating draft, please wait...', isError: true);
          return;
        }
        
        setState(() {
          _isCreatingDraft = true;
        });
        
        try {
          // Determine template ID
          String? templateId = widget.templateId;
          
          // If no template ID provided, get the first available template
          if (templateId == null) {
            final templates = await _apiService.getPublishedTemplates();
            if (templates.isNotEmpty) {
              templateId = templates.first['id'] as String;
            }
          }
          
          if (templateId == null) {
            throw Exception('No template ID available for creating draft');
          }

          // Create/get draft using the start endpoint (which handles existing drafts)
          final newDraft = await _apiService.startDraft(templateId);
          print('✅ Draft created/retrieved: ${newDraft['id']}');
          
          // Update the draft with current answers
          await _apiService.updateDraft(payload, draftId: newDraft['id']);
          
          setState(() {
            _currentDraft = newDraft;
          });
        } finally {
          setState(() {
            _isCreatingDraft = false;
          });
        }
      }
      
      if (mounted) {
        _showMessage('Draft saved successfully! You can continue later or return to the dashboard.');
        // Add a small delay to ensure message is shown before navigation
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      }
      
    } catch (e) {
      _showMessage('Failed to save draft: $e', isError: true);
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _submitAssessment() async {
    if (_answers.isEmpty) {
      _showMessage('Please answer at least one question before submitting.', isError: true);
      return;
    }

    final confirmed = await _showConfirmationDialog();
    if (!confirmed) return;

    try {
      setState(() {
        _isSaving = true;
      });

      // First, save the current answers to the draft (only if not already submitted)
      if (_currentDraft != null && _currentDraft!['id'] != null && _currentDraft!['is_submitted'] != true) {
        final payload = {
          'answers': _answers,
          'last_question_id': _questions.isNotEmpty ? _questions[_currentQuestionIndex]['id'] : null,
        };
        try {
          await _apiService.updateDraft(payload, draftId: _currentDraft!['id']);
        } catch (e) {
          // If update fails (e.g., already submitted), continue with submission
          print('Warning: Could not update draft before submission: $e');
        }
      }

      // Then submit the draft using the proper endpoint (target the right draft)
      final submission = await _apiService.submitDraft(
        draftId: _currentDraft?['id']?.toString(),
        templateId: (widget.templateId ?? _currentDraft?['template_id']?.toString()),
      );

      // On success: notify and return to dashboard
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assessment submitted successfully')),
      );
      // Pop back to dashboard after a brief delay; return true so callers can refresh
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        Navigator.pop(context, true);
      }
      
    } catch (e) {
      _showMessage('Failed to submit assessment: $e', isError: true);
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _showSubmittedSnackAndPoll(Map<String, dynamic> submission) {
    final assessmentId = submission['id']?.toString();
    if (assessmentId == null || assessmentId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Submitted. Preparing results...')),
      );
      return;
    }

    // Initial info snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Assessment submitted. Scoring in progress...')),
    );

    // Poll every 10 seconds until done or error
    Future<void>.delayed(const Duration(seconds: 2), () async {
      bool done = false;
      while (!done && mounted) {
        try {
          final status = await _apiService.getAssessmentStatus(assessmentId);
          final s = (status['status'] ?? (status['has_scores'] == true ? 'done' : 'processing')).toString();
          if (s == 'done') {
            done = true;
            // Show snackbar with View Results action
            if (!mounted) break;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Your assessment results are ready.'),
                action: SnackBarAction(
                  label: 'VIEW RESULTS',
                  onPressed: () async {
                    // Fetch full results then navigate
                    try {
                      final full = await _apiService.getAssessmentResults(assessmentId);
                      if (!mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AssessmentResultsScreen(assessment: full),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to open results: $e')),
                      );
                    }
                  },
                ),
                duration: const Duration(seconds: 6),
              ),
            );
            break;
          }
          if (s == 'error') {
            done = true;
            if (!mounted) break;
            _showScoringErrorDialog(assessmentId);
            break;
          }
        } catch (e) {
          // transient backend/network issue; continue polling
        }
        await Future<void>.delayed(const Duration(seconds: 10));
      }
    });
  }

  void _showScoringErrorDialog(String assessmentId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Scoring Delayed',
          style: TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'We hit a snag while scoring your assessment. You can retry shortly. Your draft can be saved to revisit later.',
          style: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.grey, fontFamily: 'Poppins')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Save as draft again to ensure user doesn’t lose work (no-op if already saved)
              try {
                if (_currentDraft != null && _currentDraft!['id'] != null) {
                  final payload = {
                    'answers': _answers,
                    'last_question_id': _questions.isNotEmpty ? _questions[_currentQuestionIndex]['id'] : null,
                  };
                  await _apiService.updateDraft(payload, draftId: _currentDraft!['id']);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Draft saved. You can retry submission later.')),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not save draft: $e')),
                  );
                }
              }
            },
            child: const Text('Save as Draft', style: TextStyle(color: Colors.amber, fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
  }

  Future<bool> _showConfirmationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Submit Final Assessment?',
          style: TextStyle(
            color: Colors.green,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Are you ready to submit your final assessment for review? This will convert your draft into a completed assessment that your mentor can review. You won\'t be able to make changes after submission.',
          style: TextStyle(
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text(
              'Submit Final Assessment',
              style: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
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

}
