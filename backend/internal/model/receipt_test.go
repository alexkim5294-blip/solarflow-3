package model

import (
	"strings"
	"testing"
)

// TestReceiptValidate_ZeroAmount — amount가 0일 때 에러 반환 확인
func TestReceiptValidate_ZeroAmount(t *testing.T) {
	req := CreateReceiptRequest{
		CustomerID:  "550e8400-e29b-41d4-a716-446655440001",
		ReceiptDate: "2025-03-20",
		Amount:      0,
	}
	msg := req.Validate()
	if msg == "" {
		t.Fatal("Amount=0에 대해 에러가 반환되어야 합니다")
	}
	if !strings.Contains(msg, "amount") {
		t.Fatalf("에러 메시지에 'amount'가 포함되어야 합니다, got: %s", msg)
	}
}

// TestReceiptValidate_EmptyCustomerID — customer_id가 빈 값일 때 에러 반환 확인
func TestReceiptValidate_EmptyCustomerID(t *testing.T) {
	req := CreateReceiptRequest{
		CustomerID:  "",
		ReceiptDate: "2025-03-20",
		Amount:      5000000,
	}
	msg := req.Validate()
	if msg == "" {
		t.Fatal("빈 CustomerID에 대해 에러가 반환되어야 합니다")
	}
	if !strings.Contains(msg, "customer_id") {
		t.Fatalf("에러 메시지에 'customer_id'가 포함되어야 합니다, got: %s", msg)
	}
}

// TestReceiptValidate_Success — 정상 데이터일 때 빈 문자열 반환 확인
func TestReceiptValidate_Success(t *testing.T) {
	req := CreateReceiptRequest{
		CustomerID:  "550e8400-e29b-41d4-a716-446655440001",
		ReceiptDate: "2025-03-20",
		Amount:      5000000,
	}
	msg := req.Validate()
	if msg != "" {
		t.Fatalf("정상 데이터에서 에러가 반환되면 안 됩니다, got: %s", msg)
	}
}
