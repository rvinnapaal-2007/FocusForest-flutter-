import 'dart:convert';

enum TreeSpecies {
  oak('Ancient Oak', '🌳', 'General & Humanities'),
  sakura('Sakura Bloom', '🌸', 'Languages & Design'),
  pine('Alpine Pine', '🌲', 'Math & Natural Sciences'),
  binaryTree('Algorithmic Binary Tree', '🌿', 'LeetCode & Computer Science'),
  goldenBaobab('Golden Baobab', '👑', 'Deep Focus (> 60m)');

  final String displayName;
  final String emoji;
  final String description;
  const TreeSpecies(this.displayName, this.emoji, this.description);
}

class ForestTree {
  final String id;
  final TreeSpecies species;
  final DateTime plantedAt;
  final int durationMinutes;
  final bool isWithered;
  final String subject;
  final String goalTitle;

  ForestTree({
    required this.id,
    required this.species,
    required this.plantedAt,
    required this.durationMinutes,
    this.isWithered = false,
    required this.subject,
    required this.goalTitle,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'species': species.name,
      'plantedAt': plantedAt.toIso8601String(),
      'durationMinutes': durationMinutes,
      'isWithered': isWithered,
      'subject': subject,
      'goalTitle': goalTitle,
    };
  }

  factory ForestTree.fromMap(Map<String, dynamic> map) {
    return ForestTree(
      id: map['id'] ?? '',
      species: TreeSpecies.values.firstWhere(
        (e) => e.name == map['species'],
        orElse: () => TreeSpecies.oak,
      ),
      plantedAt: DateTime.tryParse(map['plantedAt'] ?? '') ?? DateTime.now(),
      durationMinutes: map['durationMinutes'] ?? 25,
      isWithered: map['isWithered'] ?? false,
      subject: map['subject'] ?? 'General',
      goalTitle: map['goalTitle'] ?? '',
    );
  }

  String toJson() => json.encode(toMap());

  factory ForestTree.fromJson(String source) =>
      ForestTree.fromMap(json.decode(source));
}
