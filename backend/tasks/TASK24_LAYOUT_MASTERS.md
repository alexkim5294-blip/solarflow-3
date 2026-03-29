# 작업: Step 21 — 레이아웃 + 네비게이션 + 마스터 CRUD 6개
harness/RULES.md를 반드시 따를 것. harness/CHECKLIST_TEMPLATE.md 양식으로 보고할 것.
감리 2건 수정 반영: Lucide 아이콘 + ProductPage 명시 정렬.

## 사전 작업: shadcn/ui 컴포넌트 추가 (Alex가 frontend/에서 실행)
npx shadcn@latest add card input label select table dialog
npx shadcn@latest add dropdown-menu separator badge switch
npx shadcn@latest add sheet tooltip pagination alert
npx shadcn@latest add form textarea

## 사이드바 메뉴 구조 (재고 최상단)

아이콘은 전부 Lucide React (감리 지적 1번):
import { Package, LayoutDashboard, PackageCheck, ClipboardList, Truck, HandCoins, Calculator, Landmark, Database, Search, StickyNote, FileSignature, Settings } from "lucide-react"

메뉴 순서:
1. Package — 재고 현황 (/inventory) — Step 22, 현재 빈 페이지
2. LayoutDashboard — 대시보드 (/) — Step 28, 현재 빈 페이지
구분선
3. PackageCheck — 입고 관리 (/inbound) — Step 23
4. ClipboardList — 발주/결제 (/procurement) — Step 24
5. Truck — 출고/판매 (/outbound) — Step 25
6. HandCoins — 수주/수금 (/orders) — Step 26
7. Calculator — 면장/원가 (/customs) — Step 27
8. Landmark — 은행/LC (/banking) — Step 28
구분선
9. Database — 마스터 관리 (하위 펼침)
   법인 (/masters/companies)
   제조사 (/masters/manufacturers)
   품번 (/masters/products)
   거래처 (/masters/partners)
   창고 (/masters/warehouses)
   은행 (/masters/banks)
구분선
10. Search — 검색 (/search) — Step 31
11. StickyNote — 메모 (/memo) — Step 31
12. FileSignature — 결재안 (/approval) — Step 30
구분선
13. Settings — 설정 (/settings) — admin만

하단: 사용자 이름 + 역할 + 로그아웃

### 역할별 메뉴 표시
- admin: 전체
- executive: 재고, 대시보드(경영진용), 검색, 메모 (입력 메뉴 숨김)
- manager: 전체 (설정 제외)
- staff: 전체 (설정 제외, Phase 확장 시 allowed_modules 적용)
- viewer: 재고, 대시보드, 검색 (입력 메뉴 숨김)

## 파일 구조

frontend/src/
├── components/
│   ├── layout/
│   │   ├── AppLayout.tsx
│   │   ├── Sidebar.tsx
│   │   ├── Header.tsx
│   │   ├── CompanySelector.tsx
│   │   └── UserMenu.tsx
│   ├── common/
│   │   ├── DataTable.tsx
│   │   ├── SearchInput.tsx
│   │   ├── ConfirmDialog.tsx
│   │   ├── StatusBadge.tsx
│   │   ├── LoadingSpinner.tsx
│   │   └── EmptyState.tsx
│   └── masters/
│       ├── CompanyForm.tsx
│       ├── ManufacturerForm.tsx
│       ├── ProductForm.tsx
│       ├── PartnerForm.tsx
│       ├── WarehouseForm.tsx
│       └── BankForm.tsx
├── pages/
│   ├── masters/
│   │   ├── CompanyPage.tsx
│   │   ├── ManufacturerPage.tsx
│   │   ├── ProductPage.tsx
│   │   ├── PartnerPage.tsx
│   │   ├── WarehousePage.tsx
│   │   └── BankPage.tsx
│   ├── InventoryPage.tsx (빈 — "Step 22에서 구현 예정")
│   ├── DashboardPage.tsx (빈 — "Step 28에서 구현 예정")
│   └── PlaceholderPage.tsx (미구현 페이지 공통 — "Step N에서 구현 예정")
├── stores/
│   └── appStore.ts
├── types/
│   └── masters.ts
└── lib/
    └── utils.ts (포맷 유틸 추가)

## 레이아웃 상세

### AppLayout.tsx
- 좌측 사이드바 (w-64, 접힌 상태 w-16)
- 상단 헤더 (h-14)
- 메인 콘텐츠 (Outlet — React Router)
- 반응형: 768px 이하에서 사이드바를 Sheet(슬라이드)로
- 사이드바 상태는 appStore.sidebarCollapsed

### Sidebar.tsx
- 메뉴 아이템 배열 (아이콘, 라벨, 경로, 필요 역할, 하위 메뉴)
- 현재 경로 매칭 → 하이라이트 (bg-accent)
- 마스터 관리: Collapsible (클릭하면 하위 6개 펼침/접힘)
- 접힌 상태(w-16): 아이콘만 표시 + tooltip으로 라벨
- 하단: 사용자 이름(full_name) + 역할 뱃지 + 로그아웃 버튼
- 역할 기반 필터: user.role에 따라 메뉴 아이템 필터링

### Header.tsx
- 좌측: 사이드바 토글 버튼 (Menu 아이콘)
- 중앙: (비어있음 — Step 31에서 검색바)
- 우측: CompanySelector + UserMenu

### CompanySelector.tsx
- Select 드롭다운
- 옵션: "전체" + Go API GET /api/v1/companies에서 active 법인 목록
- 선택값 → appStore.selectedCompanyId
- "전체" 선택 시 null
- 컴포넌트 마운트 시 API 호출 → 법인 목록 캐시

### UserMenu.tsx
- DropdownMenu: 사용자 이름 클릭
- 메뉴: 프로필 (미구현), 로그아웃
- 로그아웃 → authStore.logout() → /login 이동

### appStore.ts (Zustand)
- selectedCompanyId: string | null
- setCompanyId(id: string | null)
- sidebarCollapsed: boolean
- toggleSidebar()

## 공통 컴포넌트 상세

### DataTable.tsx
Props:
- columns: { key: string, label: string, sortable?: boolean, render?: (row) => ReactNode }[]
- data: T[]
- loading: boolean
- searchable?: boolean
- searchPlaceholder?: string
- onSearch?: (query: string) => void
- actions?: (row: T) => ReactNode
- emptyMessage?: string
- defaultSort?: { key: string, direction: 'asc' | 'desc' }

기능:
- shadcn/ui Table 기반
- 컬럼 헤더 클릭 → 오름차순/내림차순 토글 (프론트 정렬)
- defaultSort 지정 시 초기 정렬 적용
- 검색 입력 → 300ms 디바운스 → onSearch
- loading → 스켈레톤 행 표시
- 데이터 없음 → EmptyState

### SearchInput.tsx
- Input + Search 아이콘
- 디바운스 300ms
- onChange 콜백

### ConfirmDialog.tsx
- Dialog + "정말 실행하시겠습니까?" 메시지
- 확인/취소 버튼
- onConfirm 콜백

### StatusBadge.tsx
- is_active true → Badge variant="default" "활성"
- is_active false → Badge variant="secondary" "비활성"

### LoadingSpinner.tsx
- 중앙 정렬 스피너 애니메이션

### EmptyState.tsx
- 아이콘 + "데이터가 없습니다" 메시지
- 선택적 액션 버튼 ("새로 등록")

## 마스터 6개 상세

### 공통 패턴 (6개 모두 동일):
1. Page: 목록 + 검색 + [새로 등록] 버튼 + DataTable
2. Form: Dialog 안에 폼 (생성/수정 공용)
3. API: useApi 훅으로 Go API 호출
4. 토글: Switch + ConfirmDialog

### 1. CompanyPage
- API: /api/v1/companies
- 컬럼: 법인명, 법인코드, 사업자번호, 활성
- CompanyForm: company_name(필수), company_code(필수), business_number(선택)

### 2. ManufacturerPage
- API: /api/v1/manufacturers
- 컬럼: 제조사명(한), 제조사명(영), 국가, 국내/해외, 활성
- ManufacturerForm: name_kr(필수), name_en, country(필수), domestic_foreign(Select: 국내/해외)

### 3. ProductPage (감리 지적 2번: 명시 정렬)
- API: /api/v1/products
- 컬럼: 품번코드, 품명, 제조사, 규격(Wp), 크기(mm), 활성
- 기본 정렬: manufacturer_name → module_width_mm → module_height_mm → spec_wp
  DataTable defaultSort로 다중 키 정렬 구현:
  data.sort((a, b) => {
    if (a.manufacturer_name !== b.manufacturer_name) return a.manufacturer_name.localeCompare(b.manufacturer_name)
    if (a.module_width_mm !== b.module_width_mm) return a.module_width_mm - b.module_width_mm
    if (a.module_height_mm !== b.module_height_mm) return a.module_height_mm - b.module_height_mm
    return a.spec_wp - b.spec_wp
  })
  이 정렬은 ProductPage에서 직접 적용 (DataTable의 단일 키 정렬과 별도)
- ProductForm: product_code(필수), product_name(필수), manufacturer_id(Select — 제조사 API), spec_wp(필수,양수), wattage_kw(필수,양수), module_width_mm(필수,양수), module_height_mm(필수,양수), module_depth_mm, weight_kg, wafer_platform, cell_config, series_name, memo
- 크기 표시: "2465 x 1134 mm" 형식

### 4. PartnerPage
- API: /api/v1/partners
- 컬럼: 거래처명, 유형, ERP코드, 담당자, 연락처, 활성
- 유형 표시: supplier="공급사", customer="고객사", both="공급+고객" (Badge 색상 구분)
- PartnerForm: partner_name(필수), partner_type(Select), erp_code, payment_terms, contact_name, contact_phone, contact_email

### 5. WarehousePage
- API: /api/v1/warehouses
- 컬럼: 창고코드, 창고명, 유형, 장소코드, 장소명, 활성
- 유형 표시: port="항구", factory="공장", vendor="업체"
- WarehouseForm: warehouse_code(필수,4자), warehouse_name(필수), warehouse_type(Select), location_code(필수,4자), location_name(필수)

### 6. BankPage
- API: /api/v1/banks
- 법인 필터: CompanySelector 값 자동 적용 (company_id 파라미터)
- 컬럼: 은행명, 법인, LC한도(USD), 개설수수료율(%), 인수수수료율(%), 활성
- 금액 포맷: formatUSD (예: $10,000,000.00)
- 비율 포맷: formatPercent (예: 0.20%)
- BankForm: company_id(Select — 법인 API), bank_name(필수), lc_limit_usd(필수,양수), opening_fee_rate, acceptance_fee_rate, fee_calc_method, memo

## types/masters.ts

Company: companyId, companyName, companyCode, businessNumber?, isActive
Manufacturer: manufacturerId, nameKr, nameEn?, country, domesticForeign, isActive
Product: productId, productCode, productName, manufacturerId, manufacturerName?, specWp, wattageKw, moduleWidthMm, moduleHeightMm, moduleDepthMm?, weightKg?, waferPlatform?, cellConfig?, seriesName?, memo?, isActive
Partner: partnerId, partnerName, partnerType, erpCode?, paymentTerms?, contactName?, contactPhone?, contactEmail?, isActive
Warehouse: warehouseId, warehouseCode, warehouseName, warehouseType, locationCode, locationName, isActive
Bank: bankId, companyId, companyName?, bankName, lcLimitUsd, openingFeeRate?, acceptanceFeeRate?, feeCalcMethod?, memo?, isActive

참고: Go API의 JSON 필드명(snake_case)과 프론트 타입(camelCase) 매핑 필요.
Go API가 snake_case로 반환하므로 프론트 타입도 snake_case로 통일하는 것이 실수 방지에 유리.
결정: Go API 응답 그대로 snake_case 사용.

## lib/utils.ts 포맷 유틸 추가

- formatNumber(n: number): string — "1,234,567"
- formatUSD(n: number): string — "$1,234,567.00"
- formatKRW(n: number): string — "1,234,567원"
- formatPercent(n: number): string — "0.20%"
- formatDate(d: string): string — "2026-03-29"
- formatWp(n: number): string — "635Wp"
- formatKw(n: number): string — "12,800.0kW"
- formatMW(n: number): string — "12.8MW"
- formatSize(w: number, h: number): string — "2465 x 1134 mm"

## 라우팅 (App.tsx 수정)

/ → AppLayout (ProtectedRoute)
  index → DashboardPage (빈)
  /inventory → InventoryPage (빈)
  /masters/companies → CompanyPage
  /masters/manufacturers → ManufacturerPage
  /masters/products → ProductPage
  /masters/partners → PartnerPage
  /masters/warehouses → WarehousePage
  /masters/banks → BankPage
  /inbound → PlaceholderPage (Step 23)
  /procurement → PlaceholderPage (Step 24)
  /outbound → PlaceholderPage (Step 25)
  /orders → PlaceholderPage (Step 26)
  /customs → PlaceholderPage (Step 27)
  /banking → PlaceholderPage (Step 28)
  /search → PlaceholderPage (Step 31)
  /memo → PlaceholderPage (Step 31)
  /approval → PlaceholderPage (Step 30)
/login → LoginPage

PlaceholderPage: props로 stepNumber, title 받아서 "Step N에서 구현 예정" 표시.

## DECISIONS.md 추가
- D-056: 사이드바 재고 최상단 배치. 이유: 실무에서 가장 자주 보는 화면.
- D-057: 마스터 CRUD는 Dialog 기반. 이유: 필드 적어 별도 페이지 불필요.
- D-058: 프론트 정렬/페이지네이션. 이유: 마스터 수백 건 이하.
- D-059: 프론트 타입은 snake_case. 이유: Go API 응답과 일치시켜 매핑 실수 방지.

## PROGRESS.md 업데이트
- Step 21 완료 기록

## 완료 기준
1. npm run build 성공 (타입 에러 0)
2. 로컬 테스트:
   - 로그인 -> AppLayout (사이드바 + 헤더)
   - 사이드바 재고가 최상단, Lucide 아이콘 표시
   - 법인 선택 드롭다운 동작
   - 마스터 6개 페이지 접근
   - 법인 CRUD 테스트 (목록/생성/수정/토글)
   - 품번 목록: 제조사->크기->규격 정렬 확인
   - 사이드바 접기/펼치기
3. harness/CHECKLIST_TEMPLATE.md 양식으로 보고
4. 전체 파일 코드(cat) 보여주기
