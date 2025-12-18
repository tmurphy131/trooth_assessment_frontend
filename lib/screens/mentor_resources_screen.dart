import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/weekly_tips_data.dart';
import '../data/mentor_guides_data.dart';
import '../services/api_service.dart';
import 'package:trooth_assessment/theme.dart';
import 'weekly_tip_detail_screen.dart';
import 'mentor_guides_list_screen.dart';

class MentorResourcesScreen extends StatefulWidget {
  const MentorResourcesScreen({super.key});

  @override
  State<MentorResourcesScreen> createState() => _MentorResourcesScreenState();
}

class _MentorResourcesScreenState extends State<MentorResourcesScreen> {
  final _api = ApiService();
  bool _loadingResources = true;
  String? _resourcesError;
  List<Map<String, dynamic>> _apprentices = [];
  List<Map<String, dynamic>> _resources = [];
  String? _filterApprenticeId;

  @override
  void initState() {
    super.initState();
    _loadResources();
  }

  Future<void> _loadResources() async {
    setState(() {
      _loadingResources = true;
      _resourcesError = null;
    });
    try {
      final apprentices = await _api.listApprentices();
      final resources = await _api.listMentorResources();
      setState(() {
        _apprentices = apprentices.cast<Map<String, dynamic>>();
        _resources = resources.cast<Map<String, dynamic>>();
        _loadingResources = false;
      });
    } catch (e) {
      setState(() {
        _resourcesError = 'Failed to load: $e';
        _loadingResources = false;
      });
    }
  }

  Future<void> _applyFilter(String? apprenticeId) async {
    setState(() {
      _filterApprenticeId = apprenticeId;
      _loadingResources = true;
      _resourcesError = null;
    });
    try {
      final resources =
          await _api.listMentorResources(apprenticeId: apprenticeId);
      setState(() {
        _resources = resources.cast<Map<String, dynamic>>();
        _loadingResources = false;
      });
    } catch (e) {
      setState(() {
        _resourcesError = 'Failed to load resources: $e';
        _loadingResources = false;
      });
    }
  }

  Future<void> _openLink(String? url) async {
    if (url == null || url.trim().isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _createOrEditResource({Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;
    final titleCtrl = TextEditingController(text: existing?['title'] ?? '');
    final descCtrl =
        TextEditingController(text: existing?['description'] ?? '');
    final linkCtrl = TextEditingController(text: existing?['link_url'] ?? '');
    String? apprenticeId = existing?['apprentice_id'] as String?;
    bool isShared = (existing?['is_shared'] ?? true) == true;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool saving = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              isEdit ? 'Edit Resource' : 'New Resource',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: kCharcoal,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleCtrl,
                    style: GoogleFonts.poppins(),
                    decoration: InputDecoration(
                      labelText: 'Title',
                      labelStyle: TextStyle(color: kMutedText),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: kMutedText),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: kPrimaryGold, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    style: GoogleFonts.poppins(),
                    decoration: InputDecoration(
                      labelText: 'Description (optional)',
                      labelStyle: TextStyle(color: kMutedText),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: kMutedText),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: kPrimaryGold, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: linkCtrl,
                    style: GoogleFonts.poppins(),
                    decoration: InputDecoration(
                      labelText: 'Link URL (https://...)',
                      labelStyle: TextStyle(color: kMutedText),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: kMutedText),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: kPrimaryGold, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: apprenticeId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Apprentice (optional)',
                      labelStyle: TextStyle(color: kMutedText),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: kMutedText),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: kPrimaryGold, width: 2),
                      ),
                    ),
                    items: [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Text('— None —',
                            style: GoogleFonts.poppins(color: kMutedText)),
                      ),
                      DropdownMenuItem<String>(
                        value: '__ALL__',
                        child: Text('All Apprentices',
                            style: GoogleFonts.poppins()),
                      ),
                      ..._apprentices.map((a) => DropdownMenuItem<String>(
                            value: a['id'] as String,
                            child: Text(a['name'] ?? a['email'] ?? 'Unnamed',
                                style: GoogleFonts.poppins()),
                          )),
                    ],
                    onChanged: (v) => setDialogState(() {
                      apprenticeId = v;
                    }),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('Share with apprentice',
                          style: GoogleFonts.poppins()),
                      const Spacer(),
                      Switch(
                        value: isShared,
                        activeColor: kPrimaryGold,
                        onChanged: (v) => setDialogState(() {
                          isShared = v;
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.of(ctx).pop(),
                child: Text('Cancel',
                    style: GoogleFonts.poppins(color: kMutedText)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryGold,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: saving
                    ? null
                    : () async {
                        final title = titleCtrl.text.trim();
                        if (title.isEmpty) return;
                        setDialogState(() {
                          saving = true;
                        });
                        try {
                          if (isEdit) {
                            await _api.updateMentorResource(
                              resourceId: existing['id'],
                              apprenticeId:
                                  (apprenticeId == null || apprenticeId!.isEmpty)
                                      ? null
                                      : apprenticeId,
                              title: title,
                              description: descCtrl.text.trim().isEmpty
                                  ? null
                                  : descCtrl.text.trim(),
                              linkUrl: linkCtrl.text.trim().isEmpty
                                  ? null
                                  : linkCtrl.text.trim(),
                              isShared: isShared,
                            );
                          } else {
                            await _api.createMentorResource(
                              apprenticeId:
                                  (apprenticeId == null || apprenticeId!.isEmpty)
                                      ? null
                                      : apprenticeId,
                              title: title,
                              description: descCtrl.text.trim().isEmpty
                                  ? null
                                  : descCtrl.text.trim(),
                              linkUrl: linkCtrl.text.trim().isEmpty
                                  ? null
                                  : linkCtrl.text.trim(),
                              isShared: isShared,
                            );
                          }
                          if (!mounted) return;
                          Navigator.of(ctx).pop();
                          await _applyFilter(_filterApprenticeId);
                        } catch (e) {
                          setDialogState(() {
                            saving = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to save: $e')));
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black))
                    : Text(isEdit ? 'Save' : 'Create'),
              )
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleShare(Map<String, dynamic> r) async {
    try {
      await _api.updateMentorResource(
          resourceId: r['id'], isShared: !(r['is_shared'] == true));
      await _applyFilter(_filterApprenticeId);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to update: $e')));
    }
  }

  Future<void> _deleteResource(Map<String, dynamic> r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Resource',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "${r['title']}"?',
            style: GoogleFonts.poppins()),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child:
                  Text('Cancel', style: GoogleFonts.poppins(color: kMutedText))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          )
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.deleteMentorResource(r['id']);
      await _applyFilter(_filterApprenticeId);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTip = getCurrentWeekTip();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mentor Resources'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        color: kPrimaryGold,
        onRefresh: _loadResources,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section 1: Weekly Tip
                _buildSectionHeader(
                  title: 'Weekly Tip',
                  subtitle: 'Week ${currentTip.weekNumber} of 52',
                  icon: Icons.lightbulb_outline,
                ),
                const SizedBox(height: 12),
                _buildWeeklyTipCard(currentTip),
                const SizedBox(height: 32),

                // Section 2: Mentor Guides
                _buildSectionHeader(
                  title: 'Mentor Guides',
                  subtitle: '${mentorGuides.length} guides available',
                  icon: Icons.menu_book_outlined,
                  actionLabel: 'View All',
                  onAction: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MentorGuidesListScreen()),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildGuideCategoriesRow(),
                const SizedBox(height: 32),

                // Section 3: My Shared Resources
                _buildSectionHeader(
                  title: 'My Shared Resources',
                  subtitle: _loadingResources
                      ? 'Loading...'
                      : '${_resources.length} resources',
                  icon: Icons.folder_shared_outlined,
                  actionLabel: 'Add New',
                  onAction: () => _createOrEditResource(),
                ),
                const SizedBox(height: 12),
                _buildSharedResourcesSection(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: kPrimaryGold.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: kPrimaryGold, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: kCharcoal,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: kMutedText,
                ),
              ),
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            child: Text(
              actionLabel,
              style: GoogleFonts.poppins(
                color: kPrimaryGold,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWeeklyTipCard(WeeklyTip tip) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WeeklyTipDetailScreen(tip: tip),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                kCharcoal,
                kCharcoal.withOpacity(0.9),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: kPrimaryGold.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'WEEK ${tip.weekNumber}',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: kPrimaryGold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.lightbulb,
                    color: kPrimaryGold,
                    size: 24,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                tip.title,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tip.content.split('\n\n').first,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white70,
                  height: 1.5,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Read more',
                    style: GoogleFonts.poppins(
                      color: kPrimaryGold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward, color: kPrimaryGold, size: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuideCategoriesRow() {
    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: guideCategories.length,
        itemBuilder: (context, index) {
          final category = guideCategories[index];
          final guideCount = getGuidesByCategory(category.id).length;

          return Padding(
            padding: EdgeInsets.only(
              right: 12,
              left: index == 0 ? 0 : 0,
            ),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        MentorGuidesListScreen(initialCategoryId: category.id),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 140,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: kMutedText.withOpacity(0.15),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _getIconForCategory(category.iconName),
                      color: kPrimaryGold,
                      size: 28,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      category.name,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: kCharcoal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$guideCount guides',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: kMutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _getIconForCategory(String iconName) {
    switch (iconName) {
      case 'rocket_launch':
        return Icons.rocket_launch;
      case 'chat_bubble':
        return Icons.chat_bubble_outline;
      case 'self_improvement':
        return Icons.self_improvement;
      case 'psychology':
        return Icons.psychology;
      case 'build':
        return Icons.build_outlined;
      default:
        return Icons.article_outlined;
    }
  }

  Widget _buildSharedResourcesSection() {
    if (_loadingResources) {
      return Container(
        height: 150,
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: CircularProgressIndicator(color: kPrimaryGold),
        ),
      );
    }

    if (_resourcesError != null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
            const SizedBox(height: 8),
            Text(
              _resourcesError!,
              style: GoogleFonts.poppins(color: kMutedText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadResources,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Filter dropdown
        Container(
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonFormField<String>(
            value: _filterApprenticeId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Filter by apprentice',
              labelStyle: GoogleFonts.poppins(color: kMutedText, fontSize: 14),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            items: [
              DropdownMenuItem<String>(
                value: null,
                child: Text('All apprentices', style: GoogleFonts.poppins()),
              ),
              ..._apprentices.map((a) => DropdownMenuItem<String>(
                    value: a['id'] as String,
                    child: Text(a['name'] ?? a['email'] ?? 'Unnamed',
                        style: GoogleFonts.poppins()),
                  )),
            ],
            onChanged: (v) => _applyFilter(v),
          ),
        ),
        const SizedBox(height: 12),

        // Resources list
        if (_resources.isEmpty)
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(Icons.folder_open, color: kMutedText, size: 48),
                const SizedBox(height: 12),
                Text(
                  'No resources yet',
                  style: GoogleFonts.poppins(
                    color: kMutedText,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap "Add New" to create your first resource',
                  style: GoogleFonts.poppins(
                    color: kMutedText,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _resources.length,
            itemBuilder: (context, index) {
              final r = _resources[index];
              return _buildResourceCard(r);
            },
          ),
      ],
    );
  }

  Widget _buildResourceCard(Map<String, dynamic> r) {
    final title = (r['title'] ?? '').toString();
    final desc = (r['description'] ?? '').toString();
    final url = (r['link_url'] ?? '').toString();
    final shared = r['is_shared'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: url.isNotEmpty ? () => _openLink(url) : null,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: shared
                      ? Colors.green.withOpacity(0.15)
                      : kPrimaryGold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  shared ? Icons.public : Icons.lock_outline,
                  color: shared ? Colors.green : kPrimaryGold,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: kCharcoal,
                      ),
                    ),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        desc,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: kMutedText,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (url.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        url,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: kPrimaryGold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: kMutedText),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onSelected: (v) {
                  if (v == 'edit') {
                    _createOrEditResource(existing: r);
                  } else if (v == 'toggle') {
                    _toggleShare(r);
                  } else if (v == 'delete') {
                    _deleteResource(r);
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20, color: kCharcoal),
                        const SizedBox(width: 8),
                        Text('Edit', style: GoogleFonts.poppins()),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(
                      children: [
                        Icon(
                          shared ? Icons.lock : Icons.public,
                          size: 20,
                          color: kCharcoal,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          shared ? 'Make Private' : 'Share',
                          style: GoogleFonts.poppins(),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete, size: 20, color: Colors.redAccent),
                        const SizedBox(width: 8),
                        Text('Delete',
                            style: GoogleFonts.poppins(color: Colors.redAccent)),
                      ],
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
}
