package upload

import (
	"encoding/json"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"path/filepath"
	"strconv"
	"strings"
)

// Storage uploads audio files to a Supabase Storage bucket via its REST API.
// Docs: https://supabase.com/docs/guides/storage
type Storage struct {
	baseURL    string // e.g. https://xxxxx.supabase.co
	serviceKey string // service_role key — has write access, never expose to clients
	bucket     string
	httpClient *http.Client
}

func NewStorage(baseURL, serviceKey, bucket string) *Storage {
	return &Storage{
		baseURL:    strings.TrimRight(baseURL, "/"),
		serviceKey: serviceKey,
		bucket:     bucket,
		httpClient: &http.Client{},
	}
}

// Save uploads the file to <bucket>/<noteID><ext> and returns that object
// path (not a public URL — the bucket is private; use CreateSignedURL to
// generate a temporary download link when the worker needs to read it back).
func (s *Storage) Save(noteID string, header *multipart.FileHeader, src io.Reader) (string, error) {
	ext := filepath.Ext(header.Filename)
	if ext == "" {
		ext = ".webm"
	}
	objectPath := noteID + ext

	uploadURL := fmt.Sprintf("%s/storage/v1/object/%s/%s", s.baseURL, s.bucket, objectPath)

	req, err := http.NewRequest(http.MethodPost, uploadURL, src)
	if err != nil {
		return "", fmt.Errorf("build upload request: %w", err)
	}

	contentType := header.Header.Get("Content-Type")
	if contentType == "" {
		contentType = "application/octet-stream"
	}
	req.Header.Set("Content-Type", contentType)
	req.Header.Set("Authorization", "Bearer "+s.serviceKey)
	req.Header.Set("apikey", s.serviceKey)
	req.Header.Set("x-upsert", "true") // overwrite if the same note uploads again
	if header.Size > 0 {
		req.ContentLength = header.Size
	}

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("upload to supabase storage: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		body, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("supabase storage upload failed (status %s): %s", strconv.Itoa(resp.StatusCode), string(body))
	}

	return objectPath, nil
}

// SignedURL generates a temporary, authenticated URL for downloading the
// object — needed because the bucket is private. Used later by the Python
// worker to fetch audio for transcription.
func (s *Storage) SignedURL(objectPath string, expiresInSeconds int) (string, error) {
	signURL := fmt.Sprintf("%s/storage/v1/object/sign/%s/%s", s.baseURL, s.bucket, objectPath)

	body := strings.NewReader(fmt.Sprintf(`{"expiresIn": %d}`, expiresInSeconds))
	req, err := http.NewRequest(http.MethodPost, signURL, body)
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+s.serviceKey)
	req.Header.Set("apikey", s.serviceKey)

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		respBody, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("sign url failed (status %d): %s", resp.StatusCode, string(respBody))
	}

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	var parsed struct {
		SignedURL string `json:"signedURL"`
	}
	if err := json.Unmarshal(respBody, &parsed); err != nil {
		return "", fmt.Errorf("unexpected sign response: %s", string(respBody))
	}
	if parsed.SignedURL == "" {
		return "", fmt.Errorf("unexpected sign response: %s", string(respBody))
	}

	return s.baseURL + "/storage/v1" + parsed.SignedURL, nil
}
