import 'dart:convert';

class StudyGoal {
  final String id;
  final String title;
  final String subject;
  final String category; // 'Coding', 'STEM', 'Medical', 'Humanities', 'General'
  final int targetMinutes;
  int completedMinutes;
  bool isCompleted;
  final int dayNumber;
  final DateTime date;
  final String platform; // 'LeetCode', 'HackerRank', 'CodeChef', 'Standard'
  final String difficulty; // 'Easy', 'Medium', 'Hard'

  StudyGoal({
    required this.id,
    required this.title,
    required this.subject,
    this.category = 'General',
    required this.targetMinutes,
    this.completedMinutes = 0,
    this.isCompleted = false,
    this.dayNumber = 1,
    DateTime? date,
    this.platform = 'Standard',
    this.difficulty = 'Medium',
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'subject': subject,
      'category': category,
      'targetMinutes': targetMinutes,
      'completedMinutes': completedMinutes,
      'isCompleted': isCompleted,
      'dayNumber': dayNumber,
      'date': date.toIso8601String(),
      'platform': platform,
      'difficulty': difficulty,
    };
  }

  factory StudyGoal.fromMap(Map<String, dynamic> map) {
    return StudyGoal(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      subject: map['subject'] ?? 'General',
      category: map['category'] ?? 'General',
      targetMinutes: map['targetMinutes'] ?? 30,
      completedMinutes: map['completedMinutes'] ?? 0,
      isCompleted: map['isCompleted'] ?? false,
      dayNumber: map['dayNumber'] ?? 1,
      date: DateTime.tryParse(map['date'] ?? '') ?? DateTime.now(),
      platform: map['platform'] ?? 'Standard',
      difficulty: map['difficulty'] ?? 'Medium',
    );
  }

  String toJson() => json.encode(toMap());

  factory StudyGoal.fromJson(String source) =>
      StudyGoal.fromMap(json.decode(source));
}
