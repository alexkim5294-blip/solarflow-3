package model

// SearchResponseModel — 자연어 검색 응답
type SearchResponseModel struct {
	Query        string             `json:"query"`
	Intent       string             `json:"intent"`
	Parsed       ParsedInfoModel    `json:"parsed"`
	Results      []SearchResultModel `json:"results"`
	Warnings     []string           `json:"warnings"`
	CalculatedAt string             `json:"calculated_at"`
}

// ParsedInfoModel — 파싱 결과
type ParsedInfoModel struct {
	Manufacturer *string  `json:"manufacturer,omitempty"`
	SpecWP       *int     `json:"spec_wp,omitempty"`
	Month        *string  `json:"month,omitempty"`
	Days         *int     `json:"days,omitempty"`
	Keywords     []string `json:"keywords"`
}

// SearchResultModel — 검색 결과 항목
type SearchResultModel struct {
	ResultType string            `json:"result_type"`
	Title      string            `json:"title"`
	Data       interface{}       `json:"data"`
	Link       SearchLinkModel   `json:"link"`
}

// SearchLinkModel — 결과 링크
type SearchLinkModel struct {
	Module string            `json:"module"`
	Params map[string]string `json:"params"`
}
