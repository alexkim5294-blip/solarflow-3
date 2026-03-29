#!/bin/bash
# ============================================================
# SolarFlow 3.0 — Step 5: 발주/결제 API 핸들러
# 터미널 1에서 실행: bash setup_step5.sh
# PO, LC, TT 핸들러 + 라우터 업데이트
# ============================================================

set -e

BACKEND_DIR=~/solarflow-3/backend
cd "$BACKEND_DIR"

echo "🔧 Step 5 시작: 발주/결제 API 핸들러 추가"
echo "================================================"

# SQL 파일 보관
echo "📄 SQL 파일 보관..."
cp ~/Downloads/003_po_lc_tt_tables.sql sql/migrations/ 2>/dev/null || echo "  (SQL 파일은 수동으로 복사하세요)"

# ── 1. handler/po.go — 발주 CRUD ──
echo "📄 po.go 생성..."
cat > internal/handler/po.go << 'GOEOF'
package handler

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
	supa "github.com/supabase-community/supabase-go"
)

type POHandler struct {
	DB *supa.Client
}

func NewPOHandler(db *supa.Client) *POHandler {
	return &POHandler{DB: db}
}

// List — GET /api/v1/pos — 발주 목록 (제조사, 법인 JOIN)
func (h *POHandler) List(w http.ResponseWriter, r *http.Request) {
	var result []map[string]interface{}

	query := h.DB.From("purchase_orders").
		Select("*, companies(company_name, company_code), manufacturers(name_kr)", "exact", false)

	if compID := r.URL.Query().Get("company_id"); compID != "" {
		query = query.Eq("company_id", compID)
	}
	if mfgID := r.URL.Query().Get("manufacturer_id"); mfgID != "" {
		query = query.Eq("manufacturer_id", mfgID)
	}
	if status := r.URL.Query().Get("status"); status != "" {
		query = query.Eq("status", status)
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

// GetByID — GET /api/v1/pos/{id} — PO 상세 (라인아이템, LC, TT 포함)
func (h *POHandler) GetByID(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")

	// PO 기본 정보
	var po []map[string]interface{}
	data, _, err := h.DB.From("purchase_orders").
		Select("*, companies(company_name, company_code), manufacturers(name_kr, name_en)", "exact", false).
		Eq("po_id", id).
		Execute()
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusInternalServerError)
		return
	}
	json.Unmarshal(data, &po)
	if len(po) == 0 {
		http.Error(w, `{"error":"발주를 찾을 수 없습니다"}`, http.StatusNotFound)
		return
	}

	// 라인아이템
	var lines []map[string]interface{}
	lineData, _, _ := h.DB.From("po_line_items").
		Select("*, products(product_name, spec_wp)", "exact", false).
		Eq("po_id", id).
		Execute()
	json.Unmarshal(lineData, &lines)

	// LC 목록
	var lcs []map[string]interface{}
	lcData, _, _ := h.DB.From("lc_records").
		Select("*, banks(bank_name)", "exact", false).
		Eq("po_id", id).
		Execute()
	json.Unmarshal(lcData, &lcs)

	// TT 목록
	var tts []map[string]interface{}
	ttData, _, _ := h.DB.From("tt_remittances").
		Select("*", "exact", false).
		Eq("po_id", id).
		Execute()
	json.Unmarshal(ttData, &tts)

	// 합쳐서 반환
	result := po[0]
	result["line_items"] = lines
	result["lc_records"] = lcs
	result["tt_remittances"] = tts

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
}

// Create — POST /api/v1/pos
func (h *POHandler) Create(w http.ResponseWriter, r *http.Request) {
	var body map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		http.Error(w, `{"error":"잘못된 요청입니다"}`, http.StatusBadRequest)
		return
	}

	data, _, err := h.DB.From("purchase_orders").
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

// Update — PUT /api/v1/pos/{id}
func (h *POHandler) Update(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")

	var body map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		http.Error(w, `{"error":"잘못된 요청입니다"}`, http.StatusBadRequest)
		return
	}

	data, _, err := h.DB.From("purchase_orders").
		Update(body, "", "").
		Eq("po_id", id).
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

# ── 2. handler/po_line.go — PO 라인아이템 CRUD ──
echo "📄 po_line.go 생성..."
cat > internal/handler/po_line.go << 'GOEOF'
package handler

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
	supa "github.com/supabase-community/supabase-go"
)

type POLineHandler struct {
	DB *supa.Client
}

func NewPOLineHandler(db *supa.Client) *POLineHandler {
	return &POLineHandler{DB: db}
}

// ListByPO — GET /api/v1/pos/{poId}/lines
func (h *POLineHandler) ListByPO(w http.ResponseWriter, r *http.Request) {
	poID := chi.URLParam(r, "poId")

	var result []map[string]interface{}
	data, _, err := h.DB.From("po_line_items").
		Select("*, products(product_name, spec_wp, module_width_mm, module_height_mm)", "exact", false).
		Eq("po_id", poID).
		Execute()
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusInternalServerError)
		return
	}

	json.Unmarshal(data, &result)
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
}

// Create — POST /api/v1/pos/{poId}/lines
func (h *POLineHandler) Create(w http.ResponseWriter, r *http.Request) {
	poID := chi.URLParam(r, "poId")

	var body map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		http.Error(w, `{"error":"잘못된 요청입니다"}`, http.StatusBadRequest)
		return
	}
	body["po_id"] = poID

	data, _, err := h.DB.From("po_line_items").
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

// Update — PUT /api/v1/pos/{poId}/lines/{id}
func (h *POLineHandler) Update(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")

	var body map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		http.Error(w, `{"error":"잘못된 요청입니다"}`, http.StatusBadRequest)
		return
	}

	data, _, err := h.DB.From("po_line_items").
		Update(body, "", "").
		Eq("po_line_id", id).
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

// Delete — DELETE /api/v1/pos/{poId}/lines/{id}
func (h *POLineHandler) Delete(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")

	_, _, err := h.DB.From("po_line_items").
		Delete("", "").
		Eq("po_line_id", id).
		Execute()
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "deleted"})
}
GOEOF

# ── 3. handler/lc.go — LC 개설 CRUD ──
echo "📄 lc.go 생성..."
cat > internal/handler/lc.go << 'GOEOF'
package handler

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
	supa "github.com/supabase-community/supabase-go"
)

type LCHandler struct {
	DB *supa.Client
}

func NewLCHandler(db *supa.Client) *LCHandler {
	return &LCHandler{DB: db}
}

// List — GET /api/v1/lcs — 전체 LC 목록
func (h *LCHandler) List(w http.ResponseWriter, r *http.Request) {
	var result []map[string]interface{}

	query := h.DB.From("lc_records").
		Select("*, banks(bank_name), companies(company_name, company_code), purchase_orders(po_number)", "exact", false)

	if compID := r.URL.Query().Get("company_id"); compID != "" {
		query = query.Eq("company_id", compID)
	}
	if bankID := r.URL.Query().Get("bank_id"); bankID != "" {
		query = query.Eq("bank_id", bankID)
	}
	if status := r.URL.Query().Get("status"); status != "" {
		query = query.Eq("status", status)
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

// GetByID — GET /api/v1/lcs/{id}
func (h *LCHandler) GetByID(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")

	var result []map[string]interface{}
	data, _, err := h.DB.From("lc_records").
		Select("*, banks(bank_name, lc_limit_usd, opening_fee_rate, acceptance_fee_rate), companies(company_name), purchase_orders(po_number, manufacturer_id)", "exact", false).
		Eq("lc_id", id).
		Execute()
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusInternalServerError)
		return
	}

	json.Unmarshal(data, &result)
	if len(result) == 0 {
		http.Error(w, `{"error":"LC를 찾을 수 없습니다"}`, http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result[0])
}

// Create — POST /api/v1/lcs
func (h *LCHandler) Create(w http.ResponseWriter, r *http.Request) {
	var body map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		http.Error(w, `{"error":"잘못된 요청입니다"}`, http.StatusBadRequest)
		return
	}

	data, _, err := h.DB.From("lc_records").
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

// Update — PUT /api/v1/lcs/{id}
func (h *LCHandler) Update(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")

	var body map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		http.Error(w, `{"error":"잘못된 요청입니다"}`, http.StatusBadRequest)
		return
	}

	data, _, err := h.DB.From("lc_records").
		Update(body, "", "").
		Eq("lc_id", id).
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

# ── 4. handler/tt.go — T/T 송금 CRUD ──
echo "📄 tt.go 생성..."
cat > internal/handler/tt.go << 'GOEOF'
package handler

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
	supa "github.com/supabase-community/supabase-go"
)

type TTHandler struct {
	DB *supa.Client
}

func NewTTHandler(db *supa.Client) *TTHandler {
	return &TTHandler{DB: db}
}

// List — GET /api/v1/tts
func (h *TTHandler) List(w http.ResponseWriter, r *http.Request) {
	var result []map[string]interface{}

	query := h.DB.From("tt_remittances").
		Select("*, purchase_orders(po_number, manufacturers(name_kr))", "exact", false)

	if poID := r.URL.Query().Get("po_id"); poID != "" {
		query = query.Eq("po_id", poID)
	}
	if status := r.URL.Query().Get("status"); status != "" {
		query = query.Eq("status", status)
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

// Create — POST /api/v1/tts
func (h *TTHandler) Create(w http.ResponseWriter, r *http.Request) {
	var body map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		http.Error(w, `{"error":"잘못된 요청입니다"}`, http.StatusBadRequest)
		return
	}

	data, _, err := h.DB.From("tt_remittances").
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

// Update — PUT /api/v1/tts/{id}
func (h *TTHandler) Update(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")

	var body map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		http.Error(w, `{"error":"잘못된 요청입니다"}`, http.StatusBadRequest)
		return
	}

	data, _, err := h.DB.From("tt_remittances").
		Update(body, "", "").
		Eq("tt_id", id).
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

# ── 5. router.go 교체 — Phase 2 라우트 추가 ──
echo "📄 router.go 업데이트..."
cat > internal/router/router.go << 'GOEOF'
package router

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"solarflow-backend/internal/handler"
	"solarflow-backend/internal/middleware"

	supa "github.com/supabase-community/supabase-go"
)

func New(db *supa.Client) http.Handler {
	r := chi.NewRouter()
	r.Use(middleware.CORS)
	r.Get("/health", handler.HealthCheck)

	r.Route("/api/v1", func(r chi.Router) {

		// ── Phase 1: 마스터 관리 ──

		companyH := handler.NewCompanyHandler(db)
		r.Route("/companies", func(r chi.Router) {
			r.Get("/", companyH.List)
			r.Post("/", companyH.Create)
			r.Get("/{id}", companyH.GetByID)
			r.Put("/{id}", companyH.Update)
			r.Patch("/{id}/status", companyH.ToggleStatus)
		})

		mfgH := handler.NewManufacturerHandler(db)
		r.Route("/manufacturers", func(r chi.Router) {
			r.Get("/", mfgH.List)
			r.Post("/", mfgH.Create)
			r.Get("/{id}", mfgH.GetByID)
			r.Put("/{id}", mfgH.Update)
		})

		productH := handler.NewProductHandler(db)
		r.Route("/products", func(r chi.Router) {
			r.Get("/", productH.List)
			r.Post("/", productH.Create)
			r.Get("/{id}", productH.GetByID)
			r.Put("/{id}", productH.Update)
		})

		partnerH := handler.NewPartnerHandler(db)
		r.Route("/partners", func(r chi.Router) {
			r.Get("/", partnerH.List)
			r.Post("/", partnerH.Create)
			r.Get("/{id}", partnerH.GetByID)
			r.Put("/{id}", partnerH.Update)
		})

		warehouseH := handler.NewWarehouseHandler(db)
		r.Route("/warehouses", func(r chi.Router) {
			r.Get("/", warehouseH.List)
			r.Post("/", warehouseH.Create)
			r.Get("/{id}", warehouseH.GetByID)
			r.Put("/{id}", warehouseH.Update)
		})

		bankH := handler.NewBankHandler(db)
		r.Route("/banks", func(r chi.Router) {
			r.Get("/", bankH.List)
			r.Post("/", bankH.Create)
			r.Get("/{id}", bankH.GetByID)
			r.Put("/{id}", bankH.Update)
		})

		// ── Phase 2: 발주/결제 ──

		poH := handler.NewPOHandler(db)
		poLineH := handler.NewPOLineHandler(db)
		r.Route("/pos", func(r chi.Router) {
			r.Get("/", poH.List)                    // ?company_id=&manufacturer_id=&status=
			r.Post("/", poH.Create)
			r.Get("/{id}", poH.GetByID)             // 라인아이템+LC+TT 포함
			r.Put("/{id}", poH.Update)

			// PO 하위: 라인아이템
			r.Route("/{poId}/lines", func(r chi.Router) {
				r.Get("/", poLineH.ListByPO)
				r.Post("/", poLineH.Create)
				r.Put("/{id}", poLineH.Update)
				r.Delete("/{id}", poLineH.Delete)
			})
		})

		lcH := handler.NewLCHandler(db)
		r.Route("/lcs", func(r chi.Router) {
			r.Get("/", lcH.List)                    // ?company_id=&bank_id=&status=
			r.Post("/", lcH.Create)
			r.Get("/{id}", lcH.GetByID)
			r.Put("/{id}", lcH.Update)
		})

		ttH := handler.NewTTHandler(db)
		r.Route("/tts", func(r chi.Router) {
			r.Get("/", ttH.List)                    // ?po_id=&status=
			r.Post("/", ttH.Create)
			r.Put("/{id}", ttH.Update)
		})
	})

	return r
}
GOEOF

# ── 6. 빌드 테스트 ──
echo ""
echo "🔨 빌드 테스트..."
if go build -o /dev/null .; then
    echo ""
    echo "================================================"
    echo "✅ Step 5 완료! 빌드 성공!"
    echo "================================================"
    echo ""
    echo "📁 새 핸들러:"
    ls -la internal/handler/po*.go internal/handler/lc.go internal/handler/tt.go
    echo ""
    echo "다음 명령어를 순서대로 실행하세요:"
    echo '  git add -A'
    echo '  git commit -m "feat: Step 5 — 발주/결제 API (PO, LC, TT, 라인아이템)"'
    echo '  git push origin main'
    echo '  fly deploy'
else
    echo ""
    echo "❌ 빌드 실패 — 에러 메시지를 Claude에게 보내주세요"
fi
