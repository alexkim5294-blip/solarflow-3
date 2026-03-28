# SolarFlow 3.0 — 프로젝트 진행 상태

> 새 Claude 대화 시작 시: "SolarFlow 3.0 작업 계속합니다. STATUS.md 확인해주세요."

---

## 📍 현재 위치

| 항목 | 상태 |
|------|------|
| **현재 단계** | Phase 1 — 기초 공사 (마스터 관리) |
| **마지막 작업** | Step 1 완료 — DB 마스터 테이블 6개 생성 + 초기데이터 |
| **다음 할 일** | Step 2 — Go 백엔드 프로젝트 구조 + 라우터 설정 |
| **마지막 업데이트** | 2026-03-28 20:13 |

---

## 🏗️ Phase 1: 기초 공사 (마스터 관리)

### Step 0: 인프라 배포 ✅ 완료
- [x] 프론트엔드 → solarflow-3-frontend.pages.dev
- [x] 백엔드 → solarflow-backend.fly.dev
- [x] DB → Supabase solarflow-2 (aalxpmfnsjzmhsfkuxnp)
- [x] GitHub → solarflow-3 (백엔드), solarflow-3-frontend (프론트)

### Step 1: DB 마스터 테이블 ✅ 완료
- [x] 2.0 테이블 27개 삭제 (깨끗한 상태)
- [x] 001_master_tables.sql 실행 — 6개 테이블 생성
  - companies(3), manufacturers(11), products(0), partners(0), warehouses(9), banks(0)
  - 인덱스, updated_at 트리거 포함
- [x] 002_bank_initial_data.sql 실행 — 탑솔라 은행 5개
  - 하나($10M), 산업($10M), 국민($4M), 신한($2.5M), 광주($2.5M)

### Step 2: Go 백엔드 프로젝트 구조 ⬜ 다음
- [ ] chi 라우터 설치
- [ ] 프로젝트 폴더 구조 잡기
- [ ] Supabase DB 연결 설정
- [ ] Health check API (/api/v1/health)
- [ ] 마스터 CRUD 라우터 등록

### Step 3: 마스터 CRUD API 구현 ⬜ 미착수
- [ ] 법인(companies) CRUD
- [ ] 제조사(manufacturers) CRUD
- [ ] 품번(products) CRUD
- [ ] 거래처(partners) CRUD
- [ ] 창고(warehouses) CRUD
- [ ] 은행(banks) CRUD

### Step 4: 프론트엔드 마스터 화면 ⬜ 미착수

---

## 🔮 Phase 2: 핵심 거래 (발주~입고~출고)
## 🔮 Phase 3: 재고/분석/대시보드
## 🔮 Phase 4: 연동/고도화

---

## 🔧 인프라 정보

| 항목 | 값 |
|------|---|
| 프론트 URL | https://solarflow-3-frontend.pages.dev |
| 백엔드 URL | https://solarflow-backend.fly.dev |
| Supabase | aalxpmfnsjzmhsfkuxnp.supabase.co (무료, 프로젝트 2개 제한) |
| GitHub (백엔드) | alexkim5294-blip/solarflow-3 |
| GitHub (프론트) | alexkim5294-blip/solarflow-3-frontend |
| 프로젝트 폴더 | ~/solarflow-3/backend (git), ~/solarflow-3/frontend (git) |

## 🔑 기술 결정사항

| 결정 | 선택 | 이유 |
|------|------|------|
| Go HTTP 라우터 | chi (예정) | 표준 net/http 호환 |
| DB | Supabase PostgreSQL (기존 재활용) | 무료 2개 제한 |
| 호스팅 | Cloudflare Pages + fly.io | 배포 완료 |
