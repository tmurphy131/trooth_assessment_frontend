import 'package:flutter/material.dart';
import '../data/weekly_tips_data.dart';
import 'package:trooth_assessment/theme.dart';

class WeeklyTipDetailScreen extends StatelessWidget {
  final WeeklyTip tip;

  const WeeklyTipDetailScreen({super.key, required this.tip});

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
                  color: kPrimaryGold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'WEEK ${tip.weekNumber}',
                  style: TextStyle(fontFamily: 'Poppins', 
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
                style: TextStyle(fontFamily: 'Poppins', 
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
                style: TextStyle(fontFamily: 'Poppins', 
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
                        kPrimaryGold.withValues(alpha: 0.15),
                        kPrimaryGold.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: kPrimaryGold.withValues(alpha: 0.3),
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
                            style: TextStyle(fontFamily: 'Poppins', 
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
                        style: TextStyle(fontFamily: 'Poppins', 
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
                            style: TextStyle(fontFamily: 'Poppins', 
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
                        style: TextStyle(fontFamily: 'Poppins', 
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
                          final prevTip = getTipByWeek(tip.weekNumber - 1);
                          if (prevTip != null) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    WeeklyTipDetailScreen(tip: prevTip),
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
                  // Only show Next button if next week's tip is available (not in future)
                  if (tip.weekNumber > 1 && isTipAvailable(tip.weekNumber + 1))
                    const SizedBox(width: 12),
                  if (isTipAvailable(tip.weekNumber + 1))
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final nextTip = getTipByWeek(tip.weekNumber + 1);
                          if (nextTip != null) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    WeeklyTipDetailScreen(tip: nextTip),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Next Week'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
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
