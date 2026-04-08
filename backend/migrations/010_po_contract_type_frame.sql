-- 010_po_contract_type_frame.sql
-- 목적: purchase_orders.contract_type CHECK 제약에 'frame' 추가
-- 사유: R1-2 — contract_type='frame' 저장 시 DB CHECK 위반으로 실패
-- 환경: 로컬 Mac mini PostgreSQL + 로컬 PostgREST
-- 실행:
--   psql -d solarflow -f backend/migrations/010_po_contract_type_frame.sql
--   launchctl stop com.solarflow.postgrest && launchctl start com.solarflow.postgrest

-- 기존 CHECK 제약 이름 확인 및 삭제 후 재정의
-- (제약명이 환경마다 다를 수 있어 IF EXISTS 안전)
DO $$
DECLARE
  c text;
BEGIN
  FOR c IN
    SELECT conname
      FROM pg_constraint
     WHERE conrelid = 'purchase_orders'::regclass
       AND contype = 'c'
       AND pg_get_constraintdef(oid) ILIKE '%contract_type%'
  LOOP
    EXECUTE format('ALTER TABLE purchase_orders DROP CONSTRAINT %I', c);
  END LOOP;
END$$;

-- 새 CHECK — spot/frame + 레거시 호환
ALTER TABLE purchase_orders
  ADD CONSTRAINT purchase_orders_contract_type_check
  CHECK (contract_type IN ('spot', 'frame', 'annual_frame', 'half_year_frame', 'general', 'exclusive', 'annual'));

-- 검증
SELECT conname, pg_get_constraintdef(oid)
  FROM pg_constraint
 WHERE conrelid = 'purchase_orders'::regclass
   AND contype = 'c';

-- PostgREST schema cache 재로드
NOTIFY pgrst, 'reload schema';
