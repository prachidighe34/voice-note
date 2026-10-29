import psycopg2


class Database:
    def __init__(self, db_url: str):
        self.db_url = db_url

    def _connect(self):
        return psycopg2.connect(self.db_url)

    def update_status(self, note_id: str, status: str) -> None:
        with self._connect() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "UPDATE notes SET status = %s, updated_at = now() WHERE id = %s",
                    (status, note_id),
                )

    def save_transcript(self, note_id: str, transcript: str, status: str) -> None:
        with self._connect() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    UPDATE notes
                    SET transcript = %s, status = %s, updated_at = now()
                    WHERE id = %s
                    """,
                    (transcript, status, note_id),
                )

    def save_translation(self, note_id: str, translated_text: str, status: str) -> None:
        with self._connect() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    UPDATE notes
                    SET translated_text = %s, status = %s, updated_at = now()
                    WHERE id = %s
                    """,
                    (translated_text, status, note_id),
                )

    def save_summary(self, note_id: str, summary: str, status: str) -> None:
        with self._connect() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    UPDATE notes
                    SET summary = %s, status = %s, updated_at = now()
                    WHERE id = %s
                    """,
                    (summary, status, note_id),
                )

    def get_target_language(self, note_id: str) -> str | None:
        with self._connect() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT target_language FROM notes WHERE id = %s", (note_id,))
                row = cur.fetchone()
                return row[0] if row else None

    def mark_failed(self, note_id: str) -> None:
        self.update_status(note_id, "failed")
