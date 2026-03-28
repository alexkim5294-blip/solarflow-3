package router

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"solarflow-backend/internal/handler"
	"solarflow-backend/internal/middleware"

	supa "github.com/supabase-community/supabase-go"
)

// New는 전체 라우터를 생성하고 모든 경로를 등록
func New(db *supa.Client) http.Handler {
	r := chi.NewRouter()

	// ── 미들웨어 ──
	r.Use(middleware.CORS)

	// ── 헬스체크 ──
	r.Get("/health", handler.HealthCheck)

	// ── API v1 ──
	r.Route("/api/v1", func(r chi.Router) {

		// 1. 법인 관리
		companyH := handler.NewCompanyHandler(db)
		r.Route("/companies", func(r chi.Router) {
			r.Get("/", companyH.List)
			r.Post("/", companyH.Create)
			r.Get("/{id}", companyH.GetByID)
			r.Put("/{id}", companyH.Update)
			r.Patch("/{id}/status", companyH.ToggleStatus)
		})

		// 2. 제조사 관리
		mfgH := handler.NewManufacturerHandler(db)
		r.Route("/manufacturers", func(r chi.Router) {
			r.Get("/", mfgH.List)
			r.Post("/", mfgH.Create)
			r.Get("/{id}", mfgH.GetByID)
			r.Put("/{id}", mfgH.Update)
		})

		// 3. 품번 관리 ★ NEW
		productH := handler.NewProductHandler(db)
		r.Route("/products", func(r chi.Router) {
			r.Get("/", productH.List)          // ?manufacturer_id=xxx&active=true
			r.Post("/", productH.Create)
			r.Get("/{id}", productH.GetByID)
			r.Put("/{id}", productH.Update)
		})

		// 4. 거래처 관리 ★ NEW
		partnerH := handler.NewPartnerHandler(db)
		r.Route("/partners", func(r chi.Router) {
			r.Get("/", partnerH.List)           // ?type=supplier|customer|both
			r.Post("/", partnerH.Create)
			r.Get("/{id}", partnerH.GetByID)
			r.Put("/{id}", partnerH.Update)
		})

		// 5. 창고/장소 관리 ★ NEW
		warehouseH := handler.NewWarehouseHandler(db)
		r.Route("/warehouses", func(r chi.Router) {
			r.Get("/", warehouseH.List)         // ?type=port|factory|vendor
			r.Post("/", warehouseH.Create)
			r.Get("/{id}", warehouseH.GetByID)
			r.Put("/{id}", warehouseH.Update)
		})

		// 6. 은행 관리 ★ NEW
		bankH := handler.NewBankHandler(db)
		r.Route("/banks", func(r chi.Router) {
			r.Get("/", bankH.List)              // ?company_id=xxx
			r.Post("/", bankH.Create)
			r.Get("/{id}", bankH.GetByID)
			r.Put("/{id}", bankH.Update)
		})
	})

	return r
}
