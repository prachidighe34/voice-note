package notes

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"

	"voicenotes/server/internal/models"
)

type Handler struct {
	service *Service
}

func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

func (h *Handler) Routes(r chi.Router) {
	r.Post("/notes", h.CreateNote)
	r.Get("/notes", h.ListNotes)
	r.Get("/notes/{id}", h.GetNote)
	r.Patch("/notes/{id}", h.UpdateNote)
	r.Delete("/notes/{id}", h.DeleteNote)
}

// UpdateNoteRequest currently only supports editing the transcript (e.g.
// correcting a misrecognized word) — the one field the app's UI exposes
// for editing. Extend this if you add more editable fields later.
type UpdateNoteRequest struct {
	Transcript *string `json:"transcript,omitempty"`
}

func (h *Handler) CreateNote(w http.ResponseWriter, r *http.Request) {
	var req models.CreateNoteRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	if req.UserID == "" {
		writeError(w, http.StatusBadRequest, "user_id is required")
		return
	}

	note, err := h.service.CreateNote(r.Context(), req)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to create note")
		return
	}

	writeJSON(w, http.StatusCreated, note)
}

func (h *Handler) GetNote(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")

	note, err := h.service.GetNote(r.Context(), id)
	if errors.Is(err, ErrNotFound) {
		writeError(w, http.StatusNotFound, "note not found")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to fetch note")
		return
	}

	writeJSON(w, http.StatusOK, note)
}

func (h *Handler) ListNotes(w http.ResponseWriter, r *http.Request) {
	userID := r.URL.Query().Get("user_id")
	if userID == "" {
		writeError(w, http.StatusBadRequest, "user_id query param is required")
		return
	}

	notesList, err := h.service.ListNotes(r.Context(), userID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to list notes")
		return
	}

	writeJSON(w, http.StatusOK, notesList)
}

func (h *Handler) UpdateNote(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")

	var req UpdateNoteRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	if req.Transcript == nil {
		writeError(w, http.StatusBadRequest, "transcript is required")
		return
	}

	if err := h.service.UpdateTranscript(r.Context(), id, *req.Transcript); err != nil {
		if errors.Is(err, ErrNotFound) {
			writeError(w, http.StatusNotFound, "note not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "failed to update note")
		return
	}

	note, err := h.service.GetNote(r.Context(), id)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to fetch updated note")
		return
	}

	writeJSON(w, http.StatusOK, note)
}

func (h *Handler) DeleteNote(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")

	err := h.service.DeleteNote(r.Context(), id)
	if errors.Is(err, ErrNotFound) {
		writeError(w, http.StatusNotFound, "note not found")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to delete note")
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, status int, message string) {
	writeJSON(w, status, map[string]string{"error": message})
}
