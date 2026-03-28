package main

import (
	"log"
	"net/http"

	supa "github.com/supabase-community/supabase-go"

	"solarflow-backend/internal/config"
	"solarflow-backend/internal/router"
)

func main() {
	cfg := config.Load()

	db, err := supa.NewClient(cfg.SupabaseURL, cfg.SupabaseKey, &supa.ClientOptions{})
	if err != nil {
		log.Fatalf("❌ Supabase 연결 실패: %v", err)
	}
	log.Println("✅ Supabase 연결 성공")

	r := router.New(db)

	log.Printf("🚀 SolarFlow 3.0 서버 시작: :%s", cfg.Port)
	log.Printf("📋 마스터 API (6개 모듈, 각 CRUD):")
	log.Printf("   /api/v1/companies      — 법인")
	log.Printf("   /api/v1/manufacturers   — 제조사")
	log.Printf("   /api/v1/products        — 품번")
	log.Printf("   /api/v1/partners        — 거래처")
	log.Printf("   /api/v1/warehouses      — 창고/장소")
	log.Printf("   /api/v1/banks           — 은행")

	log.Fatal(http.ListenAndServe(":"+cfg.Port, r))
}
