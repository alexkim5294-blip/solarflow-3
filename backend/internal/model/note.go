package model

import "unicode/utf8"

// Note — 메모(노트) 정보를 담는 구조체
// 비유: "포스트잇" — 업무 메모를 PO, B/L 등 특정 데이터에 붙일 수 있음
type Note struct {
	NoteID      string  `json:"note_id"`
	UserID      string  `json:"user_id"`
	Content     string  `json:"content"`
	LinkedTable *string `json:"linked_table"`
	LinkedID    *string `json:"linked_id"`
	CreatedAt   string  `json:"created_at"`
	UpdatedAt   string  `json:"updated_at"`
}

// 허용되는 linked_table 값 (map 패턴)
var validLinkedTables = map[string]bool{
	"purchase_orders": true,
	"bl_shipments":    true,
	"outbounds":       true,
	"orders":          true,
	"declarations":    true,
}

// CreateNoteRequest — 메모 등록 시 클라이언트가 보내는 데이터
// 비유: "메모 작성 신청서" — 내용 필수, 연결 대상은 선택
type CreateNoteRequest struct {
	UserID      string  `json:"user_id"`
	Content     string  `json:"content"`
	LinkedTable *string `json:"linked_table"`
	LinkedID    *string `json:"linked_id"`
}

// Validate — 메모 등록 요청의 입력값을 검증
func (req *CreateNoteRequest) Validate() string {
	if req.Content == "" {
		return "content는 필수 항목입니다"
	}
	if utf8.RuneCountInString(req.Content) > 2000 {
		return "content는 2000자를 초과할 수 없습니다"
	}
	if req.LinkedTable != nil && *req.LinkedTable != "" {
		if !validLinkedTables[*req.LinkedTable] {
			return "linked_table은 purchase_orders, bl_shipments, outbounds, orders, declarations 중 하나여야 합니다"
		}
		if req.LinkedID == nil || *req.LinkedID == "" {
			return "linked_table이 지정되면 linked_id도 필수입니다"
		}
	}
	return ""
}

// UpdateNoteRequest — 메모 수정 시 클라이언트가 보내는 데이터
type UpdateNoteRequest struct {
	Content     *string `json:"content,omitempty"`
	LinkedTable *string `json:"linked_table,omitempty"`
	LinkedID    *string `json:"linked_id,omitempty"`
}

// Validate — 메모 수정 요청의 입력값을 검증
func (req *UpdateNoteRequest) Validate() string {
	if req.Content != nil {
		if *req.Content == "" {
			return "content는 빈 값으로 변경할 수 없습니다"
		}
		if utf8.RuneCountInString(*req.Content) > 2000 {
			return "content는 2000자를 초과할 수 없습니다"
		}
	}
	if req.LinkedTable != nil && *req.LinkedTable != "" && !validLinkedTables[*req.LinkedTable] {
		return "linked_table은 허용된 값이 아닙니다"
	}
	return ""
}
