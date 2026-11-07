class RagChunk {
  final String id;
  final String docId;
  final String documentTitle;
  final int pageNumber;
  final String content;
  final List<String> keywords;
  double relevanceScore;

  RagChunk({
    required this.id,
    this.docId = '',
    required this.documentTitle,
    required this.pageNumber,
    required this.content,
    List<String>? keywords,
    this.relevanceScore = 0.0,
  }) : keywords = keywords ?? _extractKeywords(content);

  static List<String> _extractKeywords(String text) {
    final clean = text.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), ' ');
    final words = clean.split(RegExp(r'\s+')).where((w) => w.length > 3).toSet();
    return words.toList();
  }

  // Keywords are rebuilt on load, so they are not stored in the cloud.
  Map<String, dynamic> toMap() => {
        'id': id,
        'docId': docId,
        'documentTitle': documentTitle,
        'pageNumber': pageNumber,
        'content': content,
      };

  factory RagChunk.fromMap(Map<String, dynamic> map) => RagChunk(
        id: map['id'] ?? '',
        docId: map['docId'] ?? '',
        documentTitle: map['documentTitle'] ?? '',
        pageNumber: (map['pageNumber'] ?? 1) as int,
        content: map['content'] ?? '',
      );
}

/// A study document (PDF / text / pasted notes) that has been indexed.
class StudyDocument {
  final String id;
  final String title;
  final String domain;
  final int chunkCount;
  final int pageCount;
  final DateTime uploadedAt;
  final bool isBuiltIn;

  StudyDocument({
    required this.id,
    required this.title,
    required this.domain,
    required this.chunkCount,
    this.pageCount = 1,
    required this.uploadedAt,
    this.isBuiltIn = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'domain': domain,
        'chunkCount': chunkCount,
        'pageCount': pageCount,
        'uploadedAt': uploadedAt.toIso8601String(),
      };

  factory StudyDocument.fromMap(Map<String, dynamic> map) => StudyDocument(
        id: map['id'] ?? '',
        title: map['title'] ?? 'Untitled',
        domain: map['domain'] ?? 'General',
        chunkCount: (map['chunkCount'] ?? 0) as int,
        pageCount: (map['pageCount'] ?? 1) as int,
        uploadedAt: DateTime.tryParse(map['uploadedAt'] ?? '') ?? DateTime.now(),
      );
}
