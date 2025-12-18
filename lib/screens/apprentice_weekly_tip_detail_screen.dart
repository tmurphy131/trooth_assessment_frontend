import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/apprentice_weekly_tips_data.dart';
import 'package:trooth_assessment/theme.dart';

class ApprenticeWeeklyTipDetailScreen extends StatelessWidget {
  final ApprenticeWeeklyTip tip;

  const ApprenticeWeeklyTipDetailScreen({Key? key, required this.tip}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Week ${tip.weekNumber}'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Week badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: kPrimaryGold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'WEEK ${tip.weekNumber}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kPrimaryGold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                tip.title,
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: kCharcoal,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 24),

              // Content
              Text(
                tip.content,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: kText,
                  height: 1.7,
                ),
              ),
              const SizedBox(height: 32),

              // Scripture card
              if (tip.scripture != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        kPrimaryGold.withOpacity(0.15),
                        kPrimaryGold.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: kPrimaryGold.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.menu_book,
                            color: kPrimaryGold,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Scripture',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: kPrimaryGold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        tip.scripture!,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontStyle: FontStyle.italic,
                          color: kCharcoal,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Action step card
              if (tip.actionStep != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: kCharcoal,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.rocket_launch,
                            color: kPrimaryGold,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Action Step',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: kPrimaryGold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        tip.actionStep!,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          color: Colors.white,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Navigation buttons
              Row(
                children: [
                  if (tip.weekNumber > 1)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final prevTip = getApprenticeTipByWeek(tip.weekNumber - 1);
                          if (prevTip != null) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ApprenticeWeeklyTipDetailScreen(tip: prevTip),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Previous'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kCharcoal,
                          side: BorderSide(color: kCharcoal),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  if (tip.weekNumber > 1 && tip.weekNumber < 52)
                    const SizedBox(width: 12),
                  if (tip.weekNumber < 52)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final nextTip = getApprenticeTipByWeek(tip.weekNumber + 1);
                          if (nextTip != null) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ApprenticeWeeklyTipDetailScreen(tip: nextTip),
                              ),
                            );
                          }
                        },
                        icon: const Text('Next'),
                        label: const Icon(Icons.arrow_forward),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryGold,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
