import 'dart:convert';

class UserBadge {
  final String id;
  final String title;
  final String description;
  final String icon;
  final bool isUnlocked;

  UserBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.isUnlocked = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'icon': icon,
        'isUnlocked': isUnlocked,
      };

  factory UserBadge.fromMap(Map<String, dynamic> map) => UserBadge(
        id: map['id'] ?? '',
        title: map['title'] ?? '',
        description: map['description'] ?? '',
        icon: map['icon'] ?? '🏅',
        isUnlocked: map['isUnlocked'] ?? false,
      );
}

class UserProfile {
  int xp;
  int currentStreak;
  int longestStreak;
  int streakShields;
  List<UserBadge> badges;

  // Competitive Programming Stats
  int leetCodeEasy;
  int leetCodeMedium;
  int leetCodeHard;
  int hackerRankBadges;
  int codeChefRating;

  UserProfile({
    this.xp = 150,
    this.currentStreak = 4,
    this.longestStreak = 12,
    this.streakShields = 2,
    List<UserBadge>? badges,
    this.leetCodeEasy = 15,
    this.leetCodeMedium = 8,
    this.leetCodeHard = 2,
    this.hackerRankBadges = 4,
    this.codeChefRating = 1450,
  }) : badges = badges ?? _defaultBadges();

  /// Brand-new account: zero progress and every badge locked.
  factory UserProfile.fresh() => UserProfile(
        xp: 0,
        currentStreak: 0,
        longestStreak: 0,
        streakShields: 1,
        leetCodeEasy: 0,
        leetCodeMedium: 0,
        leetCodeHard: 0,
        hackerRankBadges: 0,
        codeChefRating: 1200,
        badges: _defaultBadges()
            .map((b) => UserBadge(id: b.id, title: b.title, description: b.description, icon: b.icon, isUnlocked: false))
            .toList(),
      );

  int get level => (xp / 100).floor() + 1;
  int get currentLevelProgress => xp % 100;
  int get totalLeetCodeSolved => leetCodeEasy + leetCodeMedium + leetCodeHard;

  static List<UserBadge> _defaultBadges() => [
        UserBadge(
          id: '7_day_warrior',
          title: '7-Day Warrior',
          description: 'Completed 7 consecutive study days',
          icon: '🛡️',
          isUnlocked: true,
        ),
        UserBadge(
          id: 'deep_focus',
          title: 'Deep Focus Master',
          description: 'Grew a tree with 60+ minutes unbroken focus',
          icon: '🧘',
          isUnlocked: true,
        ),
        UserBadge(
          id: 'perfect_day',
          title: 'Flawless Day',
          description: 'Completed 100% of generated goals for the day',
          icon: '⭐',
          isUnlocked: true,
        ),
        UserBadge(
          id: 'algo_knight',
          title: 'Algorithm Knight',
          description: 'Solved 25+ LeetCode / Coding challenges',
          icon: '⚔️',
          isUnlocked: true,
        ),
        UserBadge(
          id: 'early_bird',
          title: 'Early Bird',
          description: 'Finished a study goal before 8:00 AM',
          icon: '🌅',
          isUnlocked: false,
        ),
        UserBadge(
          id: 'forest_guardian',
          title: 'Forest Guardian',
          description: 'Grew 20+ thriving trees without any withered',
          icon: '🌲',
          isUnlocked: false,
        ),
      ];

  Map<String, dynamic> toMap() => {
        'xp': xp,
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'streakShields': streakShields,
        'badges': badges.map((b) => b.toMap()).toList(),
        'leetCodeEasy': leetCodeEasy,
        'leetCodeMedium': leetCodeMedium,
        'leetCodeHard': leetCodeHard,
        'hackerRankBadges': hackerRankBadges,
        'codeChefRating': codeChefRating,
      };

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        xp: map['xp'] ?? 0,
        currentStreak: map['currentStreak'] ?? 0,
        longestStreak: map['longestStreak'] ?? 0,
        streakShields: map['streakShields'] ?? 0,
        badges: (map['badges'] as List<dynamic>?)
                ?.map((e) => UserBadge.fromMap(e))
                .toList() ??
            _defaultBadges(),
        leetCodeEasy: map['leetCodeEasy'] ?? 0,
        leetCodeMedium: map['leetCodeMedium'] ?? 0,
        leetCodeHard: map['leetCodeHard'] ?? 0,
        hackerRankBadges: map['hackerRankBadges'] ?? 0,
        codeChefRating: map['codeChefRating'] ?? 1200,
      );

  String toJson() => json.encode(toMap());
  factory UserProfile.fromJson(String source) =>
      UserProfile.fromMap(json.decode(source));
}
