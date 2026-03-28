-- 007: 면장(수입신고), 원가 명세, 부대비용 테이블
-- 이미 Supabase에서 실행 완료

-- 수입신고(면장) 테이블
CREATE TABLE IF NOT EXISTS import_declarations (
    declaration_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    declaration_number VARCHAR(30) NOT NULL,
    bl_id UUID NOT NULL REFERENCES bl_shipments(bl_id),
    company_id UUID NOT NULL REFERENCES companies(company_id),
    declaration_date DATE NOT NULL,
    arrival_date DATE,
    release_date DATE,
    hs_code VARCHAR(20),
    customs_office VARCHAR(50),
    port VARCHAR(20),
    memo TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 원가 명세 테이블 (FOB → CIF → Landed 3단계)
CREATE TABLE IF NOT EXISTS cost_details (
    cost_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    declaration_id UUID NOT NULL REFERENCES import_declarations(declaration_id),
    product_id UUID NOT NULL REFERENCES products(product_id),
    quantity INTEGER NOT NULL,
    capacity_kw DECIMAL(10,3),

    -- FOB 단계
    fob_unit_usd DECIMAL(10,6),
    fob_total_usd DECIMAL(15,2),
    fob_wp_krw DECIMAL(10,2),

    -- CIF 단계
    exchange_rate DECIMAL(10,2) NOT NULL,
    cif_unit_usd DECIMAL(10,6),
    cif_total_usd DECIMAL(15,2),
    cif_total_krw DECIMAL(15,0) NOT NULL,
    cif_wp_krw DECIMAL(10,2) NOT NULL,

    -- 관세 단계
    tariff_rate DECIMAL(5,4),
    tariff_amount DECIMAL(15,0),
    vat_amount DECIMAL(15,0),

    -- Landed 단계
    customs_fee DECIMAL(15,0),
    incidental_cost DECIMAL(15,0),
    landed_total_krw DECIMAL(15,0),
    landed_wp_krw DECIMAL(10,2),

    memo TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 부대비용 테이블
CREATE TABLE IF NOT EXISTS incidental_expenses (
    expense_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bl_id UUID REFERENCES bl_shipments(bl_id),
    month VARCHAR(7),
    company_id UUID NOT NULL REFERENCES companies(company_id),
    expense_type VARCHAR(20) NOT NULL,
    amount DECIMAL(15,0) NOT NULL,
    vat DECIMAL(15,0),
    total DECIMAL(15,0) NOT NULL,
    vendor VARCHAR(100),
    memo TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- bl_id 또는 month 중 하나는 필수
ALTER TABLE incidental_expenses
    ADD CONSTRAINT chk_expense_target
    CHECK (bl_id IS NOT NULL OR month IS NOT NULL);
