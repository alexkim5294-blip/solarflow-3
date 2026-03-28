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
