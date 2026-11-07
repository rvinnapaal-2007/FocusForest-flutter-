import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/study_goal.dart';
import '../models/rag_chunk.dart';
import '../models/study_categories.dart';

class GroqException implements Exception {
  final String message;

  /// True when retrying (or switching model) cannot help, e.g. a rejected API key.
  final bool fatal;
  GroqException(this.message, {this.fatal = false});
  @override
  String toString() => message;
}

/// Talks to Groq directly from the app (or to your own backend if BACKEND_URL is set).
class GroqService {
  // Kept for compatibility with the existing provider / account menu code.
  String get apiKey => AppConfig.groqApiKey;
  String? lastError;

  Future<void> loadSavedKey() async {}
  Future<void> saveKey(String key) async {}

  // Limits chosen to stay inside Groq's free-tier tokens-per-minute budget.
  static const int _singlePassChars = 9000;
  static const int _partChars = 8000;
  static const int _maxParts = 6;

  // ------------------------------------------------------------
  //  Core chat call (model fallback + automatic retry on rate limit)
  // ------------------------------------------------------------
  Future<String> _chat({
    required String system,
    required String user,
    double temperature = 0.4,
    int maxTokens = 1800,
    List<String>? models,
  }) async {
    if (AppConfig.backendChatUrl.isEmpty && AppConfig.groqApiKey.trim().isEmpty) {
      throw GroqException('The AI key is missing. Add it in lib/config/app_config.dart.', fatal: true);
    }
    final order = models ?? const [AppConfig.mainModel, AppConfig.fastModel];
    GroqException? last;
    for (final model in order) {
      try {
        final answer = await _callOnce(
          model: model,
          system: system,
          user: user,
          temperature: temperature,
          maxTokens: maxTokens,
        );
        lastError = null;
        return answer;
      } on GroqException catch (e) {
        last = e;
        lastError = e.message;
        if (e.fatal) break;
      }
    }
    throw last ?? GroqException('The AI could not answer right now. Please try again.');
  }

  Future<String> _callOnce({
    required String model,
    required String system,
    required String user,
    required double temperature,
    required int maxTokens,
  }) async {
    final useBackend = AppConfig.backendChatUrl.isNotEmpty;
    for (var attempt = 0; attempt < 2; attempt++) {
      http.Response res;
      try {
        if (useBackend) {
          res = await http
              .post(
                Uri.parse(AppConfig.backendChatUrl),
                headers: {'Content-Type': 'application/json'},
                body: json.encode({'system': system, 'message': user, 'temperature': temperature, 'max_tokens': maxTokens}),
              )
              .timeout(const Duration(seconds: 90));
        } else {
          res = await http
              .post(
                Uri.parse(AppConfig.groqChatUrl),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer ${AppConfig.groqApiKey.trim()}',
                },
                body: json.encode({
                  'model': model,
                  'messages': [
                    {'role': 'system', 'content': system},
                    {'role': 'user', 'content': user},
                  ],
                  'temperature': temperature,
                  // gpt-oss models "think" first; those hidden tokens count toward the limit,
                  // so give them extra room and keep the thinking short.
                  'max_tokens': model.startsWith('openai/gpt-oss') ? maxTokens + 700 : maxTokens,
                  if (model.startsWith('openai/gpt-oss')) 'reasoning_effort': 'low',
                }),
              )
              .timeout(const Duration(seconds: 90));
        }
      } on TimeoutException {
        throw GroqException('The AI took too long to respond. Please try again.');
      } catch (_) {
        throw GroqException('Could not reach the AI service. Check your internet connection and try again.');
      }

      final bodyText = utf8.decode(res.bodyBytes);

      if (res.statusCode == 200) {
        try {
          final data = json.decode(bodyText);
          var text = useBackend
              ? (data['reply'] ?? '').toString()
              : (data['choices'][0]['message']['content'] ?? '').toString();
          text = text.replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '').trim();
          if (text.isNotEmpty) return text;
        } catch (_) {}
        throw GroqException('The AI sent an empty answer. Please try again.');
      }

      if (res.statusCode == 401 || res.statusCode == 403) {
        throw GroqException(
          'The AI key was rejected by Groq. Create a new key at console.groq.com/keys and put it in lib/config/app_config.dart.',
          fatal: true,
        );
      }

      if (res.statusCode == 429) {
        final wait = _retryAfterSeconds(bodyText);
        if (attempt == 0 && wait != null && wait <= 25) {
          await Future<void>.delayed(Duration(milliseconds: (wait * 1000).ceil() + 300));
          continue;
        }
        throw GroqException('The AI is busy right now (free-plan rate limit). Wait about 30 seconds and try again.');
      }

      var detail = '';
      try {
        detail = (json.decode(bodyText)['error']?['message'] ?? '').toString();
      } catch (_) {}
      // Model retired / not available -> let _chat try the next model.
      throw GroqException('AI service error (${res.statusCode}). ${detail.length > 140 ? detail.substring(0, 140) : detail}'.trim());
    }
    throw GroqException('The AI is busy right now. Please try again in a moment.');
  }

  double? _retryAfterSeconds(String body) {
    final m = RegExp(r'try again in (?:(\d+)m)?\s*([\d.]+)(ms|s)').firstMatch(body);
    if (m == null) return null;
    final minutes = double.tryParse(m.group(1) ?? '0') ?? 0;
    var secs = double.tryParse(m.group(2) ?? '') ?? 0;
    if (m.group(3) == 'ms') secs = secs / 1000;
    return minutes * 60 + secs;
  }

  /// Returns null when the AI works, otherwise a readable problem description.
  Future<String?> testConnection() async {
    try {
      final r = await _chat(system: 'Reply with the single word OK.', user: 'ping', maxTokens: 5, temperature: 0);
      return r.isEmpty ? 'Empty reply' : null;
    } catch (e) {
      return e.toString();
    }
  }

  // ------------------------------------------------------------
  //  Study plan
  // ------------------------------------------------------------
  Future<List<StudyGoal>> generateStudyPlan({
    required String subject,
    required String goalTitle,
    required int daysLeft,
    required int dailyMinutes,
    String domain = 'General',
  }) async {
    final days = daysLeft.clamp(1, 7);
    final coding = isCodingCategory(domain);
    final prompt = '''
Create a personalized $daysLeft-day study plan for a student preparing for: "$goalTitle" in subject "$subject" (category: $domain).
The student has $dailyMinutes minutes per day.

Output STRICT JSON ONLY - a JSON array, no markdown, no commentary. Each item:
{"title":"...", "targetMinutes":30, "dayNumber":1, "platform":"Standard", "difficulty":"Medium"}

Rules:
- 3 or 4 goals per day for Day 1 to Day $days.
- Titles must be specific topics of "$subject" (real chapters / concepts), not generic filler. Order them from basics to advanced, and finish with revision / practice on the last day.
- Each day's minutes must add up to about $dailyMinutes.
- platform is "Standard" unless category is Coding (then LeetCode, HackerRank or CodeChef).
- difficulty is Easy, Medium or Hard.
''';

    try {
      var raw = await _chat(
        system: 'You are an expert academic tutor and study planner for ANY subject in the world. Reply with a raw JSON array only.',
        user: prompt,
        temperature: 0.3,
        maxTokens: 1800,
      );
      final start = raw.indexOf('[');
      final end = raw.lastIndexOf(']');
      if (start != -1 && end > start) raw = raw.substring(start, end + 1);
      final list = json.decode(raw) as List<dynamic>;
      final goals = <StudyGoal>[];
      for (var i = 0; i < list.length; i++) {
        final item = list[i] as Map<String, dynamic>;
        goals.add(StudyGoal(
          id: 'goal_${DateTime.now().millisecondsSinceEpoch}_$i',
          title: (item['title'] ?? 'Study session').toString(),
          subject: subject,
          category: domain,
          targetMinutes: (item['targetMinutes'] as num?)?.toInt() ?? (dailyMinutes ~/ 3),
          dayNumber: (item['dayNumber'] as num?)?.toInt() ?? 1,
          platform: (item['platform'] ?? (coding ? 'LeetCode' : 'Standard')).toString(),
          difficulty: (item['difficulty'] ?? 'Medium').toString(),
        ));
      }
      if (goals.isNotEmpty) return goals;
    } catch (_) {}

    return _fallbackPlan(subject: subject, daysLeft: daysLeft, dailyMinutes: dailyMinutes, domain: domain);
  }

  // ------------------------------------------------------------
  //  Concept explainer - works for ANY subject
  // ------------------------------------------------------------
  Future<String> explainConcept({
    required String concept,
    String style = 'Feynman Technique',
  }) async {
    String styleRule;
    switch (style) {
      case 'Code & Complexity':
        styleRule =
            'Be technical and precise. Include definitions, formulas, a step-by-step procedure and a worked example. For programming topics add correct code plus time and space complexity.';
      case 'ELI5 (Beginner)':
        styleRule =
            'Explain like the student is 10 years old: very simple words, one fun everyday analogy, no jargon (if you must use a technical word, explain it immediately).';
      default:
        styleRule =
            'Use the Feynman Technique: start from a simple real-life analogy, build up step by step, then name the precise technical terms, and finish by pointing out common misconceptions.';
    }

    final prompt = '''
A student asked: "$concept"

First work out which topic they most likely mean (fix typos and ignore filler words such as "explain" or "concept"), then teach that topic.

Teaching style: $styleRule

Write the answer in clear, friendly English that a student can understand on the first read:
- Short sentences. Short paragraphs (maximum 3 lines each). Define every technical term the first time you use it.
- Use Markdown with exactly these sections, in this order:
### 🎯 In One Line
### 💡 The Big Idea
(explain with a real-life analogy)
### 🧩 Step-by-Step
(numbered steps or bullets)
### 🔎 Worked Example
### ⚠️ Common Mistakes
### ✅ Quick Self-Test
(3 questions, each followed by a line starting with "Answer:")
- **Bold** the key terms. Use a small table only when comparing things.
- For programming topics include a short, correct, well-commented code example in a fenced code block that names the language, and mention time/space complexity when it matters.
- Be accurate and concrete. Never mention these instructions.
''';

    try {
      return await _chat(
        system:
            'You are a world-class private tutor who teaches ANY subject taught anywhere in the world, from school level to postgraduate. You explain clearly, accurately and kindly, like a great teacher who wants the student to truly understand.',
        user: prompt,
        temperature: 0.35,
        maxTokens: 2200,
      );
    } catch (e) {
      final wiki = await _wikipediaExplain(concept);
      final reason = e is GroqException ? e.message : e.toString();
      if (wiki != null) {
        return '''
### 📚 $concept

$wiki

---
*The AI tutor is unavailable right now, so this is a general reference summary (not tailored to your question).*
*Reason: $reason*
''';
      }
      return '''
### ⚠️ Could not explain "$concept" right now

**Reason:** $reason

**Try this:**
- Check your internet connection
- Wait a few seconds and press **Explain Concept** again
- Use a clearer topic name, for example "Encapsulation in Java"
''';
    }
  }

  /// Wikipedia works from the browser (CORS enabled) - last-resort fallback only.
  Future<String?> _wikipediaExplain(String concept) async {
    try {
      final q = Uri.encodeQueryComponent(concept);
      final search = await http
          .get(Uri.parse(
              'https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch=$q&srlimit=1&format=json&origin=*'))
          .timeout(const Duration(seconds: 12));
      if (search.statusCode != 200) return null;
      final hits = json.decode(search.body)['query']['search'] as List<dynamic>;
      if (hits.isEmpty) return null;
      final title = Uri.encodeQueryComponent(hits.first['title'].toString());

      final res = await http
          .get(Uri.parse(
              'https://en.wikipedia.org/w/api.php?action=query&prop=extracts&explaintext=1&exsectionformat=plain&exchars=3000&redirects=1&titles=$title&format=json&origin=*'))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final pages = json.decode(utf8.decode(res.bodyBytes))['query']['pages'] as Map<String, dynamic>;
      final extract = pages.values.first['extract']?.toString().trim();
      if (extract == null || extract.isEmpty) return null;
      return extract;
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------
  //  Ask questions about uploaded notes / PDF (RAG)
  // ------------------------------------------------------------
  Future<String> answerWithRag({
    required String query,
    required List<RagChunk> relevantChunks,
  }) async {
    if (relevantChunks.isEmpty) {
      try {
        return await _chat(
          system: 'You are a helpful, clear tutor for students.',
          user:
              'The student asked: "$query"\nNo matching passage was found in their uploaded notes. Start with the sentence "Not found in your notes - here is a general answer:" and then answer clearly in Markdown using short paragraphs and bullet points.',
          maxTokens: 1200,
        );
      } catch (_) {
        return 'No matching passage was found in your notes for "$query". Try different keywords, or upload the relevant PDF.';
      }
    }

    final context = relevantChunks
        .map((c) => '--- [Source: ${c.documentTitle} | Page ${c.pageNumber}] ---\n${c.content}')
        .join('\n\n');

    final prompt = '''
Answer the student's question using ONLY the passages retrieved from their own notes below.

Retrieved passages:
$context

Question: "$query"

Write the answer in simple, clear English for a student:
### ✅ Short Answer
(2-4 sentences in plain words)
### 📖 Explanation
(bullet points or numbered steps; explain any difficult word; give a tiny example or analogy if it helps)
### 📍 Where to read more
(list the [Page N] numbers you used)

Rules:
- Cite sources inline like [Page N].
- Do not invent facts that are not in the passages. If the passages only partly answer the question, say clearly what is missing.
''';

    try {
      return await _chat(
        system:
            'You are a patient tutor who explains a student\'s own notes in simple language. You rely strictly on the provided passages and cite page numbers.',
        user: prompt,
        temperature: 0.2,
        maxTokens: 1500,
      );
    } catch (e) {
      final buf = StringBuffer('### 📖 Passages found in your notes\n*(The AI could not explain them right now: $e)*\n\n');
      for (final c in relevantChunks.take(3)) {
        buf.writeln('**${c.documentTitle} - Page ${c.pageNumber}**');
        buf.writeln(c.content);
        buf.writeln();
      }
      return buf.toString();
    }
  }

  // ------------------------------------------------------------
  //  PDF / notes: summarise + explain the WHOLE document
  //  mode: 'full' (summary + concepts + questions), 'concepts', 'questions'
  // ------------------------------------------------------------
  Future<String> summarizeDocument({
    required String title,
    required Map<int, String> pages,
    String mode = 'full',
    void Function(String status)? onProgress,
  }) async {
    final entries = pages.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final buf = StringBuffer();
    for (final e in entries) {
      final t = e.value.trim();
      if (t.isEmpty) continue;
      buf.writeln('[Page ${e.key}]');
      buf.writeln(t);
      buf.writeln();
    }
    final full = buf.toString();
    final pageCount = entries.length;

    if (full.trim().isEmpty) {
      return '### ⚠️ Nothing to summarize\nNo readable text was found in "$title".';
    }

    try {
      String material;
      var usedNotes = false;
      var coverage = '';

      if (full.length <= _singlePassChars) {
        material = full;
      } else {
        usedNotes = true;
        final parts = _splitParts(full, _partChars);
        var chosen = parts;
        if (parts.length > _maxParts) {
          chosen = [for (var i = 0; i < _maxParts; i++) parts[(i * (parts.length - 1) / (_maxParts - 1)).round()]];
          coverage = '\n\n*Note: this document is long, so the summary was built from $_maxParts evenly spread sections out of ${parts.length}.*';
        }
        final notes = StringBuffer();
        for (var i = 0; i < chosen.length; i++) {
          onProgress?.call('Reading part ${i + 1} of ${chosen.length}...');
          final n = await _chat(
            system: 'You turn study material into accurate, compact revision notes.',
            user: '''
Make compact study notes from the text below. Keep every important definition, formula, name, number, process step and example. Keep the [Page N] markers next to the facts. Use short bullet points. Do not add anything that is not in the text.

TEXT:
${chosen[i]}
''',
            temperature: 0.2,
            maxTokens: 450,
            models: const [AppConfig.fastModel, AppConfig.mainModel],
          );
          notes.writeln('--- Notes for part ${i + 1} of ${chosen.length} ---');
          notes.writeln(n);
          notes.writeln();
        }
        material = notes.toString();
      }

      onProgress?.call('Writing your ${mode == 'questions' ? 'practice questions' : mode == 'concepts' ? 'concept explanations' : 'summary'}...');
      final out = await _chat(
        system:
            'You are an excellent teacher. You summarise and explain study material in simple, accurate language so any student can understand it. You never invent facts.',
        user: _documentPrompt(title: title, pageCount: pageCount, material: material, mode: mode, fromNotes: usedNotes),
        temperature: 0.3,
        maxTokens: 2000,
      );
      return '### 📄 $title\n\n$out$coverage';
    } catch (e) {
      final reason = e is GroqException ? e.message : e.toString();
      return _offlineSummary(title, entries, reason);
    }
  }

  String _documentPrompt({
    required String title,
    required int pageCount,
    required String material,
    required String mode,
    required bool fromNotes,
  }) {
    final what = fromNotes
        ? 'Below are compact notes made from every part of the document (page markers like [Page N] are kept).'
        : 'Below is the text of the document (page markers like [Page N] are included).';
    final head = 'You are helping a student understand the study material "$title" ($pageCount pages).\n$what\n\n';
    final tail = '\n\nMATERIAL:\n$material';

    switch (mode) {
      case 'concepts':
        return '''${head}Explain the most important concepts of this document so a student who has never read it can understand them.

Use Markdown. For each of the 6-10 most important concepts write:
#### 1. Concept name
- **In simple words:** 2-3 short sentences
- **Analogy / example:** one line
- **Why it matters:** one line
- **Common confusion:** one line (skip if none)
Add [Page N] references. Define jargon. Only use facts from the material.$tail''';
      case 'questions':
        return '''${head}Create practice questions from this document so the student can test themselves.

Use Markdown with these sections:
### 🅰️ Multiple Choice (4 questions)
Give 4 options (A-D) and write "Answer: X - short reason".
### ✍️ Short Answer (3 questions)
Give a 2-3 line model answer.
### 📚 Long Answer (3 questions)
Give a model answer in 4-6 bullet points.
Only use facts from the material and add [Page N] references.$tail''';
      default:
        return '''${head}Summarise AND explain this document for a student. Write in simple, clear English and use exactly this Markdown structure:

### 📘 What is this document about?
(2-3 sentences)
### 📌 Summary in Brief
(6-8 bullet points that cover the whole document)
### 🔑 Key Concepts Explained Simply
(the 5-8 most important concepts; for each: **Concept** - a plain-English explanation in 2-3 short sentences, then "Example/Analogy:" in one line)
### 🧭 Section-by-Section Walkthrough
(short bullets for each section or page range, with [Page N] references)
### 📝 Definitions, Formulas & Facts to Remember
(bullet list)
### 🎯 Likely Exam Questions
(5 questions, each with a 1-2 line answer)
### ⚡ Last-Minute Revision Cheat-Sheet
(5 bullets maximum)

Rules: use only the material and do not invent facts. If some text looks broken (for example formulas lost during PDF extraction), say so briefly instead of guessing. Define any difficult term.$tail''';
    }
  }

  List<String> _splitParts(String text, int size) {
    final parts = <String>[];
    var start = 0;
    while (start < text.length) {
      var end = min(start + size, text.length);
      if (end < text.length) {
        final nl = text.lastIndexOf('\n', end);
        if (nl > start + size ~/ 2) end = nl;
      }
      parts.add(text.substring(start, end));
      start = end;
    }
    return parts;
  }

  /// Simple automatic outline used only when the AI cannot be reached at all.
  String _offlineSummary(String title, List<MapEntry<int, String>> entries, String reason) {
    const stop = {
      'this', 'that', 'with', 'from', 'have', 'which', 'their', 'there', 'these', 'those', 'would', 'about',
      'been', 'were', 'will', 'than', 'then', 'also', 'such', 'into', 'other', 'using', 'used', 'when', 'what',
      'where', 'while', 'they', 'them', 'more', 'most', 'some', 'each', 'only', 'very', 'can', 'may', 'and', 'the', 'for', 'are',
    };
    final freq = <String, int>{};
    for (final e in entries) {
      for (final w in e.value.toLowerCase().split(RegExp(r'[^a-z]+'))) {
        if (w.length > 4 && !stop.contains(w)) freq[w] = (freq[w] ?? 0) + 1;
      }
    }
    final top = (freq.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(10).map((e) => e.key).toList();

    final b = StringBuffer('### 📄 $title\n');
    b.writeln('*The AI could not be reached ($reason), so this is a quick automatic outline of your document. Press the ✨ button again in a moment for the full explanation.*\n');
    if (top.isNotEmpty) b.writeln('**Main terms:** ${top.join(', ')}\n');
    b.writeln('**Page-by-page highlights**');
    for (final e in entries.take(15)) {
      final clean = e.value.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (clean.isEmpty) continue;
      final dot = clean.indexOf('. ');
      final first = (dot > 30 && dot < 260) ? clean.substring(0, dot + 1) : (clean.length > 220 ? '${clean.substring(0, 220)}...' : clean);
      b.writeln('- [Page ${e.key}] $first');
    }
    return b.toString();
  }

  // ------------------------------------------------------------
  //  Offline fallback plan
  // ------------------------------------------------------------
  List<StudyGoal> _fallbackPlan({
    required String subject,
    required int daysLeft,
    required int dailyMinutes,
    required String domain,
  }) {
    final list = <StudyGoal>[];
    final days = daysLeft.clamp(1, 7);
    final per = (dailyMinutes / 3).round();
    for (var day = 1; day <= days; day++) {
      if (isCodingCategory(domain)) {
        list.add(StudyGoal(id: 'fb_${day}_1', title: 'Day $day: LeetCode - Arrays & Hashing', subject: subject, category: domain, targetMinutes: per, dayNumber: day, platform: 'LeetCode', difficulty: 'Easy'));
        list.add(StudyGoal(id: 'fb_${day}_2', title: 'Day $day: LeetCode - Two Pointers & Binary Search', subject: subject, category: domain, targetMinutes: per, dayNumber: day, platform: 'LeetCode', difficulty: 'Medium'));
        list.add(StudyGoal(id: 'fb_${day}_3', title: 'Day $day: HackerRank / CodeChef practice', subject: subject, category: domain, targetMinutes: dailyMinutes - per * 2, dayNumber: day, platform: 'HackerRank', difficulty: 'Medium'));
      } else {
        list.add(StudyGoal(id: 'fb_${day}_1', title: 'Day $day: $subject - fundamentals & key terms', subject: subject, category: domain, targetMinutes: per, dayNumber: day));
        list.add(StudyGoal(id: 'fb_${day}_2', title: 'Day $day: $subject - in-depth theory & examples', subject: subject, category: domain, targetMinutes: per, dayNumber: day));
        list.add(StudyGoal(id: 'fb_${day}_3', title: 'Day $day: $subject - practice questions & revision', subject: subject, category: domain, targetMinutes: dailyMinutes - per * 2, dayNumber: day));
      }
    }
    return list;
  }
}
