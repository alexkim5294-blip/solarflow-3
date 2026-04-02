# 작업: Step 30 — 결재안 자동 생성 6유형
harness/RULES.md를 반드시 따를 것. harness/CHECKLIST_TEMPLATE.md 양식으로 보고할 것.
감리 지적 2건 반영 필수. Go 서버 변경 없음 (프론트 only).

## 감리 지적 반영

### 지적 1 (중대): API 경로 — 실제 Go 라우터 사용
절대 아래 경로 사용 금지 (존재하지 않음):
  /api/v1/lc-records, /api/v1/purchase-orders, /api/v1/po-line-items,
  /api/v1/bl-shipments, /api/v1/bl-line-items, /api/v1/tt-remittances
반드시 아래 실제 경로 사용:
  GET /api/v1/lcs/{id} (LC 상세)
  GET /api/v1/pos/{id} (PO 상세)
  GET /api/v1/pos/{id}/lines (PO 라인아이템)
  GET /api/v1/bls/{id} (B/L 상세)
  GET /api/v1/bls/{id}/lines (B/L 라인아이템)
  GET /api/v1/tts?po_id=X (TT 목록)
  GET /api/v1/expenses?bl_id=X (부대비용)
  GET /api/v1/sales?customer_id=X (매출)
  POST /api/v1/calc/lc-fee (LC 수수료)
기존 hooks(useProcurement, useInbound 등)에 있는 API 호출을 재사용할 것.

### 지적 2: 유형 1 부가세 = 수입통관 부가세
수입 모듈대금 부가세 = CIF금액 x 0.1 = (lc_amount_usd x exchange_rate) x 0.1
"변동 가능" 문구 포함.

## 화면: ApprovalPage (/approval)

6유형 카드 선택 -> 데이터 선택 -> 텍스트 생성 -> 미리보기(Textarea 수정 가능) -> [클립보드 복사]

## 유형 1: 수입 모듈대금

데이터: LC Select -> PO, 은행, 라인아이템, LC수수료 자동 조회.
API: GET /api/v1/lcs/{id}, GET /api/v1/pos/{id}, GET /api/v1/pos/{id}/lines, POST /api/v1/calc/lc-fee
텍스트: 제목, PO No., 세부내역 테이블(은행/품명수량/금액/부가세/인수수수료/전신료/합계), 선적정보, LC정보, 환율, 결제조건, 출고예정.
부가세 = (lc_amount_usd x exchange_rate) x 0.1.
전신료 = 25,000원 고정.

## 유형 2: CIF 비용/제경비

데이터: B/L Select -> 라인아이템, 부대비용 자동 조회.
API: GET /api/v1/bls/{id}, GET /api/v1/bls/{id}/lines, GET /api/v1/expenses?bl_id=X
텍스트: 제목, 수입상세(Contract/B/L/품명/ETD/ETA/컨테이너/도착항), 비용 테이블(부두/셔틀/통관/운송/보관/핸들링/할증 각각 금액/VAT/합계), 지출금액, 계좌.
expense_type 매핑: dock_charge=부두발생비용, shuttle=셔틀및부대, customs_fee=통관수수료, transport=운송료, storage=보관료, handling=핸들링, surcharge=주말출고할증.

## 유형 3: 판매 세금계산서

데이터: 거래처 Select + 기간(from,to) -> 매출 목록 자동 조회.
API: GET /api/v1/sales?customer_id=X (기간 필터는 프론트에서)
텍스트: 제목, 대상, 계약명, 발전소별 테이블(발전소명/모델명/수량/단가/금액/비고), 발행일자, 발행메일, 첨부.
단가 형식: "{unit_price_ea}원 (Wp/{unit_price_wp}원)"
비고: spare_qty > 0이면 "SP{N}EA"

## 유형 4: 운송비 월정산

데이터: 거래처(운송사) Input + 기간 -> 부대비용 조회.
API: GET /api/v1/expenses?vendor=X&month=Y (expense_type=transport)
텍스트: 제목, 거래처, 기간, 금액(총액/부가세/합계), 계좌, 담당자.
차량별 상세: 수동 입력 Textarea (노란 배경 [수동 입력]).

## 유형 5: 계약금 지출

데이터: PO Select -> 라인아이템, TT이력 자동 조회.
API: GET /api/v1/pos/{id}, GET /api/v1/pos/{id}/lines, GET /api/v1/tts?po_id=X
텍스트: 제목, 거래처, 거래내용, 기존/변경 비교 테이블, 계약금/기지급/차액, 분납내역, 지급조건, 계좌(SWIFT), 담당자.
계약금율/분납횟수: 수동 입력 Input (노란 배경).

## 유형 6: 공사 현장 운송료

데이터: 기간 -> usage_category=construction 출고 조회.
API: GET /api/v1/outbounds?company_id=X&usage_category=construction (기간 프론트 필터)
텍스트: 제목, 현장별 테이블(현장/모델/수량/운송비/비고).
운송비: 수동 입력 Input (노란 배경).

## 공통

[클립보드 복사]: navigator.clipboard.writeText -> 토스트 "복사 완료"
[수정]: Textarea에 생성 텍스트 표시, 실무자 수정 가능
유니코드 테이블: 실제 문자 사용
수동 입력: 노란 배경 + [수동 입력] 라벨

## 파일 구조

frontend/src/
├── pages/ApprovalPage.tsx
├── components/approval/
│   ├── ApprovalTypeSelector.tsx (6유형 카드)
│   ├── ApprovalGenerator.tsx (유형별 분기)
│   ├── ApprovalPreview.tsx (미리보기+수정+복사)
│   ├── Type1ImportPayment.tsx
│   ├── Type2CIFExpense.tsx
│   ├── Type3TaxInvoice.tsx
│   ├── Type4TransportMonthly.tsx
│   ├── Type5DepositPayment.tsx
│   └── Type6ConstructionTransport.tsx
├── hooks/useApproval.ts
├── lib/approvalTemplates.ts (6개 순수 문자열 생성 함수)
└── types/approval.ts

## PROGRESS.md 업데이트
- Step 30 완료, 다음 Step 31

## 완료 기준
1. npm run build 성공
2. Go 변경 없음 (go build + go test 기존 통과)
3. 린터: 0건
4. 로컬 테스트: 유형 1(수입대금), 유형 3(세금계산서), 유형 5(계약금) 최소 3유형 전체 플로우
5. [복사] 후 텍스트 편집기에 붙여넣기 -> 표 구조 유지
6. 수동 입력 노란 배경 구분
7. harness/CHECKLIST_TEMPLATE.md 양식으로 보고
