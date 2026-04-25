-- 025: bl_shipments에 면장 CIF 원화금액(부가세·무상분 과세 제외) 컬럼 추가
-- 원가 계산: Wp 원화단가 = cif_amount_krw ÷ 총 유상 Wp (부가세·무상분 과세 미포함)
ALTER TABLE bl_shipments ADD COLUMN IF NOT EXISTS cif_amount_krw bigint;
