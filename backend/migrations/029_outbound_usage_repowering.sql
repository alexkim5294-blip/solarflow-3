ALTER TABLE outbounds
  DROP CONSTRAINT IF EXISTS outbounds_usage_category_check;

ALTER TABLE outbounds
  ADD CONSTRAINT outbounds_usage_category_check
  CHECK (
    usage_category IN (
      'sale',
      'sale_spare',
      'construction',
      'construction_damage',
      'repowering',
      'maintenance',
      'disposal',
      'transfer',
      'adjustment',
      'other'
    )
  );
