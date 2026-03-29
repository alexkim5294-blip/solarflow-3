package engine

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestSearch_Success(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		resp := SearchCalcResponse{Query: "진코 640 재고", Intent: "inventory", CalculatedAt: "2026-03-29T12:00:00Z"}
		w.Header().Set("Content-Type", "application/json")
		if err := json.NewEncoder(w).Encode(resp); err != nil { t.Fatalf("인코딩 실패: %v", err) }
	}))
	defer server.Close()

	client := NewEngineClient(server.URL)
	result, err := client.Search("company-uuid", "진코 640 재고")
	if err != nil { t.Fatalf("Search 실패: %v", err) }
	if result.Intent != "inventory" { t.Fatalf("Intent 예상: inventory, 실제: %s", result.Intent) }
}
