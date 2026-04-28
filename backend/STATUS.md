# SolarFlow 3.0 — Backend Status (2026-04-28)

> 현재 전체 진행 기준은 `../harness/PROGRESS.md`와 `../harness/STATUS.md`입니다. 이 파일은 backend 관점의 빠른 요약입니다.

## 현재 위치

| 항목 | 상태 |
|------|------|
| 현재 단계 | Phase 4 완료 후 실데이터 이관 + 운영 기능 보강 |
| Go 역할 | API 게이트웨이, CRUD, Auth, Import/Export, Rust CalcProxy |
| 실행 | Mac mini launchd `com.solarflow.go`, 포트 8080 |
| DB 접근 | supabase-go → 로컬 PostgREST/Caddy → PostgreSQL |
| 인증 | Supabase Auth JWT 검증 + user_profiles auto-provision |
| Rust 연동 | `ENGINE_URL` 설정 시 `/api/v1/calc/*` 프록시 |

## 주요 API 그룹

- 마스터: companies, manufacturers, products, partners, warehouses, banks, construction-sites
- 발주/결제: pos, po lines, lcs, lc lines, tts, limit-changes, price-histories
- 입고/원가: bls, bl lines, declarations, cost-details, expenses
- 수주/출고/매출: orders, receipts, receipt-matches, outbounds, sales, inventory allocations
- 운영 보강: module-demand-forecasts, attachments, notes, users
- 엑셀/ERP: import 7종, export/amaranth inbound/outbound
- 계산 프록시: inventory, landed-cost, exchange-compare, lc-fee, lc-limit-timeline, lc-maturity-alert, margin-analysis, customer-analysis, price-trend, supply-forecast, outstanding-list, receipt-match-suggest, search, inventory-turnover

## 최근 DB 마이그레이션

- 031 `module_demand_forecasts`
- 032 `lc_line_items`
- 033 `document_files`
- 034 `document_files` 권한
- 035 `incidental_expenses` 출고 운송비 컬럼(`outbound_id`, `vehicle_type`, `destination`)

## 운영 반영

Go 소스 수정 후 macOS 운영 반영은 코드 서명과 launchd 재등록이 필수입니다.

```bash
cd ~/solarflow-3/backend && go build -o solarflow-go .
codesign -f -s - solarflow-go
launchctl bootout gui/501 ~/Library/LaunchAgents/com.solarflow.go.plist 2>/dev/null || true
launchctl bootstrap gui/501 ~/Library/LaunchAgents/com.solarflow.go.plist
```

## 검증

- 최근 기록: Go 테스트 116개 PASS
- 모델/스키마 변경 시: `./scripts/check_schema.sh`
- 새 마이그레이션 적용 후: PostgREST 스키마 캐시 갱신 필수
