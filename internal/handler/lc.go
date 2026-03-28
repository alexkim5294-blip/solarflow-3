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
