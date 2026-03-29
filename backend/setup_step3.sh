#!/bin/bash
# ============================================================
# SolarFlow 3.0 — Step 3: 나머지 마스터 CRUD 핸들러 추가
# 터미널 1에서 실행: bash setup_step3.sh
# 추가: products, partners, warehouses, banks
# ============================================================

set -e

BACKEND_DIR=~/solarflow-3/backend
cd "$BACKEND_DIR"

echo "🔧 Step 3 시작: 나머지 4개 마스터 핸들러 추가"
echo "================================================"

# ── 1. handler/product.go — 품번 CRUD ──
echo "📄 product.go 생성..."
cat > internal/handler/product.go << 'GOEOF'
package handler

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
	supa "github.com/supabase-community/supabase-go"
)

// ProductHandler는 품번(products) 관련 API를 처리
// 비유: "모듈 규격 카탈로그실" — JKM635, TSM-720 같은 모듈 사양을 관리
type ProductHandler struct {
	DB *supa.Client
}

func NewProductHandler(db *supa.Client) *ProductHandler {
	return &ProductHandler{DB: db}
}

// List — GET /api/v1/products — 품번 목록 (제조사 정보 포함)
func (h *ProductHandler) List(w http.ResponseWriter, r *http.Request) {
	var result []map[string]interface{}

	// 쿼리 파라미터로 필터링 가능
	query := h.DB.From("products").
		Select("*, manufacturers(name_kr, domestic_foreign)", "exact", false)

	// ?manufacturer_id=xxx 필터
	if mfgID := r.URL.Query().Get("manufacturer_id"); mfgID != "" {
		query = query.Eq("manufacturer_id", mfgID)
	}

	// ?active=true 필터
	if active := r.URL.Query().Get("active"); active != "" {
		query = query.Eq("is_active", active)
	}

	data, _, err := query.Execute()
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusInternalServerError)
		return
	}

	json.Unmarshal(data, &result)
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
}

// GetByID — GET /api/v1/products/{id}
func (h *ProductHandler) GetByID(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")

	var result []map[string]interface{}
	data, _, err := h.DB.From("products").
		Select("*, manufacturers(name_kr, name_en, domestic_foreign)", "exact", false).
		Eq("product_id", id).
		Execute()

	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusInternalServerError)
		return
	}

	json.Unmarshal(data, &result)
	if len(result) == 0 {
		http.Error(w, `{"error":"품번을 찾을 수 없습니다"}`, http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result[0])
}

// Create — POST /api/v1/products
func (h *ProductHandler) Create(w http.ResponseWriter, r *http.Request) {
	var body map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		http.Error(w, `{"error":"잘못된 요청입니다"}`, http.StatusBadRequest)
		return
	}

	data, _, err := h.DB.From("products").
		Insert(body, false, "", "", "").
		Execute()

	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusInternalServerError)
		return
	}

	var result []map[string]interface{}
	json.Unmarshal(data, &result)

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	if len(result) > 0 {
		json.NewEncoder(w).Encode(result[0])
	}
}

// Update — PUT /api/v1/products/{id}
func (h *ProductHandler) Update(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")

	var body map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		http.Error(w, `{"error":"잘못된 요청입니다"}`, http.StatusBadRequest)
		return
	}

	data, _, err := h.DB.From("products").
		Update(body, "", "").
		Eq("product_id", id).
		Execute()

	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusInternalServerError)
		return
	}

	var result []map[string]interface{}
	json.Unmarshal(data, &result)

	w.Header().Set("Content-Type", "application/json")
	if len(result) > 0 {
		json.NewEncoder(w).Encode(result[0])
	}
}
GOEOF

# ── 2. handler/partner.go — 거래처 CRUD ──
echo "📄 partner.go 생성..."
cat > internal/handler/partner.go << 'GOEOF'
package handler

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
	supa "github.com/supabase-community/supabase-go"
)

// PartnerHandler는 거래처(partners) 관련 API를 처리
// 비유: "거래처 명함 보관함" — 바로(주), 신명엔지니어링 등 공급사/고객 관리
type PartnerHandler struct {
	DB *supa.Client
}

func NewPartnerHandler(db *supa.Client) *PartnerHandler {
	return &PartnerHandler{DB: db}
}

// List — GET /api/v1/partners
func (h *PartnerHandler) List(w http.ResponseWriter, r *http.Request) {
	var result []map[string]interface{}

	query := h.DB.From("partners").
		Select("*", "exact", false)

	// ?type=supplier|customer|both 필터
	if pType := r.URL.Query().Get("type"); pType != "" {
		query = query.Eq("partner_type", pType)
	}

	if active := r.URL.Query().Get("active"); active != "" {
		query = query.Eq("is_active", active)
	}

	data, _, err := query.Execute()
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusInternalServerError)
		return
	}

	json.Unmarshal(data, &result)
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
}

// GetByID — GET /api/v1/partners/{id}
func (h *PartnerHandler) GetByID(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")

	var result []map[string]interface{}
	data, _, err := h.DB.From("partners").
		Select("*", "exact", false).
		Eq("partner_id", id).
		Execute()

	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusInternalServerError)
		return
	}

	json.Unmarshal(data, &result)
	if len(result) == 0 {
		http.Error(w, `{"error":"거래처를 찾을 수 없습니다"}`, http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result[0])
}

// Create — POST /api/v1/partners
func (h *PartnerHandler) Create(w http.ResponseWriter, r *http.Request) {
	var body map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		http.Error(w, `{"error":"잘못된 요청입니다"}`, http.StatusBadRequest)
		return
	}

	data, _, err := h.DB.From("partners").
		Insert(body, false, "", "", "").
		Execute()

	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusInternalServerError)
		return
	}

	var result []map[string]interface{}
	json.Unmarshal(data, &result)

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	if len(result) > 0 {
		json.NewEncoder(w).Encode(result[0])
	}
}

// Update — PUT /api/v1/partners/{id}
func (h *PartnerHandler) Update(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")

	var body map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		http.Error(w, `{"error":"잘못된 요청입니다"}`, http.StatusBadRequest)
		return
	}

	data, _, err := h.DB.From("partners").
		Update(body, "", "").
		Eq("partner_id", id).
		Execute()

	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusInternalServerError)
		return
	}

	var result []map[string]interface{}
	json.Unmarshal(data, &result)

	w.Header().Set("Content-Type", "application/json")
	if len(result) > 0 {
		json.NewEncoder(w).Encode(result[0])
	}
}
GOEOF

# ── 3. handler/warehouse.go — 창고/장소 CRUD ──
echo "📄 warehouse.go 생성..."
cat > internal/handler/warehouse.go << 'GOEOF'
package handler

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
	supa "github.com/supabase-community/supabase-go"
)

// WarehouseHandler는 창고/장소(warehouses) 관련 API를 처리
// 비유: "물류센터 안내도" — 광양항, 부산항, 광주공장 등 장소 관리
type WarehouseHandler struct {
	DB *supa.Client
}

func NewWarehouseHandler(db *supa.Client) *WarehouseHandler {
	return &WarehouseHandler{DB: db}
}

// List — GET /api/v1/warehouses
func (h *WarehouseHandler) List(w http.ResponseWriter, r *http.Request) {
	var result []map[string]interface{}

	query := h.DB.From("warehouses").
		Select("*", "exact", false)

	// ?type=port|factory|vendor 필터
	if wType := r.URL.Query().Get("type"); wType != "" {
		query = query.Eq("warehouse_type", wType)
	}

	data, _, err := query.Execute()
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusInternalServerError)
		return
	}

	json.Unmarshal(data, &result)
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
}

// GetByID — GET /api/v1/warehouses/{id}
func (h *WarehouseHandler) GetByID(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")

	var result []map[string]interface{}
	data, _, err := h.DB.From("warehouses").
		Select("*", "exact", false).
		Eq("warehouse_id", id).
		Execute()

	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusInternalServerError)
		return
	}

	json.Unmarshal(data, &result)
	if len(result) == 0 {
		http.Error(w, `{"error":"창고를 찾을 수 없습니다"}`, http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result[0])
}

// Create — POST /api/v1/warehouses
func (h *WarehouseHandler) Create(w http.ResponseWriter, r *http.Request) {
	var body map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		http.Error(w, `{"error":"잘못된 요청입니다"}`, http.StatusBadRequest)
		return
	}

	data, _, err := h.DB.From("warehouses").
		Insert(body, false, "", "", "").
		Execute()

	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusInternalServerError)
		return
	}

	var result []map[string]interface{}
	json.Unmarshal(data, &result)

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	if len(result) > 0 {
		json.NewEncoder(w).Encode(result[0])
	}
}

// Update — PUT /api/v1/warehouses/{id}
func (h *WarehouseHandler) Update(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")

	var body map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		http.Error(w, `{"error":"잘못된 요청입니다"}`, http.StatusBadRequest)
		return
	}

	data, _, err := h.DB.From("warehouses").
		Update(body, "", "").
		Eq("warehouse_id", id).
		Execute()

	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusInternalServerError)
		return
	}

	var result []map[string]interface{}
	json.Unmarshal(data, &result)

	w.Header().Set("Content-Type", "application/json")
	if len(result) > 0 {
		json.NewEncoder(w).Encode(result[0])
	}
}
GOEOF

# ── 4. handler/bank.go — 은행 CRUD ──
echo "📄 bank.go 생성..."
cat > internal/handler/bank.go << 'GOEOF'
package handler

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
	supa "github.com/supabase-community/supabase-go"
)

// BankHandler는 은행(banks) 관련 API를 처리
// 비유: "은행 한도 관리 캐비넷" — LC 한도, 수수료율 관리
type BankHandler struct {
	DB *supa.Client
}

func NewBankHandler(db *supa.Client) *BankHandler {
	return &BankHandler{DB: db}
}

// List — GET /api/v1/banks — 법인별 은행 목록 (법인 정보 포함)
func (h *BankHandler) List(w http.ResponseWriter, r *http.Request) {
	var result []map[string]interface{}

	query := h.DB.From("banks").
		Select("*, companies(company_name, company_code)", "exact", false)

	// ?company_id=xxx 필터 — 특정 법인의 은행만
	if compID := r.URL.Query().Get("company_id"); compID != "" {
		query = query.Eq("company_id", compID)
	}

	data, _, err := query.Execute()
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusInternalServerError)
		return
	}

	json.Unmarshal(data, &result)
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
}

// GetByID — GET /api/v1/banks/{id}
func (h *BankHandler) GetByID(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")

	var result []map[string]interface{}
	data, _, err := h.DB.From("banks").
		Select("*, companies(company_name, company_code)", "exact", false).
		Eq("bank_id", id).
		Execute()

	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusInternalServerError)
		return
	}

	json.Unmarshal(data, &result)
	if len(result) == 0 {
		http.Error(w, `{"error":"은행을 찾을 수 없습니다"}`, http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result[0])
}

// Create — POST /api/v1/banks
func (h *BankHandler) Create(w http.ResponseWriter, r *http.Request) {
	var body map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		http.Error(w, `{"error":"잘못된 요청입니다"}`, http.StatusBadRequest)
		return
	}

	data, _, err := h.DB.From("banks").
		Insert(body, false, "", "", "").
		Execute()

	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusInternalServerError)
		return
	}

	var result []map[string]interface{}
	json.Unmarshal(data, &result)

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	if len(result) > 0 {
		json.NewEncoder(w).Encode(result[0])
	}
}

// Update — PUT /api/v1/banks/{id}
func (h *BankHandler) Update(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")

	var body map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		http.Error(w, `{"error":"잘못된 요청입니다"}`, http.StatusBadRequest)
		return
	}

	data, _, err := h.DB.From("banks").
		Update(body, "", "").
		Eq("bank_id", id).
		Execute()

	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusInternalServerError)
		return
	}

	var result []map[string]interface{}
	json.Unmarshal(data, &result)

	w.Header().Set("Content-Type", "application/json")
	if len(result) > 0 {
		json.NewEncoder(w).Encode(result[0])
	}
}
GOEOF

# ── 5. router.go 교체 — 6개 마스터 전부 등록 ──
echo "📄 router.go 교체 (6개 마스터 전부 등록)..."
cat > internal/router/router.go << 'GOEOF'
package router

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"solarflow-backend/internal/handler"
	"solarflow-backend/internal/middleware"

	supa "github.com/supabase-community/supabase-go"
)

// New는 전체 라우터를 생성하고 모든 경로를 등록
func New(db *supa.Client) http.Handler {
	r := chi.NewRouter()

	// ── 미들웨어 ──
	r.Use(middleware.CORS)

	// ── 헬스체크 ──
	r.Get("/health", handler.HealthCheck)

	// ── API v1 ──
	r.Route("/api/v1", func(r chi.Router) {

		// 1. 법인 관리
		companyH := handler.NewCompanyHandler(db)
		r.Route("/companies", func(r chi.Router) {
			r.Get("/", companyH.List)
			r.Post("/", companyH.Create)
			r.Get("/{id}", companyH.GetByID)
			r.Put("/{id}", companyH.Update)
			r.Patch("/{id}/status", companyH.ToggleStatus)
		})

		// 2. 제조사 관리
		mfgH := handler.NewManufacturerHandler(db)
		r.Route("/manufacturers", func(r chi.Router) {
			r.Get("/", mfgH.List)
			r.Post("/", mfgH.Create)
			r.Get("/{id}", mfgH.GetByID)
			r.Put("/{id}", mfgH.Update)
		})

		// 3. 품번 관리 ★ NEW
		productH := handler.NewProductHandler(db)
		r.Route("/products", func(r chi.Router) {
			r.Get("/", productH.List)          // ?manufacturer_id=xxx&active=true
			r.Post("/", productH.Create)
			r.Get("/{id}", productH.GetByID)
			r.Put("/{id}", productH.Update)
		})

		// 4. 거래처 관리 ★ NEW
		partnerH := handler.NewPartnerHandler(db)
		r.Route("/partners", func(r chi.Router) {
			r.Get("/", partnerH.List)           // ?type=supplier|customer|both
			r.Post("/", partnerH.Create)
			r.Get("/{id}", partnerH.GetByID)
			r.Put("/{id}", partnerH.Update)
		})

		// 5. 창고/장소 관리 ★ NEW
		warehouseH := handler.NewWarehouseHandler(db)
		r.Route("/warehouses", func(r chi.Router) {
			r.Get("/", warehouseH.List)         // ?type=port|factory|vendor
			r.Post("/", warehouseH.Create)
			r.Get("/{id}", warehouseH.GetByID)
			r.Put("/{id}", warehouseH.Update)
		})

		// 6. 은행 관리 ★ NEW
		bankH := handler.NewBankHandler(db)
		r.Route("/banks", func(r chi.Router) {
			r.Get("/", bankH.List)              // ?company_id=xxx
			r.Post("/", bankH.Create)
			r.Get("/{id}", bankH.GetByID)
			r.Put("/{id}", bankH.Update)
		})
	})

	return r
}
GOEOF

# ── 6. main.go 업데이트 — API 목록 로그 ──
echo "📄 main.go 업데이트..."
cat > main.go << 'GOEOF'
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
GOEOF

# ── 7. 빌드 테스트 ──
echo ""
echo "🔨 빌드 테스트..."
if go build -o /dev/null .; then
    echo ""
    echo "================================================"
    echo "✅ Step 3 완료! 빌드 성공!"
    echo "================================================"
    echo ""
    echo "📁 핸들러 파일 목록:"
    ls -la internal/handler/
    echo ""
    echo "다음 명령어를 순서대로 실행하세요:"
    echo '  git add -A'
    echo '  git commit -m "feat: Step 3 — 마스터 6개 CRUD 완성 (products/partners/warehouses/banks 추가)"'
    echo '  git push origin main'
    echo '  fly deploy'
else
    echo ""
    echo "❌ 빌드 실패 — 에러 메시지를 Claude에게 보내주세요"
fi
