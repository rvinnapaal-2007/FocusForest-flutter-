/// Central configuration for Focus Forest.
///
/// The Groq key below is compiled into the web app so the AI works on the
/// deployed site (Firebase Hosting cannot run a Python backend on the free plan).
/// IMPORTANT: anything inside a web app can be read by visitors, so
///   1) create a NEW key at https://console.groq.com/keys (the old one was pasted in chat),
///   2) set a spend/usage limit on it, and
///   3) never commit this file to a public GitHub repository.
///
/// You can also keep the key out of the source entirely and pass it at build time:
///   flutter build web --dart-define=GROQ_API_KEY=your_key
class AppConfig {
  AppConfig._();

  static const String appName = 'Focus Forest';
  static const String tagline = 'Study with AI. Focus to grow your forest.';

  // ---- Groq ----
  static const String groqApiKey = String.fromEnvironment(
    'GROQ_API_KEY',
    defaultValue: 'your_groq_api_key_here',
  );
  static const String groqChatUrl = 'https://api.groq.com/openai/v1/chat/completions';

  /// Best quality model - used for answers, explanations and final summaries.
  static const String mainModel = 'openai/gpt-oss-120b';

  /// Fast model with its own rate-limit bucket - used as fallback and for long-PDF section notes.
  static const String fastModel = 'openai/gpt-oss-20b';

  /// Optional: if you deploy the Python backend (backend/main.py), pass its URL with
  ///   --dart-define=BACKEND_URL=https://your-backend.example.com/chat
  /// When empty (default) the app talks to Groq directly.
  static const String backendChatUrl = String.fromEnvironment('BACKEND_URL', defaultValue: '');

  static const String logoAsset = 'assets/images/focus_forest_logo.png';
  static const String iconAsset = 'assets/images/focus_forest_icon.png';
}
