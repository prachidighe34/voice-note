package queue

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/redis/go-redis/v9"
)

const TranscriptionQueueKey = "transcription_jobs"

type TranscriptionJob struct {
	NoteID         string  `json:"note_id"`
	AudioPath      string  `json:"audio_path"` // object key within the Supabase Storage bucket
	TargetLanguage *string `json:"target_language,omitempty"`
}

type Queue struct {
	client *redis.Client
}

func NewQueue(redisURL string) (*Queue, error) {
	opt, err := redis.ParseURL(redisURL)
	if err != nil {
		return nil, fmt.Errorf("parse redis url: %w", err)
	}
	client := redis.NewClient(opt)
	return &Queue{client: client}, nil
}

func (q *Queue) PushTranscriptionJob(ctx context.Context, job TranscriptionJob) error {
	payload, err := json.Marshal(job)
	if err != nil {
		return fmt.Errorf("marshal job: %w", err)
	}
	if err := q.client.LPush(ctx, TranscriptionQueueKey, payload).Err(); err != nil {
		return fmt.Errorf("push job to redis: %w", err)
	}
	return nil
}

func (q *Queue) Close() error {
	return q.client.Close()
}
