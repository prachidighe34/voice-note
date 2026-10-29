package notes

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"voicenotes/server/internal/models"
)

var ErrNotFound = errors.New("note not found")

type Repository struct {
	db *pgxpool.Pool
}

func NewRepository(db *pgxpool.Pool) *Repository {
	return &Repository{db: db}
}

func (r *Repository) Create(ctx context.Context, n models.Note) (models.Note, error) {
	query := `
		INSERT INTO notes (id, user_id, title, status, target_language)
		VALUES ($1, $2, $3, $4, $5)
		ON CONFLICT (id) DO UPDATE
		SET title = EXCLUDED.title,
		    target_language = EXCLUDED.target_language,
		    updated_at = now()
		RETURNING id, user_id, title, status, audio_path, transcript,
		          translated_text, summary, target_language, version, created_at, updated_at
	`
	return r.scanRow(r.db.QueryRow(ctx, query, n.ID, n.UserID, n.Title, n.Status, n.TargetLanguage))
}

func (r *Repository) GetByID(ctx context.Context, id string) (models.Note, error) {
	query := `
		SELECT id, user_id, title, status, audio_path, transcript,
		       translated_text, summary, target_language, version, created_at, updated_at
		FROM notes WHERE id = $1
	`
	n, err := r.scanRow(r.db.QueryRow(ctx, query, id))
	if errors.Is(err, pgx.ErrNoRows) {
		return models.Note{}, ErrNotFound
	}
	return n, err
}

func (r *Repository) ListByUser(ctx context.Context, userID string) ([]models.Note, error) {
	query := `
		SELECT id, user_id, title, status, audio_path, transcript,
		       translated_text, summary, target_language, version, created_at, updated_at
		FROM notes WHERE user_id = $1 ORDER BY created_at DESC
	`
	rows, err := r.db.Query(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []models.Note
	for rows.Next() {
		n, err := r.scanRowFromRows(rows)
		if err != nil {
			return nil, err
		}
		result = append(result, n)
	}
	return result, rows.Err()
}

func (r *Repository) UpdateAudioPath(ctx context.Context, id, audioPath string) error {
	query := `UPDATE notes SET audio_path = $1, updated_at = now() WHERE id = $2`
	tag, err := r.db.Exec(ctx, query, audioPath, id)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (r *Repository) UpdateStatus(ctx context.Context, id string, status models.NoteStatus) error {
	query := `UPDATE notes SET status = $1, updated_at = now() WHERE id = $2`
	tag, err := r.db.Exec(ctx, query, status, id)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// UpdateTranscript lets a user correct a misrecognized transcript after
// the pipeline has already run. Deliberately does not touch summary or
// translated_text — those were derived from the old transcript and would
// need re-running to stay accurate; out of scope for now (see README).
func (r *Repository) UpdateTranscript(ctx context.Context, id, transcript string) error {
	tag, err := r.db.Exec(ctx,
		`UPDATE notes SET transcript = $1, updated_at = now() WHERE id = $2`,
		transcript, id,
	)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// Delete removes a note's row. NOTE: this does not delete the audio file
// from Supabase Storage — the object is left orphaned. Fine for a
// portfolio project; a production version would also delete the storage
// object (requires wiring the Storage client into this layer, or handling
// cleanup in the upload package where that client already lives).
//
// Also not scoped to user_id here, matching the rest of this prototype's
// lack of auth middleware — a production version should verify the
// requesting user owns this note before deleting.
func (r *Repository) Delete(ctx context.Context, id string) error {
	tag, err := r.db.Exec(ctx, `DELETE FROM notes WHERE id = $1`, id)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (r *Repository) scanRow(row pgx.Row) (models.Note, error) {
	var n models.Note
	err := row.Scan(
		&n.ID, &n.UserID, &n.Title, &n.Status, &n.AudioPath, &n.Transcript,
		&n.TranslatedText, &n.Summary, &n.TargetLanguage, &n.Version, &n.CreatedAt, &n.UpdatedAt,
	)
	return n, err
}

func (r *Repository) scanRowFromRows(rows pgx.Rows) (models.Note, error) {
	var n models.Note
	err := rows.Scan(
		&n.ID, &n.UserID, &n.Title, &n.Status, &n.AudioPath, &n.Transcript,
		&n.TranslatedText, &n.Summary, &n.TargetLanguage, &n.Version, &n.CreatedAt, &n.UpdatedAt,
	)
	return n, err
}
