# Focus Forest - AI Study Coach

Flutter web app: login, AI study plans for any subject, an explain-anything tutor, PDF summaries + Q&A,
a focus timer that grows your forest, Coders Hub and a 91-day heatmap. Data is stored per user in
Firebase (project `habitsynch`).

## Run locally
```powershell
flutter pub get
flutter run -d chrome
```
The AI works out of the box: the Groq key lives in `lib/config/app_config.dart`
(or pass it with `--dart-define=GROQ_API_KEY=your_key`). No Python backend is needed.

## Deploy (Firebase Hosting)
```powershell
flutter build web --release
firebase deploy --only hosting
```
Then hard-refresh the site (Ctrl+Shift+R) so the browser loads the new build.

## Check the AI
Open the avatar menu (top right) -> **AI connection test**. It tells you in plain words if the key,
network or rate limit is the problem.

## Security note about the Groq key
A key inside a web app can be read by anyone who opens the site. Create your own key at
https://console.groq.com/keys, set a usage limit, replace the one in `app_config.dart`, and do not
publish this project publicly with the key in it. For a fully private key, run `backend/` somewhere
(Render, Railway, Cloud Run...) and build with `--dart-define=BACKEND_URL=https://your-backend/chat`.

## Firebase one-time setup (Firebase Console -> project habitsynch)
1. **Authentication -> Sign-in method**: enable **Email/Password** and **Google**.
2. **Authentication -> Settings -> Authorized domains**: `localhost` and `habitsynch.web.app` must be listed.
3. **Firestore Database** -> create database, then paste `firestore.rules` into **Rules** and Publish.

## Firestore layout
```
users/{uid}                    profile, goals, trees, heatmap
users/{uid}/documents/{id}     uploaded PDF / notes metadata
users/{uid}/chunks/{id}        indexed text chunks (page number kept for citations)
```

## Notes
- PDF text extraction uses `syncfusion_flutter_pdf`. Scanned PDFs (images only) have no text to read.
- Very long PDFs are summarized from up to 6 evenly spread sections to stay inside Groq's free-tier limits.
