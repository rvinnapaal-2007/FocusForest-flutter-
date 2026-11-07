import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../models/study_goal.dart';
import '../models/forest_tree.dart';
import '../models/user_profile.dart';
import '../models/rag_chunk.dart';
import '../services/groq_service.dart';
import '../services/rag_service.dart';
import '../services/sync_service.dart';
import '../services/cloud_service.dart';
import '../services/focus_lock_service.dart';
import '../services/demo_data_service.dart';

enum AuthStatus { initializing, signedOut, loadingData, ready }

class StudyProvider with ChangeNotifier, WidgetsBindingObserver {
  final GroqService _groq = GroqService();
  final RagService _rag = RagService();
  final SyncService _sync = SyncService();
  final CloudService _cloud = CloudService();

  // ---- Auth / cloud ----
  AuthStatus _authStatus = AuthStatus.initializing;
  String? _uid;
  String? _email;
  String? _displayName;
  String? _cloudError;
  StreamSubscription<User?>? _authSub;
  Timer? _saveDebounce;

  // ---- Core data ----
  List<StudyGoal> _goals = [];
  List<ForestTree> _forestTrees = [];
  UserProfile _userProfile = _freshProfile();
  Map<String, int> _heatmap = {};

  // ---- Focus timer ----
  StudyGoal? _activeGoal;
  TreeSpecies _selectedTreeSpecies = TreeSpecies.pine;
  int _timerTotalSeconds = 25 * 60;
  int _timerSecondsRemaining = 25 * 60;
  bool _isTimerRunning = false;
  Timer? _countdownTimer;

  // ---- Leave-app detection (YouTube / WhatsApp / Instagram etc.) ----
  /// How long the user may be away from the app before the tree withers.
  static const Duration leaveGracePeriod = Duration(seconds: 10);
  DateTime? _sessionEndsAt; // wall-clock end of the running session
  DateTime? _leftAt; // when the app went to the background
  int _remainingAtLeave = 0;
  Timer? _leaveGraceTimer;
  bool _leftAppNotice = false;
  bool _justPlanted = false;

  // ---- AI state ----
  bool _isAiGenerating = false;
  bool _isUploading = false;
  String? _lastAiInsight;
  String? _lastConceptExplanation;
  String? _lastRagAnswer;
  String? _lastDocSummary;
  String? _summaryDocId;
  String _aiStatus = '';

  static UserProfile _freshProfile() => UserProfile.fresh();

  // ---- Getters ----
  AuthStatus get authStatus => _authStatus;
  String? get email => _email;
  String get displayName =>
      (_displayName != null && _displayName!.trim().isNotEmpty) ? _displayName! : (_email?.split('@').first ?? 'Learner');
  String? get cloudError => _cloudError;
  List<StudyGoal> get goals => List.unmodifiable(_goals);
  List<ForestTree> get forestTrees => List.unmodifiable(_forestTrees);
  UserProfile get userProfile => _userProfile;
  Map<String, int> get heatmap => Map.unmodifiable(_heatmap);
  SyncState get syncState => _sync.state;
  bool get isOnline => _sync.isOnline;
  DateTime? get lastSyncedAt => _sync.lastSyncedAt;
  StudyGoal? get activeGoal => _activeGoal;
  TreeSpecies get selectedTreeSpecies => _selectedTreeSpecies;
  int get timerSecondsRemaining => _timerSecondsRemaining;
  int get timerTotalSeconds => _timerTotalSeconds;
  bool get isTimerRunning => _isTimerRunning;
  bool get leftAppNotice => _leftAppNotice;

  /// Returns true once if a "you left the app" notice is pending.
  bool consumeLeftAppNotice() {
    final v = _leftAppNotice;
    _leftAppNotice = false;
    return v;
  }

  /// True from the moment a focus session starts until it is completed or
  /// abandoned (includes the paused state). Used to lock tab navigation.
  bool get isFocusSessionActive =>
      _isTimerRunning || _timerSecondsRemaining != _timerTotalSeconds;
  bool get justPlanted => _justPlanted;
  double get timerProgress =>
      _timerTotalSeconds > 0 ? 1.0 - (_timerSecondsRemaining / _timerTotalSeconds) : 0.0;
  bool get isAiGenerating => _isAiGenerating;
  bool get isUploading => _isUploading;
  String? get lastAiInsight => _lastAiInsight;
  String? get lastConceptExplanation => _lastConceptExplanation;
  String? get lastRagAnswer => _lastRagAnswer;
  String? get lastDocSummary => _lastDocSummary;
  String? get summaryDocId => _summaryDocId;
  String get aiStatus => _aiStatus;
  List<StudyDocument> get documents => _rag.documents;
  String get groqKey => _groq.apiKey;
  int get totalFocusMinutes => _heatmap.values.fold(0, (a, b) => a + b);

  StudyProvider() {
    WidgetsBinding.instance.addObserver(this);
    _groq.loadSavedKey();
    _sync.syncStream.listen((_) => notifyListeners());
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
  }

  // ==========================================
  //  AUTH + CLOUD LOAD
  // ==========================================
  Future<void> _onAuthChanged(User? user) async {
    if (user == null) {
      _detach();
      return;
    }
    if (_uid == user.uid && _authStatus == AuthStatus.ready) {
      _displayName = user.displayName;
      notifyListeners();
      return;
    }
    _uid = user.uid;
    _email = user.email;
    _displayName = user.displayName;
    _authStatus = AuthStatus.loadingData;
    notifyListeners();
    await _loadFromCloud();
    _authStatus = AuthStatus.ready;
    notifyListeners();
  }

  void _detach() {
    _saveDebounce?.cancel();
    _isTimerRunning = false;
    _countdownTimer?.cancel();
    FocusLockService.unlock();
    _uid = null;
    _email = null;
    _displayName = null;
    _cloudError = null;
    _goals = [];
    _forestTrees = [];
    _heatmap = {};
    _userProfile = _freshProfile();
    _activeGoal = null;
    _isTimerRunning = false;
    _timerTotalSeconds = 25 * 60;
    _timerSecondsRemaining = _timerTotalSeconds;
    _lastAiInsight = null;
    _lastConceptExplanation = null;
    _lastRagAnswer = null;
    _lastDocSummary = null;
    _summaryDocId = null;
    _rag.removeWhereUser();
    _authStatus = AuthStatus.signedOut;
    notifyListeners();
  }

  Future<void> _loadFromCloud() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final data = await _cloud.loadState(uid);
      if (data == null) {
        _goals = [];
        _forestTrees = [];
        _heatmap = {};
        _userProfile = _freshProfile();
        await _saveNow(); // create the user document
      } else {
        _applyMap(data);
      }
      final docs = await _cloud.loadDocuments(uid);
      _rag.replaceUserDocuments(docs.documents, docs.chunks);
      _cloudError = null;
      _sync.markSynced();
    } catch (e) {
      _cloudError = _friendlyCloudError(e);
      _sync.markOffline(_cloudError!);
    }
    _recomputeStreak();
    if (_goals.isNotEmpty) _activeGoal = _goals.firstWhere((g) => !g.isCompleted, orElse: () => _goals.first);
    computeCoachInsight();
  }

  String _friendlyCloudError(Object e) {
    final s = e.toString();
    if (s.contains('permission-denied')) {
      return 'Firestore permission denied. In Firebase Console > Firestore > Rules, publish the rules from firestore.rules.';
    }
    if (s.contains('not-found') || s.contains('NOT_FOUND')) {
      return 'Firestore database not found. In Firebase Console > Build > Firestore Database, click "Create database".';
    }
    if (s.contains('unavailable') || s.contains('network')) {
      return 'Cannot reach Firebase. Check your internet connection.';
    }
    return 'Cloud error: $s';
  }

  void _applyMap(Map<String, dynamic> data) {
    _userProfile = data['profile'] is Map
        ? UserProfile.fromMap(Map<String, dynamic>.from(data['profile'] as Map))
        : _freshProfile();
    _goals = (data['goals'] as List<dynamic>? ?? [])
        .map((e) => StudyGoal.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    _forestTrees = (data['trees'] as List<dynamic>? ?? [])
        .map((e) => ForestTree.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    final hm = data['heatmap'] as Map<dynamic, dynamic>? ?? {};
    _heatmap = hm.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
  }

  Map<String, dynamic> _toMap() => {
        'email': _email,
        'displayName': _displayName,
        'profile': _userProfile.toMap(),
        'goals': _goals.map((g) => g.toMap()).toList(),
        'trees': _forestTrees.map((t) => t.toMap()).toList(),
        'heatmap': _heatmap,
      };

  Future<bool> _saveNow() async {
    final uid = _uid;
    if (uid == null) return false;
    return _sync.run(() => _cloud.saveState(uid, _toMap()));
  }

  /// Debounced save so rapid taps produce one cloud write.
  void _triggerSync() {
    if (_uid == null) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 700), () async {
      final ok = await _saveNow();
      if (!ok) _cloudError = _friendlyCloudError(_sync.lastError ?? 'unknown');
      if (ok) _cloudError = null;
      notifyListeners();
    });
  }

  Future<void> syncNow() async {
    _saveDebounce?.cancel();
    final ok = await _saveNow();
    _cloudError = ok ? null : _friendlyCloudError(_sync.lastError ?? 'unknown');
    notifyListeners();
  }

  Future<void> setGroqKey(String key) async {
    await _groq.saveKey(key);
    notifyListeners();
  }

  // ==========================================
  //  AI STUDY COACH
  // ==========================================
  Future<void> generatePlanWithGroq({
    required String subject,
    required String goalTitle,
    required int daysLeft,
    required int dailyMinutes,
    String domain = 'General',
  }) async {
    _isAiGenerating = true;
    notifyListeners();

    final newGoals = await _groq.generateStudyPlan(
      subject: subject,
      goalTitle: goalTitle,
      daysLeft: daysLeft,
      dailyMinutes: dailyMinutes,
      domain: domain,
    );

    _goals = newGoals;
    if (_goals.isNotEmpty) _activeGoal = _goals.first;
    _isAiGenerating = false;
    _triggerSync();
    computeCoachInsight();
    notifyListeners();
  }

  Future<String> explainConcept({required String concept, String style = 'Feynman Technique'}) async {
    _isAiGenerating = true;
    _lastConceptExplanation = null;
    notifyListeners();
    final result = await _groq.explainConcept(concept: concept, style: style);
    _lastConceptExplanation = result;
    _isAiGenerating = false;
    notifyListeners();
    return result;
  }

  static final RegExp _summaryRequest = RegExp(
      r'\b(summari[sz]e|summary|overview|what is (this|the) (document|pdf|paper|file|note)|about (this|the) (document|pdf|paper|file|note)|main (points|ideas)|explain (this|the) (document|pdf|paper|file|note))\b',
      caseSensitive: false);

  Future<String> askRagAssistant(String query, {String? docId}) async {
    // "Summarize this PDF" style questions are answered from the WHOLE document, not just a few chunks.
    final userDocs = _rag.documents.where((d) => !d.isBuiltIn).toList();
    StudyDocument? target;
    if (docId != null) {
      for (final d in _rag.documents) {
        if (d.id == docId) target = d;
      }
    } else if (userDocs.isNotEmpty) {
      target = userDocs.last;
    }
    if (target != null && !target.isBuiltIn && _summaryRequest.hasMatch(query)) {
      await summarizeDocument(target);
      _lastRagAnswer = _lastDocSummary;
      notifyListeners();
      return _lastRagAnswer ?? '';
    }

    _isAiGenerating = true;
    _aiStatus = 'Searching your notes...';
    notifyListeners();
    final chunks = _rag.retrieveRelevantChunks(query, topK: 6, docId: docId);
    _aiStatus = 'Writing the answer...';
    notifyListeners();
    final answer = await _groq.answerWithRag(query: query, relevantChunks: chunks);
    _lastRagAnswer = answer;
    _isAiGenerating = false;
    _aiStatus = '';
    notifyListeners();
    return answer;
  }

  /// Index an uploaded file (PDF or text). Throws FormatException with a friendly message.
  Future<StudyDocument> uploadDocument({
    required String fileName,
    required Uint8List bytes,
    required String domain,
  }) async {
    _isUploading = true;
    notifyListeners();
    StudyDocument? doc;
    try {
      final lower = fileName.toLowerCase();
      final title = fileName.replaceAll(RegExp(r'\.(pdf|txt|md)$', caseSensitive: false), '');
      late final RagIngestResult result;
      if (lower.endsWith('.pdf')) {
        final pages = await _rag.extractPdfPages(bytes);
        result = _rag.ingestPages(title: title, pages: pages, domain: domain);
      } else {
        result = _rag.ingestText(title: title, content: const Utf8Decoder(allowMalformed: true).convert(bytes), domain: domain);
      }
      await _persistDocument(result);
      doc = result.document;
      return result.document;
    } finally {
      _isUploading = false;
      notifyListeners();
      // Automatically summarise + explain the new document for the student.
      if (doc != null) unawaited(summarizeDocument(doc));
    }
  }

  Future<StudyDocument> addPastedNotes(String title, String content, String domain) async {
    _isUploading = true;
    notifyListeners();
    StudyDocument? doc;
    try {
      final result = _rag.ingestText(title: title, content: content, domain: domain);
      await _persistDocument(result);
      doc = result.document;
      return result.document;
    } finally {
      _isUploading = false;
      notifyListeners();
      if (doc != null) unawaited(summarizeDocument(doc));
    }
  }

  Future<void> _persistDocument(RagIngestResult r) async {
    final uid = _uid;
    if (uid == null) return;
    final ok = await _sync.run(() => _cloud.saveDocument(uid, r.document, r.chunks));
    if (!ok) _cloudError = _friendlyCloudError(_sync.lastError ?? 'unknown');
  }

  Future<void> removeDocument(String docId) async {
    _rag.removeDocument(docId);
    notifyListeners();
    final uid = _uid;
    if (uid != null) await _sync.run(() => _cloud.deleteDocument(uid, docId));
    notifyListeners();
  }

  /// mode: 'full' (summary + concepts + exam questions), 'concepts', 'questions'
  Future<void> summarizeDocument(StudyDocument doc, {String mode = 'full'}) async {
    if (_isAiGenerating) return;
    _isAiGenerating = true;
    _summaryDocId = doc.id;
    _lastDocSummary = null;
    _aiStatus = 'Reading "${doc.title}"...';
    notifyListeners();

    // Rebuild the pages (in order) from the indexed chunks.
    final chunks = _rag.allChunks.where((c) => c.docId == doc.id).toList();
    final pages = <int, String>{};
    for (final c in chunks) {
      pages[c.pageNumber] = pages.containsKey(c.pageNumber) ? '${pages[c.pageNumber]}\n${c.content}' : c.content;
    }

    _lastDocSummary = await _groq.summarizeDocument(
      title: doc.title,
      pages: pages,
      mode: mode,
      onProgress: (status) {
        _aiStatus = status;
        notifyListeners();
      },
    );
    _isAiGenerating = false;
    _aiStatus = '';
    notifyListeners();
  }

  /// Used by the "AI status" dialog. Returns null when the AI works.
  Future<String?> testAi() => _groq.testConnection();

  // ==========================================
  //  INSIGHTS
  // ==========================================
  void computeCoachInsight() {
    _checkBadges();
    final total = _goals.length;
    final done = _goals.where((g) => g.isCompleted).length;
    final rate = total > 0 ? done / total : 0.0;

    if (total == 0) {
      _lastAiInsight = '🌱 Welcome, $displayName! Ask the AI Coach for a study plan, then plant your first tree in the Focus Forest.';
    } else if (rate >= 0.75) {
      _lastAiInsight = '🔥 Outstanding momentum! You completed ${(rate * 100).toInt()}% of your goals. Keep the streak alive!';
    } else if (hasSlipWarningForTomorrow()) {
      _lastAiInsight = '⚠️ Heads up for tomorrow: your focus tends to slip on ${_getTomorrowWeekdayName()}s. Plan a shorter 25-minute session!';
    } else {
      _lastAiInsight = '🌱 Steady growth: you have clocked $totalFocusMinutes focus minutes in total. Close your pending goals today.';
    }
    notifyListeners();
  }

  // ==========================================
  //  FOCUS TIMER + FOREST
  // ==========================================
  void setTimerGoal(StudyGoal? goal, {TreeSpecies? species, int minutes = 25}) {
    if (isFocusSessionActive) return; // don't reset a session in progress
    _activeGoal = goal;
    if (species != null) _selectedTreeSpecies = species;
    _timerTotalSeconds = minutes * 60;
    _timerSecondsRemaining = _timerTotalSeconds;
    _isTimerRunning = false;
    _justPlanted = false;
    _countdownTimer?.cancel();
    notifyListeners();
  }

  void selectTreeSpecies(TreeSpecies species) {
    if (_isTimerRunning) return;
    _selectedTreeSpecies = species;
    notifyListeners();
  }

  void setTimerMinutes(int minutes) {
    if (_isTimerRunning) return;
    _timerTotalSeconds = minutes * 60;
    _timerSecondsRemaining = _timerTotalSeconds;
    _justPlanted = false;
    notifyListeners();
  }

  void startFocusTimer() {
    if (_isTimerRunning) return;
    _isTimerRunning = true;
    _justPlanted = false;
    _leftAppNotice = false;
    _sessionEndsAt = DateTime.now().add(Duration(seconds: _timerSecondsRemaining));
    FocusLockService.lock(onFullscreenExit: _onFullscreenExit);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    notifyListeners();
  }

  /// Wall-clock based so the countdown stays correct even if the browser or
  /// OS throttles timers while the app is in the background.
  void _tick() {
    if (!_isTimerRunning || _sessionEndsAt == null) return;
    final remaining = _sessionEndsAt!.difference(DateTime.now()).inSeconds;
    if (remaining > 0) {
      _timerSecondsRemaining = remaining;
      notifyListeners();
    } else {
      _countdownTimer?.cancel();
      _isTimerRunning = false;
      _sessionEndsAt = null;
      _timerSecondsRemaining = 0;
      FocusLockService.unlock();
      _completeTimerSession();
    }
  }

  void pauseFocusTimer() {
    if (_isTimerRunning && _sessionEndsAt != null) {
      final remaining = _sessionEndsAt!.difference(DateTime.now()).inSeconds;
      _timerSecondsRemaining = remaining.clamp(1, _timerTotalSeconds);
    }
    _isTimerRunning = false;
    _sessionEndsAt = null;
    _countdownTimer?.cancel();
    FocusLockService.unlock();
    notifyListeners();
  }

  // ---- App lifecycle: detect the user leaving the app ----
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isTimerRunning) return;
    if (state == AppLifecycleState.hidden || state == AppLifecycleState.paused) {
      _markAway();
    } else if (state == AppLifecycleState.resumed && _leftAt != null) {
      final away = DateTime.now().difference(_leftAt!);
      _leaveGraceTimer?.cancel();
      if (away > leaveGracePeriod) {
        _failBecauseUserLeft();
      } else {
        _leftAt = null; // came back in time - session continues
        _tick();
      }
    }
  }

  void _markAway() {
    if (_leftAt != null) return;
    _leftAt = DateTime.now();
    _remainingAtLeave = _sessionEndsAt == null
        ? _timerSecondsRemaining
        : _sessionEndsAt!.difference(_leftAt!).inSeconds.clamp(0, _timerTotalSeconds);
    _leaveGraceTimer?.cancel();
    _leaveGraceTimer = Timer(leaveGracePeriod, _failBecauseUserLeft);
    notifyListeners();
  }

  /// Web: user pressed Esc / left browser fullscreen during a session.
  void _onFullscreenExit() {
    if (!_isTimerRunning) return;
    _fullscreenLost = true;
    _markAway();
  }

  /// True while the user has left fullscreen and must return (web).
  bool get fullscreenLost => _fullscreenLost && _isTimerRunning;
  bool _fullscreenLost = false;

  /// Called from a button tap (user gesture) to re-enter fullscreen and
  /// keep the session alive.
  void returnToFocus() {
    if (!_isTimerRunning) return;
    _leaveGraceTimer?.cancel();
    _leftAt = null;
    _fullscreenLost = false;
    FocusLockService.lock(onFullscreenExit: _onFullscreenExit);
    _tick();
    notifyListeners();
  }

  void _failBecauseUserLeft() {
    if (!_isTimerRunning) {
      _leftAt = null;
      return;
    }
    _leaveGraceTimer?.cancel();
    _timerSecondsRemaining = _remainingAtLeave;
    _leftAt = null;
    _fullscreenLost = false;
    _leftAppNotice = true;
    abandonFocusTimer(useShield: false, reason: 'Left the app');
  }

  void abandonFocusTimer({bool useShield = false, String reason = 'Abandoned'}) {
    _countdownTimer?.cancel();
    _leaveGraceTimer?.cancel();
    _leftAt = null;
    _fullscreenLost = false;
    _sessionEndsAt = null;
    _isTimerRunning = false;
    FocusLockService.unlock();
    final elapsed = ((_timerTotalSeconds - _timerSecondsRemaining) / 60).round();
    final subject = _activeGoal?.subject ?? 'General Focus';
    final title = _activeGoal?.title ?? 'Focus session';

    if (useShield && _userProfile.streakShields > 0) {
      _userProfile.streakShields--;
      _forestTrees.add(ForestTree(
        id: 'tree_${DateTime.now().millisecondsSinceEpoch}',
        species: _selectedTreeSpecies,
        plantedAt: DateTime.now(),
        durationMinutes: elapsed,
        isWithered: false,
        subject: subject,
        goalTitle: '$title (Shield Protected)',
      ));
    } else {
      _forestTrees.add(ForestTree(
        id: 'withered_${DateTime.now().millisecondsSinceEpoch}',
        species: _selectedTreeSpecies,
        plantedAt: DateTime.now(),
        durationMinutes: elapsed,
        isWithered: true,
        subject: subject,
        goalTitle: '$title ($reason)',
      ));
    }

    _timerSecondsRemaining = _timerTotalSeconds;
    _triggerSync();
    notifyListeners();
  }

  void _completeTimerSession() {
    final minutes = (_timerTotalSeconds / 60).round();
    final species = _selectedTreeSpecies;

    _forestTrees.add(ForestTree(
      id: 'tree_${DateTime.now().millisecondsSinceEpoch}',
      species: minutes >= 60 ? TreeSpecies.goldenBaobab : species,
      plantedAt: DateTime.now(),
      durationMinutes: minutes,
      isWithered: false,
      subject: _activeGoal?.subject ?? 'General Focus',
      goalTitle: _activeGoal?.title ?? 'Focus session',
    ));

    if (_activeGoal != null) {
      _activeGoal!.completedMinutes += minutes;
      if (!_activeGoal!.isCompleted && _activeGoal!.completedMinutes >= _activeGoal!.targetMinutes) {
        _activeGoal!.isCompleted = true;
        _awardXp(20);
      }
    }
    _awardXp(10);

    final key = _todayKey();
    _heatmap[key] = (_heatmap[key] ?? 0) + minutes;

    if (_goals.isNotEmpty && _goals.every((g) => g.isCompleted)) _awardXp(50);

    _justPlanted = true;
    _recomputeStreak();
    _timerSecondsRemaining = _timerTotalSeconds;
    _triggerSync();
    computeCoachInsight();
    notifyListeners();
  }

  // ==========================================
  //  HEATMAP / STREAK
  // ==========================================
  int getMinutesForDate(DateTime date) => _heatmap[_keyFor(date)] ?? 0;

  String _keyFor(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _todayKey() => _keyFor(DateTime.now());

  void _recomputeStreak() {
    var day = DateTime.now();
    if ((_heatmap[_keyFor(day)] ?? 0) == 0) day = day.subtract(const Duration(days: 1));
    var streak = 0;
    while ((_heatmap[_keyFor(day)] ?? 0) > 0) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    _userProfile.currentStreak = streak;
    if (streak > _userProfile.longestStreak) _userProfile.longestStreak = streak;
  }

  void consumeShield() {
    if (_userProfile.streakShields > 0) {
      _userProfile.streakShields--;
      _triggerSync();
      notifyListeners();
    }
  }

  // ==========================================
  //  XP & GOALS
  // ==========================================
  void _awardXp(int amount) {
    _userProfile.xp += amount;
    if (_userProfile.currentStreak > 0 && _userProfile.currentStreak % 7 == 0) {
      _userProfile.streakShields++;
    }
  }

  void toggleGoalCompletion(StudyGoal goal) {
    goal.isCompleted = !goal.isCompleted;
    if (goal.isCompleted) {
      _awardXp(20);
      if (_goals.isNotEmpty && _goals.every((g) => g.isCompleted)) _awardXp(50);
    } else {
      final xp = _userProfile.xp - 20;
      _userProfile.xp = xp < 0 ? 0 : xp;
    }
    _triggerSync();
    computeCoachInsight();
    notifyListeners();
  }

  void incrementCodingStat(String platform, {String difficulty = 'Medium'}) {
    if (platform == 'LeetCode') {
      if (difficulty == 'Easy') _userProfile.leetCodeEasy++;
      if (difficulty == 'Medium') _userProfile.leetCodeMedium++;
      if (difficulty == 'Hard') _userProfile.leetCodeHard++;
    } else if (platform == 'HackerRank') {
      _userProfile.hackerRankBadges++;
    } else if (platform == 'CodeChef') {
      _userProfile.codeChefRating += 15;
    }
    _awardXp(15);
    _checkBadges();
    _triggerSync();
    notifyListeners();
  }

  void _checkBadges() {
    final thriving = _forestTrees.where((t) => !t.isWithered).length;
    final withered = _forestTrees.length - thriving;
    final unlock = <String, bool>{
      '7_day_warrior': _userProfile.currentStreak >= 7 || _userProfile.longestStreak >= 7,
      'deep_focus': _forestTrees.any((t) => !t.isWithered && t.durationMinutes >= 60),
      'perfect_day': _goals.isNotEmpty && _goals.every((g) => g.isCompleted),
      'algo_knight': _userProfile.totalLeetCodeSolved >= 25,
      'early_bird': _forestTrees.any((t) => !t.isWithered && t.plantedAt.hour < 8),
      'forest_guardian': thriving >= 20 && withered == 0,
    };
    _userProfile.badges = _userProfile.badges
        .map((b) => (b.isUnlocked || unlock[b.id] == true)
            ? UserBadge(id: b.id, title: b.title, description: b.description, icon: b.icon, isUnlocked: true)
            : b)
        .toList();
  }

  // ==========================================
  //  SLIP ALERTS (derived from real heatmap)
  // ==========================================
  bool hasSlipWarningForTomorrow() {
    final tomorrow = DateTime.now().add(const Duration(days: 1)).weekday;
    var seen = 0, hit = 0;
    for (var i = 1; i <= 56; i++) {
      final d = DateTime.now().subtract(Duration(days: i));
      if (d.weekday != tomorrow) continue;
      seen++;
      if ((_heatmap[_keyFor(d)] ?? 0) >= 25) hit++;
    }
    if (seen < 3) return false;
    return hit / seen < 0.5;
  }

  String getSlipWarningMessage() =>
      '⚠️ Heads up! You have historically completed fewer sessions on ${_getTomorrowWeekdayName()}s. Consider a shorter session or an early start.';

  String _getTomorrowWeekdayName() {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[DateTime.now().add(const Duration(days: 1)).weekday - 1];
  }

  // ==========================================
  //  DEMO DATA & RESET
  // ==========================================
  void loadDemoData() {
    final demo = DemoDataService.generate60DayDemoPackage();
    _heatmap = Map<String, int>.from(demo['heatmap']);
    _forestTrees = List<ForestTree>.from(demo['trees']);
    _goals = List<StudyGoal>.from(demo['goals']);
    _userProfile = demo['profile'];
    _recomputeStreak();
    if (_goals.isNotEmpty) setTimerGoal(_goals.first, minutes: 25);
    computeCoachInsight();
    _triggerSync();
    notifyListeners();
  }

  void resetAllData() {
    _goals = [];
    _forestTrees = [];
    _heatmap = {};
    _userProfile = _freshProfile();
    _lastAiInsight = null;
    _lastConceptExplanation = null;
    _lastRagAnswer = null;
    _timerTotalSeconds = 25 * 60;
    _timerSecondsRemaining = _timerTotalSeconds;
    _isTimerRunning = false;
    _countdownTimer?.cancel();
    _activeGoal = null;
    computeCoachInsight();
    _triggerSync();
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _isTimerRunning = false;
    FocusLockService.unlock();
    _countdownTimer?.cancel();
    _leaveGraceTimer?.cancel();
    _saveDebounce?.cancel();
    _authSub?.cancel();
    _sync.dispose();
    super.dispose();
  }
}
