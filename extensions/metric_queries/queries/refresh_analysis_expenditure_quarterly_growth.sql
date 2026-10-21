-- Routine: silverzone.refresh_analysis_expenditure_quarterly_growth
-- Source: capable-code-486208-j8.silverzone

BEGIN
CREATE OR REPLACE TABLE silverzone.analysis_expenditure_quarterly_growth
  CLUSTER BY company_id, yyyymm
AS
WITH
  base AS (
    SELECT
      company_id,
      company_name,
      sector,
      subsector,
      flag,
      yyyymm,
      increase_decrease_in_stock,
      raw_material_consumed,
      power_fuel_cost,
      employee_cost,
      total_expenditure,
      interest,
      depreciation
    FROM silverzone.combined_profit_and_loss_expenditure_quarterly
  ),
  lagged AS (
    SELECT
      *,
      LAG(yyyymm) OVER w AS prev_yyyymm,
      LAG(increase_decrease_in_stock)
        OVER w AS increase_decrease_in_stock_prev_q,
      LAG(raw_material_consumed) OVER w AS raw_material_consumed_prev_q,
      LAG(power_fuel_cost) OVER w AS power_fuel_cost_prev_q,
      LAG(employee_cost) OVER w AS employee_cost_prev_q,
      LAG(total_expenditure) OVER w AS total_expenditure_prev_q,
      LAG(interest) OVER w AS interest_prev_q,
      LAG(depreciation) OVER w AS depreciation_prev_q
    FROM base
    WINDOW w AS (PARTITION BY company_id, flag ORDER BY yyyymm)
  )
SELECT
  l.company_id,
  l.company_name,
  l.sector,
  l.subsector,
  l.flag,
  l.yyyymm,
  l.prev_yyyymm,
  p.yyyymm AS prior_yr_yyyymm,
  l.increase_decrease_in_stock,
  l.increase_decrease_in_stock_prev_q,
  IF(
    DATE_DIFF(
      PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
      PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
      MONTH)
      = 3,
    (l.increase_decrease_in_stock - l.increase_decrease_in_stock_prev_q)
      / ABS(NULLIF(l.increase_decrease_in_stock_prev_q, 0))
      * 100,
    NULL)
    AS increase_decrease_in_stock_qoq_pct,
  p.increase_decrease_in_stock AS increase_decrease_in_stock_prior_yr_q,
  (l.increase_decrease_in_stock - p.increase_decrease_in_stock)
    / ABS(NULLIF(p.increase_decrease_in_stock, 0))
    * 100
    AS increase_decrease_in_stock_yoy_pct,
  l.raw_material_consumed,
  l.raw_material_consumed_prev_q,
  IF(
    DATE_DIFF(
      PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
      PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
      MONTH)
      = 3,
    (l.raw_material_consumed - l.raw_material_consumed_prev_q)
      / ABS(NULLIF(l.raw_material_consumed_prev_q, 0))
      * 100,
    NULL)
    AS raw_material_consumed_qoq_pct,
  p.raw_material_consumed AS raw_material_consumed_prior_yr_q,
  (l.raw_material_consumed - p.raw_material_consumed)
    / ABS(NULLIF(p.raw_material_consumed, 0))
    * 100
    AS raw_material_consumed_yoy_pct,
  l.power_fuel_cost,
  l.power_fuel_cost_prev_q,
  IF(
    DATE_DIFF(
      PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
      PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
      MONTH)
      = 3,
    (l.power_fuel_cost - l.power_fuel_cost_prev_q)
      / ABS(NULLIF(l.power_fuel_cost_prev_q, 0))
      * 100,
    NULL)
    AS power_fuel_cost_qoq_pct,
  p.power_fuel_cost AS power_fuel_cost_prior_yr_q,
  (l.power_fuel_cost - p.power_fuel_cost)
    / ABS(NULLIF(p.power_fuel_cost, 0))
    * 100
    AS power_fuel_cost_yoy_pct,
  l.employee_cost,
  l.employee_cost_prev_q,
  IF(
    DATE_DIFF(
      PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
      PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
      MONTH)
      = 3,
    (l.employee_cost - l.employee_cost_prev_q)
      / ABS(NULLIF(l.employee_cost_prev_q, 0))
      * 100,
    NULL)
    AS employee_cost_qoq_pct,
  p.employee_cost AS employee_cost_prior_yr_q,
  (l.employee_cost - p.employee_cost) / ABS(NULLIF(p.employee_cost, 0)) * 100
    AS employee_cost_yoy_pct,
  l.total_expenditure,
  l.total_expenditure_prev_q,
  IF(
    DATE_DIFF(
      PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
      PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
      MONTH)
      = 3,
    (l.total_expenditure - l.total_expenditure_prev_q)
      / ABS(NULLIF(l.total_expenditure_prev_q, 0))
      * 100,
    NULL)
    AS total_expenditure_qoq_pct,
  p.total_expenditure AS total_expenditure_prior_yr_q,
  (l.total_expenditure - p.total_expenditure)
    / ABS(NULLIF(p.total_expenditure, 0))
    * 100
    AS total_expenditure_yoy_pct,
  l.interest,
  l.interest_prev_q,
  IF(
    DATE_DIFF(
      PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
      PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
      MONTH)
      = 3,
    (l.interest - l.interest_prev_q) / ABS(NULLIF(l.interest_prev_q, 0)) * 100,
    NULL)
    AS interest_qoq_pct,
  p.interest AS interest_prior_yr_q,
  (l.interest - p.interest) / ABS(NULLIF(p.interest, 0)) * 100
    AS interest_yoy_pct,
  l.depreciation,
  l.depreciation_prev_q,
  IF(
    DATE_DIFF(
      PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
      PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
      MONTH)
      = 3,
    (l.depreciation - l.depreciation_prev_q)
      / ABS(NULLIF(l.depreciation_prev_q, 0))
      * 100,
    NULL)
    AS depreciation_qoq_pct,
  p.depreciation AS depreciation_prior_yr_q,
  (l.depreciation - p.depreciation) / ABS(NULLIF(p.depreciation, 0)) * 100
    AS depreciation_yoy_pct
FROM lagged l
LEFT JOIN base p
  ON
    p.company_id = l.company_id
    AND COALESCE(p.flag, '') = COALESCE(l.flag, '')
    AND p.yyyymm = l.yyyymm - 100;

END
