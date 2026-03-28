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
