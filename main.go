package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"

	supa "github.com/supabase-community/supabase-go"
)

var supabaseClient *supa.Client

func corsMiddleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}
		next(w, r)
	}
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	supabaseURL := os.Getenv("SUPABASE_URL")
	supabaseKey := os.Getenv("SUPABASE_KEY")

	var err error
	supabaseClient, err = supa.NewClient(supabaseURL, supabaseKey, &supa.ClientOptions{})
	if err != nil {
		log.Fatalf("Supabase 연결 실패: %v", err)
	}
	log.Println("Supabase 연결 성공")

	http.HandleFunc("/health", corsMiddleware(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{
			"status":  "ok",
			"service": "solarflow-backend",
		})
	}))

	log.Printf("서버 시작: :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}
