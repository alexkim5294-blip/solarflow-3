-- ============================================================
-- SolarFlow 3.0 — Step 1 보충: 은행 초기 데이터
-- 실행 순서: 001_master_tables.sql 이후 실행
-- 데이터 출처: 외환현황 (기준일: 2026.03)
-- ============================================================

-- 탑솔라 법인의 은행 데이터 입력
-- (company_id는 companies 테이블에서 탑솔라 조회)
INSERT INTO banks (company_id, bank_name, lc_limit_usd, opening_fee_rate, acceptance_fee_rate, fee_calc_method, memo)
SELECT 
    c.company_id,
    v.bank_name,
    v.lc_limit_usd,
    v.opening_fee_rate,
    v.acceptance_fee_rate,
    v.fee_calc_method,
    v.memo
FROM companies c
CROSS JOIN (VALUES
    ('하나은행',    10000000.00, 0.0020, 0.0030, NULL,          NULL),
    ('산업은행',    10000000.00, 0.0036, 0.0040, NULL,          NULL),
    ('신한은행',     2500000.00, 0.0080, 0.0080, '연이율/360일', '개설,인수 : 0.8%/360'),
    ('국민은행',     4000000.00, 0.0016, 0.0016, NULL,          NULL),
    ('광주은행',     2500000.00, 0.0075, 0.0075, NULL,          '트리나30MW 2026.01.22 개설완료')
) AS v(bank_name, lc_limit_usd, opening_fee_rate, acceptance_fee_rate, fee_calc_method, memo)
WHERE c.company_code = 'TS'
ON CONFLICT (company_id, bank_name) DO NOTHING;

-- 결과 확인
SELECT 
    b.bank_name,
    c.company_name,
    b.lc_limit_usd AS "한도(USD)",
    (b.opening_fee_rate * 100) || '%' AS "개설수수료",
    (b.acceptance_fee_rate * 100) || '%' AS "인수수수료",
    b.memo
FROM banks b
JOIN companies c ON c.company_id = b.company_id
ORDER BY b.lc_limit_usd DESC;
