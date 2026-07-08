# Stream-IT

Stream-IT is a premium, feature-rich Flutter client for browsing movies and TV shows powered by the **The Movie Database (TMDB)** API.

It is designed with a sleek dark-themed layout, smooth micro-interactions, robust network handling, and extensive content details (cast profiles, production companies, and zoomable artwork).

---

## Key Features

1. **Cast & Filmography Integrations**

   - Displays a horizontal scrolling **Cast** row on the Movie/TV Show details screen.
   - Tap on any cast member to navigate to their **Actor Profile Screen**, showing their profile details, biography, and a chronological grid of their entire filmography (movies/shows).
2. **Production Company Directories**

   - Integrated TMDB company searching directly into the search tab.
   - Displays dedicated **Company Screens** featuring company branding (logo), origin details, and headquarters.
   - Fetches the company's entire catalog upfront concurrently in parallel (using `Future.wait`) and supports sorting by release year.
3. **Artwork Enlarger & Gestures**

   - Click on the backdrop image on the details screen to open a high-resolution dialog view.
   - Integrated with `InteractiveViewer` supporting native **pinch-to-zoom** and **pan** gestures.
4. **App Lock & Biometric Protection**
   
   - Integrates `local_auth` to lock the application on startup.
   - Prompts the user for system biometrics (Fingerprint/FaceID) or device credentials (PIN/Pattern/Passcode) to unlock the app when screen lock protection is enabled.
5. **Instant Details Page & Background Stream Scrapers**

   - Separates fast TMDB data queries from third-party streaming providers.
   - The Details Screen renders metadata and cast instantly (under 300ms), while SpeedPorn and UiiUMovie scrapers run asynchronously in the background.
6. **Stable PiP Restore & Player Sandboxing**

   - Entering Picture-in-Picture (PiP) mode renders the video player borderless. Exiting PiP mode seamlessly restores the full-screen player, maintaining video playback continuity.
   - Protects the video player using a dual-layer sandbox that blocks ad redirects and intercepts popups (`window.open`).
7. **Search Settings & Preferences**

   - Stateful settings panel accessible directly from the Search bar.
   - Allows toggling adult content filters (`include_adult`) and biometric lock settings, persisting preferences locally using **Hive**.
8. **Dark Mode Loading & Auto-Rotation**

   - Features a black WebView canvas background and early HTML body color overrides to ensure zero white flashes during player initialization.
   - Supports freeform sensor-based rotation between normal and reverse landscape, automatically recovered when exiting PiP mode.
9. **Premium Exit Flow**

   - Intercepts system back-key presses at the root.
   - Pressing back on sub-tabs redirects to the **Home** tab first.
   - Pressing back on the **Home** tab prompts a custom Netflix-red dark-styled confirmation dialog asking *"Do you want to exit?"*.
10. **State & Routing Architecture**

   - State management powered by **Riverpod**.
   - Navigation and deep linking configured using **GoRouter**.

---

## Project Structure

```
lib/
├── models/             # Data models (ContentItem, etc.)
├── screens/            # Application views (Home, Details, Company, Person, Search, etc.)
├── services/           # TMDB API service and database connectivity
├── utils/              # DNS adapters and helpers
└── widgets/            # Custom reusable widgets (PosterCard, ContentCarousel, etc.)
```

---

## Setup & Running

### 1. Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (stable channel)
- Android SDK / JDK (for Android builds) or Xcode (for macOS/iOS targets)

### 2. Environment Configuration
Create a `config/dev.json` file in the root directory:
```json
{
  "TMDB_API_KEY": "your_tmdb_api_key_here",
  "TMDB_BASE_URL": "https://api.themoviedb.org/3"
}
```

### 3. Run the Application
Start the Android emulator or connect a device, then run:
```bash
flutter run --dart-define-from-file=config/dev.json
```

### 4. Build Signed Release APK
To build a signed release Android APK using the preconfigured keystore settings:
```bash
flutter build apk --release --dart-define-from-file=config/dev.json
```

The output signed APK will be located at:
`build/app/outputs/flutter-apk/app-release.apk`
