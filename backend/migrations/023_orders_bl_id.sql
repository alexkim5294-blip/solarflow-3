-- orders에 BL 연결 추가 (원가 추적용, 선택)
ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS bl_id uuid REFERENCES bl_shipments(bl_id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_orders_bl_id ON orders (bl_id);
