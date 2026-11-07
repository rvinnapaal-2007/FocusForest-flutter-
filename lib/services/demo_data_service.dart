import 'dart:math';
import '../models/study_goal.dart';
import '../models/forest_tree.dart';
import '../models/user_profile.dart';

class DemoDataService {
  /// Generates 60-day realistic historical study data
  static Map<String, dynamic> generate60DayDemoPackage() {
    final now = DateTime.now();
    final random = Random(42); // deterministic seed for consistent beautiful demo

    // 1. Heatmap daily minutes: map of 'YYYY-MM-DD' -> minutes
    final Map<String, int> heatmapHistory = {};
    // 2. Weekday completion statistics (for Slip Alerts)
    final Map<int, List<bool>> weekdayCompletions = {
      1: [], // Mon
      2: [], // Tue
      3: [], // Wed
      4: [], // Thu
      5: [], // Fri (intentionally low for demo alert)
      6: [], // Sat
      7: [], // Sun
    };

    // 3. Virtual Forest Trees
    final List<ForestTree> demoTrees = [];

    for (int i = 60; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final weekday = date.weekday;

      int minutes = 0;
      bool completed = false;

      // Realistic weekday distribution:
      // Mon-Thu: high productivity (70-130 mins)
      // Friday: intentionally low (0-20 mins) to trigger "Likely to Slip Tomorrow" alert!
      // Sat-Sun: moderate (40-90 mins)
      if (weekday == DateTime.friday) {
        if (random.nextDouble() < 0.28) {
          minutes = 20 + random.nextInt(20);
          completed = true;
        } else {
          minutes = random.nextDouble() < 0.3 ? 15 : 0;
          completed = false;
        }
      } else if (weekday >= DateTime.monday && weekday <= DateTime.thursday) {
        minutes = 60 + random.nextInt(75);
        completed = true;
      } else {
        minutes = 30 + random.nextInt(60);
        completed = random.nextBool();
      }

      heatmapHistory[dateKey] = minutes;
      weekdayCompletions[weekday]!.add(completed);

      // If studied >= 25 mins, plant a tree in the forest
      if (minutes >= 25) {
        final speciesList = TreeSpecies.values;
        final species = speciesList[random.nextInt(speciesList.length)];
        demoTrees.add(ForestTree(
          id: 'demo_tree_$i',
          species: species,
          plantedAt: date.add(Duration(hours: 14 + random.nextInt(6))),
          durationMinutes: minutes,
          isWithered: false,
          subject: (i % 2 == 0) ? 'LeetCode DSA' : 'DBMS Architecture',
          goalTitle: 'Deep Study Session',
        ));
      } else if (minutes > 0 && minutes < 20 && random.nextDouble() < 0.4) {
        // Occasional withered tree showing abandon mechanic
        demoTrees.add(ForestTree(
          id: 'demo_withered_$i',
          species: TreeSpecies.oak,
          plantedAt: date,
          durationMinutes: minutes,
          isWithered: true,
          subject: 'Operating Systems',
          goalTitle: 'Interrupted Session',
        ));
      }
    }

    // 4. Sample active goals for today
    final List<StudyGoal> activeGoals = [
      StudyGoal(
        id: 'active_1',
        title: 'LeetCode: Invert Binary Tree & Lowest Common Ancestor',
        subject: 'Data Structures & Algorithms',
        category: 'Coding',
        targetMinutes: 35,
        completedMinutes: 35,
        isCompleted: true,
        platform: 'LeetCode',
        difficulty: 'Easy',
      ),
      StudyGoal(
        id: 'active_2',
        title: 'DBMS: B+ Tree Indexing & Transaction Isolation Levels',
        subject: 'Database Systems',
        category: 'STEM',
        targetMinutes: 40,
        completedMinutes: 25,
        isCompleted: false,
        platform: 'Standard',
        difficulty: 'Hard',
      ),
      StudyGoal(
        id: 'active_3',
        title: 'CodeChef: Practice Starters Contest Problems A & B',
        subject: 'Competitive Programming',
        category: 'Coding',
        targetMinutes: 30,
        completedMinutes: 0,
        isCompleted: false,
        platform: 'CodeChef',
        difficulty: 'Medium',
      ),
      StudyGoal(
        id: 'active_4',
        title: 'Review System Design: Consistent Hashing & Cache Tier',
        subject: 'Software Architecture',
        category: 'Coding',
        targetMinutes: 25,
        completedMinutes: 0,
        isCompleted: false,
        platform: 'Standard',
        difficulty: 'Medium',
      ),
    ];

    // 5. User Profile with high engagement
    final profile = UserProfile(
      xp: 680,
      currentStreak: 6,
      longestStreak: 18,
      streakShields: 2,
      leetCodeEasy: 24,
      leetCodeMedium: 14,
      leetCodeHard: 4,
      hackerRankBadges: 6,
      codeChefRating: 1620,
    );

    return {
      'heatmap': heatmapHistory,
      'weekdayCompletions': weekdayCompletions,
      'trees': demoTrees,
      'goals': activeGoals,
      'profile': profile,
    };
  }
}
