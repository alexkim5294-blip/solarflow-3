-- LC 라인아이템: PO 한 건에 품목이 여러 개일 때 LC가 어느 품목 몇 장을 개설했는지 추적
-- B/L 라인아이템과 같은 po_line_id 연결을 사용해 PO → LC → B/L 흐름을 맞춘다.

CREATE TABLE IF NOT EXISTS lc_line_items (
  lc_line_id       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lc_id            uuid NOT NULL REFERENCES lc_records(lc_id) ON DELETE CASCADE,
  po_line_id       uuid REFERENCES po_line_items(po_line_id),
  product_id       uuid NOT NULL REFERENCES products(product_id),
  quantity         int NOT NULL CHECK (quantity > 0),
  capacity_kw      numeric NOT NULL CHECK (capacity_kw > 0),
  amount_usd       numeric,
  unit_price_usd_wp numeric,
  item_type        varchar(20) NOT NULL DEFAULT 'main',
  payment_type     varchar(20) NOT NULL DEFAULT 'paid',
  memo             text,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_lc_line_items_lc ON lc_line_items(lc_id);
CREATE INDEX IF NOT EXISTS idx_lc_line_items_po_line ON lc_line_items(po_line_id);
CREATE INDEX IF NOT EXISTS idx_lc_line_items_product ON lc_line_items(product_id);

DROP TRIGGER IF EXISTS update_lc_line_items_updated_at ON lc_line_items;
CREATE TRIGGER update_lc_line_items_updated_at
BEFORE UPDATE ON lc_line_items
FOR EACH ROW EXECUTE FUNCTION update_updated_at();
