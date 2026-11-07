import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/study_provider.dart';

class ProgressHeatmapScreen extends StatelessWidget {
  const ProgressHeatmapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StudyProvider>();
    final profile = provider.userProfile;

    return Scaffold(
      backgroundColor: const Color(0xFF08150F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF102A20),
        elevation: 0,
        title: const Text('📊 Progress & Analytics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        actions: [
          // Demo Data Quick Actions
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
            color: const Color(0xFF102A20),
            onSelected: (value) {
              if (value == 'load_demo') {
                provider.loadDemoData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🧪 Loaded 60-Day Demo Data (Heatmap, Streaks, Trees, Badges)!'),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              } else if (value == 'reset') {
                _confirmReset(context, provider);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'load_demo',
                child: Row(
                  children: [
                    Icon(Icons.science_rounded, color: Color(0xFF10B981), size: 18),
                    SizedBox(width: 8),
                    Text('Load Demo Data', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.refresh_rounded, color: Color(0xFFEF4444), size: 18),
                    SizedBox(width: 8),
                    Text('Reset to Fresh State', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Streak & Streak Shield Feature Banner
            _buildStreakAndShieldCard(context, provider),
            const SizedBox(height: 20),

            // Feature 4: Consistency Heatmap (13 weeks / 91 days)
            _buildHeatmapCard(context, provider),
            const SizedBox(height: 20),

            // Feature 2: Coach Insight Card
            _buildCoachInsightCard(provider),
            const SizedBox(height: 20),

            // Feature 6: XP, Levels and Badges
            _buildBadgesCard(profile),
            const SizedBox(height: 24),

            // Feature 9: Demo Data Controls Banner
            _buildDemoControlsBanner(context, provider),
          ],
        ),
      ),
    );
  }

  // FEATURE 5: Streak & Shield Card
  Widget _buildStreakAndShieldCard(BuildContext context, StudyProvider provider) {
    final profile = provider.userProfile;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF102A20), Color(0xFF08150F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('🔥 ', style: TextStyle(fontSize: 28)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${profile.currentStreak} Day Streak',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Longest: ${profile.longestStreak} days',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              // Streak Shields Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Text('🛡️ ', style: TextStyle(fontSize: 16)),
                    Text(
                      '${profile.streakShields} Shields',
                      style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF08150F),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFF38BDF8), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Earn 1 Shield every 7 consecutive days. Shields auto-protect your streak if you miss a study day.',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // FEATURE 4: Consistency Heatmap (91 Days / 13 Weeks)
  Widget _buildHeatmapCard(BuildContext context, StudyProvider provider) {
    final now = DateTime.now();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF102A20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🗓️ Consistency Heatmap', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('Last 13 weeks (91 days) activity', style: TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
              // Legend
              Row(
                children: [
                  _legendSquare(const Color(0xFF334155)),
                  const SizedBox(width: 3),
                  _legendSquare(const Color(0xFF064E3B)),
                  const SizedBox(width: 3),
                  _legendSquare(const Color(0xFF047857)),
                  const SizedBox(width: 3),
                  _legendSquare(const Color(0xFF10B981)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 13 columns (weeks), 7 rows (days per week)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(13, (weekIndex) {
                return Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: Column(
                    children: List.generate(7, (dayIndex) {
                      // Calculate date for this square: 91 days backwards
                      final daysAgo = ((12 - weekIndex) * 7) + (6 - dayIndex);
                      final targetDate = now.subtract(Duration(days: daysAgo));
                      final minutes = provider.getMinutesForDate(targetDate);
                      final color = _getHeatmapColor(minutes);

                      return Tooltip(
                        message: '${targetDate.month}/${targetDate.day}: $minutes mins',
                        child: Container(
                          width: 14,
                          height: 14,
                          margin: const EdgeInsets.only(bottom: 5),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      );
                    }),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Color _getHeatmapColor(int minutes) {
    if (minutes == 0) return const Color(0xFF334155); // grey
    if (minutes <= 30) return const Color(0xFF064E3B); // light
    if (minutes <= 60) return const Color(0xFF047857); // medium
    return const Color(0xFF10B981); // dark emerald
  }

  Widget _legendSquare(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
    );
  }

  // FEATURE 2: Coach Insight Card
  Widget _buildCoachInsightCard(StudyProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF102A20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('📊 ', style: TextStyle(fontSize: 18)),
              Text('Coach Insight', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              Spacer(),
              Text('AI Pattern Analysis', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            provider.lastAiInsight ??
                "You complete 85% of your goals during weekdays. Maintain this pace to easily crush your upcoming exams!",
            style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  // FEATURE 6: Badges & Gamification Showcase
  Widget _buildBadgesCard(dynamic profile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF102A20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('🎮 Badges & Milestones', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              Text('Level ${profile.level}', style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: profile.badges.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.2,
            ),
            itemBuilder: (ctx, i) {
              final b = profile.badges[i];
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: b.isUnlocked ? const Color(0xFF08150F) : const Color(0xFF102A20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: b.isUnlocked ? const Color(0xFF10B981).withValues(alpha: 0.4) : Colors.white10,
                  ),
                ),
                child: Row(
                  children: [
                    Text(b.icon, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            b.title,
                            style: TextStyle(
                              color: b.isUnlocked ? Colors.white : Colors.white38,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            b.description,
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 9),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // FEATURE 9: Demo Data Controls
  Widget _buildDemoControlsBanner(BuildContext context, StudyProvider provider) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF08150F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🧪 ', style: TextStyle(fontSize: 18)),
              Text('Project Demo Controls', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Instantly populate 60 days of historical data, heatmap records, virtual trees, coding milestones and slip patterns for demonstrations.',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    provider.loadDemoData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ 60-Day Demo Data Loaded!'), backgroundColor: Color(0xFF10B981)),
                    );
                  },
                  icon: const Icon(Icons.bolt_rounded, size: 16),
                  label: const Text('Load Demo Data', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () => _confirmReset(context, provider),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Reset', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFEF4444), side: const BorderSide(color: Color(0xFFEF4444))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context, StudyProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF102A20),
        title: const Text('Reset All Data?', style: TextStyle(color: Colors.white)),
        content: const Text('This will clear all demo records, heatmaps, and forest trees back to zero.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel', style: TextStyle(color: Colors.white60))),
          ElevatedButton(
            onPressed: () {
              provider.resetAllData();
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🧹 Cleared all data to fresh state.')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
