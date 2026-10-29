# Voice Notes

Voice notes that translate themselves. Record offline on your phone, and
the note syncs, transcribes, translates, and summarizes itself in the
background — a Flutter app backed by a Go API, a Redis job queue, and a
Python worker running Whisper, Google Translate, and an LLM summarizer.

Built as a portfolio project to demonstrate offline-first mobile
engineering and an async ML pipeline, not a from-scratch translation
engine — the "translate themselves" part leans on existing models and
APIs, glued together by the sync/pipeline architecture below.

**A note on the mascot:** rather than generic spinners, I experimented
with giving the app a small character that visibly reacts to what's
happening with a note — listening while recording, working while
transcribing, a happy pose once done. I'm not an illustrator, so these
are free, commercially-licensed line illustrations by
[Tegaki Desuno](https://regeld.com/desi/), not original artwork — a
deliberate scope choice to spend my time on the sync/pipeline
engineering instead.

This character was used only for project purposes, not to commercialize the character.

## Demo

[![Voice-note](https://img.youtube.com/vi/QywwFe8lqHU/0.jpg)](https://www.youtube.com/watch?v=QywwFe8lqHU)

## Architecture

```
┌─────────────┐      HTTP       ┌─────────────┐
│  Flutter    │ ───────────────▶│  Go server  │
│  (offline-  │◀─────────────── │  (chi,      │
│  first app) │   JSON/multipart│   pgx)      │
└─────────────┘                 └──────┬──────┘
      │                                │
      │ sqflite                        │ Postgres + Storage
      ▼                                ▼
┌─────────────┐                 ┌─────────────┐
│ Local SQLite│                 │  Supabase   │
│ (survives   │                 │ (Postgres,  │
│  restarts)  │                 │  Storage,   │
└─────────────┘                 │  Auth)      │
                                └──────┬──────┘
                                       │
                                       ▼
                                 ┌─────────────┐      LPUSH/BRPOP     ┌──────────────┐
                                 │   Redis     │◀─────────────────────│  Go server   │
                                 │   queue     │──────────────────────▶│  (on upload) │
                                 └──────┬──────┘                      └──────────────┘
                                        │
                                        ▼
                                 ┌──────────────────────────┐
                                 │     Python worker        │
                                 │  faster-whisper (STT)    │
                                 │  deep-translator (MT)    │
                                 │  OpenRouter LLM (summary)│
                                 └──────────────────────────┘
```

**Why this shape:** the phone never talks to Redis, Whisper, or the LLM
directly — it only ever talks to the Go server over plain HTTP, and the
Go server is the only thing that touches Postgres, Storage, and the job
queue. The worker is a separate process that can scale independently of
the API and never blocks a user-facing request.

## Status pipeline

A note moves through these states, each one visible in the UI:

```
(client-only)              (server-driven)
recording → pending → uploading → uploaded → transcribing
                                                  │
                                    ┌─────────────┘
                                    ▼
                          translating (only if a target
                          language was selected)
                                    │
                                    ▼
                              summarizing
                                    │
                                    ▼
                               summarized (done)

failed — reachable from any step; retryable
```

Each step saves its result immediately and degrades gracefully: if
translation or summarization fails (e.g. a rate limit), the transcript
already produced is never lost — the note still lands on `summarized`,
just missing that one piece.

## Tech stack

| Layer              | Tech                                                                                            |
| ------------------ | ----------------------------------------------------------------------------------------------- |
| Mobile app         | Flutter, sqflite (local DB), `record` (audio capture), `audioplayers` (playback), Supabase Auth |
| API server         | Go, chi (router), pgx (Postgres driver), go-redis                                               |
| Database & storage | Supabase (managed Postgres + private Storage bucket)                                            |
| Job queue          | Redis                                                                                           |
| Transcription      | faster-whisper (local, CPU, runs in the worker)                                                 |
| Translation        | deep-translator (Google Translate, free tier)                                                   |
| Summarization      | OpenRouter (free-tier LLM, model swappable via env var)                                         |

## Project structure

```
voice-notes/
├── app/            # Flutter mobile app
│   └── lib/
│       ├── config/       # server base URL
│       ├── models/       # Note, NoteStatus, supported languages
│       ├── screens/       # home, record, note detail, auth
│       ├── services/      # local DB, API client, sync, recorder, auth
│       ├── theme/         # color palette, typography
│       └── widgets/       # mascot (status-aware character)
├── server/         # Go API
│   └── internal/
│       ├── config/       # env var loading
│       ├── db/            # Postgres connection + migrations
│       ├── models/        # Note, NoteStatus
│       ├── notes/         # CRUD handlers/service/repository
│       ├── queue/         # Redis job push
│       └── upload/        # Supabase Storage client + upload handler
├── worker/         # Python background worker
│   ├── db/         # Postgres writes
│   ├── jobqueue/   # Redis consumer
│   ├── pipeline/   # transcribe, translate, summarize
│   └── storage/    # Supabase Storage downloads
└── docker-compose.yml   # local Redis
```

## Setup

### Prerequisites

- Go 1.22+
- Python 3.12+ (with `venv`)
- Flutter (recent stable)
- Docker (for local Redis)
- A free [Supabase](https://supabase.com) project
- A free [OpenRouter](https://openrouter.ai) API key

### 1. Supabase

1. Create a project. Note the Postgres connection string (**Project
   Settings → Database**) and the **service role** key (**Project
   Settings → API** — not the anon key).
2. Run the migrations in `server/internal/db/migrations/` against your
   project's SQL Editor, in order.
3. Create a **private** Storage bucket named `audio`.
4. Enable Email auth (**Authentication → Providers**). For local testing,
   disabling "Confirm sign up" avoids waiting on confirmation emails.

### 2. Redis

```bash
docker compose up -d redis
```

### 3. Go server

```bash
cd server
cp .env.example .env   # fill in DB_URL, SUPABASE_URL, SUPABASE_SERVICE_KEY, REDIS_URL
go mod tidy
go run cmd/api/main.go
```

### 4. Python worker

```bash
cd worker
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # same Supabase values, plus OPENROUTER_API_KEY
python main.py
```

First run downloads the Whisper model — expect a short delay before you
see "ready, waiting for jobs".

### 5. Flutter app

```bash
cd app
flutter pub get
```

Edit `lib/config/server_config.dart` — `localhost` means the device
itself, not your laptop:

- Android emulator → `http://10.0.2.2:8080`
- iOS simulator → `http://localhost:8080`
- Physical device → your laptop's LAN IP, e.g. `http://192.168.1.x:8080`

```bash
flutter run
```

## API reference

| Method   | Path                 | Purpose                                                     |
| -------- | -------------------- | ----------------------------------------------------------- |
| `POST`   | `/notes`             | Create a note (idempotent — safe to retry with the same ID) |
| `GET`    | `/notes/{id}`        | Fetch a note's current state                                |
| `GET`    | `/notes?user_id=`    | List a user's notes                                         |
| `PATCH`  | `/notes/{id}`        | Edit the transcript                                         |
| `DELETE` | `/notes/{id}`        | Delete a note                                               |
| `POST`   | `/notes/{id}/upload` | Upload audio, triggers the pipeline                         |

## Design decisions

- **Supabase over self-hosted Postgres/S3** — one free account covers
  managed Postgres, private object storage, and auth, which matters for
  a project built and demoed from a single laptop.
- **Offline-first via local SQLite, not a cache** — a recording is
  durable the instant it's saved locally, before any network call is
  attempted. The app works fully with no connectivity; sync is something
  that happens _to_ already-safe data, not a requirement for safety.
- **Idempotent note creation** — `POST /notes` upserts on conflict
  rather than erroring, so a retried request (flaky connection, app
  killed mid-sync) is always safe to resend.
- **Best-effort server sync for edits** — rename, delete, and transcript
  edits all update the local copy first and attempt a server sync
  second. The user's local state is never blocked on network success.
- **Polling over push** — the app checks note status on open and
  pull-to-refresh rather than holding a persistent connection. Simpler
  to reason about and sufficient for this use case; a production version
  with many concurrent users would likely move to websockets or SSE.

## Known limitations

- Editing a transcript does **not** re-trigger summarization or
  translation — the summary/translation will reflect the original
  transcript until a future version re-runs those steps on edit.
- Deleting a note removes it from Postgres but leaves its audio file
  orphaned in Supabase Storage (not yet cleaned up).
- No auth/ownership checks on the API — any request with a valid note ID
  can read/edit/delete it. Fine for a single-user demo, not production-ready.
- Audio upload is single-shot, not chunked or resumable — acceptable for
  short voice notes, but a large file on a flaky connection could fail
  outright rather than resuming.
- Conflict resolution for concurrent edits across multiple devices isn't
  implemented — the current model assumes one device per note. A
  production version would use the existing `version` column for
  last-writer-wins or a merge strategy.
- Translation (free Google Translate wrapper) and summarization
  (free OpenRouter models) can be rate-limited or change availability
  over time, since both rely on free tiers rather than paid, SLA-backed APIs.

## License

MIT. See [LICENSE](LICENSE).
