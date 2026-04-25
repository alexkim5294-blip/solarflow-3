-- 024: purchase_orders_ext 뷰에 first_spec_wp 추가
-- 목적: PO 드롭다운에서 spec_wp 표시를 위해 N+1 fetch 없이
--       뷰 1회 조회로 첫 번째 유상 라인의 spec_wp를 반환
-- LATERAL JOIN으로 PO별 첫 번째 유상(paid) 라인의 spec_wp를 서브쿼리로 취득

CREATE OR REPLACE VIEW purchase_orders_ext AS
SELECT
  po.po_id,
  po.po_number,
  po.company_id,
  po.manufacturer_id,
  po.contract_type,
  po.contract_date,
  po.incoterms,
  po.payment_terms,
  po.total_qty,
  po.total_mw,
  po.contract_period_start,
  po.contract_period_end,
  po.status,
  po.memo,
  po.created_at,
  po.updated_at,
  po.parent_po_id,
  m.name_kr AS manufacturer_name,
  m.name_en AS manufacturer_name_en,
  first_line.spec_wp AS first_spec_wp
FROM purchase_orders po
LEFT JOIN manufacturers m ON po.manufacturer_id = m.manufacturer_id
LEFT JOIN LATERAL (
  SELECT pr.spec_wp
  FROM po_line_items pl
  LEFT JOIN products pr ON pl.product_id = pr.product_id
  WHERE pl.po_id = po.po_id
    AND (pl.payment_type IS NULL OR pl.payment_type = 'paid')
  ORDER BY pl.created_at ASC
  LIMIT 1
) first_line ON true;
