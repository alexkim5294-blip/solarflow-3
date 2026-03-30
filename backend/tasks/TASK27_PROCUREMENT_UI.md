# 작업: Step 24 — 발주/결제 화면 (PO + LC + TT + 단가이력)
harness/RULES.md를 반드시 따를 것. harness/CHECKLIST_TEMPLATE.md 양식으로 보고할 것.
감리 승인. 1건 반영: D-061 PO 입고현황 프론트 합산.

## ProcurementPage (/procurement) — 4개 탭

탭 1: PO (발주/계약) — 목록 + 상세(5개 서브탭)
탭 2: LC (신용장) — 목록 + 생성/수정
탭 3: TT (송금) — 목록 + 생성/수정
탭 4: 단가 변경 이력 — 목록 + 등록

## 탭 1: PO

### PO 목록
필터: [상태 ▼] [제조사 ▼] [계약유형 ▼]  [새로 등록]
컬럼: PO번호(NULL이면 "-"), 제조사, 계약유형, 계약일, Incoterms, 총수량, 총MW, 상태
상태 Badge: draft=회색"초안", contracted=파란"계약완료", shipping=노란"선적중", completed=초록"완료"
계약유형: general="일반", exclusive="독점", annual="연간", spot="스팟"

### PO 상세 (행 클릭) — 5개 서브탭

서브탭 1: 기본정보 (PO 필드 표시 + [수정] 버튼)
서브탭 2: 라인아이템 (테이블 + [추가] + 각 행 [수정])
  컬럼: 품번, 품명, 규격(Wp), 수량, USD/Wp단가, 총액(USD)
  total_amount_usd 자동: quantity x spec_wp x unit_price_usd (읽기전용)
서브탭 3: LC현황 (해당 PO의 LC 목록)
  컬럼: LC번호, 은행, 개설일, 금액(USD), 만기일, 상태
서브탭 4: TT이력 (해당 PO의 TT 목록)
  컬럼: 송금일, 금액(USD), 원화, 환율, 목적, 상태
  하단 합계: TT합계(USD), 송금비율(%)
서브탭 5: 입고현황 (프론트 합산 — D-061)
  GET /api/v1/bl-shipments?po_id=X -> 프론트에서 수량 합산
  계약량, LC개설량, 선적완료, 입고완료, 잔여량
  진행률 바: (입고완료/계약량)x100% — 0~50% 빨간, 50~80% 노란, 80~100% 초록

## 탭 2: LC

필터: [상태 ▼] [은행 ▼]  [새로 등록]
컬럼: LC번호, PO번호, 은행, 법인, 개설일, 금액(USD), 대상수량, Usance, 만기일, 결제일, 상태
상태 Badge: pending=회색"대기", opened=파란"개설", docs_received=노란"서류접수", settled=초록"결제완료"
만기 7일 이내: 빨간 Badge "만기임박", 만기 경과: 빨간 Badge "만기초과"

LCForm Dialog:
lc_number(선택), po_id(필수 PO Select), bank_id(필수 은행 Select), company_id(자동),
open_date, amount_usd(필수,양수), target_qty, target_mw,
usance_days(기본90), usance_type(buyers/shippers),
maturity_date, settlement_date, status(필수), memo

## 탭 3: TT

필터: [상태 ▼] [PO ▼]  [새로 등록]
컬럼: PO번호, 제조사, 송금일, 금액(USD), 원화(KRW), 환율, 목적, 상태, 은행
상태 Badge: planned=회색"예정", completed=초록"완료"

TTForm Dialog:
po_id(필수 PO Select), remit_date, amount_usd(필수,양수),
amount_krw, exchange_rate, purpose(자유기재, placeholder: "계약금1차"),
status(필수), bank_name(자유기재), memo

## 탭 4: 단가이력

필터: [제조사 ▼]  [새로 등록]
컬럼: 제조사, 품번, 변경일, 이전단가(USD/Wp), 변경단가(USD/Wp), 사유, 관련PO
단가 변화: 인상=빨간↑, 인하=초록↓, 동일=회색"-"

PriceHistoryForm Dialog:
manufacturer_id(필수), product_id(필수, 해당 제조사 필터),
change_date(필수), previous_price, new_price(필수),
reason(Select: 시세변동/재협상/계약갱신/최초계약 + 자유기재),
related_po_id(선택), memo

## API

PO: GET/POST/PUT /api/v1/purchase-orders
PO라인: GET/POST/PUT /api/v1/po-line-items
LC: GET/POST/PUT /api/v1/lc-records
TT: GET/POST/PUT /api/v1/tt-remittances
단가: GET/POST/PUT /api/v1/price-histories
입고현황: GET /api/v1/bl-shipments?po_id=X

## 파일 구조

frontend/src/
├── pages/ProcurementPage.tsx
├── components/procurement/
│   ├── POListTable.tsx
│   ├── PODetailView.tsx (5개 서브탭)
│   ├── POForm.tsx
│   ├── POLineTable.tsx
│   ├── POLineForm.tsx
│   ├── POInboundProgress.tsx (진행률 바)
│   ├── LCListTable.tsx
│   ├── LCForm.tsx
│   ├── TTListTable.tsx
│   ├── TTForm.tsx
│   ├── PriceHistoryTable.tsx
│   └── PriceHistoryForm.tsx
├── hooks/useProcurement.ts
└── types/procurement.ts

## types/procurement.ts

PurchaseOrder: po_id, po_number?(NULL가능), company_id, company_name?, manufacturer_id, manufacturer_name?, contract_type("general"|"exclusive"|"annual"|"spot"), contract_date?, incoterms?, payment_terms?, total_qty?, total_mw?, contract_period_start?, contract_period_end?, status("draft"|"contracted"|"shipping"|"completed"), memo?

POLineItem: po_line_id, po_id, product_id, product_name?, product_code?, spec_wp?, quantity, unit_price_usd?, total_amount_usd?, memo?

LCRecord: lc_id, lc_number?, po_id, po_number?, bank_id, bank_name?, company_id, company_name?, open_date?, amount_usd, target_qty?, target_mw?, usance_days?, usance_type?, maturity_date?, settlement_date?, status("pending"|"opened"|"docs_received"|"settled"), memo?

TTRemittance: tt_id, po_id, po_number?, manufacturer_name?, remit_date?, amount_usd, amount_krw?, exchange_rate?, purpose?, status("planned"|"completed"), bank_name?, memo?

PriceHistory: price_history_id, product_id, product_name?, manufacturer_id, manufacturer_name?, change_date, previous_price?, new_price, reason?, related_po_id?, related_po_number?, memo?

## DECISIONS.md 추가
- D-061: PO 입고현황은 프론트에서 B/L 수량 합산.
  이유: PO당 B/L 수십 건 이하로 성능 문제 없음. 데이터 증가 시 Rust API로 이동.

## PROGRESS.md 업데이트
- Step 24 완료 기록
- 프론트엔드: "Step 24 완료 (재고+입고+발주)"

## 완료 기준
1. npm run build 성공
2. 로컬 테스트:
   - /procurement -> 4개 탭
   - PO: 목록, 생성, 수정, 상세(5서브탭), 입고현황 진행률 바
   - LC: 목록, 생성, 수정, 만기임박 표시
   - TT: 목록, 생성, 수정
   - 단가: 목록, 등록, 인상/인하 화살표
   - 법인 변경 -> 재조회
3. harness/CHECKLIST_TEMPLATE.md 양식으로 보고
4. 전체 파일 코드 보여주기
