# Sofi Saint App Architecture

## Overview
Fashion avatar design studio app with AI-powered outfit generation, featuring a freemium model with premium studio access.

---

## Current State Assessment ✅

### Pages & Navigation Flow
```
SplashPage (video intro) → SofiStudioPage (main) → PremiumStudioPage
                                                 → DiscoverPage
                                                 → ShareHubPage
                                                 → FavoritesHubPage
                                                 → SofiMusicPage
```

### Core Features
| Feature | Status | Notes |
|---------|--------|-------|
| **Splash Video** | 🟡 Pending | Streaming from Firebase Storage, needs rules fix |
| **Doll Selection** | ✅ Working | 10 base + 5 special dolls |
| **Outfit Categories** | ✅ Working | Hair, Top, Bottom, Shoes, Accessories, Hats, Jewelry, Glasses, Background |
| **AI Generation** | ✅ Working | ModelsLab + TwoStepGeneration services |
| **History/Undo** | ✅ Working | Local history with cloud backup |
| **Haptic Feedback** | ✅ Working | On buttons, generation events |
| **Audio SFX** | 🟡 Partial | AudioService exists, limited UI integration |
| **Cloud Storage** | 🟡 Partial | Upload works, some download issues on web |
| **Favorites** | ✅ Working | FavoritesManager with local + cloud sync |
| **Premium Studio** | ✅ Working | Male/Female bases, full outfit presets |
| **Share Hub** | ✅ Working | Social sharing capabilities |

### Services Architecture
```
lib/services/
├── storage_service.dart       # Firebase Storage wrapper
├── audio_service.dart         # SFX playback (click, generate, success, error)
├── generation_service.dart    # Base generation logic
├── image_gen_service.dart     # Image generation API
├── models_lab_service.dart    # ModelsLab API integration
├── two_step_generation_service.dart # Advanced generation pipeline
└── studio_transfer_service.dart # Transfer between studios
```

### Data Models
```
lib/presentation/sofi_studio/
├── sofi_studio_models.dart    # DollInfo, EditCategory, CategoryData
├── sofi_prompt_data.dart      # Prompt templates per category
├── favorites_manager.dart     # Favorite outfit persistence
├── custom_doll_storage.dart   # Cloud history management
└── state_snapshot.dart        # State serialization
```

### Assets (Local Bundle)
- 386 total assets
- Dolls: 10 base + 5 special (stage + thumb variants)
- Outfit items: 12 per category × 9 categories
- Audio: UI sounds (.ogg) + accent sounds (.mp3)
- Backgrounds: 12 options

---

## Known Issues 🐛

1. **Storage Download Failures (Web)**
   - Some HTTP fetches failing with `ClientException`
   - Object-not-found errors for orphaned references
   - Needs graceful fallback handling

2. **Splash Video Authorization**
   - Firebase Storage rules need `allow read: if true` for `/videos/**`
   - Currently blocked until user updates rules

3. **Audio Coverage**
   - AudioService exists but not connected to all interactive elements
   - Need to add sounds to: drawer tabs, tile selections, swipe actions

---

## Upgrade Roadmap 🚀

### Phase 1: Polish & Stability (Current Priority)
- [ ] Fix storage download error handling
- [ ] Complete audio integration across all buttons
- [ ] Add generation progress sounds
- [ ] Confirm splash video plays after rules fix

### Phase 2: Enhanced UX
- [ ] Add transition animations between pages
- [ ] Implement loading skeletons for thumbnails
- [ ] Add swipe gestures for history navigation
- [ ] Generation queue with progress indicator

### Phase 3: Premium Features
- [ ] Music player integration in studio
- [ ] Style presets library expansion
- [ ] Outfit recommendations based on favorites
- [ ] Social sharing templates

### Phase 4: Backend Optimization
- [ ] Migrate heavy assets to Firebase Storage
- [ ] Implement lazy loading for outfit thumbnails
- [ ] Add caching layer for generated images
- [ ] Analytics integration

---

## File Structure
```
lib/
├── main.dart                     # App entry, Firebase init
├── theme.dart                    # App-wide theme constants
├── firebase_options.dart         # Firebase config
├── models/                       # Shared data models
├── services/                     # Backend services
├── data/                         # Static data (theme presets)
├── utils/                        # Helpers (base64, etc.)
└── presentation/
    ├── splash/                   # Splash screen
    ├── shared/                   # Reusable widgets
    ├── sofi_studio/              # Main design studio
    │   ├── widgets/              # Studio UI components
    │   └── [controllers, models] 
    └── premium/                  # Premium tier pages
```

---

## Quick Commands

**Test splash video**: Update Firebase Storage rules, hot restart app

**Add new outfit item**: Add image to `assets/{category}/`, update `sofi_prompt_data.dart`

**Add new sound**: Add to `assets/audio/`, update `AudioService` paths

---

*Last updated: Current session*
