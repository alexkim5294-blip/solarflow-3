package model

import (
	"strings"
	"testing"
)

// TestExpenseValidate_NoBLIDNoMonth — bl_id와 month가 둘 다 없을 때 에러 반환 확인
func TestExpenseValidate_NoBLIDNoMonth(t *testing.T) {
	req := CreateExpenseRequest{
		CompanyID:   "550e8400-e29b-41d4-a716-446655440001",
		ExpenseType: "transport",
		Amount:      150000,
		Total:       165000,
		BLID:        nil,
		Month:       nil,
	}
	msg := req.Validate()
	if msg == "" {
		t.Fatal("bl_id와 month가 둘 다 없을 때 에러가 반환되어야 합니다")
	}
	if !strings.Contains(msg, "bl_id") || !strings.Contains(msg, "month") {
		t.Fatalf("에러 메시지에 'bl_id'와 'month'가 포함되어야 합니다, got: %s", msg)
	}
}

// TestExpenseValidate_InvalidType — 허용되지 않은 expense_type일 때 에러 반환 확인
func TestExpenseValidate_InvalidType(t *testing.T) {
	blID := "550e8400-e29b-41d4-a716-446655440000"
	req := CreateExpenseRequest{
		CompanyID:   "550e8400-e29b-41d4-a716-446655440001",
		ExpenseType: "invalid_type",
		Amount:      150000,
		Total:       165000,
		BLID:        &blID,
	}
	msg := req.Validate()
	if msg == "" {
		t.Fatal("잘못된 ExpenseType에 대해 에러가 반환되어야 합니다")
	}
	if !strings.Contains(msg, "expense_type") {
		t.Fatalf("에러 메시지에 'expense_type'이 포함되어야 합니다, got: %s", msg)
	}
}

// TestExpenseValidate_ZeroAmount — amount가 0일 때 에러 반환 확인
func TestExpenseValidate_ZeroAmount(t *testing.T) {
	blID := "550e8400-e29b-41d4-a716-446655440000"
	req := CreateExpenseRequest{
		CompanyID:   "550e8400-e29b-41d4-a716-446655440001",
		ExpenseType: "transport",
		Amount:      0,
		Total:       165000,
		BLID:        &blID,
	}
	msg := req.Validate()
	if msg == "" {
		t.Fatal("Amount=0에 대해 에러가 반환되어야 합니다")
	}
	if !strings.Contains(msg, "amount") {
		t.Fatalf("에러 메시지에 'amount'가 포함되어야 합니다, got: %s", msg)
	}
}

// TestExpenseValidate_WithBLID — bl_id가 있을 때 성공 확인
func TestExpenseValidate_WithBLID(t *testing.T) {
	blID := "550e8400-e29b-41d4-a716-446655440000"
	req := CreateExpenseRequest{
		CompanyID:   "550e8400-e29b-41d4-a716-446655440001",
		ExpenseType: "transport",
		Amount:      150000,
		Total:       165000,
		BLID:        &blID,
	}
	msg := req.Validate()
	if msg != "" {
		t.Fatalf("bl_id가 있는 정상 데이터에서 에러가 반환되면 안 됩니다, got: %s", msg)
	}
}

// TestExpenseValidate_WithMonth — month가 있을 때 성공 확인
func TestExpenseValidate_WithMonth(t *testing.T) {
	month := "2025-03"
	req := CreateExpenseRequest{
		CompanyID:   "550e8400-e29b-41d4-a716-446655440001",
		ExpenseType: "lc_fee",
		Amount:      50000,
		Total:       55000,
		Month:       &month,
	}
	msg := req.Validate()
	if msg != "" {
		t.Fatalf("month가 있는 정상 데이터에서 에러가 반환되면 안 됩니다, got: %s", msg)
	}
}
