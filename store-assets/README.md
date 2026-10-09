# App Store assets

Upload-ready art for App Store Connect. Folders starting with `_review-only` are previews with guides; don't upload them.

| Folder | What | Where it goes in App Store Connect |
|---|---|---|
| `app-store-2.2.0/` | Product page header (3840×1646) and search results image (3840×2560) | Asset Library → submit → live version → **Header and Search Results** → Publish (no new build; iOS 27+) |
| `cpp-bible-trivia-challenge/` | Custom product page: 6 connected iPhone (1206×2622) and iPad (2064×2752) screenshots, plus an iPhone app preview (886×1920, 29.5 s) | **Custom Product Pages** → "Bible Trivia Challenge" → App Previews and Screenshots (iPhone / iPad tabs), in panel order |

All images are RGB PNGs with no alpha. Store art must not show prices or discount codes.

## Rebuilding

The screenshots and video are real app screens captured from the iOS simulator by
`integration_test/store_capture_test.dart`, which serves **fictional demo data** (no backend, no real users).

Requirements: Xcode simulators, Google Chrome, Python 3 with Pillow, `ffmpeg` (`brew install ffmpeg`).

```bash
cd store-assets/tools
python3 make_assets.py                                  # header + search results → build/header_search/
python3 capture.py <iphone-17-pro-udid> build/iphone    # screenshots (CAPTURE markers → simctl screenshot)
python3 capture.py <ipad-pro-13-udid>   build/ipad
python3 compose_cpp.py iphone && python3 compose_cpp.py ipad   # connected panels → build/final_*/
python3 capture.py <iphone-17-pro-udid> build/video video      # screen recording + scene timings
python3 finish_video.py                                 # captions, end card, Apple spec → build/final_video/
cd ../.. && flutter build ios --config-only             # flutter test repoints Generated.xcconfig
```

Find simulator IDs with `xcrun simctl list devices available`. Copy the results from `tools/build/` (gitignored)
into a new dated folder here. The wordmark font is Special Elite (Apache 2.0) in `tools/fonts/`.
