import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/mentor_guides_data.dart';
import 'package:trooth_assessment/theme.dart';
import 'mentor_guide_detail_screen.dart';

class MentorGuidesListScreen extends StatefulWidget {
  final String? initialCategoryId;

  const MentorGuidesListScreen({Key? key, this.initialCategoryId})
      : super(key: key);

  @override
  State<MentorGuidesListScreen> createState() => _MentorGuidesListScreenState();
}

class _MentorGuidesListScreenState extends State<MentorGuidesListScreen> {
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.initialCategoryId;
  }

  IconData _getIconForName(String iconName) {
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
      case 'handshake':
        return Icons.handshake_outlined;
      case 'school':
        return Icons.school_outlined;
      case 'flag':
        return Icons.flag_outlined;
      case 'hearing':
        return Icons.hearing;
      case 'help_outline':
        return Icons.help_outline;
      case 'rate_review':
        return Icons.rate_review_outlined;
      case 'volunteer_activism':
        return Icons.volunteer_activism;
      case 'menu_book':
        return Icons.menu_book_outlined;
      case 'card_giftcard':
        return Icons.card_giftcard;
      case 'pause_circle':
        return Icons.pause_circle_outline;
      case 'forum':
        return Icons.forum_outlined;
      case 'emergency':
        return Icons.emergency_outlined;
      case 'event_note':
        return Icons.event_note_outlined;
      case 'front_hand':
        return Icons.front_hand;
      case 'local_library':
        return Icons.local_library_outlined;
      default:
        return Icons.article_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mentor Guides'),
        centerTitle: true,
      ),
      body: _selectedCategoryId == null
          ? _buildCategoryList()
          : _buildGuideList(_selectedCategoryId!),
    );
  }

  Widget _buildCategoryList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: guideCategories.length,
      itemBuilder: (context, index) {
        final category = guideCategories[index];
        final guideCount = getGuidesByCategory(category.id).length;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedCategoryId = category.id;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: kPrimaryGold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getIconForName(category.iconName),
                      color: kPrimaryGold,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.name,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: kCharcoal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          category.description,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: kMutedText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$guideCount guides',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: kPrimaryGold,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: kMutedText,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGuideList(String categoryId) {
    final category = getCategoryById(categoryId);
    final guides = getGuidesByCategory(categoryId);

    return Column(
      children: [
        // Back to categories header
        Container(
          color: kSurface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    _selectedCategoryId = null;
                  });
                },
                child: Row(
                  children: [
                    Icon(Icons.arrow_back_ios, size: 16, color: kPrimaryGold),
                    const SizedBox(width: 4),
                    Text(
                      'All Categories',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: kPrimaryGold,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (category != null)
                Row(
                  children: [
                    Icon(
                      _getIconForName(category.iconName),
                      size: 18,
                      color: kCharcoal,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      category.name,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: kCharcoal,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),

        // Guide list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: guides.length,
            itemBuilder: (context, index) {
              final guide = guides[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MentorGuideDetailScreen(guide: guide),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: kCharcoal,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _getIconForName(guide.iconName ?? 'article'),
                            color: kPrimaryGold,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                guide.title,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: kCharcoal,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                guide.summary,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: kMutedText,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.schedule,
                                    size: 14,
                                    color: kMutedText,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${guide.readTimeMinutes} min read',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: kMutedText,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: kMutedText,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
