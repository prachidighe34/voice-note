package config

import ("os"
)


type Config struct {
	Port               string
	DBURL              string
	SupabaseURL        string
	SupabaseServiceKey string
	SupabaseBucket     string
	RedisURL           string
}

func Load() Config {
	return Config{
		Port:               getEnv("PORT", "8080"),
		DBURL:              getEnv("DB_URL", ""),
		SupabaseURL:        getEnv("SUPABASE_URL", ""),
		SupabaseServiceKey: getEnv("SUPABASE_SERVICE_KEY", ""),
		SupabaseBucket:     getEnv("SUPABASE_BUCKET", "audio"),
		RedisURL:		    getEnv("REDIS_URL", ""),
	}
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}