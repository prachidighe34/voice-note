package models

import "time"

type NoteStatus string

const (
	StatusUploaded     NoteStatus = "uploaded"
	StatusTranscribing NoteStatus = "transcribing"
	StatusTranslating  NoteStatus = "translating"
	StatusSummarizing  NoteStatus = "summarizing"
	StatusSummarized   NoteStatus = "summarized"
	StatusFailed       NoteStatus = "failed"
)

type Note struct {
	ID             string     `json:"id"`
	UserID         string     `json:"user_id"`
	Title          string     `json:"title"`
	Status         NoteStatus `json:"status"`
	AudioPath      *string    `json:"audio_path,omitempty"`
	Transcript     *string    `json:"transcript,omitempty"`
	TranslatedText *string    `json:"translated_text,omitempty"`
	Summary        *string    `json:"summary,omitempty"`
	TargetLanguage *string    `json:"target_language,omitempty"`
	Version        int        `json:"version"`
	CreatedAt      time.Time  `json:"created_at"`
	UpdatedAt      time.Time  `json:"updated_at"`
}

type CreateNoteRequest struct {
	ID             string  `json:"id"`
	UserID         string  `json:"user_id"`
	Title          string  `json:"title"`
	TargetLanguage *string `json:"target_language,omitempty"`
}
