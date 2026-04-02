# 작업: Step 29B — Go Import API 7개 + 업로드 확정 연동
harness/RULES.md를 반드시 따를 것. harness/CHECKLIST_TEMPLATE.md 양식으로 보고할 것.
감리 지적 4건 반영 (즉시수정1 + 지적3).

## 선행: 29A 즉시 수정 (D-060)

frontend/src/lib/excelTemplates.ts 입고 양식 통화 드롭다운 하드코딩 수정.
setDropdown에서 하드코딩된 코드표 열 참조를 writeCodeColumn 반환값으로 변경.

## 감리 지적 반영

### 지적 1 (중대): 매출 Import outbound 매칭
변경: 매출 양식에 outbound_id 컬럼 추가 (필수).
매출 Import는 outbound가 먼저 등록된 상태에서만 가능.
Go에서 outbound_id로 직접 조회 후 sales INSERT.
29A의 매출 양식(excelTemplates.ts)도 수정:
A: outbound_id* | B: 거래처코드* | C: Wp단가(원)* | D: 세금계산서발행일 | E: 발행메일 | F: ERP마감(Y/N) | G: ERP마감일 | H: 메모
코드표에 outbound 목록 추가 (outbound_id + 출고일 + 품번 + 수량 + 현장명).
29A의 매출 검증(excelValidation.ts)도 수정: outbound_id 필수.

### 지적 2: 면장 Import 한 번에 전송 확정
POST /api/v1/import/declarations
body: { "declarations": [...], "costs": [...] }
Go에서 declarations 먼저 INSERT -> 생성된 declaration_id 보관 -> 면장번호로 매핑 -> costs INSERT.
면장번호 매칭 안 되는 cost 행은 에러: "N행: 면장번호 XXX가 위 면장 데이터에 없습니다"
분리 전송 금지.

### 지적 3: 입고 B/L 그룹핑 기본정보 불일치
같은 B/L No.로 여러 행이 올 때:
첫 행에서 bl_shipments INSERT (기본정보: ETD, ETA, 포워더 등).
2행 이후에서 기본정보가 첫 행과 다르면:
  첫 행 값 사용 + 경고: "N행: B/L 기본정보(ETD)가 첫 행과 다릅니다 (첫 행 값 사용)"
경고는 에러 카운트에 포함하지 않음 (warning level).

## Go Import API 7개

### 모델 (backend/internal/model/import.go)

ImportResponse: Success bool, ImportedCount int, ErrorCount int, WarningCount int, Errors []ImportError, Warnings []ImportWarning
ImportError: Row int, Field string, Message string
ImportWarning: Row int, Field string, Message string
DeclarationImportRequest: Declarations []map[string]interface{}, Costs []map[string]interface{}

### 공통 헬퍼 (backend/internal/handler/import.go)

validateRequired(row, fields) -> []ImportError
validateAllowedValues(value, allowed map[string]bool) -> bool (RULES.md: map 패턴)
resolveFK(db, table, matchColumns, value) -> (uuid, error)
parseDate(value) -> (string, error)

### 라우터 (main.go)

r.Route("/api/v1/import", func(r chi.Router) {
    r.Use(AuthMiddleware)
    r.Post("/inbound", importHandler.Inbound)
    r.Post("/outbound", importHandler.Outbound)
    r.Post("/sales", importHandler.Sales)
    r.Post("/declarations", importHandler.Declarations)
    r.Post("/expenses", importHandler.Expenses)
    r.Post("/orders", importHandler.Orders)
    r.Post("/receipts", importHandler.Receipts)
})

### 1. POST /api/v1/import/inbound
입력: { "rows": [...] }
같은 B/L No. 그룹핑: bl_shipments 1건 + bl_line_items N건.
capacity_kw 자동: products에서 wattage_kw 조회.
B/L 기본정보 불일치: 첫 행 우선 + warnings 추가 (지적 3).
FK: manufacturer(name_kr), product(product_code), warehouse(warehouse_code), company(company_code).

### 2. POST /api/v1/import/outbound
입력: { "rows": [...] }
capacity_kw 자동. group_trade "Y"->true + target_company_id 매핑.
status "active" 자동.
FK: product, warehouse, company, order(선택).

### 3. POST /api/v1/import/sales (지적 1 반영)
입력: { "rows": [...] }
outbound_id(필수) -> outbounds에서 직접 조회 -> product_id, quantity, spec_wp 가져옴.
자동계산: unit_price_ea = unit_price_wp * spec_wp, supply_amount = unit_price_ea * quantity, vat_amount = supply_amount * 0.1, total_amount = supply_amount + vat_amount.
FK: outbound_id(필수), customer(partner).

### 4. POST /api/v1/import/declarations (지적 2 반영)
입력: { "declarations": [...], "costs": [...] }
단계 1: declarations -> declarations INSERT -> declaration_id 보관 -> 면장번호:ID 매핑 맵.
단계 2: costs -> 면장번호(참조)로 매핑 -> declaration_costs INSERT (cost-details 테이블).
매핑 실패 에러. 응답: 양쪽 합산.

### 5. POST /api/v1/import/expenses
입력: { "rows": [...] }
bl_id 또는 month 필수 (둘 다 없으면 에러). total 자동: amount + vat.
FK: company, bl(선택).

### 6. POST /api/v1/import/orders
입력: { "rows": [...] }
capacity_kw 자동. shipped_qty=0, remaining_qty=quantity, status="received" 자동.
FK: company, customer, product.

### 7. POST /api/v1/import/receipts
입력: { "rows": [...] }
FK: customer.

## 프론트 변경

### ImportPreviewDialog.tsx 수정
[확정 등록] 활성화 (유효 행 0건이면 비활성).
클릭 -> ConfirmDialog "유효한 N건을 등록하시겠습니까? 에러 M건은 건너뜁니다."
면장: { declarations: validDecl, costs: validCosts }
그 외: { rows: validRows.map(r => r.data) }
응답 -> ImportResultDialog.

### ImportResultDialog.tsx (신규)
성공: 초록 Banner "N건 등록 완료"
에러: 빨간 Banner "N건 에러" + 에러 테이블 (행/필드/메시지)
경고: 노란 Banner "N건 경고" + 경고 테이블
"N건 등록, M건 에러, K건 경고"
[닫기] -> 목록 새로고침.

### 매출 양식 수정 (excelTemplates.ts + excelValidation.ts)
양식: A: outbound_id* | B: 거래처코드* | C: Wp단가(원)* | D~H
코드표에 outbound 목록 (outbound_id + 출고일 + 품번 + 수량 + 현장명).
검증: outbound_id 필수.

### useExcel.ts 추가
submitImport(type, data) -> ImportResult
면장: POST body { declarations, costs }
그 외: POST body { rows }
경로: POST /api/v1/import/{type}

## types/excel.ts 추가

ImportResult: success, imported_count, error_count, warning_count, errors(ImportError[]), warnings(ImportWarning[])
ImportError: row, field, message
ImportWarning: row, field, message

## Go 테스트

backend/internal/handler/import_test.go:
- TestImport_Inbound_Success: 같은 B/L 3행 -> shipments 1건 + lines 3건
- TestImport_Inbound_PartialError: 5행 중 2행 FK에러 -> 3건+2에러
- TestImport_Inbound_BLWarning: 같은 B/L 2행 ETA 다름 -> 경고 1건 (에러아님)
- TestImport_Inbound_EmptyRows: 빈 배열 -> 400
- TestImport_Outbound_GroupTrade: Y->true + 상대법인
- TestImport_Sales_OutboundID: outbound_id 직접 매칭 + 자동계산
- TestImport_Sales_InvalidOutbound: 없는 outbound_id -> 에러
- TestImport_Declarations_Combined: declarations 2건 + costs 4건 -> 6건
- TestImport_Declarations_CostFK: costs 없는 면장번호 -> 에러
- TestImport_Orders_AutoFields: capacity_kw/shipped_qty/remaining_qty 자동
- TestImport_Expenses_BLorMonth: 둘 다 없으면 에러

## PROGRESS.md 업데이트
- Step 29B 완료 기록

## 완료 기준
1. Go: go build + go vet + go test 성공 (import 테스트 전부 PASS)
2. npm run build 성공
3. 로컬 테스트: 최소 2종 전체 플로우 (업로드->미리보기->확정->결과)
4. harness/CHECKLIST_TEMPLATE.md 양식으로 보고
5. 전체 파일 코드 보여주기
