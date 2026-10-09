# App Store assets

Upload-ready art for App Store Connect. Folders starting with `_review-only` are previews with guides; don't upload them.

| Folder | What | Where it goes in App Store Connect |
|---|---|---|
| `app-store-2.2.0/` | Product page header (3840×1646) and search results image (3840×2560) | Asset Library → submit → live version → **Header and Search Results** → Publish (no new build; iOS 27+) |
| `cpp-bible-trivia-challenge/` | Custom product page: 6 connected iPhone (1206×2622) and iPad (2064×2752) screenshots, plus an iPhone app preview (886×1920, 29.5 s) | **Custom Product Pages** → "Bible Trivia Challenge" → App Previews and Screenshots (iPhone / iPad tabs), in panel order |

All images are RGB PNGs with no alpha. Store art must not show prices or discount codes.

## Custom product page: Bible Trivia Challenge

**Screenshots connect across panels.** One set of gold roots and a gold thread runs through all six screenshots, so they read as one strip as people swipe. For the joins to line up:

- Upload the six files in each device folder **in number order, 01 → 06**, and don't skip any.
- Upload the iPhone set on the **iPhone** tab and the iPad set on the **iPad** tab. These go in the **App Previews and Screenshots** section, not the Header box, which only accepts 3840×1646 or 5244×2950.
- Put the video from `app_preview_iphone_886x1920/` in the iPhone preview slot.
- Click **Preview** in App Store Connect and swipe through the screenshots. They should match `_review-only/panorama_iphone.png`.

**The panoramas are for review only.** The files in `_review-only/` show all six panels side by side, which is what someone swiping will see. Don't upload them.

**Promotional text** (max 170 characters; changes on a custom product page need App Review, but no build):

| When | Text |
|---|---|
| During the competition (159 chars) | New: a Bible question every day. Build your streak, challenge your mentor, and climb the 60-Day Launch Competition leaderboard (Nov 1–Dec 30) for merch prizes. |
| After Dec 30 (124 chars) | Grow in God's Word one question at a time. Build a daily streak, challenge your mentor head-to-head, and see where you rank. |

Keep dollar amounts out of store copy; prize details belong in emails and the in-app rules.

**Keywords:** choose trivia-focused ones from the app's keyword list, such as bible trivia, bible quiz, scripture quiz, christian trivia, bible game.

**After approval:** copy the page's unique URL for launch emails and social posts. Results show up under **Analytics → Acquisition**.

**After the competition:** the art and copy mention the 60-Day Competition, so after Dec 30, switch to the timeless promotional text and recapture the screenshots (see below), or retire the page.

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
