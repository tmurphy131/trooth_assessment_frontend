# Contracts

The app uses the backend API contract defined in the backend repo. It is the source of truth (constitution Principle XII):

**[trooth_assessment_backend/specs/001-trivia-integrity/contracts/trivia-api.md](../../../../trooth_assessment_backend/specs/001-trivia-integrity/contracts/trivia-api.md)**

Endpoints this app version uses or changes behaviour for:

| Endpoint | Used for | Status codes the app handles |
|---|---|---|
| `POST /trivia/single/start` | Start a game | 200; 400 (no questions) → message on setup |
| `POST /trivia/single/{id}/answer` | Answer or time out (`selected: null`) | 200; 409 → re-sync; 404 → error and exit; 400 (not expected) → error |
| `POST /trivia/single/{id}/grace` | Use or decline a grace token | 200; 409 → re-sync; 404 |
| `POST /trivia/single/{id}/finish` | Results, or leave mid-game | 200; 404 |
| `POST /trivia/challenges` | Create challenge | 200; **403 → upgrade prompt** |

No longer called (minimum app version **2.2.0**): `GET /trivia/questions/draw`, `POST /trivia/single/submit`.
