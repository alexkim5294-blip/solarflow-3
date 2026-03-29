package model

// SupplyForecastResponse — 월별 수급 전망 응답
type SupplyForecastResponse struct {
	Products     []ProductForecastResp `json:"products"`
	Summary      ForecastSummaryResp   `json:"summary"`
	CalculatedAt string                `json:"calculated_at"`
}

// ProductForecastResp — 품번별 전망
type ProductForecastResp struct {
	ProductID        string                  `json:"product_id"`
	ProductCode      string                  `json:"product_code"`
	ProductName      string                  `json:"product_name"`
	ManufacturerName string                  `json:"manufacturer_name"`
	SpecWP           int                     `json:"spec_wp"`
	Months           []MonthForecastResp     `json:"months"`
	Unscheduled      UnscheduledForecastResp `json:"unscheduled"`
}

// MonthForecastResp — 월별 전망 데이터
type MonthForecastResp struct {
	Month                 string  `json:"month"`
	OpeningKW             float64 `json:"opening_kw"`
	IncomingKW            float64 `json:"incoming_kw"`
	OutgoingConstructionKW float64 `json:"outgoing_construction_kw"`
	OutgoingSaleKW        float64 `json:"outgoing_sale_kw"`
	ClosingKW             float64 `json:"closing_kw"`
	ReservedKW            float64 `json:"reserved_kw"`
	AllocatedKW           float64 `json:"allocated_kw"`
	AvailableKW           float64 `json:"available_kw"`
	Insufficient          bool    `json:"insufficient"`
}

// UnscheduledForecastResp — 미확정 물량
type UnscheduledForecastResp struct {
	SaleKW         float64 `json:"sale_kw"`
	ConstructionKW float64 `json:"construction_kw"`
	IncomingKW     float64 `json:"incoming_kw"`
}

// ForecastSummaryResp — 전체 합계
type ForecastSummaryResp struct {
	Months []SummaryMonthResp `json:"months"`
}

// SummaryMonthResp — 월별 합계
type SummaryMonthResp struct {
	Month            string  `json:"month"`
	TotalOpeningKW   float64 `json:"total_opening_kw"`
	TotalIncomingKW  float64 `json:"total_incoming_kw"`
	TotalOutgoingKW  float64 `json:"total_outgoing_kw"`
	TotalClosingKW   float64 `json:"total_closing_kw"`
	TotalAvailableKW float64 `json:"total_available_kw"`
}
