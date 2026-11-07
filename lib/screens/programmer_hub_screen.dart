import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/study_provider.dart';

class ProgrammerHubScreen extends StatelessWidget {
  const ProgrammerHubScreen({super.key});

  static Future<void> _open(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
    if (!ok) {
      messenger.showSnackBar(SnackBar(content: Text('Could not open $url')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StudyProvider>();
    final profile = provider.userProfile;

    return Scaffold(
      backgroundColor: const Color(0xFF08150F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF102A20),
        elevation: 0,
        title: const Row(
          children: [
            Text('💻 Programmer & DSA Hub', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Competitive Programming Overview Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF102A20), Color(0xFF08150F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
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
                          Text('LeetCode Problem Tracker', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('Track Easy, Medium & Hard milestones', style: TextStyle(color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${profile.totalLeetCodeSolved} Solved',
                          style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _open(context, 'https://leetcode.com/problemset/'),
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('Open LeetCode & solve a problem', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFFF59E0B), padding: EdgeInsets.zero),
                    ),
                  ),
                  // Easy / Medium / Hard Breakdown
                  Row(
                    children: [
                      _buildDifficultyCard('Easy', profile.leetCodeEasy, const Color(0xFF10B981), () {
                        provider.incrementCodingStat('LeetCode', difficulty: 'Easy');
                      }),
                      const SizedBox(width: 10),
                      _buildDifficultyCard('Medium', profile.leetCodeMedium, const Color(0xFFF59E0B), () {
                        provider.incrementCodingStat('LeetCode', difficulty: 'Medium');
                      }),
                      const SizedBox(width: 10),
                      _buildDifficultyCard('Hard', profile.leetCodeHard, const Color(0xFFEF4444), () {
                        provider.incrementCodingStat('LeetCode', difficulty: 'Hard');
                      }),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Platforms Row (HackerRank & CodeChef)
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF102A20),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Text('⭐ ', style: TextStyle(fontSize: 16)),
                            Text('HackerRank', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('${profile.hackerRankBadges} Badges', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 18)),
                        InkWell(
                          onTap: () => _open(context, 'https://www.hackerrank.com/dashboard'),
                          child: const Padding(
                            padding: EdgeInsets.only(bottom: 2),
                            child: Text('Open HackerRank ↗', style: TextStyle(fontSize: 11, color: Colors.white54)),
                          ),
                        ),
                        TextButton(
                          onPressed: () => provider.incrementCodingStat('HackerRank'),
                          child: const Text('+ Record Badge', style: TextStyle(fontSize: 11, color: Color(0xFF38BDF8))),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF102A20),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Text('🏆 ', style: TextStyle(fontSize: 16)),
                            Text('CodeChef', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('${profile.codeChefRating} Rating', style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 18)),
                        InkWell(
                          onTap: () => _open(context, 'https://www.codechef.com/'),
                          child: const Padding(
                            padding: EdgeInsets.only(bottom: 2),
                            child: Text('Open CodeChef ↗', style: TextStyle(fontSize: 11, color: Colors.white54)),
                          ),
                        ),
                        TextButton(
                          onPressed: () => provider.incrementCodingStat('CodeChef'),
                          child: const Text('+ Win Contest (+15)', style: TextStyle(fontSize: 11, color: Color(0xFF38BDF8))),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),

            // Curated Study Websites Directory
            const Text(
              '🌐 Integrated Study & Practice Platforms',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ..._studyPlatforms.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: const Color(0xFF102A20),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _open(context, p['url'] as String),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: p['color'] as Color, borderRadius: BorderRadius.circular(8)),
                              child: Text(p['icon'] as String, style: const TextStyle(fontSize: 16)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p['name'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text(p['description'] as String, style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(6)),
                              child: Text(p['tag'] as String, style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.open_in_new_rounded, size: 18, color: Colors.white54),
                          ],
                        ),
                      ),
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyCard(String label, int count, Color color, VoidCallback onAdd) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('$count', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            InkWell(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('+ 1', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const List<Map<String, dynamic>> _studyPlatforms = [
    {
      'name': 'LeetCode',
      'url': 'https://leetcode.com/problemset/',
      'description': 'Industry standard algorithmic challenges (NeetCode 150 & Blind 75)',
      'icon': '⚡',
      'color': Color(0xFFF59E0B),
      'tag': 'DSA / Coding',
    },
    {
      'name': 'HackerRank',
      'url': 'https://www.hackerrank.com/dashboard',
      'description': 'Structured skill assessments for Python, Algorithms, SQL & C++',
      'icon': '⭐',
      'color': Color(0xFF10B981),
      'tag': 'Certifications',
    },
    {
      'name': 'CodeChef',
      'url': 'https://www.codechef.com/',
      'description': 'Weekly speed-coding contests and rating ladders',
      'icon': '🏆',
      'color': Color(0xFF3B82F6),
      'tag': 'Competitive',
    },
    {
      'name': 'Codeforces',
      'url': 'https://codeforces.com/problemset',
      'description': 'Rated contests and a huge archive of competitive problems',
      'icon': '⚔️',
      'color': Color(0xFF6366F1),
      'tag': 'Competitive',
    },
    {
      'name': 'GeeksforGeeks',
      'url': 'https://www.geeksforgeeks.org/',
      'description': 'Comprehensive CS engineering articles, DBMS, OS & Gate archives',
      'icon': '📖',
      'color': Color(0xFF22C55E),
      'tag': 'Academic & Core',
    },
    {
      'name': 'Roadmap.sh',
      'url': 'https://roadmap.sh/',
      'description': 'Community-driven visual roadmaps for CS, Backend, AI & DevOps',
      'icon': '🗺️',
      'color': Color(0xFF8B5CF6),
      'tag': 'Curriculum',
    },
    {
      'name': 'MIT OpenCourseWare & CS50',
      'url': 'https://cs50.harvard.edu/x/',
      'description': 'World-class open computer science lectures, assignments and exams',
      'icon': '🎓',
      'color': Color(0xFFEC4899),
      'tag': 'Video Lectures',
    },
  ];
}
