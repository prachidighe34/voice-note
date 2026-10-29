package main

import (
	"log"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/joho/godotenv"

	"voicenotes/server/internal/config"
	"voicenotes/server/internal/db"
	"voicenotes/server/internal/notes"
	"voicenotes/server/internal/queue"
	"voicenotes/server/internal/upload"
)

func main() {
	if err := godotenv.Load(); err != nil {
		log.Println("no .env file found, relying on real environment variables")
	}

	cfg := config.Load()

	pool, err := db.Connect(cfg.DBURL)
	if err != nil {
		log.Fatalf("failed to connect to db: %v", err)
	}
	defer pool.Close()

	repo := notes.NewRepository(pool)
	service := notes.NewService(repo)
	handler := notes.NewHandler(service)

	storage := upload.NewStorage(cfg.SupabaseURL, cfg.SupabaseServiceKey, cfg.SupabaseBucket)

	jobQueue, err := queue.NewQueue(cfg.RedisURL)
	if err != nil {
		log.Fatalf("failed to set up redis queue: %v", err)
	}
	defer jobQueue.Close()

	uploadHandler := upload.NewHandler(storage, service, jobQueue)

	r := chi.NewRouter()
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)

	r.Get("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	})

	handler.Routes(r)
	uploadHandler.Routes(r)

	log.Printf("listening on :%s", cfg.Port)
	if err := http.ListenAndServe(":"+cfg.Port, r); err != nil {
		log.Fatal(err)
	}
}
