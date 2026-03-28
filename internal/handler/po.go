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
