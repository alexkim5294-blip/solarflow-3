package model

// ReceiptMatch — 수금 매칭 정보를 담는 구조체
// 비유: "수금-출고 매칭 대장" — 어떤 수금이 어떤 출고에 얼마만큼 매칭되었는지 기록
type ReceiptMatch struct {
	MatchID       string  `json:"match_id"`
	ReceiptID     string  `json:"receipt_id"`
	OutboundID    string  `json:"outbound_id"`
	MatchedAmount float64 `json:"matched_amount"`
}

// CreateReceiptMatchRequest — 수금 매칭 등록 시 클라이언트가 보내는 데이터
// 비유: "수금 매칭 등록 신청서" — 수금, 출고, 매칭 금액을 필수 기재
type CreateReceiptMatchRequest struct {
	ReceiptID     string  `json:"receipt_id"`
	OutboundID    string  `json:"outbound_id"`
	MatchedAmount float64 `json:"matched_amount"`
}

// Validate — 수금 매칭 등록 요청의 입력값을 검증
// 비유: 접수 창구에서 매칭 신청서 필수 항목 확인
func (req *CreateReceiptMatchRequest) Validate() string {
	if req.ReceiptID == "" {
		return "receipt_id는 필수 항목입니다"
	}
	if req.OutboundID == "" {
		return "outbound_id는 필수 항목입니다"
	}
	if req.MatchedAmount <= 0 {
		return "matched_amount는 양수여야 합니다"
	}
	return ""
}
