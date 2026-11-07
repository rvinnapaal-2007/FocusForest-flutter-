import 'dart:math';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/rag_chunk.dart';

class RagIngestResult {
  final StudyDocument document;
  final List<RagChunk> chunks;
  RagIngestResult(this.document, this.chunks);
}

class RagService {
  final List<RagChunk> _chunks = [];
  final List<StudyDocument> _documents = [];

  List<StudyDocument> get documents => List.unmodifiable(_documents);
  List<RagChunk> get allChunks => List.unmodifiable(_chunks);

  static const _stop = {
    'the', 'and', 'for', 'are', 'was', 'were', 'what', 'which', 'who', 'whom', 'this',
    'that', 'these', 'those', 'with', 'from', 'into', 'about', 'how', 'why', 'when',
    'where', 'does', 'did', 'can', 'could', 'should', 'would', 'will', 'you', 'your',
    'has', 'have', 'had', 'not', 'but', 'any', 'all', 'its', 'their', 'there', 'than',
    'then', 'them', 'they', 'explain', 'define', 'describe', 'tell', 'give', 'between',
  };

  RagService() {
    _loadBuiltInKnowledgeBase();
  }

  // ---------------------------------------------------------------
  //  PDF / TXT extraction (real text, page by page)
  // ---------------------------------------------------------------
  /// Extract text from a PDF, one string per page.
  Future<List<String>> extractPdfPages(List<int> bytes) async {
    final doc = PdfDocument(inputBytes: bytes);
    final pages = <String>[];
    try {
      final extractor = PdfTextExtractor(doc);
      final count = doc.pages.count;
      for (var i = 0; i < count; i++) {
        pages.add(extractor.extractText(startPageIndex: i, endPageIndex: i));
        if (i % 4 == 3) await Future<void>.delayed(Duration.zero); // keep UI responsive
      }
    } finally {
      doc.dispose();
    }
    return pages;
  }

  /// Split plain text into virtual "pages" of ~2500 chars (for TXT / pasted notes).
  List<String> textToPages(String text, {int pageSize = 2500}) {
    final pages = <String>[];
    var start = 0;
    while (start < text.length) {
      var end = min(start + pageSize, text.length);
      if (end < text.length) {
        final nl = text.indexOf('\n', end - 200 < start ? start : end - 200);
        if (nl != -1 && nl < end + 200) end = nl;
      }
      pages.add(text.substring(start, end));
      start = end;
    }
    return pages;
  }

  // ---------------------------------------------------------------
  //  Ingestion
  // ---------------------------------------------------------------
  RagIngestResult ingestPages({
    required String title,
    required List<String> pages,
    required String domain,
  }) {
    final docId = 'doc_${DateTime.now().millisecondsSinceEpoch}';
    final chunks = <RagChunk>[];
    var totalChars = 0;

    for (var p = 0; p < pages.length; p++) {
      final clean = pages[p].replaceAll(RegExp(r'[ \t]+'), ' ').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
      totalChars += clean.length;
      if (clean.length < 20) continue;
      chunks.addAll(_chunkPage(docId, title, p + 1, clean, chunks.length));
    }

    if (totalChars < 40 || chunks.isEmpty) {
      throw const FormatException(
          'No readable text found. This PDF may be a scanned image - please use a text-based PDF or paste the text.');
    }

    final ref = StudyDocument(
      id: docId,
      title: title,
      domain: domain,
      chunkCount: chunks.length,
      pageCount: pages.length,
      uploadedAt: DateTime.now(),
    );
    _chunks.addAll(chunks);
    _documents.add(ref);
    return RagIngestResult(ref, chunks);
  }

  RagIngestResult ingestText({required String title, required String content, required String domain}) {
    return ingestPages(title: title, pages: textToPages(content), domain: domain);
  }

  List<RagChunk> _chunkPage(String docId, String title, int page, String text, int offset) {
    const size = 900, overlap = 120;
    final out = <RagChunk>[];
    var start = 0;
    var i = 0;
    while (start < text.length) {
      var end = min(start + size, text.length);
      if (end < text.length) {
        final period = text.indexOf('. ', max(start, end - 80));
        if (period != -1 && period < end + 80) end = min(period + 1, text.length);
      }
      final piece = text.substring(start, end).trim();
      if (piece.isNotEmpty) {
        out.add(RagChunk(
          id: '${docId}_c${offset + i}',
          docId: docId,
          documentTitle: title,
          pageNumber: page,
          content: piece,
        ));
        i++;
      }
      if (end >= text.length) break;
      start = max(end - overlap, start + 1);
    }
    return out;
  }

  /// Replace all user documents (called when loading from the cloud).
  void replaceUserDocuments(List<StudyDocument> docs, List<RagChunk> chunks) {
    removeWhereUser();
    _documents.addAll(docs);
    _chunks.addAll(chunks);
  }

  void removeWhereUser() {
    final builtIn = _documents.where((d) => d.isBuiltIn).map((d) => d.id).toSet();
    _documents.removeWhere((d) => !d.isBuiltIn);
    _chunks.removeWhere((c) => !builtIn.contains(c.docId));
  }

  void removeDocument(String docId) {
    _documents.removeWhere((d) => d.id == docId);
    _chunks.removeWhere((c) => c.docId == docId);
  }

  // ---------------------------------------------------------------
  //  Retrieval (TF-IDF style scoring)
  // ---------------------------------------------------------------
  List<String> _tokens(String q) {
    final clean = q.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    return clean
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 2 && !_stop.contains(t))
        .map((t) => t.length > 4 && t.endsWith('s') ? t.substring(0, t.length - 1) : t)
        .toSet()
        .toList();
  }

  int _count(String text, String token) {
    var n = 0, from = 0;
    while (true) {
      final i = text.indexOf(token, from);
      if (i == -1) break;
      n++;
      from = i + token.length;
    }
    return n;
  }

  List<RagChunk> retrieveRelevantChunks(String query, {int topK = 4, String? docId}) {
    final pool = docId == null ? _chunks : _chunks.where((c) => c.docId == docId).toList();
    if (pool.isEmpty) return [];
    final tokens = _tokens(query);
    if (tokens.isEmpty) return [];

    final lowered = pool.map((c) => c.content.toLowerCase()).toList();
    final idf = <String, double>{};
    for (final t in tokens) {
      var df = 0;
      for (final l in lowered) {
        if (l.contains(t)) df++;
      }
      idf[t] = log(1 + pool.length / (1 + df));
    }

    for (var i = 0; i < pool.length; i++) {
      var score = 0.0;
      for (final t in tokens) {
        final tf = _count(lowered[i], t);
        if (tf > 0) score += (1 + log(tf)) * idf[t]!;
      }
      final title = pool[i].documentTitle.toLowerCase();
      for (final t in tokens) {
        if (title.contains(t)) score += 0.8;
      }
      pool[i].relevanceScore = score;
    }

    final sorted = List<RagChunk>.from(pool)..sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
    return sorted.where((c) => c.relevanceScore > 0).take(topK).toList();
  }

  // ---------------------------------------------------------------
  //  Built-in sample notes
  // ---------------------------------------------------------------
  void _loadBuiltInKnowledgeBase() {
    void add(String title, String domain, String content) {
      final docId = 'builtin_${_documents.length}';
      final chunks = _chunkPage(docId, title, 1, content.trim(), 0);
      _chunks.addAll(chunks);
      _documents.add(StudyDocument(
        id: docId,
        title: title,
        domain: domain,
        chunkCount: chunks.length,
        pageCount: 1,
        uploadedAt: DateTime.now(),
        isBuiltIn: true,
      ));
    }

    add('Database Management Systems & SQL Fundamentals', 'Computer Science', '''
Database Management Systems (DBMS) serve as the interface between database administrators, end users, and the underlying storage engines.
Core Relational Architecture includes ACID properties: Atomicity guarantees all-or-nothing transactions; Consistency ensures database constraints are preserved; Isolation protects concurrently executed transactions using locking or Multi-Version Concurrency Control (MVCC); and Durability ensures committed changes survive power failures using Write-Ahead Logging (WAL).
Entity-Relationship (ER) modeling translates real-world entities into relational schemas with Primary Keys, Foreign Keys, and Normalization up to Boyce-Codd Normal Form (BCNF) to eliminate insertion, deletion, and update anomalies.
B+ Trees and Hash Indexes are primary indexing structures used in PostgreSQL and MySQL InnoDB engines to accelerate lookup queries from O(N) linear scans to O(log N) indexed searches. A B+ Tree keeps all records in linked leaf nodes so range queries are fast, while a hash index only supports equality lookups.
''');

    add('LeetCode & Competitive Programming Master Handbook', 'Coding', '''
The Blind 75 and NeetCode 150 frameworks classify coding interview algorithms into distinct recurring paradigms.
Two Pointers & Sliding Window: Used for contiguous subarray problems, palindromes, and array manipulation in O(N) time complexity with O(1) auxiliary space.
Binary Search: Applicable whenever the search space is monotonic or sorted. Allows finding targets, peak elements, or split array largest sums in O(log N) time.
Dynamic Programming: Decomposes problems with overlapping subproblems and optimal substructure into state tables. Classic problems include 0/1 Knapsack, Longest Common Subsequence (LCS), and Coin Change.
Graph Algorithms: Breadth-First Search (BFS) computes shortest paths in unweighted graphs using queues, while Depth-First Search (DFS) discovers topological orders and connected components. Dijkstra and Bellman-Ford handle weighted shortest path calculations.
''');

    add('Operating Systems: Kernel, Concurrency & Memory Management', 'Engineering', '''
Operating Systems manage hardware resources through process scheduling, virtual memory management, and file systems.
Processes vs Threads: A process possesses its own independent address space (code, data, heap, stack), whereas threads within the same process share heap memory while retaining separate call stacks and program counters.
Deadlock Prevention: Deadlocks require four simultaneous Coffman conditions: Mutual Exclusion, Hold and Wait, No Preemption, and Circular Wait. Banker's Algorithm dynamically avoids deadlocks by evaluating safe states.
Virtual Memory & Paging: Paging translates virtual addresses to physical frames using page tables and Translation Lookaside Buffers (TLB). Page faults trigger LRU (Least Recently Used) page replacement algorithms.
''');
  }
}
