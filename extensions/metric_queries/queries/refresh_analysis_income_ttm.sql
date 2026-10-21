-- Routine: silverzone.refresh_analysis_income_ttm
-- Source: capable-code-486208-j8.silverzone

BEGIN
CREATE OR REPLACE TABLE silverzone.analysis_income_ttm
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
  gross_sales,
  SUM(gross_sales) OVER w AS gross_sales_ttm,
  less_excise_duty,
  SUM(less_excise_duty) OVER w AS less_excise_duty_ttm,
  net_sales,
  SUM(net_sales) OVER w AS net_sales_ttm
FROM silverzone.combined_profit_and_loss_income_quarterly
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
