-- ============================================================
-- SolarFlow 3.0 — Step 1: 마스터 테이블 생성
-- 실행 대상: Supabase SQL Editor
-- 작성일: 2026-03-28
-- ============================================================

-- 0. UUID 확장 활성화 (이미 있으면 무시됨)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- 1. 법인 마스터 (companies)
--    탑솔라(주), 디원, 화신이엔지 — 3개 법인 + 추후 확장
-- ============================================================
CREATE TABLE IF NOT EXISTS companies (
    company_id      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_name    VARCHAR(100) NOT NULL,          -- 탑솔라(주), 디원, 화신이엔지
    company_code    VARCHAR(10)  NOT NULL UNIQUE,    -- TS, DW, HS
    business_number VARCHAR(20),                     -- 사업자등록번호
    is_active       BOOLEAN NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE  companies IS '법인 마스터 — 탑솔라 그룹 법인 관리';
COMMENT ON COLUMN companies.company_code IS '법인 약어: TS(탑솔라), DW(디원), HS(화신)';

-- ============================================================
-- 2. 제조사 마스터 (manufacturers)
--    해외: 진코, 트리나, 라이젠, 캐나디안, JA, 통웨이, LONGi
--    국내: 한화, SDN/AIKO, 한솔, 현대
-- ============================================================
CREATE TABLE IF NOT EXISTS manufacturers (
    manufacturer_id  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name_kr          VARCHAR(50)  NOT NULL,          -- 진코솔라, 트리나, 라이젠 등
    name_en          VARCHAR(100),                    -- ZHEJIANG JINKO SOLAR CO.,LTD 등
    country          VARCHAR(20)  NOT NULL,           -- 중국, 한국, 베트남 등
    domestic_foreign VARCHAR(10)  NOT NULL             -- '국내' 또는 '해외'
        CHECK (domestic_foreign IN ('국내', '해외')),
    is_active        BOOLEAN NOT NULL DEFAULT true,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE  manufacturers IS '제조사 마스터 — 태양광 모듈 제조사';
COMMENT ON COLUMN manufacturers.domestic_foreign IS '국내/해외 구분 — 입고유형 결정에 사용';

-- ============================================================
-- 3. 품번 마스터 (products)
--    모듈 규격: Wp, 크기(mm), 제조사 연결
--    ★ 모듈 크기(mm)가 1차 정렬키 — 현장 구조물 호환 확인용
-- ============================================================
CREATE TABLE IF NOT EXISTS products (
    product_id       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_code     VARCHAR(30)  NOT NULL UNIQUE,    -- 아마란스 ITEM_CD (M-JK0635-01)
    product_name     VARCHAR(100) NOT NULL,            -- JKM635N-78HL4-BDV-S
    manufacturer_id  UUID NOT NULL
        REFERENCES manufacturers(manufacturer_id),
    spec_wp          INTEGER NOT NULL,                 -- 규격 Wp (635, 640, 720)
    wattage_kw       DECIMAL(10,3) NOT NULL,           -- kW 환산 (0.635)
    module_width_mm  INTEGER NOT NULL,                 -- 모듈 가로 (mm)
    module_height_mm INTEGER NOT NULL,                 -- 모듈 세로 (mm)
    module_depth_mm  INTEGER,                          -- 모듈 두께 (mm)
    weight_kg        DECIMAL(5,1),                     -- 무게 (kg)
    wafer_platform   VARCHAR(30),                      -- M10(182mm), N-type 등
    cell_config      VARCHAR(30),                      -- 72셀(144 half-cut) 등
    series_name      VARCHAR(50),                      -- Hi-MO 7, Tiger Neo 등
    is_active        BOOLEAN NOT NULL DEFAULT true,
    memo             TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE  products IS '품번 마스터 — 태양광 모듈 규격';
COMMENT ON COLUMN products.product_code IS '아마란스10 ITEM_CD와 동일';
COMMENT ON COLUMN products.module_width_mm IS '★ 모듈 크기(mm) = 1차 정렬키 (현장 구조물 호환)';
COMMENT ON COLUMN products.spec_wp IS 'Wp 규격 — MW 환산의 기준값';

-- ============================================================
-- 4. 거래처 마스터 (partners)
--    공급사(supplier) + 고객(customer) + 양방향(both)
-- ============================================================
CREATE TABLE IF NOT EXISTS partners (
    partner_id     UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    partner_name   VARCHAR(100) NOT NULL,              -- 바로(주), 신명엔지니어링 등
    partner_type   VARCHAR(20) NOT NULL                -- supplier/customer/both
        CHECK (partner_type IN ('supplier', 'customer', 'both')),
    erp_code       VARCHAR(10),                        -- 아마란스10 거래처코드
    payment_terms  VARCHAR(50),                        -- 기본 결제조건 (60일, 현금 등)
    contact_name   VARCHAR(50),                        -- 담당자
    contact_phone  VARCHAR(20),                        -- 연락처
    contact_email  VARCHAR(100),                       -- 이메일
    is_active      BOOLEAN NOT NULL DEFAULT true,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE  partners IS '거래처 마스터 — 공급사/고객/양방향';
COMMENT ON COLUMN partners.partner_type IS 'supplier=공급사, customer=고객, both=양방향';
COMMENT ON COLUMN partners.erp_code IS '아마란스10 거래처코드';

-- ============================================================
-- 5. 창고/장소 마스터 (warehouses)
--    1개 창고 = 여러 장소(location) 가능
--    아마란스10 WH_CD + LC_CD 매핑
-- ============================================================
CREATE TABLE IF NOT EXISTS warehouses (
    warehouse_id    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    warehouse_code  VARCHAR(10) NOT NULL,              -- 아마란스 WH_CD (A200, A400, F100)
    warehouse_name  VARCHAR(50) NOT NULL,              -- 블루오션에어, 선진로지스틱스 등
    warehouse_type  VARCHAR(20) NOT NULL               -- port/factory/vendor
        CHECK (warehouse_type IN ('port', 'factory', 'vendor')),
    location_code   VARCHAR(10) NOT NULL,              -- 아마란스 LC_CD (A202, A401)
    location_name   VARCHAR(50) NOT NULL,              -- 광양항, 부산항, B동공장 등
    is_active       BOOLEAN NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- 동일 창고의 동일 장소 중복 방지
    UNIQUE (warehouse_code, location_code)
);

COMMENT ON TABLE  warehouses IS '창고/장소 마스터 — 항구, 공장, 업체공장';
COMMENT ON COLUMN warehouses.warehouse_code IS '아마란스10 WH_CD';
COMMENT ON COLUMN warehouses.location_code IS '아마란스10 LC_CD';

-- ============================================================
-- 6. 은행 마스터 (banks)
--    법인별 LC 개설한도 + 수수료율
-- ============================================================
CREATE TABLE IF NOT EXISTS banks (
    bank_id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id           UUID NOT NULL
        REFERENCES companies(company_id),
    bank_name            VARCHAR(50) NOT NULL,          -- 하나은행, 산업은행 등
    lc_limit_usd         DECIMAL(15,2) NOT NULL,        -- LC 개설한도 (USD)
    opening_fee_rate     DECIMAL(5,4),                   -- 개설수수료율 (%) — 예: 0.0020 = 0.2%
    acceptance_fee_rate  DECIMAL(5,4),                   -- 인수수수료율 (%) — 예: 0.0030 = 0.3%
    fee_calc_method      VARCHAR(20),                    -- 수수료 계산방식 (연이율/360일 등)
    memo                 TEXT,
    is_active            BOOLEAN NOT NULL DEFAULT true,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- 같은 법인에 같은 은행 중복 등록 방지
    UNIQUE (company_id, bank_name)
);

COMMENT ON TABLE  banks IS '은행 마스터 — 법인별 LC 한도 및 수수료';
COMMENT ON COLUMN banks.opening_fee_rate IS '개설수수료율 — 소수점 표기 (0.002 = 0.2%)';
COMMENT ON COLUMN banks.acceptance_fee_rate IS '인수수수료율 — 소수점 표기 (0.003 = 0.3%)';

-- ============================================================
-- 7. 인덱스
-- ============================================================

-- 법인
CREATE INDEX IF NOT EXISTS idx_companies_active ON companies(is_active);

-- 제조사
CREATE INDEX IF NOT EXISTS idx_manufacturers_active ON manufacturers(is_active);
CREATE INDEX IF NOT EXISTS idx_manufacturers_domestic ON manufacturers(domestic_foreign);

-- 품번 (★ 가장 많이 조회되는 테이블)
CREATE INDEX IF NOT EXISTS idx_products_manufacturer ON products(manufacturer_id);
CREATE INDEX IF NOT EXISTS idx_products_spec ON products(spec_wp);
CREATE INDEX IF NOT EXISTS idx_products_active ON products(is_active);
-- 모듈 크기순 정렬 (핵심 정렬키)
CREATE INDEX IF NOT EXISTS idx_products_size ON products(module_width_mm, module_height_mm);

-- 거래처
CREATE INDEX IF NOT EXISTS idx_partners_type ON partners(partner_type);
CREATE INDEX IF NOT EXISTS idx_partners_active ON partners(is_active);

-- 창고
CREATE INDEX IF NOT EXISTS idx_warehouses_type ON warehouses(warehouse_type);
CREATE INDEX IF NOT EXISTS idx_warehouses_active ON warehouses(is_active);

-- 은행
CREATE INDEX IF NOT EXISTS idx_banks_company ON banks(company_id);
CREATE INDEX IF NOT EXISTS idx_banks_active ON banks(is_active);

-- ============================================================
-- 8. updated_at 자동 갱신 트리거
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 각 테이블에 트리거 연결
DO $$
DECLARE
    tbl TEXT;
BEGIN
    FOR tbl IN SELECT unnest(ARRAY[
        'companies', 'manufacturers', 'products', 
        'partners', 'warehouses', 'banks'
    ])
    LOOP
        EXECUTE format(
            'DROP TRIGGER IF EXISTS trg_%s_updated ON %I; 
             CREATE TRIGGER trg_%s_updated 
             BEFORE UPDATE ON %I 
             FOR EACH ROW EXECUTE FUNCTION update_updated_at();',
            tbl, tbl, tbl, tbl
        );
    END LOOP;
END;
$$;

-- ============================================================
-- 9. 초기 데이터: 법인 3개
-- ============================================================
INSERT INTO companies (company_name, company_code, is_active)
VALUES 
    ('탑솔라(주)', 'TS', true),
    ('디원', 'DW', true),
    ('화신이엔지', 'HS', true)
ON CONFLICT (company_code) DO NOTHING;

-- ============================================================
-- 10. 초기 데이터: 주요 제조사
-- ============================================================
INSERT INTO manufacturers (name_kr, name_en, country, domestic_foreign, is_active)
VALUES 
    -- 해외 제조사
    ('진코솔라', 'ZHEJIANG JINKO SOLAR CO.,LTD', '중국', '해외', true),
    ('트리나솔라', 'TRINA SOLAR CO.,LTD', '중국', '해외', true),
    ('라이젠에너지', 'RISEN ENERGY CO.,LTD', '중국', '해외', true),
    ('캐나디안솔라', 'CANADIAN SOLAR INC.', '캐나다', '해외', true),
    ('JA솔라', 'JA SOLAR TECHNOLOGY CO.,LTD', '중국', '해외', true),
    ('LONGi', 'LONGI GREEN ENERGY TECHNOLOGY CO.,LTD', '중국', '해외', true),
    ('통웨이솔라', 'TONGWEI SOLAR CO.,LTD', '중국', '해외', true),
    -- 국내 제조사
    ('한화솔루션', NULL, '한국', '국내', true),
    ('에스디엔', NULL, '한국', '국내', true),
    ('한솔테크닉스', NULL, '한국', '국내', true),
    ('현대에너지솔루션', NULL, '한국', '국내', true)
ON CONFLICT DO NOTHING;

-- ============================================================
-- 11. 초기 데이터: 창고/장소 (실무 현황)
-- ============================================================
INSERT INTO warehouses (warehouse_code, warehouse_name, warehouse_type, location_code, location_name)
VALUES
    -- 블루오션에어 (항구)
    ('A200', '블루오션에어', 'port', 'A202', '광양항'),
    -- 선진로지스틱스 (항구, 3곳)
    ('A400', '선진로지스틱스', 'port', 'A401', '광양항'),
    ('A400', '선진로지스틱스', 'port', 'A402', '부산항'),
    ('A400', '선진로지스틱스', 'port', 'A403', '평택항'),
    -- 광주공장 (자사)
    ('F100', '광주공장', 'factory', 'F101', 'B동공장'),
    ('F100', '광주공장', 'factory', 'F102', '제3공장'),
    -- 업체공장 (국내 제조사)
    ('B100', '한화 진천', 'vendor', 'B101', '한화 진천공장'),
    ('B100', '에스디엔 광주', 'vendor', 'B102', '에스디엔 광주공장'),
    ('B100', '한솔테크닉스', 'vendor', 'B103', '한솔 공장')
ON CONFLICT (warehouse_code, location_code) DO NOTHING;

-- ============================================================
-- 완료 확인
-- ============================================================
SELECT 
    'companies' AS table_name, count(*) AS row_count FROM companies
UNION ALL SELECT 
    'manufacturers', count(*) FROM manufacturers
UNION ALL SELECT 
    'products', count(*) FROM products
UNION ALL SELECT 
    'partners', count(*) FROM partners
UNION ALL SELECT 
    'warehouses', count(*) FROM warehouses
UNION ALL SELECT 
    'banks', count(*) FROM banks
ORDER BY table_name;
