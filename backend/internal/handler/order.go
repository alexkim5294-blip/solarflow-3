package handler

import (
	"encoding/json"
	"log"
	"net/http"

	"github.com/go-chi/chi/v5"
	supa "github.com/supabase-community/supabase-go"

	"solarflow-backend/internal/model"
	"solarflow-backend/internal/response"
)

// OrderHandler — 수주(orders) 관련 API를 처리하는 핸들러
// 비유: "수주 관리실" — 고객별 판매 주문서를 관리
type OrderHandler struct {
	DB *supa.Client
}

// NewOrderHandler — OrderHandler 생성자
func NewOrderHandler(db *supa.Client) *OrderHandler {
	return &OrderHandler{DB: db}
}

// List — GET /api/v1/orders — 수주 목록 조회
// 비유: 수주 관리실에서 전체 주문서를 꺼내 보여주는 것
// TODO: delivery_due 범위 필터 추가 (대시보드 출고 예정 알림용)
func (h *OrderHandler) List(w http.ResponseWriter, r *http.Request) {
	query := h.DB.From("orders").
		Select("*", "exact", false)

	// 비유: ?company_id=xxx — 특정 법인의 수주만 필터
	if compID := r.URL.Query().Get("company_id"); compID != "" && compID != "all" {
		query = query.Eq("company_id", compID)
	}

	// 비유: ?customer_id=xxx — 특정 고객의 수주만 필터
	if custID := r.URL.Query().Get("customer_id"); custID != "" {
		query = query.Eq("customer_id", custID)
	}

	// 비유: ?status=received — 특정 상태의 수주만 필터
	if status := r.URL.Query().Get("status"); status != "" {
		query = query.Eq("status", status)
	}

	// 비유: ?product_id=xxx — 특정 품번의 수주만 필터
	if prodID := r.URL.Query().Get("product_id"); prodID != "" {
		query = query.Eq("product_id", prodID)
	}

	// 비유: ?management_category=sale — 관리구분 필터
	if mgmtCat := r.URL.Query().Get("management_category"); mgmtCat != "" {
		query = query.Eq("management_category", mgmtCat)
	}

	// 비유: ?fulfillment_source=stock — 충당 소스 필터
	if source := r.URL.Query().Get("fulfillment_source"); source != "" {
		query = query.Eq("fulfillment_source", source)
	}

	data, _, err := query.Execute()
	if err != nil {
		log.Printf("[수주 목록 조회 실패] %v", err)
		response.RespondError(w, http.StatusInternalServerError, "수주 목록 조회에 실패했습니다")
		return
	}

	var orders []model.Order
	if err := json.Unmarshal(data, &orders); err != nil {
		log.Printf("[수주 목록 디코딩 실패] %v", err)
		response.RespondError(w, http.StatusInternalServerError, "응답 데이터 처리에 실패했습니다")
		return
	}
	h.enrichOrders(orders)

	response.RespondJSON(w, http.StatusOK, orders)
}

// GetByID — GET /api/v1/orders/{id} — 수주 상세 조회
// 비유: 특정 주문서를 꺼내 자세히 보는 것
func (h *OrderHandler) GetByID(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")

	data, _, err := h.DB.From("orders").
		Select("*", "exact", false).
		Eq("order_id", id).
		Execute()
	if err != nil {
		log.Printf("[수주 상세 조회 실패] id=%s, err=%v", id, err)
		response.RespondError(w, http.StatusInternalServerError, "수주 조회에 실패했습니다")
		return
	}

	var orders []model.Order
	if err := json.Unmarshal(data, &orders); err != nil {
		log.Printf("[수주 상세 디코딩 실패] %v", err)
		response.RespondError(w, http.StatusInternalServerError, "응답 데이터 처리에 실패했습니다")
		return
	}

	if len(orders) == 0 {
		response.RespondError(w, http.StatusNotFound, "수주를 찾을 수 없습니다")
		return
	}
	h.enrichOrders(orders)

	response.RespondJSON(w, http.StatusOK, orders[0])
}

type orderPartnerSummary struct {
	PartnerID   string `json:"partner_id"`
	PartnerName string `json:"partner_name"`
}

type orderCompanySummary struct {
	CompanyID   string `json:"company_id"`
	CompanyName string `json:"company_name"`
}

type orderProductSummary struct {
	ProductID      string  `json:"product_id"`
	ProductCode    string  `json:"product_code"`
	ProductName    string  `json:"product_name"`
	ManufacturerID string  `json:"manufacturer_id"`
	SpecWP         int     `json:"spec_wp"`
	WattageKW      float64 `json:"wattage_kw"`
}

type orderManufacturerSummary struct {
	ManufacturerID string  `json:"manufacturer_id"`
	NameKR         string  `json:"name_kr"`
	ShortName      *string `json:"short_name"`
}

func (h *OrderHandler) enrichOrders(orders []model.Order) {
	if len(orders) == 0 {
		return
	}

	companyIDs := make([]string, 0)
	customerIDs := make([]string, 0)
	productIDs := make([]string, 0)
	seenCompanies := map[string]bool{}
	seenCustomers := map[string]bool{}
	seenProducts := map[string]bool{}
	for _, order := range orders {
		if order.CompanyID != "" && !seenCompanies[order.CompanyID] {
			companyIDs = append(companyIDs, order.CompanyID)
			seenCompanies[order.CompanyID] = true
		}
		if order.CustomerID != "" && !seenCustomers[order.CustomerID] {
			customerIDs = append(customerIDs, order.CustomerID)
			seenCustomers[order.CustomerID] = true
		}
		if order.ProductID != "" && !seenProducts[order.ProductID] {
			productIDs = append(productIDs, order.ProductID)
			seenProducts[order.ProductID] = true
		}
	}

	companyMap := map[string]orderCompanySummary{}
	if len(companyIDs) > 0 {
		if data, _, err := h.DB.From("companies").
			Select("company_id, company_name", "exact", false).
			In("company_id", companyIDs).
			Execute(); err == nil {
			var companies []orderCompanySummary
			if err := json.Unmarshal(data, &companies); err == nil {
				for _, company := range companies {
					companyMap[company.CompanyID] = company
				}
			}
		} else {
			log.Printf("[수주 표시명 보강: 법인 조회 실패] %v", err)
		}
	}

	partnerMap := map[string]orderPartnerSummary{}
	if len(customerIDs) > 0 {
		if data, _, err := h.DB.From("partners").
			Select("partner_id, partner_name", "exact", false).
			In("partner_id", customerIDs).
			Execute(); err == nil {
			var partners []orderPartnerSummary
			if err := json.Unmarshal(data, &partners); err == nil {
				for _, partner := range partners {
					partnerMap[partner.PartnerID] = partner
				}
			}
		} else {
			log.Printf("[수주 표시명 보강: 거래처 조회 실패] %v", err)
		}
	}

	productMap := map[string]orderProductSummary{}
	manufacturerIDs := make([]string, 0)
	seenManufacturers := map[string]bool{}
	if len(productIDs) > 0 {
		if data, _, err := h.DB.From("products").
			Select("product_id, product_code, product_name, manufacturer_id, spec_wp, wattage_kw", "exact", false).
			In("product_id", productIDs).
			Execute(); err == nil {
			var products []orderProductSummary
			if err := json.Unmarshal(data, &products); err == nil {
				for _, product := range products {
					productMap[product.ProductID] = product
					if product.ManufacturerID != "" && !seenManufacturers[product.ManufacturerID] {
						manufacturerIDs = append(manufacturerIDs, product.ManufacturerID)
						seenManufacturers[product.ManufacturerID] = true
					}
				}
			}
		} else {
			log.Printf("[수주 표시명 보강: 품목 조회 실패] %v", err)
		}
	}

	manufacturerMap := map[string]orderManufacturerSummary{}
	if len(manufacturerIDs) > 0 {
		if data, _, err := h.DB.From("manufacturers").
			Select("manufacturer_id, name_kr, short_name", "exact", false).
			In("manufacturer_id", manufacturerIDs).
			Execute(); err == nil {
			var manufacturers []orderManufacturerSummary
			if err := json.Unmarshal(data, &manufacturers); err == nil {
				for _, manufacturer := range manufacturers {
					manufacturerMap[manufacturer.ManufacturerID] = manufacturer
				}
			}
		} else {
			log.Printf("[수주 표시명 보강: 제조사 조회 실패] %v", err)
		}
	}

	for i := range orders {
		if company, ok := companyMap[orders[i].CompanyID]; ok {
			orders[i].CompanyName = &company.CompanyName
		}
		if partner, ok := partnerMap[orders[i].CustomerID]; ok {
			orders[i].CustomerName = &partner.PartnerName
		}
		if product, ok := productMap[orders[i].ProductID]; ok {
			orders[i].ProductCode = &product.ProductCode
			orders[i].ProductName = &product.ProductName
			orders[i].SpecWp = &product.SpecWP
			orders[i].WattageKw = &product.WattageKW
			if manufacturer, ok := manufacturerMap[product.ManufacturerID]; ok {
				name := manufacturer.NameKR
				if manufacturer.ShortName != nil && *manufacturer.ShortName != "" {
					name = *manufacturer.ShortName
				}
				orders[i].ManufacturerName = &name
			}
		}
	}
}

// Create — POST /api/v1/orders — 수주 등록
// 비유: 새 주문서를 작성하여 관리실에 보관하는 것
func (h *OrderHandler) Create(w http.ResponseWriter, r *http.Request) {
	var req model.CreateOrderRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		log.Printf("[수주 등록 요청 파싱 실패] %v", err)
		response.RespondError(w, http.StatusBadRequest, "잘못된 요청 형식입니다")
		return
	}

	// 비유: management_category 미입력이면 기본값 "sale" 설정
	if req.ManagementCategory == "" {
		req.ManagementCategory = "sale"
	}
	// 비유: fulfillment_source 미입력이면 기본값 "stock" 설정
	if req.FulfillmentSource == "" {
		req.FulfillmentSource = "stock"
	}

	if msg := req.Validate(); msg != "" {
		response.RespondError(w, http.StatusBadRequest, msg)
		return
	}

	data, _, err := h.DB.From("orders").
		Insert(req, false, "", "", "").
		Execute()
	if err != nil {
		log.Printf("[수주 등록 실패] %v", err)
		response.RespondError(w, http.StatusInternalServerError, "수주 등록에 실패했습니다")
		return
	}

	var created []model.Order
	if err := json.Unmarshal(data, &created); err != nil {
		log.Printf("[수주 등록 결과 디코딩 실패] %v", err)
		response.RespondError(w, http.StatusInternalServerError, "응답 데이터 처리에 실패했습니다")
		return
	}

	if len(created) == 0 {
		response.RespondError(w, http.StatusInternalServerError, "수주 등록 결과를 확인할 수 없습니다")
		return
	}

	response.RespondJSON(w, http.StatusCreated, created[0])
}

// Update — PUT /api/v1/orders/{id} — 수주 수정
// 비유: 기존 주문서의 내용을 수정하는 것
func (h *OrderHandler) Update(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")

	var req model.UpdateOrderRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		log.Printf("[수주 수정 요청 파싱 실패] %v", err)
		response.RespondError(w, http.StatusBadRequest, "잘못된 요청 형식입니다")
		return
	}

	if msg := req.Validate(); msg != "" {
		response.RespondError(w, http.StatusBadRequest, msg)
		return
	}

	data, _, err := h.DB.From("orders").
		Update(req, "", "").
		Eq("order_id", id).
		Execute()
	if err != nil {
		log.Printf("[수주 수정 실패] id=%s, err=%v", id, err)
		response.RespondError(w, http.StatusInternalServerError, "수주 수정에 실패했습니다")
		return
	}

	var updated []model.Order
	if err := json.Unmarshal(data, &updated); err != nil {
		log.Printf("[수주 수정 결과 디코딩 실패] %v", err)
		response.RespondError(w, http.StatusInternalServerError, "응답 데이터 처리에 실패했습니다")
		return
	}

	if len(updated) == 0 {
		response.RespondError(w, http.StatusNotFound, "수정할 수주를 찾을 수 없습니다")
		return
	}

	response.RespondJSON(w, http.StatusOK, updated[0])
}

// Delete — DELETE /api/v1/orders/{id} — 수주 삭제
// 비유: 수주 주문서를 파기하는 것 — 연결된 출고가 있으면 DB FK 제약으로 막힘
func (h *OrderHandler) Delete(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")

	_, _, err := h.DB.From("orders").
		Delete("", "").
		Eq("order_id", id).
		Execute()
	if err != nil {
		log.Printf("[수주 삭제 실패] id=%s, err=%v", id, err)
		response.RespondError(w, http.StatusInternalServerError, "수주 삭제에 실패했습니다 (연결된 출고가 있으면 먼저 삭제해야 합니다)")
		return
	}

	response.RespondJSON(w, http.StatusOK, struct {
		Status string `json:"status"`
	}{Status: "deleted"})
}
