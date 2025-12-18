import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/apprentice_weekly_tips_data.dart';
import '../data/apprentice_guides_data.dart';
import 'package:trooth_assessment/theme.dart';
import 'apprentice_weekly_tip_detail_screen.dart';
import 'apprentice_guides_list_screen.dart';

class ApprenticeResourcesScreen extends StatefulWidget {
  const ApprenticeResourcesScreen({super.key});

  @override
  State<ApprenticeResourcesScreen> createState() => _ApprenticeResourcesScreenState();
}

class _ApprenticeResourcesScreenState extends State<ApprenticeResourcesScreen> {
  @override
  Widget build(BuildContext context) {
    final currentTip = getApprenticeCurrentWeekTip();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resources'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        color: kPrimaryGold,
        onRefresh: () async {
          setState(() {});
        },
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

                // Section 2: Guides
                _buildSectionHeader(
                  title: 'Growth Guides',
                  subtitle: '${apprenticeGuides.length} guides available',
                  icon: Icons.menu_book_outlined,
                  actionLabel: 'View All',
                  onAction: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ApprenticeGuidesListScreen()),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildGuideCategoriesRow(),
                const SizedBox(height: 32),

                // Section 3: Quick Links
                _buildSectionHeader(
                  title: 'Quick Links',
                  subtitle: 'Helpful resources',
                  icon: Icons.link,
                ),
                const SizedBox(height: 12),
                _buildQuickLinksSection(),
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

  Widget _buildWeeklyTipCard(ApprenticeWeeklyTip tip) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ApprenticeWeeklyTipDetailScreen(tip: tip),
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
        itemCount: apprenticeGuideCategories.length,
        itemBuilder: (context, index) {
          final category = apprenticeGuideCategories[index];
          final guideCount = getApprenticeGuidesByCategory(category.id).length;

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
                        ApprenticeGuidesListScreen(initialCategoryId: category.id),
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
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: kPrimaryGold.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getIconForName(category.iconName),
                        color: kPrimaryGold,
                        size: 20,
                      ),
                    ),
                    const Spacer(),
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

  Widget _buildQuickLinksSection() {
    final links = [
      {
        'title': 'Bible App',
        'subtitle': 'Read Scripture daily',
        'icon': Icons.menu_book,
        'color': Colors.teal,
      },
      {
        'title': 'Prayer Journal',
        'subtitle': 'Track your prayers',
        'icon': Icons.edit_note,
        'color': Colors.purple,
      },
      {
        'title': 'Worship Music',
        'subtitle': 'Connect with God',
        'icon': Icons.music_note,
        'color': Colors.blue,
      },
    ];

    return Column(
      children: links.map((link) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (link['color'] as Color).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  link['icon'] as IconData,
                  color: link['color'] as Color,
                  size: 24,
                ),
              ),
              title: Text(
                link['title'] as String,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: kCharcoal,
                ),
              ),
              subtitle: Text(
                link['subtitle'] as String,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: kMutedText,
                ),
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: kMutedText,
              ),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${link['title']} - Coming soon!'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
          ),
        );
      }).toList(),
    );
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
      default:
        return Icons.article_outlined;
    }
  }
}
