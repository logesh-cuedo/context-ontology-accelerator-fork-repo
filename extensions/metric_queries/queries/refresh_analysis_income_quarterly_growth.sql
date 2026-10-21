-- Routine: silverzone.refresh_analysis_income_quarterly_growth
-- Source: capable-code-486208-j8.silverzone

BEGIN
CREATE OR REPLACE TABLE silverzone.analysis_income_quarterly_growth
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
      gross_sales,
      less_excise_duty,
      net_sales
    FROM silverzone.combined_profit_and_loss_income_quarterly
  ),
  lagged AS (
    SELECT
      *,
      LAG(yyyymm) OVER w AS prev_yyyymm,
      LAG(gross_sales) OVER w AS gross_sales_prev_q,
      LAG(less_excise_duty) OVER w AS less_excise_duty_prev_q,
      LAG(net_sales) OVER w AS net_sales_prev_q
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
  l.gross_sales,
  l.gross_sales_prev_q,
  IF(
    DATE_DIFF(
      PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
      PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
      MONTH)
      = 3,
    (l.gross_sales - l.gross_sales_prev_q)
      / ABS(NULLIF(l.gross_sales_prev_q, 0))
      * 100,
    NULL)
    AS gross_sales_qoq_pct,
  p.gross_sales AS gross_sales_prior_yr_q,
  (l.gross_sales - p.gross_sales) / ABS(NULLIF(p.gross_sales, 0)) * 100
    AS gross_sales_yoy_pct,
  l.less_excise_duty,
  l.less_excise_duty_prev_q,
  IF(
    DATE_DIFF(
      PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
      PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
      MONTH)
      = 3,
    (l.less_excise_duty - l.less_excise_duty_prev_q)
      / ABS(NULLIF(l.less_excise_duty_prev_q, 0))
      * 100,
    NULL)
    AS less_excise_duty_qoq_pct,
  p.less_excise_duty AS less_excise_duty_prior_yr_q,
  (l.less_excise_duty - p.less_excise_duty)
    / ABS(NULLIF(p.less_excise_duty, 0))
    * 100
    AS less_excise_duty_yoy_pct,
  l.net_sales,
  l.net_sales_prev_q,
  IF(
    DATE_DIFF(
      PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
      PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
      MONTH)
      = 3,
    (l.net_sales - l.net_sales_prev_q)
      / ABS(NULLIF(l.net_sales_prev_q, 0))
      * 100,
    NULL)
    AS net_sales_qoq_pct,
  p.net_sales AS net_sales_prior_yr_q,
  (l.net_sales - p.net_sales) / ABS(NULLIF(p.net_sales, 0)) * 100
    AS net_sales_yoy_pct
FROM lagged l
LEFT JOIN base p
  ON
    p.company_id = l.company_id
    AND COALESCE(p.flag, '') = COALESCE(l.flag, '')
    AND p.yyyymm = l.yyyymm - 100;

END
