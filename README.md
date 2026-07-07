# Vid API

Vid API is a premium, feature-rich Flutter client for browsing movies and TV shows powered by the **The Movie Database (TMDB)** API.

It is designed with a sleek dark-themed layout, smooth micro-interactions, robust network handling, and extensive content details (cast profiles, production companies, and zoomable artwork).

---

## Key Features

1. **Robust Networking (DNS-over-HTTPS)**

   - Configured with a `CustomDnsAdapter` on top of the Dio client.
   - Bypasses network resolution blocks automatically by querying Cloudflare/Google DNS endpoints securely over HTTPS.
2. **Cast & Filmography Integrations**

   - Displays a horizontal scrolling **Cast** row on the Movie/TV Show details screen.
   - Tap on any cast member to navigate to their **Actor Profile Screen**, showing their profile details, biography, and a chronological grid of their entire filmography (movies/shows).
3. **Production Company Directories**

   - Integrated TMDB company searching directly into the search tab.
   - Displays dedicated **Company Screens** featuring company branding (logo), origin details, and headquarters.
   - Fetches the company's entire catalog upfront concurrently in parallel (using `Future.wait`) and supports sorting by release year.
4. **Artwork Enlarger & Gestures**

   - Click on the backdrop image on the details screen to open a high-resolution dialog view.
   - Integrated with `InteractiveViewer` supporting native **pinch-to-zoom** and **pan** gestures.
5. **Premium Exit Flow**

   - Intercepts system back-key presses at the root.
   - Pressing back on sub-tabs redirects to the **Home** tab first.
   - Pressing back on the **Home** tab prompts a custom Netflix-red dark-styled confirmation dialog asking *"Do you want to exit?"*.
6. **State & Routing Architecture**

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

Create a `.env` file in the root directory:

```env
TMDB_API_KEY=your_tmdb_api_key_here
TMDB_BASE_URL=https://api.themoviedb.org/3
```

### 3. Run the Application

Start the Android emulator or connect a device, then run:

```bash
flutter run
```

### 4. Build Signed Release APK

To build a signed release Android APK using the preconfigured keystore settings:

```bash
flutter build apk --release
```

The output signed APK will be located at:
`build/app/outputs/flutter-apk/app-release.apk`
