-- Routine: silverzone.refresh_analysis_income_quarterly_share_of_fy
-- Source: capable-code-486208-j8.silverzone

BEGIN
CREATE OR REPLACE TABLE silverzone.analysis_income_quarterly_share_of_fy
  CLUSTER BY company_id, yyyymm
AS
WITH
  q AS (
    SELECT *, DIV(yyyymm, 100) + IF(MOD(yyyymm, 100) >= 4, 1, 0) AS fiscal_year
    FROM silverzone.combined_profit_and_loss_income_quarterly
  )
SELECT
  company_id,
  company_name,
  sector,
  subsector,
  flag,
  yyyymm,
  fiscal_year,
  CASE MOD(yyyymm, 100)
    WHEN 6 THEN 'Q1'
    WHEN 9 THEN 'Q2'
    WHEN 12 THEN 'Q3'
    WHEN 3 THEN 'Q4'
    END
    AS fiscal_quarter,
  gross_sales,
  SUM(gross_sales) OVER fy AS gross_sales_fy_total,
  IF(
    ABS(SUM(gross_sales) OVER fy) < 1e-6,
    NULL,
    gross_sales / SUM(gross_sales) OVER fy * 100)
    AS gross_sales_pct_of_fy,
  less_excise_duty,
  SUM(less_excise_duty) OVER fy AS less_excise_duty_fy_total,
  IF(
    ABS(SUM(less_excise_duty) OVER fy) < 1e-6,
    NULL,
    less_excise_duty / SUM(less_excise_duty) OVER fy * 100)
    AS less_excise_duty_pct_of_fy,
  net_sales,
  SUM(net_sales) OVER fy AS net_sales_fy_total,
  IF(
    ABS(SUM(net_sales) OVER fy) < 1e-6,
    NULL,
    net_sales / SUM(net_sales) OVER fy * 100)
    AS net_sales_pct_of_fy
FROM q
QUALIFY COUNT(*) OVER fy = 4
WINDOW fy AS (PARTITION BY company_id, flag, fiscal_year);

END
