# Implementation Plan: Flutter Streaming App (VidAPI + TMDB/IMDB)

This document outlines the architecture, data flow, and implementation steps for building a cross-platform mobile and web streaming application using Flutter, powered by **VidAPI** for video delivery and **TMDB/IMDB** for rich metadata.

## 1. Project Overview & Architecture

**Goal**: Create a premium, Netflix-style streaming application that works seamlessly on iOS, Android, and Web browsers.
**Tech Stack**:
*   **Framework**: Flutter (Dart)
*   **State Management**: Riverpod (or Provider) for scalable and predictable state.
*   **Routing**: `go_router` for deep linking and web URL support.
*   **Networking**: `dio` or `http` for API requests.
*   **Local Storage**: `shared_preferences` or `hive` (for watch history and bookmarks).
*   **Video Playback**: 
    *   *Mobile (iOS/Android)*: `webview_flutter` to render the VidAPI iframe.
    *   *Web*: `HtmlElementView` with a native `<iframe>` tag for optimal web performance.

## 2. Data Strategy

The app will use a hybrid data approach, leveraging both TMDB and VidAPI's endpoints.

### A. Metadata & Catalog (TMDB API)
While VidAPI provides recent listings, the **TMDB API** will be the primary source of truth for the app's catalog to ensure rich metadata (high-res backdrops, cast, trailers, recommendations, and robust search functionality).
*   **Endpoints to use**:
    *   `/trending/all/day` (Home page carousel)
    *   `/movie/popular`, `/tv/popular` (Category rows)
    *   `/search/multi` (Search functionality)
    *   `/movie/{movie_id}`, `/tv/{tv_id}` (Details page)

### B. Video Streaming (VidAPI)
Once a user selects a movie or TV show, the app will pass the TMDB ID (or IMDB ID) to the VidAPI embed player.
*   **Movies**: `https://vaplayer.ru/embed/movie/{tmdb_id}` (or `?imdb={imdb_id}`)
*   **TV Shows**: `https://vaplayer.ru/embed/tv/{tmdb_id}/{season}/{episode}`
*   **Features to utilize**:
    *   Custom themes via URL params (e.g., `?primaryColor=%23E50914` for Netflix red).
    *   Resume playback via `?resumeAt={seconds}`.

## 3. Core Features & UI/UX

*   **Premium Dark Theme**: Sleek, glassmorphism elements, dark background (`#141414`), and vibrant primary accents.
*   **Home Screen**:
    *   Hero section with a featured trending movie/show.
    *   Horizontal scrolling lists (Popular, Top Rated, Action, Comedy, etc.).
*   **Search & Discovery**:
    *   Real-time search using TMDB API.
    *   Grid view of results.
*   **Details Screen**:
    *   Large backdrop image with a gradient fade.
    *   Synopsis, rating, runtime, and cast.
    *   "Play" button, and for TV Shows, a Season/Episode selector.
*   **Video Player Screen**:
    *   Full-screen WebView/iframe.
    *   Javascript bridge implementation to listen to `PLAYER_EVENT` messages (to save playback progress `player_progress` for the "Continue Watching" feature).

## 4. Phased Implementation Steps

### Phase 1: Setup & Core Integration
1.  Initialize a new Flutter project (`flutter create streaming_app --platforms android,ios,web`).
2.  Set up TMDB API keys and create a networking service (`api_service.dart`) to fetch and parse TMDB JSON responses.
3.  Create data models (`Movie`, `TVShow`, `Episode`).
4.  Set up Riverpod providers to manage the state of the Home Screen (fetching popular/trending content).

### Phase 2: UI Development
1.  Build the **Home Screen** with horizontal carousels (`ListView.builder` horizontal).
2.  Build the **Details Screen** with slivers (`SliverAppBar` for the backdrop image).
3.  Build the **Search Screen** with a debounce search input.
4.  Implement navigation between these screens using `go_router`.

### Phase 3: VidAPI Player Integration
1.  Create a `PlayerScreen` widget.
2.  **Mobile Implementation**: 
    *   Install `webview_flutter`.
    *   Configure the WebView to load the VidAPI URL based on the passed TMDB ID.
    *   Inject JavaScript channels to listen to the `PLAYER_EVENT` `postMessage` to track watch progress.
3.  **Web Implementation**:
    *   Register a view factory using `dart:ui_web`.
    *   Create an `HtmlElementView` that renders an `<iframe>` pointing to the VidAPI URL.
    *   Use `window.addEventListener('message', ...)` in Dart interop to track progress.

### Phase 4: Polish & Advanced Features
1.  **Watch History & Resume**: Save progress to `shared_preferences`. When opening a video, append `?resumeAt={saved_progress}` to the VidAPI URL.
2.  **Bookmarks/Watchlist**: Allow users to save items locally.
3.  **TV Show Seasons**: Fetch season/episode data from TMDB and create a bottom sheet or dropdown to select episodes, passing the dynamic season/episode numbers to the VidAPI URL.
4.  **Platform Optimization**: Ensure responsive design (grid cross-axis count changes based on screen width for web/tablets).

## 5. Security & Considerations
*   **Domain Whitelisting**: Ensure the web app's domain (once deployed) is added to the VidAPI dashboard to prevent unauthorized usage.
*   **CORS & API Keys**: Keep TMDB API keys secure. If deploying to production, consider a lightweight backend proxy (Node.js/Cloudflare Worker) to hide the TMDB API key instead of embedding it directly in the Flutter client.
