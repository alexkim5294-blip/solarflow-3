package engine

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

// TestGetInventory_Success — mock 서버로 재고 집계 응답 파싱 확인
func TestGetInventory_Success(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/api/calc/inventory" {
			t.Fatalf("예상 경로: /api/calc/inventory, 실제: %s", r.URL.Path)
		}

		// 요청 본문에서 company_id 확인
		var reqBody map[string]interface{}
		if err := json.NewDecoder(r.Body).Decode(&reqBody); err != nil {
			t.Fatalf("요청 본문 파싱 실패: %v", err)
		}
		if reqBody["company_id"] == nil {
			t.Fatal("company_id가 요청 본문에 있어야 합니다")
		}

		// mock 응답
		resp := InventoryResponse{
			Items: []InventoryItem{
				{
					ProductID:        "test-product-uuid",
					ProductCode:      "M-JK0635-01",
					ProductName:      "JKM635N",
					ManufacturerName: "진코솔라",
					SpecWP:           635,
					ModuleWidthMM:    2465,
					ModuleHeightMM:   1134,
					PhysicalKW:       48200.0,
					ReservedKW:       12800.0,
					AllocatedKW:      5200.0,
					AvailableKW:      30200.0,
					IncomingKW:       30000.0,
					IncomingReservedKW: 20000.0,
					AvailableIncomingKW: 10000.0,
					TotalSecuredKW:   40200.0,
					LongTermStatus:   "normal",
				},
			},
			Summary: InventorySummary{
				TotalPhysicalKW:  48200.0,
				TotalAvailableKW: 30200.0,
				TotalIncomingKW:  30000.0,
				TotalSecuredKW:   40200.0,
			},
			CalculatedAt: "2026-03-29T12:00:00Z",
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		if err := json.NewEncoder(w).Encode(resp); err != nil {
			t.Fatalf("응답 인코딩 실패: %v", err)
		}
	}))
	defer server.Close()

	client := NewEngineClient(server.URL)
	result, err := client.GetInventory("test-company-uuid", nil, nil)
	if err != nil {
		t.Fatalf("GetInventory 실패: %v", err)
	}

	if len(result.Items) != 1 {
		t.Fatalf("Items 개수 예상: 1, 실제: %d", len(result.Items))
	}
	if result.Items[0].ProductCode != "M-JK0635-01" {
		t.Fatalf("ProductCode 예상: M-JK0635-01, 실제: %s", result.Items[0].ProductCode)
	}
	if result.Summary.TotalPhysicalKW != 48200.0 {
		t.Fatalf("TotalPhysicalKW 예상: 48200.0, 실제: %f", result.Summary.TotalPhysicalKW)
	}
	if result.Summary.TotalSecuredKW != 40200.0 {
		t.Fatalf("TotalSecuredKW 예상: 40200.0, 실제: %f", result.Summary.TotalSecuredKW)
	}
}

// TestGetInventory_WithFilters — product_id, manufacturer_id 필터 전달 확인
func TestGetInventory_WithFilters(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var reqBody map[string]interface{}
		if err := json.NewDecoder(r.Body).Decode(&reqBody); err != nil {
			t.Fatalf("요청 본문 파싱 실패: %v", err)
		}
		if reqBody["product_id"] == nil {
			t.Fatal("product_id가 요청 본문에 있어야 합니다")
		}
		if reqBody["manufacturer_id"] == nil {
			t.Fatal("manufacturer_id가 요청 본문에 있어야 합니다")
		}

		resp := InventoryResponse{
			Items:        []InventoryItem{},
			Summary:      InventorySummary{},
			CalculatedAt: "2026-03-29T12:00:00Z",
		}
		w.Header().Set("Content-Type", "application/json")
		if err := json.NewEncoder(w).Encode(resp); err != nil {
			t.Fatalf("응답 인코딩 실패: %v", err)
		}
	}))
	defer server.Close()

	client := NewEngineClient(server.URL)
	prodID := "test-product-uuid"
	mfgID := "test-mfg-uuid"
	result, err := client.GetInventory("test-company-uuid", &prodID, &mfgID)
	if err != nil {
		t.Fatalf("GetInventory 실패: %v", err)
	}
	if len(result.Items) != 0 {
		t.Fatalf("빈 결과 예상, 실제: %d items", len(result.Items))
	}
}
