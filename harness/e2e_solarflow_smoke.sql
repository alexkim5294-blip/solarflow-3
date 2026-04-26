-- SolarFlow end-to-end smoke data.
-- 실제 검증용 데이터이며 모든 주요 번호에 SF-E2E 접두어를 붙인다.

DO $$
DECLARE
  suffix text := to_char(clock_timestamp(), 'YYYYMMDDHH24MISSMS');
  v_company uuid;
  v_mfg uuid;
  v_product uuid;
  v_customer uuid;
  v_warehouse uuid;
  v_bank uuid;
  v_po uuid;
  v_po_line uuid;
  v_lc uuid;
  v_bl uuid;
  v_order uuid;
  v_outbound uuid;
  v_sale uuid;
  v_receipt uuid;
  v_qty_purchase integer := 5000;
  v_qty_sale integer := 1000;
  v_spec_wp integer := 640;
  v_purchase_usd_wp numeric := 0.118;
  v_sale_krw_wp numeric := 190;
  v_supply numeric;
  v_vat numeric;
  v_total numeric;
BEGIN
  SELECT company_id INTO v_company FROM companies WHERE company_code = 'TS' LIMIT 1;
  SELECT manufacturer_id INTO v_mfg FROM manufacturers WHERE name_kr = '진코솔라' LIMIT 1;
  SELECT warehouse_id INTO v_warehouse FROM warehouses WHERE is_active ORDER BY warehouse_name LIMIT 1;
  SELECT bank_id INTO v_bank FROM banks WHERE company_id = v_company AND is_active ORDER BY lc_limit_usd DESC LIMIT 1;

  IF v_company IS NULL OR v_mfg IS NULL OR v_warehouse IS NULL OR v_bank IS NULL THEN
    RAISE EXCEPTION 'E2E seed prerequisite missing: company %, manufacturer %, warehouse %, bank %', v_company, v_mfg, v_warehouse, v_bank;
  END IF;

  INSERT INTO products (
    product_code, product_name, manufacturer_id, spec_wp, wattage_kw,
    module_width_mm, module_height_mm, module_depth_mm, weight_kg,
    wafer_platform, cell_config, series_name, memo
  ) VALUES (
    'SF-E2E-JK640-' || suffix, 'SF-E2E 진코 640W 검증모듈', v_mfg, v_spec_wp, 0.640,
    2465, 1134, 35, 33.0,
    'N-Type', '78HL4', 'E2E', 'SF-E2E smoke test product'
  ) RETURNING product_id INTO v_product;

  INSERT INTO partners (
    partner_name, partner_type, erp_code, payment_terms, contact_name, contact_email
  ) VALUES (
    'SF-E2E 검증거래처 ' || suffix, 'customer', substring('E2E' || suffix from 1 for 10),
    '세금계산서 발행 후 입금', '검증담당', 'e2e@example.com'
  ) RETURNING partner_id INTO v_customer;

  INSERT INTO purchase_orders (
    po_number, company_id, manufacturer_id, contract_type, contract_date,
    incoterms, payment_terms, total_qty, total_mw, status, memo
  ) VALUES (
    'SF-E2E-PO-' || suffix, v_company, v_mfg, 'spot', CURRENT_DATE,
    'FOB', 'T/T 10%, L/C 90%', v_qty_purchase, v_qty_purchase * v_spec_wp / 1000000.0,
    'contracted', 'SF-E2E purchase flow'
  ) RETURNING po_id INTO v_po;

  INSERT INTO po_line_items (
    po_id, product_id, quantity, unit_price_usd, unit_price_usd_wp,
    total_amount_usd, item_type, payment_type, memo
  ) VALUES (
    v_po, v_product, v_qty_purchase, v_spec_wp * v_purchase_usd_wp, v_purchase_usd_wp,
    v_qty_purchase * v_spec_wp * v_purchase_usd_wp, 'main', 'paid', 'SF-E2E PO line'
  ) RETURNING po_line_id INTO v_po_line;

  INSERT INTO price_histories (
    product_id, manufacturer_id, company_id, change_date, previous_price,
    new_price, reason, related_po_id, memo
  ) VALUES (
    v_product, v_mfg, v_company, CURRENT_DATE, NULL,
    v_purchase_usd_wp, 'SF-E2E 최초계약', v_po, 'dashboard price trend smoke'
  );

  INSERT INTO lc_records (
    po_id, lc_number, bank_id, company_id, open_date, amount_usd,
    target_qty, target_mw, usance_days, usance_type, maturity_date, status, memo
  ) VALUES (
    v_po, 'SF-E2E-LC-' || suffix, v_bank, v_company, CURRENT_DATE,
    v_qty_purchase * v_spec_wp * v_purchase_usd_wp, v_qty_purchase,
    v_qty_purchase * v_spec_wp / 1000000.0, 90, 'buyers',
    CURRENT_DATE + INTERVAL '90 days', 'opened', 'SF-E2E LC'
  ) RETURNING lc_id INTO v_lc;

  INSERT INTO bl_shipments (
    bl_number, po_id, lc_id, company_id, manufacturer_id, inbound_type,
    currency, exchange_rate, etd, eta, actual_arrival, port,
    warehouse_id, invoice_number, status, erp_registered, payment_terms,
    incoterms, memo
  ) VALUES (
    'SF-E2E-BL-' || suffix, v_po, v_lc, v_company, v_mfg, 'import',
    'USD', 1380, CURRENT_DATE - INTERVAL '20 days', CURRENT_DATE - INTERVAL '5 days',
    CURRENT_DATE - INTERVAL '4 days', '부산', v_warehouse,
    'SF-E2E-INV-' || suffix, 'completed', false, 'L/C 90 days',
    'FOB', 'SF-E2E inbound completed'
  ) RETURNING bl_id INTO v_bl;

  INSERT INTO bl_line_items (
    bl_id, product_id, quantity, capacity_kw, item_type, payment_type,
    invoice_amount_usd, unit_price_usd_wp, usage_category, po_line_id, memo
  ) VALUES (
    v_bl, v_product, v_qty_purchase, v_qty_purchase * v_spec_wp / 1000.0,
    'main', 'paid', v_qty_purchase * v_spec_wp * v_purchase_usd_wp,
    v_purchase_usd_wp, 'sale', v_po_line, 'SF-E2E BL line'
  );

  INSERT INTO orders (
    order_number, company_id, customer_id, order_date, receipt_method,
    management_category, fulfillment_source, product_id, quantity, capacity_kw,
    unit_price_wp, site_name, payment_terms, delivery_due, shipped_qty,
    remaining_qty, status, bl_id, memo
  ) VALUES (
    'SF-E2E-ORD-' || suffix, v_company, v_customer, CURRENT_DATE,
    'email', 'sale', 'stock', v_product, v_qty_sale,
    v_qty_sale * v_spec_wp / 1000.0, v_sale_krw_wp, 'SF-E2E 검증현장',
    '계산서 발행 후 입금', CURRENT_DATE + INTERVAL '7 days',
    v_qty_sale, 0, 'completed', v_bl, 'SF-E2E order'
  ) RETURNING order_id INTO v_order;

  INSERT INTO outbounds (
    outbound_date, company_id, product_id, quantity, capacity_kw,
    warehouse_id, usage_category, order_id, site_name, status, bl_id, memo
  ) VALUES (
    CURRENT_DATE, v_company, v_product, v_qty_sale, v_qty_sale * v_spec_wp / 1000.0,
    v_warehouse, 'sale', v_order, 'SF-E2E 검증현장',
    'active', v_bl, 'SF-E2E outbound'
  ) RETURNING outbound_id INTO v_outbound;

  v_supply := v_qty_sale * v_spec_wp * v_sale_krw_wp;
  v_vat := round(v_supply * 0.1);
  v_total := v_supply + v_vat;

  INSERT INTO sales (
    outbound_id, order_id, customer_id, quantity, capacity_kw,
    unit_price_wp, unit_price_ea, supply_amount, vat_amount, total_amount,
    tax_invoice_date, tax_invoice_email, erp_closed, memo
  ) VALUES (
    v_outbound, v_order, v_customer, v_qty_sale, v_qty_sale * v_spec_wp / 1000.0,
    v_sale_krw_wp, v_spec_wp * v_sale_krw_wp, v_supply, v_vat, v_total,
    CURRENT_DATE, 'e2e@example.com', false, 'SF-E2E sale'
  ) RETURNING sale_id INTO v_sale;

  INSERT INTO receipts (
    customer_id, receipt_date, amount, bank_account, memo
  ) VALUES (
    v_customer, CURRENT_DATE, v_total, 'SF-E2E 검증계좌', 'SF-E2E receipt'
  ) RETURNING receipt_id INTO v_receipt;

  INSERT INTO receipt_matches (
    receipt_id, outbound_id, sale_id, matched_amount
  ) VALUES (
    v_receipt, v_outbound, v_sale, v_total
  );

  INSERT INTO module_demand_forecasts (
    company_id, site_name, demand_month, demand_type, manufacturer_id,
    spec_wp, module_width_mm, module_height_mm, required_kw, status, notes
  ) VALUES (
    v_company, 'SF-E2E 자체공사 전망 ' || suffix,
    to_char(CURRENT_DATE + INTERVAL '6 months', 'YYYY-MM'), 'construction', v_mfg,
    v_spec_wp, 2465, 1134, 3000, 'planned', 'SF-E2E forecast demand'
  );

  RAISE NOTICE 'SF-E2E created suffix=%, product=%, customer=%, po=%, bl=%, order=%, outbound=%, sale=%, receipt=%',
    suffix, v_product, v_customer, v_po, v_bl, v_order, v_outbound, v_sale, v_receipt;
END $$;

WITH e2e AS (
  SELECT
    (SELECT count(*) FROM purchase_orders WHERE po_number LIKE 'SF-E2E-PO-%') AS po_count,
    (SELECT count(*) FROM bl_shipments WHERE bl_number LIKE 'SF-E2E-BL-%') AS bl_count,
    (SELECT count(*) FROM orders WHERE order_number LIKE 'SF-E2E-ORD-%') AS order_count,
    (SELECT count(*) FROM outbounds WHERE memo LIKE 'SF-E2E outbound%') AS outbound_count,
    (SELECT count(*) FROM sales WHERE memo LIKE 'SF-E2E sale%') AS sale_count,
    (SELECT count(*) FROM receipts WHERE memo LIKE 'SF-E2E receipt%') AS receipt_count,
    (SELECT count(*) FROM module_demand_forecasts WHERE notes LIKE 'SF-E2E forecast%') AS forecast_count
)
SELECT 'record_counts' AS check_name, row_to_json(e2e) AS result
FROM e2e;

SELECT 'latest_flow_balances' AS check_name,
       json_build_object(
         'order_remaining_qty', o.remaining_qty,
         'inbound_qty', bli.quantity,
         'outbound_qty', ob.quantity,
         'available_after_outbound_qty', bli.quantity - ob.quantity,
         'sale_total', s.total_amount,
         'receipt_amount', r.amount,
         'matched_amount', rm.matched_amount,
         'outstanding_after_match', s.total_amount - rm.matched_amount
       ) AS result
FROM orders o
JOIN outbounds ob ON ob.order_id = o.order_id
JOIN sales s ON s.outbound_id = ob.outbound_id
JOIN receipt_matches rm ON rm.sale_id = s.sale_id
JOIN receipts r ON r.receipt_id = rm.receipt_id
JOIN bl_shipments bl ON bl.bl_id = ob.bl_id
JOIN bl_line_items bli ON bli.bl_id = bl.bl_id AND bli.product_id = ob.product_id
WHERE o.order_number LIKE 'SF-E2E-ORD-%'
ORDER BY o.created_at DESC
LIMIT 1;
