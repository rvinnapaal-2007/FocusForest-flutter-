import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/study_provider.dart';
import '../models/study_goal.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/sync_radar_badge.dart';
import '../widgets/account_menu.dart';
import '../widgets/forest_painters.dart';
import '../widgets/brand_logo.dart';

class HomeDashboardScreen extends StatelessWidget {
  final Function(int) onTabChange;

  const HomeDashboardScreen({super.key, required this.onTabChange});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StudyProvider>();
    final profile = provider.userProfile;
    final hasSlipWarning = provider.hasSlipWarningForTomorrow();

    return Scaffold(
      backgroundColor: const Color(0xFF08150F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF102A20),
        elevation: 0,
        title: const Align(
          alignment: Alignment.centerLeft,
          child: FocusForestLogo(height: 34, radius: 10),
        ),
        actions: const [
          SyncRadarBadge(),
          SizedBox(width: 10),
          AccountMenuButton(),
          SizedBox(width: 14),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Forest hero with greeting
            _buildForestHero(provider, onTabChange),
            const SizedBox(height: 16),

            if (provider.cloudError != null) ...[
              _buildCloudErrorBanner(provider),
              const SizedBox(height: 16),
            ],

            // User XP & Level Header Bar
            _buildXpLevelCard(profile),
            const SizedBox(height: 16),

            // Feature 7: "Likely to Slip Tomorrow" Alert Banner
            if (hasSlipWarning) ...[
              _buildSlipWarningBanner(provider),
              const SizedBox(height: 16),
            ],

            // Feature 2: Coach Insight Card
            _buildCoachInsightCard(provider),
            const SizedBox(height: 20),

            // Quick Navigation Hub
            _buildQuickNavHub(onTabChange),
            const SizedBox(height: 22),

            // Feature 1 & 3: Today's Goals & Focus Launchers
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Today's Study Goals",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                TextButton.icon(
                  onPressed: () => onTabChange(1), // switch to AI Coach
                  icon: const Icon(Icons.auto_awesome, size: 16, color: Color(0xFF10B981)),
                  label: const Text('AI Planner', style: TextStyle(color: Color(0xFF10B981), fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (provider.goals.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: Column(
                    children: [
                      const Text('📝', style: TextStyle(fontSize: 36)),
                      const SizedBox(height: 8),
                      const Text('No study goals generated yet.', style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => onTabChange(1),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                        child: const Text('Generate with Groq AI', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...provider.goals.map((goal) => _buildGoalCard(context, provider, goal, onTabChange)),
          ],
        ),
      ),
    );
  }

  Widget _buildForestHero(StudyProvider provider, Function(int) onTabChange) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');
    final thriving = provider.forestTrees.where((t) => !t.isWithered).length;
    return ForestGardenScene(
      trees: provider.forestTrees,
      height: 190,
      overlay: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$greeting, ${provider.displayName}',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, shadows: [Shadow(color: Colors.black87, blurRadius: 8)])),
                  const SizedBox(height: 2),
                  Text('$thriving trees in your forest',
                      style: const TextStyle(color: Color(0xFFA7F3D0), fontSize: 13, shadows: [Shadow(color: Colors.black87, blurRadius: 6)])),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => onTabChange(2),
              icon: const Icon(Icons.eco_rounded, size: 16),
              label: const Text('Plant', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCloudErrorBanner(StudyProvider provider) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF7F1D1D).withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cloud_off_rounded, color: Color(0xFFFCA5A5), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(provider.cloudError ?? '', style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.35)),
          ),
          TextButton(onPressed: provider.syncNow, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildXpLevelCard(dynamic profile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF102A20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Level ${profile.level}',
                      style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${profile.xp} Total XP',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              Row(
                children: [
                  Text('🔥 ${profile.currentStreak}d', style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 10),
                  Text('🛡️ ${profile.streakShields}', style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // XP Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (profile.currentLevelProgress / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: const Color(0xFF08150F),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${profile.currentLevelProgress} / 100 XP to Level ${profile.level + 1}', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
              const Text('+20 XP per goal', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSlipWarningBanner(StudyProvider provider) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF78350F).withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Likely to Slip Tomorrow Alert',
                  style: TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  provider.getSlipWarningMessage(),
                  style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoachInsightCard(StudyProvider provider) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF102A20),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.insights_rounded, color: Color(0xFF10B981), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              provider.lastAiInsight ?? "Complete your goals today to earn XP and expand your Focus Forest!",
              style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickNavHub(Function(int) onTabChange) {
    return Row(
      children: [
        _quickActionTile('Focus Forest', '🌲', const Color(0xFF10B981), () => onTabChange(2)),
        const SizedBox(width: 10),
        _quickActionTile('AI Explainer', '💡', const Color(0xFF38BDF8), () => onTabChange(1)),
        const SizedBox(width: 10),
        _quickActionTile('Coders Hub', '💻', const Color(0xFFF59E0B), () => onTabChange(3)),
        const SizedBox(width: 10),
        _quickActionTile('91d Heatmap', '🗓️', const Color(0xFF8B5CF6), () => onTabChange(4)),
      ],
    );
  }

  Widget _quickActionTile(String title, String emoji, Color accent, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF102A20),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 4),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  String? _platformUrl(String platform) {
    switch (platform) {
      case 'LeetCode':
        return 'https://leetcode.com/problemset/';
      case 'HackerRank':
        return 'https://www.hackerrank.com/dashboard';
      case 'CodeChef':
        return 'https://www.codechef.com/practice';
      default:
        return null;
    }
  }

  Widget _buildGoalCard(BuildContext context, StudyProvider provider, StudyGoal goal, Function(int) onTabChange) {
    Color platformColor = const Color(0xFF38BDF8);
    if (goal.platform == 'LeetCode') platformColor = const Color(0xFFF59E0B);
    if (goal.platform == 'HackerRank') platformColor = const Color(0xFF10B981);
    if (goal.platform == 'CodeChef') platformColor = const Color(0xFF8B5CF6);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF102A20),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: goal.isCompleted ? const Color(0xFF10B981).withValues(alpha: 0.3) : Colors.white10,
        ),
      ),
      child: Row(
        children: [
          // Checkbox toggle
          InkWell(
            onTap: () => provider.toggleGoalCompletion(goal),
            child: Icon(
              goal.isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: goal.isCompleted ? const Color(0xFF10B981) : Colors.white38,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),

          // Goal Title & Subject
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: platformColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        goal.platform,
                        style: TextStyle(color: platformColor, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${goal.targetMinutes} min target',
                      style: const TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  goal.title,
                  style: TextStyle(
                    color: goal.isCompleted ? Colors.white54 : Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    decoration: goal.isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(
                  goal.subject,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                ),
              ],
            ),
          ),
          if (_platformUrl(goal.platform) != null) ...[
            IconButton(
              tooltip: 'Open ${goal.platform}',
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.open_in_new_rounded, size: 18, color: platformColor),
              onPressed: () => launchUrl(Uri.parse(_platformUrl(goal.platform)!),
                  mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank'),
            ),
          ],
          const SizedBox(width: 4),

          // Start Focus Button (Switches to Focus Forest)
          ElevatedButton.icon(
            onPressed: () {
              provider.setTimerGoal(goal, minutes: goal.targetMinutes);
              onTabChange(2); // navigate to Focus Forest tab
            },
            icon: const Icon(Icons.timer_rounded, size: 14),
            label: const Text('Focus', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.2),
              foregroundColor: const Color(0xFF10B981),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}
