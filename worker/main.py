import os
import time

from dotenv import load_dotenv

from db.client import Database
from pipeline.transcribe import Transcriber
from job_queue.consumer import JobConsumer
from storage.clientStorage import SupabaseStorage
from pipeline.translate import Translator
from pipeline.summarize import Summarizer

load_dotenv()


DB_URL = os.environ["DB_URL"]
SUPABASE_URL = os.environ["SUPABASE_URL"]
SUPABASE_SERVICE_KEY = os.environ["SUPABASE_SERVICE_KEY"]
SUPABASE_BUCKET = os.environ.get("SUPABASE_BUCKET", "audio")
REDIS_URL = os.environ.get("REDIS_URL", "redis://localhost:6379/0")
WHISPER_MODEL_SIZE = os.environ.get("WHISPER_MODEL_SIZE", "base")
OPENROUTER_API_KEY = os.environ["OPENROUTER_API_KEY"]
OPENROUTER_MODEL = os.environ.get("OPENROUTER_MODEL", "meta-llama/llama-3.1-8b-instruct:free")


def process_job(
    job: dict,
    db: Database,
    storage: SupabaseStorage,
    transcriber: Transcriber,
    translator: Translator,
    summarizer: Summarizer,
) -> None:
    note_id = job["note_id"]
    audio_path = job["audio_path"]
    target_language = job.get("target_language")

    print(f"[worker] picked up job for note {note_id} (target_language={target_language})")

    local_path = None
    try:
        local_path = storage.download_to_tempfile(audio_path)
        transcript = transcriber.transcribe(local_path)
    except Exception as exc:
        print(f"[worker] transcription failed for note {note_id}: {exc}")
        db.mark_failed(note_id)
        if local_path and os.path.exists(local_path):
            os.remove(local_path)
        return

    # Transcription succeeded — save immediately so it's never lost,
    # regardless of what happens in the steps after this.
    next_status = "translating" if target_language else "summarizing"
    db.save_transcript(note_id, transcript, status=next_status)
    print(f"[worker] note {note_id} transcribed ({len(transcript)} chars)")

    if target_language:
        try:
            translated = translator.translate(transcript, target_language)
            db.save_translation(note_id, translated, status="summarizing")
            print(f"[worker] note {note_id} translated ({len(translated)} chars)")
        except Exception as exc:
            # Translation failed — transcript is safe, move on to
            # summarization anyway rather than losing the whole note.
            print(f"[worker] translation failed for note {note_id} (transcript kept): {exc}")
            db.update_status(note_id, "summarizing")

    try:
        summary = summarizer.summarize(transcript)
        db.save_summary(note_id, summary, status="summarized")
        print(f"[worker] note {note_id} summarized ({len(summary)} chars)")
    except Exception as exc:
        # Summarization failed — transcript (and translation, if any) are
        # still saved. Land on "summarized" anyway so the note isn't
        # stuck "in progress" forever; it just won't have a summary.
        print(f"[worker] summarization failed for note {note_id} (transcript/translation kept): {exc}")
        db.update_status(note_id, "summarized")

    if local_path and os.path.exists(local_path):
        os.remove(local_path)


def main():
    db = Database(DB_URL)
    storage = SupabaseStorage(SUPABASE_URL, SUPABASE_SERVICE_KEY, SUPABASE_BUCKET)
    consumer = JobConsumer(REDIS_URL)

    print("[worker] loading whisper model (this can take a moment on first run)...")
    transcriber = Transcriber(WHISPER_MODEL_SIZE)
    translator = Translator()
    summarizer = Summarizer(OPENROUTER_API_KEY, OPENROUTER_MODEL)
    print("[worker] ready, waiting for jobs")

    while True:
        job = consumer.next_job()
        if job is None:
            continue
        try:
            process_job(job, db, storage, transcriber, translator, summarizer)
        except Exception as exc:
            print(f"[worker] unexpected error processing job {job}: {exc}")
            time.sleep(1)


if __name__ == "__main__":
    main()
