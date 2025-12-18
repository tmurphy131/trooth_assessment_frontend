import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/apprentice_guides_data.dart';
import 'package:trooth_assessment/theme.dart';
import 'apprentice_guide_detail_screen.dart';

class ApprenticeGuidesListScreen extends StatefulWidget {
  final String? initialCategoryId;

  const ApprenticeGuidesListScreen({Key? key, this.initialCategoryId})
      : super(key: key);

  @override
  State<ApprenticeGuidesListScreen> createState() => _ApprenticeGuidesListScreenState();
}

class _ApprenticeGuidesListScreenState extends State<ApprenticeGuidesListScreen> {
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
      case 'auto_awesome':
        return Icons.auto_awesome;
      case 'person_search':
        return Icons.person_search;
      case 'people':
        return Icons.people_outline;
      case 'favorite':
        return Icons.favorite_outline;
      case 'trending_up':
        return Icons.trending_up;
      case 'lightbulb':
        return Icons.lightbulb_outline;
      case 'emoji_events':
        return Icons.emoji_events_outlined;
      case 'explore':
        return Icons.explore_outlined;
      case 'sports':
        return Icons.sports;
      case 'event_available':
        return Icons.event_available;
      case 'help_outline':
        return Icons.help_outline;
      case 'self_improvement':
        return Icons.self_improvement;
      case 'psychology':
        return Icons.psychology;
      case 'church':
        return Icons.church;
      case 'volunteer_activism':
        return Icons.volunteer_activism;
      case 'group':
        return Icons.group;
      case 'family_restroom':
        return Icons.family_restroom;
      case 'health_and_safety':
        return Icons.health_and_safety;
      case 'mood':
        return Icons.mood;
      case 'support':
        return Icons.support;
      case 'school':
        return Icons.school;
      case 'account_balance_wallet':
        return Icons.account_balance_wallet;
      case 'schedule':
        return Icons.schedule;
      case 'share':
        return Icons.share;
      case 'campaign':
        return Icons.campaign;
      default:
        return Icons.article_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Growth Guides'),
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
      itemCount: apprenticeGuideCategories.length,
      itemBuilder: (context, index) {
        final category = apprenticeGuideCategories[index];
        final guideCount = getApprenticeGuidesByCategory(category.id).length;

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
                          guideCount > 0 ? '$guideCount guides' : 'Coming soon',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: guideCount > 0 ? kPrimaryGold : kMutedText,
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
    final category = apprenticeGuideCategories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => apprenticeGuideCategories.first,
    );
    final guides = getApprenticeGuidesByCategory(categoryId);

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
          child: guides.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.upcoming_outlined,
                        size: 64,
                        color: kMutedText.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Coming Soon',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: kMutedText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Guides for this category are being written.',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: kMutedText,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
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
                              builder: (_) => ApprenticeGuideDetailScreen(guide: guide),
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
