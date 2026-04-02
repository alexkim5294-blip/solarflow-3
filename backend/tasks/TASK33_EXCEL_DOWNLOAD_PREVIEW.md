# 작업: Step 29A — 엑셀 양식 다운로드 7종 + 업로드 파싱 + 미리보기
harness/RULES.md를 반드시 따를 것. harness/CHECKLIST_TEMPLATE.md 양식으로 보고할 것.
감리 승인. 지적 2건 반영 필수.
Go 서버 변경 없음 (프론트 only).

## 사전: ExcelJS 설치 (Alex가 frontend/에서 실행)
npm install exceljs file-saver
npm install -D @types/file-saver

## 감리 지적 반영 사항

### 지적 1: ExcelJS dynamic import 필수
ExcelJS는 약 1MB 번들. static import하면 모든 페이지 초기 로딩에 영향.
lib/excelTemplates.ts와 lib/excelParser.ts에서 반드시:
  const ExcelJS = await import('exceljs');
로 dynamic import. 양식 다운로드/업로드 시점에만 로드.
절대 파일 상단에 import ExcelJS from 'exceljs' 하지 말 것!

### 지적 2: 면장 양식 2시트 파싱
면장 양식만 "면장등록" + "원가등록" 2개 시트.
excelParser.ts에서 면장 타입일 때:
  반환 타입: { declarations: ParsedRow[], costs: ParsedRow[] }
ImportPreviewDialog에서 면장일 때 탭 2개로 표시:
  [면장 (N건)] [원가 (N건)]

## 핵심 흐름

### 다운로드 흐름
1. [양식 다운로드] 클릭
2. Go API에서 마스터 데이터 조회
3. ExcelJS(dynamic import)로 워크북 생성:
   데이터 시트(헤더+필수표시) + 코드표 시트(마스터목록) + Data Validation(드롭다운)
4. file-saver로 .xlsx 다운로드

### 업로드 흐름 (미리보기→확정 2단계)
1. [업로드] 클릭 → 파일 선택 (drag & drop)
2. ExcelJS(dynamic import)로 파싱 → JSON 배열
3. 프론트 기본 검증 (필수/코드존재/양수/허용값/날짜)
4. 미리보기 테이블: 유효=흰색, 에러=빨간+메시지
5. [확정 등록] 비활성 (Step 29B에서 활성화)
6. [에러만 다운로드] → 에러 행만 새 .xlsx 생성

## 양식 7종 필드 + 드롭다운

### 1. 입고 (inbound)
A: B/L No.* | B: 입고유형* | C: 법인코드* | D: 제조사코드* |
E: 통화* | F: 환율 | G: ETD | H: ETA | I: 실제입항일 |
J: 항구 | K: 포워더 | L: 창고코드 | M: Invoice No. | N: 메모 |
O: 품번코드* | P: 수량* | Q: 본품/스페어* | R: 유상/무상* |
S: Invoice금액(USD) | T: USD/Wp단가 | U: KRW/Wp단가 | V: 용도* | W: 라인메모
드롭다운: B(입고유형4개), C(법인), D(제조사), E(USD/KRW), L(창고), O(품번), Q(main/spare), R(paid/free), V(용도9개)

### 2. 출고 (outbound)
A: 출고일* | B: 법인코드* | C: 품번코드* | D: 수량* |
E: 창고코드* | F: 용도* | G: 수주번호 | H: 현장명 |
I: 현장주소 | J: 스페어수량 | K: 그룹거래(Y/N) | L: 상대법인코드 |
M: ERP출고번호 | N: 메모
드롭다운: B(법인), C(품번), E(창고), F(용도9개), K(Y/N), L(법인)

### 3. 매출 (sale)
A: 출고일(참조)* | B: 품번코드(참조)* | C: 거래처코드* |
D: Wp단가(원)* | E: 세금계산서발행일 | F: 발행메일 |
G: ERP마감(Y/N) | H: ERP마감일 | I: 메모
드롭다운: C(거래처 customer/both만), G(Y/N)

### 4. 면장 (declaration) — 시트 2개!
시트1 "면장등록":
A: 면장번호* | B: B/L No.* | C: 법인코드* | D: 신고일* |
E: 입항일 | F: 반출일 | G: HS코드 | H: 세관 | I: 항구 | J: 메모
드롭다운: C(법인)

시트2 "원가등록":
A: 면장번호(참조)* | B: 품번코드* | C: 수량* | D: 환율* |
E: FOB단가(USD/Wp) | F: FOB총액(USD) | G: FOB Wp단가(원) |
H: CIF총액(원)* | I: CIF단가(USD/Wp) | J: CIF총액(USD) |
K: 관세율(%) | L: 관세액(원) | M: 부가세(원) | N: 통관비(원) | O: 기타부대비(원) | P: 메모
드롭다운: B(품번)

시트3 "코드표": 법인, 품번

### 5. 부대비용 (expense)
A: B/L No. | B: 월(YYYY-MM) | C: 법인코드* | D: 비용유형* |
E: 금액(원)* | F: 부가세(원) | G: 거래처 | H: 메모
드롭다운: C(법인), D(비용유형11개)

### 6. 수주 (order)
A: 발주번호 | B: 법인코드* | C: 거래처코드* | D: 수주일* |
E: 접수방법* | F: 관리구분* | G: 충당소스* | H: 품번코드* |
I: 수량* | J: Wp단가(원)* | K: 현장명 | L: 현장주소 |
M: 현장담당자 | N: 현장연락처 | O: 결제조건 | P: 계약금비율(%) |
Q: 납기요청일 | R: 스페어수량 | S: 메모
드롭다운: B(법인), C(거래처), E(접수방법4개), F(관리구분6개), G(충당소스2개), H(품번)

### 7. 수금 (receipt)
A: 거래처코드* | B: 입금일* | C: 입금액(원)* | D: 입금계좌 | E: 메모
드롭다운: A(거래처)

## ExcelJS 드롭다운 구현 패턴

async function generateTemplate(type, masterData) {
  const ExcelJS = await import('exceljs');  // dynamic import!
  const workbook = new ExcelJS.Workbook();
  const dataSheet = workbook.addWorksheet('입고등록');
  const codeSheet = workbook.addWorksheet('코드표');

  // 코드표에 제조사 목록
  codeSheet.getColumn(1).header = '제조사';
  masterData.manufacturers.forEach((m, i) => {
    codeSheet.getCell(`A${i + 2}`).value = m.name_kr;
  });

  // 드롭다운 설정 (행 2~1000)
  for (let row = 2; row <= 1000; row++) {
    dataSheet.getCell(`D${row}`).dataValidation = {
      type: 'list',
      formulae: [`'코드표'!$A$2:$A$${masterData.manufacturers.length + 1}`],
      showErrorMessage: true,
      errorTitle: '유효하지 않은 값',
      error: '코드표에서 선택해주세요'
    };
  }
}

## 면장 파싱 로직 (지적 2 반영)

async function parseDeclarationFile(file) {
  const ExcelJS = await import('exceljs');  // dynamic import!
  const workbook = new ExcelJS.Workbook();
  await workbook.xlsx.load(await file.arrayBuffer());

  const declSheet = workbook.getWorksheet('면장등록');
  const costSheet = workbook.getWorksheet('원가등록');

  const declarations = parseSheet(declSheet, declarationFieldMap);
  const costs = parseSheet(costSheet, costFieldMap);

  return { declarations, costs };  // 2시트 각각 반환
}

ImportPreviewDialog에서 면장일 때:
<Tabs>
  <TabsTrigger>면장 ({declarations.length}건)</TabsTrigger>
  <TabsTrigger>원가 ({costs.length}건)</TabsTrigger>
</Tabs>
각 탭에서 유효/에러 행 표시.

## 프론트 검증 규칙

validateRow(row, type, masterData) -> { valid, errors[] }
1. 필수: *표시 필드가 빈값이면 "필수 항목입니다"
2. 코드존재: 제조사코드가 masterData.manufacturers에 없으면 "존재하지 않는 제조사입니다"
3. 양수: 수량, 금액 등 <= 0이면 "양수여야 합니다"
4. 허용값: 입고유형이 4개 중 아니면 "허용되지 않는 값입니다"
5. 날짜: YYYY-MM-DD 패턴 불일치 시 "날짜 형식 오류 (YYYY-MM-DD)"
6. B/L또는월: 부대비용에서 둘 다 비면 "B/L 또는 월 중 하나는 필수입니다"

## 미리보기 UI (ImportPreviewDialog)

파일명, 전체N건, 유효N건(초록), 에러N건(빨간)
필터: 유효만/에러만/전체
테이블: #, 각 컬럼값..., 상태(체크/X+에러메시지)
에러 행: 빨간 배경 + 해당 셀에 에러 메시지 tooltip

[에러만 다운로드]: 에러 행만 ExcelJS로 새 파일 → 마지막 컬럼에 에러 사유 추가
[취소]: Dialog 닫기
[확정 등록 (N건)]: 비활성 + 툴팁 "Step 29B에서 활성화"

## 파일 구조

frontend/src/
├── components/excel/
│   ├── ExcelDownloadButton.tsx
│   ├── ExcelUploadButton.tsx (파일 선택 + drag&drop)
│   ├── ImportPreviewDialog.tsx (미리보기 + 면장 탭 2개)
│   ├── ImportPreviewTable.tsx (행별 유효/에러)
│   └── ExcelToolbar.tsx (다운로드+업로드 통합)
├── hooks/
│   └── useExcel.ts
├── lib/
│   ├── excelTemplates.ts (양식 7종 생성 — dynamic import)
│   ├── excelParser.ts (파싱 — dynamic import, 면장 2시트 처리)
│   └── excelValidation.ts (검증 7종)
└── types/
    └── excel.ts

## types/excel.ts

TemplateType: "inbound"|"outbound"|"sale"|"declaration"|"expense"|"order"|"receipt"
ParsedRow: { rowNumber, data: Record<string,any>, valid, errors: RowError[] }
RowError: { field, message }
ImportPreview: { fileName, totalRows, validRows, errorRows, rows: ParsedRow[] }
DeclarationImportPreview: { fileName, declarations: ParsedRow[], costs: ParsedRow[] }
MasterDataForExcel: { companies, manufacturers, products, partners, warehouses }

## 각 페이지에 ExcelToolbar 추가

InboundPage 상단: ExcelToolbar type="inbound"
OutboundPage 출고탭: ExcelToolbar type="outbound"
OutboundPage 매출탭: ExcelToolbar type="sale"
CustomsPage 면장탭: ExcelToolbar type="declaration"
CustomsPage 부대비용탭: ExcelToolbar type="expense"
OrdersPage 수주탭: ExcelToolbar type="order"
OrdersPage 수금탭: ExcelToolbar type="receipt"

## DECISIONS.md 추가
- D-063: 엑셀 업로드 미리보기→확정 2단계. D-025 패턴. 중복 등록 방지.
- D-064: PDF 자동 데이터 입력 (Phase 5 예정). Phase 4는 엑셀 Import/Export로 진행. PDF 자동 입력은 Phase 5에서 실무 빈도 확인 후 구현. 후보: Claude API 또는 정형 PDF 좌표 파싱.

## PROGRESS.md 업데이트
- Step 29A 완료 기록

## 완료 기준
1. npm run build 성공
2. ExcelJS가 별도 chunk로 분리됨 확인 (빌드 출력에서 exceljs chunk 확인)
3. 로컬 테스트:
   - 입고 [양식 다운로드] -> .xlsx 열림, 드롭다운 동작, 코드표 있음
   - 작성 후 [업로드] -> 미리보기 표시
   - 유효=흰색, 에러=빨간+메시지
   - [에러만 다운로드] -> 에러 행+사유 .xlsx
   - [확정 등록] 비활성
   - 면장 양식: 시트 2개 생성, 업로드 시 탭 2개 표시
   - 최소 3종 양식 테스트 (입고+출고+면장)
4. harness/CHECKLIST_TEMPLATE.md 양식으로 보고
5. 전체 파일 코드 보여주기
