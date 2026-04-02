# 작업: Step 31 — 메모 + 검색 + 알림 센터
harness/RULES.md를 반드시 따를 것. harness/CHECKLIST_TEMPLATE.md 양식으로 보고할 것.
감리 지적 3건 + 확인 1건 반영.
확인: vite.config.ts는 fly.dev — 문제 없음.

## 선행: notes 테이블 생성 (Alex가 Supabase SQL Editor에서 실행)

CREATE TABLE IF NOT EXISTS notes (
    note_id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL,
    content TEXT NOT NULL,
    linked_table VARCHAR(30),
    linked_id UUID,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX idx_notes_user_id ON notes(user_id);
CREATE INDEX idx_notes_linked ON notes(linked_table, linked_id);

## 1. 독립 메모장

### Go API (신규)

backend/internal/handler/note.go — NoteHandler
backend/internal/model/note.go — Note 구조체

라우터 (main.go):
r.Route("/api/v1/notes", func(r chi.Router) {
    r.Use(AuthMiddleware)
    r.Get("/", noteHandler.List)
    r.Post("/", noteHandler.Create)
    r.Put("/{id}", noteHandler.Update)
    r.Delete("/{id}", noteHandler.Delete)
})

List: JWT uid로 user_id 필터. 쿼리 옵션: linked_table, linked_id.
Create: user_id = JWT uid. content 필수. linked_table+linked_id 선택.
Update: 본인 메모만 (user_id 확인, 타인이면 403).
Delete: 본인 메모만.

### Go 테스트 (backend/internal/handler/note_test.go)
- TestNote_Create_Success
- TestNote_List_ByUser
- TestNote_List_LinkedFilter: linked_table+linked_id로 필터
- TestNote_Update_Owner: 본인 수정 성공
- TestNote_Update_NotOwner: 타인 수정 403
- TestNote_Delete_Owner: 본인 삭제 성공

### 프론트 메모 UI

MemoPage (/memo):
포스트잇 스타일 카드 그리드.
각 카드: content 미리보기, 날짜, 연결 데이터 링크 아이콘.
[새 메모] → MemoForm Dialog (content Textarea + linked_table Select + linked_id Select).
수정/삭제 가능.

linked_table → 페이지 이동 매핑:
purchase_orders → /procurement
bl_shipments → /inbound
outbounds → /outbound
orders → /orders
declarations → /customs

LinkedMemoWidget: 각 상세 페이지(PO, B/L, 출고, 수주, 면장) 하단에 배치.
GET /api/v1/notes?linked_table=X&linked_id=Y → 연결 메모 표시 + [메모 추가].

파일:
frontend/src/pages/MemoPage.tsx
frontend/src/components/memo/MemoCard.tsx
frontend/src/components/memo/MemoForm.tsx
frontend/src/components/memo/MemoGrid.tsx
frontend/src/components/memo/LinkedMemoWidget.tsx
frontend/src/hooks/useMemo.ts
frontend/src/types/memo.ts

types/memo.ts:
Note: note_id, user_id, content, linked_table?, linked_id?, created_at, updated_at

## 2. 글로벌 검색 바

### Rust search API 응답 구조 (실제 확인 — 감리 지적 2 반영)

types/search.ts는 아래 Rust 모델과 정확히 일치시킬 것:

SearchResponse:
  query: string
  intent: string (inventory/compare/outbound/lc_maturity/po_payment/outstanding/fallback)
  parsed: ParsedInfo
  results: SearchResult[]
  warnings: string[]
  calculated_at: string

ParsedInfo:
  manufacturer?: string (skip_serializing_if None → 필드 자체 없을 수 있음)
  spec_wp?: number
  month?: string
  days?: number
  keywords: string[]

SearchResult:
  result_type: string
  title: string
  data: any (serde_json::Value → 의도별 다른 구조)
  link: SearchLink

SearchLink:
  module: string
  params: Record<string, string> (HashMap<String,String>)

주의: ParsedInfo의 optional 필드는 null이 아니라 필드 자체가 없을 수 있음 (skip_serializing_if).

### Header.tsx 수정: 검색 바 추가

헤더 중앙에 GlobalSearchBar 컴포넌트.
Ctrl+K (Mac: Cmd+K) → 포커스.
입력 → 500ms 디바운스 → POST /api/v1/calc/search { company_id, query }.
결과 → SearchResultPanel 드롭다운.

### SearchResultPanel

의도 표시: "의도: {intent} | 제조사: {parsed.manufacturer} | 규격: {parsed.spec_wp}Wp"
결과 목록: SearchResult 배열 → SearchResultCard 컴포넌트.
각 카드: result_type 아이콘 + title + data 요약 + [상세 보기] 링크.
warnings 있으면 노란 경고 배너: "⚠ {warning}"

결과 클릭 → link.module에 따라 페이지 이동:
inventory → /inventory
po → /procurement
outbound → /outbound
lc → /banking
customer-analysis → /orders
inbound → /inbound

### SearchPage (/search)

전체 화면 검색. 헤더 검색과 동일 로직.
검색 이력: localStorage "solarflow_search_history" 최근 10개.
인기 예시 표시: "진코 640 재고", "LC 만기 이번달", "미수금 60일"

파일:
frontend/src/pages/SearchPage.tsx
frontend/src/components/search/GlobalSearchBar.tsx
frontend/src/components/search/SearchResultPanel.tsx
frontend/src/components/search/SearchResultCard.tsx
frontend/src/components/search/SearchHistory.tsx
frontend/src/components/layout/Header.tsx (수정: 검색 바 추가)
frontend/src/hooks/useSearch.ts
frontend/src/types/search.ts

## 3. 알림 센터

### useAlerts.ts 분리 (감리 지적 3 반영)

Step 28B의 useDashboard에서 알림 계산 로직을 useAlerts.ts로 추출.
DashboardPage.tsx의 ManagerDashboard에서도 useAlerts를 import하도록 수정.
(기존: useDashboard 내부에서 알림 계산 → 변경: useAlerts 호출)

useAlerts(companyId):
- Promise.allSettled로 6개 API 호출 (기존 28B 로직)
- 9가지 알림 계산
- 5분 interval 자동 갱신 (setInterval + cleanup)
- 법인 변경 시 즉시 재조회
- 반환: alerts(AlertItem[]), totalCount, criticalCount, loading

### Header.tsx 수정: 알림 아이콘 추가

Bell 아이콘 (lucide-react) + Badge (criticalCount + warningCount).
클릭 → AlertDropdown (Sheet 또는 Popover).

### AlertDropdown

알림 목록 (severity 순: critical→warning→info).
건수 0인 알림 숨김.
각 알림 클릭 → 해당 페이지 이동 (link 필드).
[전체 보기] → /dashboard.

### DashboardPage.tsx 수정 (감리 지적 3 반영!)

ManagerDashboard의 AlertPanel에서:
변경 전: useDashboard 내부 알림 데이터 사용
변경 후: useAlerts hook import하여 사용
AlertPanel props: alerts(useAlerts 반환값)

파일:
frontend/src/components/layout/Header.tsx (수정: Bell 아이콘 + AlertDropdown)
frontend/src/components/layout/AlertDropdown.tsx (신규)
frontend/src/hooks/useAlerts.ts (28B에서 분리)
frontend/src/hooks/useDashboard.ts (수정: 알림 로직 제거, useAlerts 사용)
frontend/src/pages/DashboardPage.tsx (수정: useAlerts import)
frontend/src/components/dashboard/ManagerDashboard.tsx (수정: useAlerts 사용)

## API 경로 정리 (실제 Go 라우터 기준)

메모: GET/POST/PUT/DELETE /api/v1/notes
검색: POST /api/v1/calc/search
알림용 (기존 — useAlerts 재사용):
  POST /api/v1/calc/lc-maturity-alert
  POST /api/v1/calc/customer-analysis
  POST /api/v1/calc/inventory
  GET /api/v1/bls (입항 예정)
  GET /api/v1/orders (출고 예정)
  GET /api/v1/outbounds + /api/v1/sales (계산서 미발행)

## PROGRESS.md 업데이트
- Step 31 완료 기록
- "다음 작업: Step 32 — 배포 + 실데이터 검증"

## 완료 기준
1. Go: go build + go vet + go test 성공 (notes 테스트 포함)
2. npm run build 성공
3. 린터: bash scripts/lint_rules.sh 0건
4. 로컬 테스트:
   - /memo → 메모 카드 (새 메모 → 생성 → 수정 → 삭제)
   - 데이터 연결 메모 (PO에 연결 → PO 상세에서 LinkedMemoWidget 표시)
   - 헤더 Ctrl+K → 검색 바 포커스 → "진코 640 재고" → 결과 드롭다운
   - 검색 결과 클릭 → /inventory 이동
   - /search → 전체 화면 + 이력
   - 헤더 Bell → 알림 드롭다운 → 클릭 이동
   - DashboardPage 알림이 useAlerts에서 오는지 확인
   - 법인 변경 → 알림 재조회
5. harness/CHECKLIST_TEMPLATE.md 양식으로 보고
