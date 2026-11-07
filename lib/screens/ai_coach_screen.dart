import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/study_provider.dart';
import '../models/rag_chunk.dart';
import '../models/study_categories.dart';
import '../widgets/markdown_lite.dart';

class AiCoachScreen extends StatefulWidget {
  const AiCoachScreen({super.key});

  @override
  State<AiCoachScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends State<AiCoachScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Plan Generator controllers
  final _goalController = TextEditingController();
  final _subjectController = TextEditingController();
  int _daysLeft = 5;
  int _dailyMinutes = 120;
  String _domain = 'Science';

  // Concept Explainer controllers
  final _conceptController = TextEditingController();
  String _explanationStyle = 'Feynman Technique';

  // RAG & PDF Assistant controllers
  final _ragQueryController = TextEditingController();
  String? _ragDocFilter; // null = search all documents
  final _newDocTitleController = TextEditingController();
  final _newDocContentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _goalController.dispose();
    _subjectController.dispose();
    _conceptController.dispose();
    _ragQueryController.dispose();
    _newDocTitleController.dispose();
    _newDocContentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StudyProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF08150F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF102A20),
        elevation: 0,
        title: const Row(
          children: [
            Text('🤖 AI Study Coach', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
            SizedBox(width: 8),
            Text('(Groq AI + RAG)', style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF10B981),
          labelColor: const Color(0xFF10B981),
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'Plan Maker'),
            Tab(text: 'Explainer'),
            Tab(text: 'RAG / Notes'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPlanMakerTab(context, provider),
          _buildConceptExplainerTab(context, provider),
          _buildRagAssistantTab(context, provider),
        ],
      ),
    );
  }

  // TAB 1: AI Study Plan Generator
  Widget _buildPlanMakerTab(BuildContext context, StudyProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF102A20),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Text('⚡', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Powered by Groq Llama-3.3 70B',
                        style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Generates customized daily goals for ANY subject or coding syllabus with instant offline fallback.',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Exam Goal Field
          const Text('Exam or Target Goal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 6),
          TextField(
            controller: _goalController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('e.g., Ace my final exam, Crack LeetCode 75, Master Neuroanatomy'),
          ),
          const SizedBox(height: 16),

          // Subject Field
          const Text('Subject / Domain', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 6),
          TextField(
            controller: _subjectController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('Any subject: Biology, Law, Economics, DBMS, History...'),
          ),
          const SizedBox(height: 16),

          // Category selector - any subject, any student
          const Text('Category / Subject Area', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          _categoryChips(const Color(0xFF10B981)),
          const SizedBox(height: 16),

          // Sliders
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Days Left: $_daysLeft days', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    Slider(
                      value: _daysLeft.toDouble(),
                      min: 1,
                      max: 30,
                      divisions: 29,
                      activeColor: const Color(0xFF10B981),
                      onChanged: (v) => setState(() => _daysLeft = v.toInt()),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Daily Study: $_dailyMinutes mins', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    Slider(
                      value: _dailyMinutes.toDouble(),
                      min: 30,
                      max: 360,
                      divisions: 11,
                      activeColor: const Color(0xFF38BDF8),
                      onChanged: (v) => setState(() => _dailyMinutes = v.toInt()),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Generate Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: provider.isAiGenerating
                  ? null
                  : () async {
                      if (_subjectController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Enter a subject first (any subject works)')),
                        );
                        return;
                      }
                      await provider.generatePlanWithGroq(
                        subject: _subjectController.text.trim(),
                        goalTitle: _goalController.text.trim().isEmpty ? 'Master ${_subjectController.text.trim()}' : _goalController.text.trim(),
                        daysLeft: _daysLeft,
                        dailyMinutes: _dailyMinutes,
                        domain: _domain,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✨ New AI Study Plan Generated! Switched to Dashboard goals.'),
                            backgroundColor: Color(0xFF10B981),
                          ),
                        );
                      }
                    },
              icon: provider.isAiGenerating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(
                provider.isAiGenerating ? 'Synthesizing with Groq LLM...' : 'Generate Personalized Plan',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Generated Goals Preview
          const Text('Active Plan Goals:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          ...provider.goals.map((g) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF102A20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      g.isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: g.isCompleted ? const Color(0xFF10B981) : Colors.white38,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        g.title,
                        style: TextStyle(
                          color: g.isCompleted ? Colors.white54 : Colors.white,
                          decoration: g.isCompleted ? TextDecoration.lineThrough : null,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text('${g.targetMinutes}m', style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // TAB 2: Concept Explainer (any subject in the world)
  Widget _buildConceptExplainerTab(BuildContext context, StudyProvider provider) {
    final suggestions = categoryByName(_domain).examples;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF102A20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Text('🌍', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ask about ANY subject: science, medicine, law, history, commerce, languages, engineering, coding...',
                  style: TextStyle(color: Colors.grey.shade300, fontSize: 12),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          const Text('Subject Area', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          _categoryChips(const Color(0xFF38BDF8)),
          const SizedBox(height: 16),
          const Text('Concept to Explain', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 6),
          TextField(
            controller: _conceptController,
            style: const TextStyle(color: Colors.white),
            onSubmitted: (_) => _explain(provider),
            decoration: _inputDecoration('e.g., Mitosis, Black-Scholes model, Fundamental Rights, Pointers in C'),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: suggestions
                .map((s) => ActionChip(
                      label: Text(s, style: const TextStyle(fontSize: 11, color: Colors.white70)),
                      backgroundColor: const Color(0xFF102A20),
                      side: const BorderSide(color: Colors.white12),
                      onPressed: () {
                        _conceptController.text = s;
                        _explain(provider);
                      },
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          const Text('Explanation Style', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['Feynman Technique', 'Code & Complexity', 'ELI5 (Beginner)'].map((s) {
              final isSelected = _explanationStyle == s;
              return ChoiceChip(
                label: Text(s),
                selected: isSelected,
                selectedColor: const Color(0xFF38BDF8).withValues(alpha: 0.25),
                backgroundColor: const Color(0xFF102A20),
                labelStyle: TextStyle(
                  color: isSelected ? const Color(0xFF38BDF8) : Colors.white70,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (val) {
                  if (val) setState(() => _explanationStyle = s);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: provider.isAiGenerating ? null : () => _explain(provider),
              icon: provider.isAiGenerating
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.psychology_rounded),
              label: Text(provider.isAiGenerating ? 'Thinking...' : 'Explain Concept', style: const TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 22),
          if (provider.lastConceptExplanation != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF102A20),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: SelectionArea(child: MarkdownLite(data: provider.lastConceptExplanation!, accent: const Color(0xFF38BDF8))),
            ),
        ],
      ),
    );
  }

  /// Neat, equal-size grid of subject tiles (instead of a ragged wrap of chips).
  Widget _categoryChips(Color color) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final cols = w >= 1000 ? 5 : (w >= 700 ? 4 : (w >= 480 ? 3 : 2));
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: kStudyCategories.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          mainAxisExtent: 48,
        ),
        itemBuilder: (context, i) {
          final c = kStudyCategories[i];
          final isSelected = _domain == c.name;
          return Material(
            color: isSelected ? color.withValues(alpha: 0.22) : const Color(0xFF102A20),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _domain = c.name),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isSelected ? color : Colors.white12, width: isSelected ? 1.6 : 1),
                ),
                child: Row(children: [
                  Text(c.emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      c.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.15,
                        color: isSelected ? color : Colors.white70,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          );
        },
      );
    });
  }

  void _explain(StudyProvider provider) {
    final concept = _conceptController.text.trim();
    if (concept.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Type a topic first')));
      return;
    }
    provider.explainConcept(concept: concept, style: _explanationStyle);
  }

  // TAB 3: RAG & PDF Assistant
  Widget _buildRagAssistantTab(BuildContext context, StudyProvider provider) {
    final docs = provider.documents;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Upload card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [const Color(0xFF14532D).withValues(alpha: 0.6), const Color(0xFF102A20)]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Text('📚', style: TextStyle(fontSize: 24)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('Upload your notes or textbook PDF',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(
                  'Upload a PDF and the AI reads the WHOLE file: it summarizes it, explains the concepts in simple words and lets you ask questions (answers cite the [Page]).',
                  style: TextStyle(color: Colors.grey.shade300, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: provider.isUploading ? null : () => _pickAndUpload(provider),
                      icon: provider.isUploading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.upload_file_rounded),
                      label: Text(provider.isUploading ? 'Reading your file...' : 'Upload PDF / TXT',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: provider.isUploading ? null : () => _showAddDocumentDialog(context, provider),
                    icon: const Icon(Icons.edit_note_rounded, size: 20),
                    label: const Text('Paste text'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 18),

          const Text('Active Knowledge Bases', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          ...docs.map((d) => _docTile(provider, d)),
          const SizedBox(height: 14),
          _summarySection(provider),
          const SizedBox(height: 18),

          const Text('Ask your notes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _filterChip('All documents', _ragDocFilter == null, () => setState(() => _ragDocFilter = null)),
              ...docs.map((d) => _filterChip(d.title.length > 22 ? '${d.title.substring(0, 22)}...' : d.title,
                  _ragDocFilter == d.id, () => setState(() => _ragDocFilter = d.id))),
            ]),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _ragQueryController,
            style: const TextStyle(color: Colors.white),
            onSubmitted: (_) => _askRag(provider),
            decoration: _inputDecoration('e.g., What are the Coffman conditions for deadlock?'),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: provider.isAiGenerating ? null : () => _askRag(provider),
              icon: provider.isAiGenerating
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.search_rounded),
              label: Text(provider.isAiGenerating ? (provider.aiStatus.isEmpty ? 'Working...' : provider.aiStatus) : 'Retrieve Chunks & Answer',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (provider.lastRagAnswer != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF102A20),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
              ),
              child: SelectionArea(child: MarkdownLite(data: provider.lastRagAnswer!, accent: const Color(0xFFF59E0B))),
            ),
        ],
      ),
    );
  }

  Widget _summarySection(StudyProvider provider) {
    final docId = provider.summaryDocId;
    final busy = provider.isAiGenerating && provider.lastDocSummary == null && docId != null;
    if (!busy && provider.lastDocSummary == null) return const SizedBox.shrink();

    StudyDocument? doc;
    for (final d in provider.documents) {
      if (d.id == docId) doc = d;
    }
    final target = doc;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF102A20),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.auto_awesome_rounded, color: Color(0xFF34D399), size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text('PDF Summary & Explanation',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ]),
          const SizedBox(height: 12),
          if (busy)
            Row(children: [
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF34D399))),
              const SizedBox(width: 12),
              Expanded(
                child: Text(provider.aiStatus.isEmpty ? 'Reading your PDF...' : provider.aiStatus,
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ),
            ])
          else ...[
            SelectionArea(child: MarkdownLite(data: provider.lastDocSummary!)),
            if (target != null) ...[
              const SizedBox(height: 14),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 6, children: [
                ActionChip(
                  avatar: const Icon(Icons.summarize_rounded, size: 16, color: Color(0xFF34D399)),
                  label: const Text('Full summary', style: TextStyle(fontSize: 12, color: Colors.white)),
                  backgroundColor: const Color(0xFF0B1F17),
                  side: const BorderSide(color: Colors.white12),
                  onPressed: provider.isAiGenerating ? null : () => provider.summarizeDocument(target),
                ),
                ActionChip(
                  avatar: const Icon(Icons.lightbulb_outline_rounded, size: 16, color: Color(0xFFFBBF24)),
                  label: const Text('Explain concepts in detail', style: TextStyle(fontSize: 12, color: Colors.white)),
                  backgroundColor: const Color(0xFF0B1F17),
                  side: const BorderSide(color: Colors.white12),
                  onPressed: provider.isAiGenerating ? null : () => provider.summarizeDocument(target, mode: 'concepts'),
                ),
                ActionChip(
                  avatar: const Icon(Icons.quiz_outlined, size: 16, color: Color(0xFF38BDF8)),
                  label: const Text('Practice questions', style: TextStyle(fontSize: 12, color: Colors.white)),
                  backgroundColor: const Color(0xFF0B1F17),
                  side: const BorderSide(color: Colors.white12),
                  onPressed: provider.isAiGenerating ? null : () => provider.summarizeDocument(target, mode: 'questions'),
                ),
              ]),
            ],
          ],
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        selected: selected,
        selectedColor: const Color(0xFFF59E0B).withValues(alpha: 0.25),
        backgroundColor: const Color(0xFF102A20),
        labelStyle: TextStyle(color: selected ? const Color(0xFFF59E0B) : Colors.white70),
        onSelected: (_) => onTap(),
      ),
    );
  }

  Widget _docTile(StudyProvider provider, StudyDocument d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFF102A20), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(d.isBuiltIn ? Icons.menu_book_rounded : Icons.picture_as_pdf_rounded,
              color: d.isBuiltIn ? const Color(0xFF38BDF8) : Colors.redAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.title, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('${d.isBuiltIn ? "Sample" : "${d.pageCount} pages"} - ${d.chunkCount} chunks',
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ]),
          ),
          if (!d.isBuiltIn) ...[
            IconButton(
              tooltip: 'Summarize & explain this PDF',
              icon: const Icon(Icons.auto_awesome_rounded, size: 18, color: Color(0xFF34D399)),
              onPressed: provider.isAiGenerating ? null : () => provider.summarizeDocument(d),
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.white38),
              onPressed: () {
                if (_ragDocFilter == d.id) setState(() => _ragDocFilter = null);
                provider.removeDocument(d.id);
              },
            ),
          ],
        ],
      ),
    );
  }

  void _askRag(StudyProvider provider) {
    final q = _ragQueryController.text.trim();
    if (q.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Type a question first')));
      return;
    }
    provider.askRagAssistant(q, docId: _ragDocFilter);
  }

  Future<void> _pickAndUpload(StudyProvider provider) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'txt', 'md'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        messenger.showSnackBar(const SnackBar(content: Text('Could not read that file. Try again.'), backgroundColor: Colors.redAccent));
        return;
      }
      final doc = await provider.uploadDocument(fileName: file.name, bytes: bytes, domain: _domain);
      messenger.showSnackBar(SnackBar(
        content: Text('Read "${doc.title}" (${doc.pageCount} pages). Your summary is being created below - you can also ask questions!'),
        backgroundColor: const Color(0xFF10B981),
      ));
    } on FormatException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.redAccent));
    }
  }

  void _showAddDocumentDialog(BuildContext context, StudyProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0B1F17),
        title: const Text('Paste notes', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _newDocTitleController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Title (e.g. Biology Unit 2)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _newDocContentController,
                maxLines: 8,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Paste chapter notes or text...'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () async {
              final title = _newDocTitleController.text.trim();
              final content = _newDocContentController.text.trim();
              if (title.isEmpty || content.length < 40) return;
              Navigator.of(ctx).pop();
              try {
                await provider.addPastedNotes(title, content, _domain);
                _newDocTitleController.clear();
                _newDocContentController.clear();
              } on FormatException catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            child: const Text('Index notes', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
      filled: true,
      fillColor: const Color(0xFF102A20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF10B981))),
    );
  }
}
