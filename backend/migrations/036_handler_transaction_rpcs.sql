-- 036: 핸들러 다단계 변경을 Postgres 함수 1회 호출로 묶어 부분 성공을 방지한다.

CREATE OR REPLACE FUNCTION sf_recalculate_order_progress(p_order_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_order_qty integer;
  v_order_status text;
  v_shipped_qty integer;
  v_remaining_qty integer;
  v_next_status text;
BEGIN
  IF p_order_id IS NULL THEN
    RETURN;
  END IF;

  SELECT quantity, status
    INTO v_order_qty, v_order_status
    FROM orders
   WHERE order_id = p_order_id
   FOR UPDATE;

  IF NOT FOUND OR v_order_status = 'cancelled' THEN
    RETURN;
  END IF;

  SELECT COALESCE(SUM(quantity), 0)
    INTO v_shipped_qty
    FROM outbounds
   WHERE order_id = p_order_id
     AND status = 'active';

  v_remaining_qty := GREATEST(v_order_qty - v_shipped_qty, 0);
  v_next_status := 'received';

  IF v_shipped_qty > 0 AND v_remaining_qty > 0 THEN
    v_next_status := 'partial';
  ELSIF v_shipped_qty > 0 AND v_remaining_qty = 0 THEN
    v_next_status := 'completed';
  END IF;

  UPDATE orders
     SET shipped_qty = v_shipped_qty,
         remaining_qty = v_remaining_qty,
         status = v_next_status
   WHERE order_id = p_order_id;
END;
$$;

CREATE OR REPLACE FUNCTION sf_insert_outbound_bl_items(p_outbound_id uuid, p_bl_items jsonb)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO outbound_bl_items (outbound_id, bl_id, quantity)
  SELECT p_outbound_id,
         (item->>'bl_id')::uuid,
         (item->>'quantity')::integer
    FROM jsonb_array_elements(
           CASE
             WHEN p_bl_items IS NULL OR jsonb_typeof(p_bl_items) <> 'array' THEN '[]'::jsonb
             ELSE p_bl_items
           END
         ) AS item
   WHERE COALESCE(item->>'bl_id', '') <> ''
     AND COALESCE((item->>'quantity')::integer, 0) > 0;
END;
$$;

CREATE OR REPLACE FUNCTION sf_create_outbound(
  p_outbound_id uuid,
  p_outbound jsonb,
  p_bl_items jsonb DEFAULT '[]'::jsonb
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_order_id uuid;
BEGIN
  v_order_id := NULLIF(p_outbound->>'order_id', '')::uuid;

  INSERT INTO outbounds (
    outbound_id,
    outbound_date,
    company_id,
    product_id,
    quantity,
    capacity_kw,
    warehouse_id,
    usage_category,
    order_id,
    site_name,
    site_address,
    spare_qty,
    group_trade,
    target_company_id,
    erp_outbound_no,
    status,
    memo,
    bl_id
  )
  VALUES (
    p_outbound_id,
    (p_outbound->>'outbound_date')::date,
    (p_outbound->>'company_id')::uuid,
    (p_outbound->>'product_id')::uuid,
    (p_outbound->>'quantity')::integer,
    NULLIF(p_outbound->>'capacity_kw', '')::numeric,
    (p_outbound->>'warehouse_id')::uuid,
    p_outbound->>'usage_category',
    v_order_id,
    p_outbound->>'site_name',
    p_outbound->>'site_address',
    NULLIF(p_outbound->>'spare_qty', '')::integer,
    (p_outbound->>'group_trade')::boolean,
    NULLIF(p_outbound->>'target_company_id', '')::uuid,
    p_outbound->>'erp_outbound_no',
    COALESCE(NULLIF(p_outbound->>'status', ''), 'active'),
    p_outbound->>'memo',
    NULLIF(p_outbound->>'bl_id', '')::uuid
  );

  PERFORM sf_insert_outbound_bl_items(p_outbound_id, p_bl_items);
  PERFORM sf_recalculate_order_progress(v_order_id);
END;
$$;

CREATE OR REPLACE FUNCTION sf_update_outbound(
  p_outbound_id uuid,
  p_outbound jsonb,
  p_bl_items jsonb DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_prev_order_id uuid;
  v_new_order_id uuid;
  v_rows integer;
BEGIN
  SELECT order_id
    INTO v_prev_order_id
    FROM outbounds
   WHERE outbound_id = p_outbound_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'outbound not found: %', p_outbound_id USING ERRCODE = 'P0002';
  END IF;

  UPDATE outbounds
     SET outbound_date = CASE WHEN p_outbound ? 'outbound_date' THEN (p_outbound->>'outbound_date')::date ELSE outbound_date END,
         company_id = CASE WHEN p_outbound ? 'company_id' THEN (p_outbound->>'company_id')::uuid ELSE company_id END,
         product_id = CASE WHEN p_outbound ? 'product_id' THEN (p_outbound->>'product_id')::uuid ELSE product_id END,
         quantity = CASE WHEN p_outbound ? 'quantity' THEN (p_outbound->>'quantity')::integer ELSE quantity END,
         capacity_kw = CASE WHEN p_outbound ? 'capacity_kw' THEN NULLIF(p_outbound->>'capacity_kw', '')::numeric ELSE capacity_kw END,
         warehouse_id = CASE WHEN p_outbound ? 'warehouse_id' THEN (p_outbound->>'warehouse_id')::uuid ELSE warehouse_id END,
         usage_category = CASE WHEN p_outbound ? 'usage_category' THEN p_outbound->>'usage_category' ELSE usage_category END,
         order_id = CASE WHEN p_outbound ? 'order_id' THEN NULLIF(p_outbound->>'order_id', '')::uuid ELSE order_id END,
         site_name = CASE WHEN p_outbound ? 'site_name' THEN p_outbound->>'site_name' ELSE site_name END,
         site_address = CASE WHEN p_outbound ? 'site_address' THEN p_outbound->>'site_address' ELSE site_address END,
         spare_qty = CASE WHEN p_outbound ? 'spare_qty' THEN NULLIF(p_outbound->>'spare_qty', '')::integer ELSE spare_qty END,
         group_trade = CASE WHEN p_outbound ? 'group_trade' THEN (p_outbound->>'group_trade')::boolean ELSE group_trade END,
         target_company_id = CASE WHEN p_outbound ? 'target_company_id' THEN NULLIF(p_outbound->>'target_company_id', '')::uuid ELSE target_company_id END,
         erp_outbound_no = CASE WHEN p_outbound ? 'erp_outbound_no' THEN p_outbound->>'erp_outbound_no' ELSE erp_outbound_no END,
         status = CASE WHEN p_outbound ? 'status' THEN p_outbound->>'status' ELSE status END,
         memo = CASE WHEN p_outbound ? 'memo' THEN p_outbound->>'memo' ELSE memo END,
         bl_id = CASE WHEN p_outbound ? 'bl_id' THEN NULLIF(p_outbound->>'bl_id', '')::uuid ELSE bl_id END
   WHERE outbound_id = p_outbound_id;

  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows = 0 THEN
    RAISE EXCEPTION 'outbound not found: %', p_outbound_id USING ERRCODE = 'P0002';
  END IF;

  IF p_bl_items IS NOT NULL AND jsonb_typeof(p_bl_items) = 'array' THEN
    DELETE FROM outbound_bl_items
     WHERE outbound_id = p_outbound_id;

    PERFORM sf_insert_outbound_bl_items(p_outbound_id, p_bl_items);
  END IF;

  SELECT order_id
    INTO v_new_order_id
    FROM outbounds
   WHERE outbound_id = p_outbound_id;

  PERFORM sf_recalculate_order_progress(v_prev_order_id);

  IF v_new_order_id IS DISTINCT FROM v_prev_order_id THEN
    PERFORM sf_recalculate_order_progress(v_new_order_id);
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION sf_delete_outbound(p_outbound_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_order_id uuid;
BEGIN
  SELECT order_id
    INTO v_order_id
    FROM outbounds
   WHERE outbound_id = p_outbound_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'outbound not found: %', p_outbound_id USING ERRCODE = 'P0002';
  END IF;

  UPDATE sales
     SET outbound_id = NULL
   WHERE outbound_id = p_outbound_id
     AND order_id IS NOT NULL;

  DELETE FROM sales
   WHERE outbound_id = p_outbound_id
     AND order_id IS NULL;

  DELETE FROM outbounds
   WHERE outbound_id = p_outbound_id;

  PERFORM sf_recalculate_order_progress(v_order_id);
END;
$$;

CREATE OR REPLACE FUNCTION sf_delete_purchase_order(p_po_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_rows integer;
BEGIN
  PERFORM 1
    FROM purchase_orders
   WHERE po_id = p_po_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'purchase order not found: %', p_po_id USING ERRCODE = 'P0002';
  END IF;

  DELETE FROM tt_remittances
   WHERE po_id = p_po_id;

  DELETE FROM price_histories
   WHERE related_po_id = p_po_id;

  DELETE FROM po_line_items
   WHERE po_id = p_po_id;

  DELETE FROM purchase_orders
   WHERE po_id = p_po_id;

  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows = 0 THEN
    RAISE EXCEPTION 'purchase order not found: %', p_po_id USING ERRCODE = 'P0002';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION sf_delete_declaration(p_declaration_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_rows integer;
BEGIN
  PERFORM 1
    FROM import_declarations
   WHERE declaration_id = p_declaration_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'declaration not found: %', p_declaration_id USING ERRCODE = 'P0002';
  END IF;

  DELETE FROM cost_details
   WHERE declaration_id = p_declaration_id;

  DELETE FROM import_declarations
   WHERE declaration_id = p_declaration_id;

  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows = 0 THEN
    RAISE EXCEPTION 'declaration not found: %', p_declaration_id USING ERRCODE = 'P0002';
  END IF;
END;
$$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    GRANT EXECUTE ON FUNCTION sf_recalculate_order_progress(uuid) TO anon;
    GRANT EXECUTE ON FUNCTION sf_insert_outbound_bl_items(uuid, jsonb) TO anon;
    GRANT EXECUTE ON FUNCTION sf_create_outbound(uuid, jsonb, jsonb) TO anon;
    GRANT EXECUTE ON FUNCTION sf_update_outbound(uuid, jsonb, jsonb) TO anon;
    GRANT EXECUTE ON FUNCTION sf_delete_outbound(uuid) TO anon;
    GRANT EXECUTE ON FUNCTION sf_delete_purchase_order(uuid) TO anon;
    GRANT EXECUTE ON FUNCTION sf_delete_declaration(uuid) TO anon;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    GRANT EXECUTE ON FUNCTION sf_recalculate_order_progress(uuid) TO authenticated;
    GRANT EXECUTE ON FUNCTION sf_insert_outbound_bl_items(uuid, jsonb) TO authenticated;
    GRANT EXECUTE ON FUNCTION sf_create_outbound(uuid, jsonb, jsonb) TO authenticated;
    GRANT EXECUTE ON FUNCTION sf_update_outbound(uuid, jsonb, jsonb) TO authenticated;
    GRANT EXECUTE ON FUNCTION sf_delete_outbound(uuid) TO authenticated;
    GRANT EXECUTE ON FUNCTION sf_delete_purchase_order(uuid) TO authenticated;
    GRANT EXECUTE ON FUNCTION sf_delete_declaration(uuid) TO authenticated;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
    GRANT EXECUTE ON FUNCTION sf_recalculate_order_progress(uuid) TO service_role;
    GRANT EXECUTE ON FUNCTION sf_insert_outbound_bl_items(uuid, jsonb) TO service_role;
    GRANT EXECUTE ON FUNCTION sf_create_outbound(uuid, jsonb, jsonb) TO service_role;
    GRANT EXECUTE ON FUNCTION sf_update_outbound(uuid, jsonb, jsonb) TO service_role;
    GRANT EXECUTE ON FUNCTION sf_delete_outbound(uuid) TO service_role;
    GRANT EXECUTE ON FUNCTION sf_delete_purchase_order(uuid) TO service_role;
    GRANT EXECUTE ON FUNCTION sf_delete_declaration(uuid) TO service_role;
  END IF;
END $$;
