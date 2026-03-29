package engine

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestGetSupplyForecast_Success(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		resp := ForecastCalcResponse{
			Products: []ForecastCalcProduct{
				{ProductCode: "M-JK0635-01", ManufacturerName: "진코솔라", SpecWP: 635},
			},
			CalculatedAt: "2026-03-29T12:00:00Z",
		}
		w.Header().Set("Content-Type", "application/json")
		if err := json.NewEncoder(w).Encode(resp); err != nil {
			t.Fatalf("인코딩 실패: %v", err)
		}
	}))
	defer server.Close()

	client := NewEngineClient(server.URL)
	result, err := client.GetSupplyForecast("company-uuid", nil, nil, 6)
	if err != nil {
		t.Fatalf("GetSupplyForecast 실패: %v", err)
	}
	if len(result.Products) != 1 {
		t.Fatalf("Products 예상: 1, 실제: %d", len(result.Products))
	}
	if result.Products[0].SpecWP != 635 {
		t.Fatalf("SpecWP 예상: 635, 실제: %d", result.Products[0].SpecWP)
	}
}
