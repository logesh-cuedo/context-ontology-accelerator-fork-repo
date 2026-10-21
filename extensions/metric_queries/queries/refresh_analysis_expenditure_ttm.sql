-- Routine: silverzone.refresh_analysis_expenditure_ttm
-- Source: capable-code-486208-j8.silverzone

BEGIN
CREATE OR REPLACE TABLE silverzone.analysis_expenditure_ttm
  CLUSTER BY company_id, yyyymm
AS
SELECT
  company_id,
  company_name,
  sector,
  subsector,
  flag,
  yyyymm,
  MIN(yyyymm) OVER w AS ttm_start_yyyymm,
  increase_decrease_in_stock,
  SUM(increase_decrease_in_stock) OVER w AS increase_decrease_in_stock_ttm,
  raw_material_consumed,
  SUM(raw_material_consumed) OVER w AS raw_material_consumed_ttm,
  power_fuel_cost,
  SUM(power_fuel_cost) OVER w AS power_fuel_cost_ttm,
  employee_cost,
  SUM(employee_cost) OVER w AS employee_cost_ttm,
  total_expenditure,
  SUM(total_expenditure) OVER w AS total_expenditure_ttm,
  interest,
  SUM(interest) OVER w AS interest_ttm,
  depreciation,
  SUM(depreciation) OVER w AS depreciation_ttm
FROM silverzone.combined_profit_and_loss_expenditure_quarterly
QUALIFY
  COUNT(*) OVER w = 4
  AND DATE_DIFF(
    PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
    PARSE_DATE('%Y%m', CAST(MIN(yyyymm) OVER w AS STRING)),
    MONTH)
    = 9
WINDOW
  w AS (
    PARTITION BY company_id, flag
    ORDER BY yyyymm
    ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
  );

END
