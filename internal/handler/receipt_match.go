package handler

import (
	"encoding/json"
	"log"
	"net/http"

	"github.com/go-chi/chi/v5"
	supa "github.com/supabase-community/supabase-go"

	"solarflow-backend/internal/model"
	"solarflow-backend/internal/response"
)

// ReceiptMatchHandler — 수금 매칭(receipt_matches) 관련 API를 처리하는 핸들러
// 비유: "수금-출고 매칭 대장" — 어떤 입금이 어떤 출고에 얼마만큼 매칭되었는지 관리
// TODO: Rust 계산엔진 연동 — 수금 매칭 자동 추천 (미수금 금액 조합 최적화)
// TODO: Rust 계산엔진 연동 — 거래처별 미수금 총괄 (미수금, 경과일, 상태)
type ReceiptMatchHandler struct {
	DB *supa.Client
}

// NewReceiptMatchHandler — ReceiptMatchHandler 생성자
func NewReceiptMatchHandler(db *supa.Client) *ReceiptMatchHandler {
	return &ReceiptMatchHandler{DB: db}
}

// List — GET /api/v1/receipt-matches — 수금 매칭 목록 조회
// 비유: 매칭 대장에서 전체 매칭 내역을 꺼내 보여주는 것
func (h *ReceiptMatchHandler) List(w http.ResponseWriter, r *http.Request) {
	query := h.DB.From("receipt_matches").
		Select("*", "exact", false)

	// 비유: ?receipt_id=xxx — 특정 수금의 매칭만 필터
	if recID := r.URL.Query().Get("receipt_id"); recID != "" {
		query = query.Eq("receipt_id", recID)
	}

	data, _, err := query.Execute()
	if err != nil {
		log.Printf("[수금 매칭 목록 조회 실패] %v", err)
		response.RespondError(w, http.StatusInternalServerError, "수금 매칭 목록 조회에 실패했습니다")
		return
	}

	var matches []model.ReceiptMatch
	if err := json.Unmarshal(data, &matches); err != nil {
		log.Printf("[수금 매칭 목록 디코딩 실패] %v", err)
		response.RespondError(w, http.StatusInternalServerError, "응답 데이터 처리에 실패했습니다")
		return
	}

	response.RespondJSON(w, http.StatusOK, matches)
}

// Create — POST /api/v1/receipt-matches — 수금 매칭 등록
// 비유: 새 매칭 기록을 대장에 추가하는 것
func (h *ReceiptMatchHandler) Create(w http.ResponseWriter, r *http.Request) {
	var req model.CreateReceiptMatchRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		log.Printf("[수금 매칭 등록 요청 파싱 실패] %v", err)
		response.RespondError(w, http.StatusBadRequest, "잘못된 요청 형식입니다")
		return
	}

	if msg := req.Validate(); msg != "" {
		response.RespondError(w, http.StatusBadRequest, msg)
		return
	}

	data, _, err := h.DB.From("receipt_matches").
		Insert(req, false, "", "", "").
		Execute()
	if err != nil {
		log.Printf("[수금 매칭 등록 실패] %v", err)
		response.RespondError(w, http.StatusInternalServerError, "수금 매칭 등록에 실패했습니다")
		return
	}

	var created []model.ReceiptMatch
	if err := json.Unmarshal(data, &created); err != nil {
		log.Printf("[수금 매칭 등록 결과 디코딩 실패] %v", err)
		response.RespondError(w, http.StatusInternalServerError, "응답 데이터 처리에 실패했습니다")
		return
	}

	if len(created) == 0 {
		response.RespondError(w, http.StatusInternalServerError, "수금 매칭 등록 결과를 확인할 수 없습니다")
		return
	}

	response.RespondJSON(w, http.StatusCreated, created[0])
}

// Delete — DELETE /api/v1/receipt-matches/{id} — 수금 매칭 삭제
// 비유: 매칭 대장에서 특정 매칭 기록을 제거하는 것
func (h *ReceiptMatchHandler) Delete(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")

	_, _, err := h.DB.From("receipt_matches").
		Delete("", "").
		Eq("match_id", id).
		Execute()
	if err != nil {
		log.Printf("[수금 매칭 삭제 실패] id=%s, err=%v", id, err)
		response.RespondError(w, http.StatusInternalServerError, "수금 매칭 삭제에 실패했습니다")
		return
	}

	result := struct {
		Status string `json:"status"`
	}{
		Status: "deleted",
	}

	response.RespondJSON(w, http.StatusOK, result)
}
