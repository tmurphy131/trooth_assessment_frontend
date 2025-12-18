import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/apprentice_guides_data.dart';
import 'package:trooth_assessment/theme.dart';

class ApprenticeGuideDetailScreen extends StatelessWidget {
  final ApprenticeGuide guide;

  const ApprenticeGuideDetailScreen({Key? key, required this.guide})
      : super(key: key);

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

  ApprenticeGuideCategory? _getCategoryById(String categoryId) {
    try {
      return apprenticeGuideCategories.firstWhere((c) => c.id == categoryId);
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final category = _getCategoryById(guide.category);

    return Scaffold(
      appBar: AppBar(
        title: Text(guide.title),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    kCharcoal,
                    kCharcoal.withOpacity(0.9),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category badge
                    if (category != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: kPrimaryGold.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getIconForName(category.iconName),
                              size: 14,
                              color: kPrimaryGold,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              category.name,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: kPrimaryGold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),

                    // Title
                    Text(
                      guide.title,
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Summary
                    Text(
                      guide.summary,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Read time
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 16,
                          color: kPrimaryGold,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${guide.readTimeMinutes} min read',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: kPrimaryGold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Content section
            Padding(
              padding: const EdgeInsets.all(20),
              child: MarkdownBody(
                data: guide.content,
                styleSheet: MarkdownStyleSheet(
                  h1: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: kCharcoal,
                    height: 1.4,
                  ),
                  h2: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: kCharcoal,
                    height: 1.4,
                  ),
                  h3: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: kCharcoal,
                    height: 1.4,
                  ),
                  h4: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: kCharcoal,
                    height: 1.4,
                  ),
                  p: GoogleFonts.poppins(
                    fontSize: 15,
                    color: kText,
                    height: 1.7,
                  ),
                  listBullet: GoogleFonts.poppins(
                    fontSize: 15,
                    color: kText,
                  ),
                  blockquote: GoogleFonts.poppins(
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    color: kMutedText,
                    height: 1.6,
                  ),
                  blockquoteDecoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: kPrimaryGold,
                        width: 3,
                      ),
                    ),
                  ),
                  blockquotePadding: const EdgeInsets.only(left: 16),
                  strong: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: kCharcoal,
                  ),
                  em: GoogleFonts.poppins(
                    fontStyle: FontStyle.italic,
                  ),
                  code: GoogleFonts.sourceCodePro(
                    fontSize: 14,
                    backgroundColor: kSurface,
                    color: kCharcoal,
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: kSurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  codeblockPadding: const EdgeInsets.all(16),
                  horizontalRuleDecoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: kMutedText.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                  ),
                  listIndent: 20,
                ),
                selectable: true,
              ),
            ),

            // Footer with related guides
            _buildRelatedGuidesSection(context),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildRelatedGuidesSection(BuildContext context) {
    final relatedGuides = getApprenticeGuidesByCategory(guide.category)
        .where((g) => g.id != guide.id)
        .take(3)
        .toList();

    if (relatedGuides.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kSurface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Related Guides',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kCharcoal,
            ),
          ),
          const SizedBox(height: 12),
          ...relatedGuides.map((relatedGuide) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ApprenticeGuideDetailScreen(guide: relatedGuide),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: kMutedText.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: kPrimaryGold.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getIconForName(relatedGuide.iconName ?? 'article'),
                            color: kPrimaryGold,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                relatedGuide.title,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: kCharcoal,
                                ),
                              ),
                              Text(
                                '${relatedGuide.readTimeMinutes} min read',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: kMutedText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: kMutedText,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
