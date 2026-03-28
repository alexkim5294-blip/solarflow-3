# SolarFlow 3.0 — 프로젝트 진행 상태

> **이 파일의 용도**: 새 Claude 대화를 시작할 때 이 파일을 보여주면,
> 어디까지 했고 다음에 뭘 해야 하는지 바로 파악할 수 있습니다.
> 매 작업 완료 시 이 파일을 업데이트합니다.

---

## 📍 현재 위치

| 항목 | 상태 |
|------|------|
| **현재 단계** | Phase 1 — 기초 공사 (마스터 관리) |
| **마지막 작업** | Step 0 완료 — 빈 집 배포 |
| **다음 할 일** | Step 1-A — Supabase 기존 테이블 확인 |
| **마지막 업데이트** | 2026-03-28 |

---

## 🏗️ Phase 1: 기초 공사 (마스터 관리)

### Step 0: 인프라 배포 ✅ 완료
- [x] 프론트엔드 빈 집 배포 → solarflow-3-frontend.pages.dev
- [x] 백엔드 빈 집 배포 → solarflow-backend.fly.dev
- [x] DB 연결 → Supabase solarflow-2 (aalxpmfnsjzmhsfkuxnp)
- [x] GitHub 레포 생성 → solarflow-3, solarflow-3-frontend

### Step 1: DB 마스터 테이블 생성 ⬜ 진행 예정
- [ ] **1-A**: Supabase에서 기존 2.0 테이블 확인
- [ ] **1-B**: 001_master_tables.sql 실행 (6개 테이블 + 초기데이터)
- [ ] **1-C**: 002_bank_initial_data.sql 실행 (탑솔라 은행 5개)
- [ ] **1-D**: 확인 쿼리로 결과 검증

### Step 2: Go 백엔드 프로젝트 구조 ⬜ 미착수
- [ ] HTTP 라우터 선정 (chi 추천)
- [ ] 프로젝트 폴더 구조 잡기
- [ ] Supabase 연결 설정
- [ ] Health check API

### Step 3: 마스터 CRUD API 구현 ⬜ 미착수
- [ ] 법인(companies) CRUD
- [ ] 제조사(manufacturers) CRUD
- [ ] 품번(products) CRUD
- [ ] 거래처(partners) CRUD
- [ ] 창고(warehouses) CRUD
- [ ] 은행(banks) CRUD

### Step 4: 프론트엔드 마스터 화면 ⬜ 미착수
- [ ] 마스터 관리 메뉴 구성
- [ ] 각 마스터 목록/등록/수정 화면

---

## 🔮 Phase 2: 핵심 거래 (발주~입고~출고)
- [ ] Step 5: PO/LC/TT 테이블 + API
- [ ] Step 6: B/L 입고 테이블 + API
- [ ] Step 7: 수주/출고/매출 테이블 + API
- [ ] Step 8: 면장/원가 테이블 + API

## 🔮 Phase 3: 재고/분석/대시보드
- [ ] Step 9: 재고 3단계 집계
- [ ] Step 10: 분석 뷰
- [ ] Step 11: 대시보드

## 🔮 Phase 4: 연동/고도화
- [ ] Step 12: 아마란스10 엑셀 내보내기
- [ ] Step 13: 엑셀 Import (초기 데이터 이관)
- [ ] Step 14: 결재안 자동 생성
- [ ] Step 15: 검색 기능

---

## 🔧 인프라 정보

| 항목 | 값 |
|------|---|
| 프론트 URL | https://solarflow-3-frontend.pages.dev |
| 백엔드 URL | https://solarflow-backend.fly.dev |
| Supabase | aalxpmfnsjzmhsfkuxnp.supabase.co |
| GitHub (백엔드) | alexkim5294-blip/solarflow-3 |
| GitHub (프론트) | alexkim5294-blip/solarflow-3-frontend |

## 🔑 기술 결정사항

| 결정 | 선택 | 이유 |
|------|------|------|
| Go HTTP 라우터 | chi (예정) | 표준 net/http 호환 |
| DB | Supabase PostgreSQL | 기존 사용 중 |
| 호스팅 | Cloudflare Pages + fly.io | 배포 완료 |

## ⚠️ 알려진 이슈
- Supabase 무료 플랜 → 장기 미사용 시 자동 일시정지
- 2.0 테이블이 같은 DB에 남아있을 수 있음 (확인 필요)
