-- 출고별 현장 운송료를 기존 부대비용 전표에 귀속할 수 있게 확장
ALTER TABLE incidental_expenses
    ADD COLUMN IF NOT EXISTS outbound_id UUID REFERENCES outbounds(outbound_id) ON DELETE CASCADE,
    ADD COLUMN IF NOT EXISTS vehicle_type VARCHAR(50),
    ADD COLUMN IF NOT EXISTS destination VARCHAR(200);

CREATE INDEX IF NOT EXISTS idx_incidental_expenses_outbound
    ON incidental_expenses(outbound_id);

ALTER TABLE incidental_expenses
    DROP CONSTRAINT IF EXISTS chk_expense_target;

ALTER TABLE incidental_expenses
    ADD CONSTRAINT chk_expense_target
    CHECK (bl_id IS NOT NULL OR month IS NOT NULL OR outbound_id IS NOT NULL);
