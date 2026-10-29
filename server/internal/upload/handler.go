package upload

import (
	"errors"
	"log"
	"net/http"

	"github.com/go-chi/chi/v5"

	"voicenotes/server/internal/models"
	"voicenotes/server/internal/notes"
	"voicenotes/server/internal/queue"
)

const maxUploadSize = 50 << 20 // 50 MB, generous for a voice note

type Handler struct {
	storage      *Storage
	notesService *notes.Service
	queue        *queue.Queue
}

func NewHandler(storage *Storage, notesService *notes.Service, q *queue.Queue) *Handler {
	return &Handler{storage: storage, notesService: notesService, queue: q}
}

func (h *Handler) Routes(r chi.Router) {
	r.Post("/notes/{id}/upload", h.UploadAudio)
}

func (h *Handler) UploadAudio(w http.ResponseWriter, r *http.Request) {
	noteID := chi.URLParam(r, "id")

	// Fetch the note (not just check existence) — we need its
	// target_language to include in the transcription job.
	note, err := h.notesService.GetNote(r.Context(), noteID)
	if err != nil {
		if errors.Is(err, notes.ErrNotFound) {
			writeError(w, http.StatusNotFound, "note not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "failed to look up note")
		return
	}

	r.Body = http.MaxBytesReader(w, r.Body, maxUploadSize)
	if err := r.ParseMultipartForm(maxUploadSize); err != nil {
		writeError(w, http.StatusBadRequest, "file too large or invalid form")
		return
	}

	file, header, err := r.FormFile("audio")
	if err != nil {
		writeError(w, http.StatusBadRequest, "missing 'audio' file field")
		return
	}
	defer file.Close()

	path, err := h.storage.Save(noteID, header, file)
	if err != nil {
		log.Printf("save audio error for note %s: %v", noteID, err)
		writeError(w, http.StatusInternalServerError, "failed to save audio file")
		return
	}

	if err := h.notesService.AttachAudio(r.Context(), noteID, path); err != nil {
		writeError(w, http.StatusInternalServerError, "failed to update note")
		return
	}

	job := queue.TranscriptionJob{
		NoteID:         noteID,
		AudioPath:      path,
		TargetLanguage: note.TargetLanguage,
	}
	if err := h.queue.PushTranscriptionJob(r.Context(), job); err != nil {
		log.Printf("failed to enqueue transcription job for note %s: %v", noteID, err)
	} else if err := h.notesService.UpdateStatus(r.Context(), noteID, models.StatusTranscribing); err != nil {
		log.Printf("failed to update status for note %s: %v", noteID, err)
	}

	updatedNote, err := h.notesService.GetNote(r.Context(), noteID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to fetch updated note")
		return
	}

	writeJSON(w, http.StatusOK, updatedNote)
}
