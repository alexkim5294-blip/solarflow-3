package engine

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestGetMarginAnalysis_Success(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		resp := MarginCalcResponse{
			Items:   []MarginCalcItem{{ProductCode: "M-JK0635-01", AvgSalePriceWP: 155.0, TotalRevenueKRW: 520584000}},
			Summary: MarginCalcSummary{OverallMarginRate: 15.16, CostBasis: "cif"},
			CalculatedAt: "2026-03-29T12:00:00Z",
		}
		w.Header().Set("Content-Type", "application/json")
		if err := json.NewEncoder(w).Encode(resp); err != nil { t.Fatalf("인코딩 실패: %v", err) }
	}))
	defer server.Close()

	client := NewEngineClient(server.URL)
	result, err := client.GetMarginAnalysis("company-uuid", nil, nil, nil, nil, "cif")
	if err != nil { t.Fatalf("GetMarginAnalysis 실패: %v", err) }
	if result.Summary.CostBasis != "cif" { t.Fatalf("CostBasis 예상: cif, 실제: %s", result.Summary.CostBasis) }
	if len(result.Items) != 1 { t.Fatalf("Items 예상: 1, 실제: %d", len(result.Items)) }
}

func TestGetCustomerAnalysis_Success(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		resp := CustomerCalcResponse{
			Items:        []CustomerCalcItem{{CustomerName: "바로(주)", TotalSalesKRW: 850000000, OutstandingKRW: 64562400, Status: "normal"}},
			CalculatedAt: "2026-03-29T12:00:00Z",
		}
		w.Header().Set("Content-Type", "application/json")
		if err := json.NewEncoder(w).Encode(resp); err != nil { t.Fatalf("인코딩 실패: %v", err) }
	}))
	defer server.Close()

	client := NewEngineClient(server.URL)
	result, err := client.GetCustomerAnalysis("company-uuid", nil, nil, nil)
	if err != nil { t.Fatalf("GetCustomerAnalysis 실패: %v", err) }
	if result.Items[0].Status != "normal" { t.Fatalf("Status 예상: normal, 실제: %s", result.Items[0].Status) }
}

func TestGetPriceTrend_Success(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		resp := PriceTrendCalcResponse{
			Trends:       []TrendCalcProduct{{ManufacturerName: "진코솔라", ProductName: "JKM635N", SpecWP: 635}},
			CalculatedAt: "2026-03-29T12:00:00Z",
		}
		w.Header().Set("Content-Type", "application/json")
		if err := json.NewEncoder(w).Encode(resp); err != nil { t.Fatalf("인코딩 실패: %v", err) }
	}))
	defer server.Close()

	client := NewEngineClient(server.URL)
	result, err := client.GetPriceTrend("company-uuid", nil, nil, "quarterly")
	if err != nil { t.Fatalf("GetPriceTrend 실패: %v", err) }
	if len(result.Trends) != 1 { t.Fatalf("Trends 예상: 1, 실제: %d", len(result.Trends)) }
}
