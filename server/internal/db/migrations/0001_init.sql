CREATE TABLE notes (
    id UUID PRIMARY KEY,              -- client-generated
    user_id UUID NOT NULL,
    title TEXT,
    status TEXT NOT NULL DEFAULT 'uploaded',  -- uploaded/transcribing/translating/summarized/failed
    audio_path TEXT,
    transcript TEXT,
    translated_text TEXT,
    summary TEXT,
    version INT NOT NULL DEFAULT 1,   -- for conflict resolution later
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notes_user_id ON notes(user_id);

ALTER TABLE notes ADD COLUMN IF NOT EXISTS target_language TEXT;