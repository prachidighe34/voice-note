package notes

import (
	"context"

	"github.com/google/uuid"

	"voicenotes/server/internal/models"
)

type Service struct {
	repo *Repository
}

func NewService(repo *Repository) *Service {
	return &Service{repo: repo}
}

func (s *Service) CreateNote(ctx context.Context, req models.CreateNoteRequest) (models.Note, error) {
	id := req.ID
	if id == "" {
		id = uuid.NewString()
	}

	n := models.Note{
		ID:             id,
		UserID:         req.UserID,
		Title:          req.Title,
		Status:         models.StatusUploaded,
		TargetLanguage: req.TargetLanguage,
	}
	return s.repo.Create(ctx, n)
}

func (s *Service) GetNote(ctx context.Context, id string) (models.Note, error) {
	return s.repo.GetByID(ctx, id)
}

func (s *Service) ListNotes(ctx context.Context, userID string) ([]models.Note, error) {
	return s.repo.ListByUser(ctx, userID)
}

func (s *Service) AttachAudio(ctx context.Context, id, audioPath string) error {
	return s.repo.UpdateAudioPath(ctx, id, audioPath)
}

func (s *Service) UpdateStatus(ctx context.Context, id string, status models.NoteStatus) error {
	return s.repo.UpdateStatus(ctx, id, status)
}

func (s *Service) DeleteNote(ctx context.Context, id string) error {
	return s.repo.Delete(ctx, id)
}

func (s *Service) UpdateTranscript(ctx context.Context, id, transcript string) error {
	return s.repo.UpdateTranscript(ctx, id, transcript)
}
