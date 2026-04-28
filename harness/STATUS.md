# SolarFlow 3.0 STATUS (2026-04-28)

이 파일은 빠른 상태 확인용 요약입니다. 상세 이력과 다음 작업은 `harness/PROGRESS.md`를 우선 확인합니다.

## 역할 체계

- **Alex**: 프로젝트 리더. 기획조정실 3팀. 비개발자. 무역/수입 전문가. 비유 기반 설명 선호.
- **재이(설계시공자)**: TASK 작성 + 방향 설정 + 시공자 지시.
- **감리자**: 별도 대화창. 코드 검토/승인/지적/점수 판정.
- **시공자(Claude Code/Codex)**: 워크트리에서 코드 작성, 빌드, 테스트, 문서 갱신.

## 현재 위치

Phase 4 완료 + Mac mini 로컬 운영 이전 완료. 현재는 실데이터 이관, 운영 검증, UI/업무흐름 보강 단계입니다.

최근 코드 기준으로 반영된 주요 보강:

- LC 다품목 PO 대응: `lc_line_items`, LCForm 품목 명세, `GET /api/v1/lcs/{id}/lines`
- 재고/수요 운영 보강: `module_demand_forecasts`, 재고 화면 수요 계획 패널, Rust `inventory-turnover`
- 업무 서류 보강: `document_files`, 첨부파일 업로드/미리보기/다운로드, B/L 상세 서류 탭
- 출고 보강: 출고별 운송비 패널, `expenses?outbound_id=...&expense_type=transport`
- PO 화면 보강: LC/TT/BL 진행률, B/L별 MW 표시, PO에서 LC/입고 바로 등록

## 인프라

- **서버**: Mac mini 로컬
- **Go 백엔드**: localhost:8080 (`com.solarflow.go`)
- **Rust 엔진**: localhost:8081 (`com.solarflow.engine`)
- **PostgREST**: localhost:3000 (`com.solarflow.postgrest`)
- **Caddy**: localhost:3001(PostgREST 경로변환) + localhost:5173(프론트 정적서빙, `/api/*` Go 프록시)
- **DB**: 로컬 PostgreSQL + PostgREST, RLS 비활성화
- **인증**: Supabase Auth + ES256 JWKS + HMAC 폴백 + auto-provision
- **외부접속**: Tailscale VPN — 100.123.70.19:5173
- **자동시작**: launchd 5개 서비스 (Go, Rust, PostgREST, Caddy, PostgreSQL)

## 운영 반영 절차

**Go 변경 후:**
```bash
cd ~/solarflow-3/backend && go build -o solarflow-go .
codesign -f -s - solarflow-go
launchctl bootout gui/501 ~/Library/LaunchAgents/com.solarflow.go.plist 2>/dev/null || true
launchctl bootstrap gui/501 ~/Library/LaunchAgents/com.solarflow.go.plist
```

**Rust 변경 후:**
```bash
cd ~/solarflow-3/engine && cargo build --release
codesign -f -s - target/release/solarflow-engine
launchctl bootout gui/501 ~/Library/LaunchAgents/com.solarflow.engine.plist 2>/dev/null || true
launchctl bootstrap gui/501 ~/Library/LaunchAgents/com.solarflow.engine.plist
```

**프론트 변경 후:**
```bash
cd ~/solarflow-3/frontend && npm run build
```

Caddy가 `frontend/dist/`를 직접 서빙하므로 프론트 운영 반영은 빌드가 기준입니다.

## 테스트/검증 기록

- Go: 최근 기록 116 PASS
- Rust: 최근 기록 75 PASS
- 프론트: `npm run build` 기준 검증
- DB 모델 변경 시: `backend/scripts/check_schema.sh`로 Go struct ↔ PostgREST 스키마 동기화 확인

## DECISIONS 요약 (D-001~D-091)

주요: D-001 Go+Rust 분리, D-051 프론트→Go→Rust, D-054 CalcProxy, D-060 즉시수정, D-071 전체 법인 합산, D-075 PostgREST 로컬, D-077 auto-provision, D-078 Tailscale, D-079 프론트 정적서빙, D-089 운영 이관 데이터/과거 참고자료 분리, D-090 LC 라인아이템, D-091 Supabase Auth JWT와 로컬 PostgREST JWT 분리.

## 남은 작업

1. 라이젠에너지 T/T 데이터와 DepositStatusPanel 실데이터 검증
2. 운영 이관 입고 상태값 처리 (`completed`/`erp_done`) 방식 확정
3. 첨부파일 저장 경로, 미리보기/다운로드, 삭제 권한 운영 검증
4. 출고 운송비 입력과 결재안 월정산 흐름 검증
5. 수요예측 수동 계획(`module_demand_forecasts`) 실사용 검증
