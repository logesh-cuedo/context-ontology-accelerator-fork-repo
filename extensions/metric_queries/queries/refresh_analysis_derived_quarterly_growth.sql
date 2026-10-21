-- Routine: silverzone.refresh_analysis_derived_quarterly_growth
-- Source: capable-code-486208-j8.silverzone

BEGIN
CREATE OR REPLACE TABLE silverzone.analysis_derived_quarterly_growth
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
      operating_profit_excl_oi,
      operating_profit,
      pbdt,
      profit_before_tax,
      profit_after_tax,
      earnings_per_share_calculated,
      adjusted_eps,
      eps_basic_reported,
      eps_diluted_reported
    FROM silverzone.combined_profit_and_loss_derived_quarterly
  ),
  lagged AS (
    SELECT
      *,
      LAG(yyyymm) OVER w AS prev_yyyymm,
      LAG(operating_profit_excl_oi) OVER w AS operating_profit_excl_oi_prev_q,
      LAG(operating_profit) OVER w AS operating_profit_prev_q,
      LAG(pbdt) OVER w AS pbdt_prev_q,
      LAG(profit_before_tax) OVER w AS profit_before_tax_prev_q,
      LAG(profit_after_tax) OVER w AS profit_after_tax_prev_q,
      LAG(earnings_per_share_calculated)
        OVER w AS earnings_per_share_calculated_prev_q,
      LAG(adjusted_eps) OVER w AS adjusted_eps_prev_q,
      LAG(eps_basic_reported) OVER w AS eps_basic_reported_prev_q,
      LAG(eps_diluted_reported) OVER w AS eps_diluted_reported_prev_q
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
  l.operating_profit_excl_oi,
  l.operating_profit_excl_oi_prev_q,
  IF(
    DATE_DIFF(
      PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
      PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
      MONTH)
      = 3,
    (l.operating_profit_excl_oi - l.operating_profit_excl_oi_prev_q)
      / ABS(NULLIF(l.operating_profit_excl_oi_prev_q, 0))
      * 100,
    NULL)
    AS operating_profit_excl_oi_qoq_pct,
  p.operating_profit_excl_oi AS operating_profit_excl_oi_prior_yr_q,
  (l.operating_profit_excl_oi - p.operating_profit_excl_oi)
    / ABS(NULLIF(p.operating_profit_excl_oi, 0))
    * 100
    AS operating_profit_excl_oi_yoy_pct,
  l.operating_profit,
  l.operating_profit_prev_q,
  IF(
    DATE_DIFF(
      PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
      PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
      MONTH)
      = 3,
    (l.operating_profit - l.operating_profit_prev_q)
      / ABS(NULLIF(l.operating_profit_prev_q, 0))
      * 100,
    NULL)
    AS operating_profit_qoq_pct,
  p.operating_profit AS operating_profit_prior_yr_q,
  (l.operating_profit - p.operating_profit)
    / ABS(NULLIF(p.operating_profit, 0))
    * 100
    AS operating_profit_yoy_pct,
  l.pbdt,
  l.pbdt_prev_q,
  IF(
    DATE_DIFF(
      PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
      PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
      MONTH)
      = 3,
    (l.pbdt - l.pbdt_prev_q) / ABS(NULLIF(l.pbdt_prev_q, 0)) * 100,
    NULL)
    AS pbdt_qoq_pct,
  p.pbdt AS pbdt_prior_yr_q,
  (l.pbdt - p.pbdt) / ABS(NULLIF(p.pbdt, 0)) * 100 AS pbdt_yoy_pct,
  l.profit_before_tax,
  l.profit_before_tax_prev_q,
  IF(
    DATE_DIFF(
      PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
      PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
      MONTH)
      = 3,
    (l.profit_before_tax - l.profit_before_tax_prev_q)
      / ABS(NULLIF(l.profit_before_tax_prev_q, 0))
      * 100,
    NULL)
    AS profit_before_tax_qoq_pct,
  p.profit_before_tax AS profit_before_tax_prior_yr_q,
  (l.profit_before_tax - p.profit_before_tax)
    / ABS(NULLIF(p.profit_before_tax, 0))
    * 100
    AS profit_before_tax_yoy_pct,
  l.profit_after_tax,
  l.profit_after_tax_prev_q,
  IF(
    DATE_DIFF(
      PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
      PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
      MONTH)
      = 3,
    (l.profit_after_tax - l.profit_after_tax_prev_q)
      / ABS(NULLIF(l.profit_after_tax_prev_q, 0))
      * 100,
    NULL)
    AS profit_after_tax_qoq_pct,
  p.profit_after_tax AS profit_after_tax_prior_yr_q,
  (l.profit_after_tax - p.profit_after_tax)
    / ABS(NULLIF(p.profit_after_tax, 0))
    * 100
    AS profit_after_tax_yoy_pct,
  l.earnings_per_share_calculated,
  l.earnings_per_share_calculated_prev_q,
  IF(
    DATE_DIFF(
      PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
      PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
      MONTH)
      = 3,
    (l.earnings_per_share_calculated - l.earnings_per_share_calculated_prev_q)
      / ABS(NULLIF(l.earnings_per_share_calculated_prev_q, 0))
      * 100,
    NULL)
    AS earnings_per_share_calculated_qoq_pct,
  p.earnings_per_share_calculated AS earnings_per_share_calculated_prior_yr_q,
  (l.earnings_per_share_calculated - p.earnings_per_share_calculated)
    / ABS(NULLIF(p.earnings_per_share_calculated, 0))
    * 100
    AS earnings_per_share_calculated_yoy_pct,
  l.adjusted_eps,
  l.adjusted_eps_prev_q,
  IF(
    DATE_DIFF(
      PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
      PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
      MONTH)
      = 3,
    (l.adjusted_eps - l.adjusted_eps_prev_q)
      / ABS(NULLIF(l.adjusted_eps_prev_q, 0))
      * 100,
    NULL)
    AS adjusted_eps_qoq_pct,
  p.adjusted_eps AS adjusted_eps_prior_yr_q,
  (l.adjusted_eps - p.adjusted_eps) / ABS(NULLIF(p.adjusted_eps, 0)) * 100
    AS adjusted_eps_yoy_pct,
  l.eps_basic_reported,
  l.eps_basic_reported_prev_q,
  IF(
    DATE_DIFF(
      PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
      PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
      MONTH)
      = 3,
    (l.eps_basic_reported - l.eps_basic_reported_prev_q)
      / ABS(NULLIF(l.eps_basic_reported_prev_q, 0))
      * 100,
    NULL)
    AS eps_basic_reported_qoq_pct,
  p.eps_basic_reported AS eps_basic_reported_prior_yr_q,
  (l.eps_basic_reported - p.eps_basic_reported)
    / ABS(NULLIF(p.eps_basic_reported, 0))
    * 100
    AS eps_basic_reported_yoy_pct,
  l.eps_diluted_reported,
  l.eps_diluted_reported_prev_q,
  IF(
    DATE_DIFF(
      PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
      PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
      MONTH)
      = 3,
    (l.eps_diluted_reported - l.eps_diluted_reported_prev_q)
      / ABS(NULLIF(l.eps_diluted_reported_prev_q, 0))
      * 100,
    NULL)
    AS eps_diluted_reported_qoq_pct,
  p.eps_diluted_reported AS eps_diluted_reported_prior_yr_q,
  (l.eps_diluted_reported - p.eps_diluted_reported)
    / ABS(NULLIF(p.eps_diluted_reported, 0))
    * 100
    AS eps_diluted_reported_yoy_pct
FROM lagged l
LEFT JOIN base p
  ON
    p.company_id = l.company_id
    AND COALESCE(p.flag, '') = COALESCE(l.flag, '')
    AND p.yyyymm = l.yyyymm - 100;

END
