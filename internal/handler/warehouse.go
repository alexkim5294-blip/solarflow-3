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
