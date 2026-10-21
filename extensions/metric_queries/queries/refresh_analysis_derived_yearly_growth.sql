-- Routine: silverzone.refresh_analysis_derived_yearly_growth
-- Source: capable-code-486208-j8.silverzone

BEGIN
CREATE OR REPLACE TABLE silverzone.analysis_derived_yearly_growth
  CLUSTER BY company_id, yyyymm
AS
WITH
  lagged AS (
    SELECT
      *,
      LAG(yyyymm) OVER w AS prev_yyyymm,
      LAG(yyyymm, 3) OVER w AS yyyymm_3y_back,
      LAG(yyyymm, 5) OVER w AS yyyymm_5y_back,
      LAG(operating_profit_excl_oi) OVER w AS operating_profit_excl_oi_prev_yr,
      LAG(operating_profit_excl_oi, 3)
        OVER w AS operating_profit_excl_oi_3y_back,
      LAG(operating_profit_excl_oi, 5)
        OVER w AS operating_profit_excl_oi_5y_back,
      LAG(operating_profit) OVER w AS operating_profit_prev_yr,
      LAG(operating_profit, 3) OVER w AS operating_profit_3y_back,
      LAG(operating_profit, 5) OVER w AS operating_profit_5y_back,
      LAG(pbdt) OVER w AS pbdt_prev_yr,
      LAG(pbdt, 3) OVER w AS pbdt_3y_back,
      LAG(pbdt, 5) OVER w AS pbdt_5y_back,
      LAG(profit_before_tax) OVER w AS profit_before_tax_prev_yr,
      LAG(profit_before_tax, 3) OVER w AS profit_before_tax_3y_back,
      LAG(profit_before_tax, 5) OVER w AS profit_before_tax_5y_back,
      LAG(profit_after_tax) OVER w AS profit_after_tax_prev_yr,
      LAG(profit_after_tax, 3) OVER w AS profit_after_tax_3y_back,
      LAG(profit_after_tax, 5) OVER w AS profit_after_tax_5y_back,
      LAG(earnings_per_share_calculated)
        OVER w AS earnings_per_share_calculated_prev_yr,
      LAG(earnings_per_share_calculated, 3)
        OVER w AS earnings_per_share_calculated_3y_back,
      LAG(earnings_per_share_calculated, 5)
        OVER w AS earnings_per_share_calculated_5y_back,
      LAG(adjusted_eps) OVER w AS adjusted_eps_prev_yr,
      LAG(adjusted_eps, 3) OVER w AS adjusted_eps_3y_back,
      LAG(adjusted_eps, 5) OVER w AS adjusted_eps_5y_back,
      LAG(eps_basic_reported) OVER w AS eps_basic_reported_prev_yr,
      LAG(eps_basic_reported, 3) OVER w AS eps_basic_reported_3y_back,
      LAG(eps_basic_reported, 5) OVER w AS eps_basic_reported_5y_back,
      LAG(eps_diluted_reported) OVER w AS eps_diluted_reported_prev_yr,
      LAG(eps_diluted_reported, 3) OVER w AS eps_diluted_reported_3y_back,
      LAG(eps_diluted_reported, 5) OVER w AS eps_diluted_reported_5y_back
    FROM silverzone.combined_profit_and_loss_derived_quarterly_merged
    WINDOW w AS (PARTITION BY company_id, flag ORDER BY yyyymm)
  )
SELECT
  company_id,
  company_name,
  sector,
  subsector,
  flag,
  yyyymm,
  value_basis,
  prev_yyyymm,
  yyyymm_3y_back,
  yyyymm_5y_back,
  operating_profit_excl_oi,
  operating_profit_excl_oi_prev_yr,
  (operating_profit_excl_oi - operating_profit_excl_oi_prev_yr)
    / ABS(NULLIF(operating_profit_excl_oi_prev_yr, 0))
    * 100
    AS operating_profit_excl_oi_yoy_pct,
  operating_profit_excl_oi_3y_back,
  IF(
    operating_profit_excl_oi > 0
      AND operating_profit_excl_oi_3y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        operating_profit_excl_oi / operating_profit_excl_oi_3y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS operating_profit_excl_oi_cagr_3y_pct,
  operating_profit_excl_oi_5y_back,
  IF(
    operating_profit_excl_oi > 0
      AND operating_profit_excl_oi_5y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_5y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        operating_profit_excl_oi / operating_profit_excl_oi_5y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_5y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS operating_profit_excl_oi_cagr_5y_pct,
  operating_profit,
  operating_profit_prev_yr,
  (operating_profit - operating_profit_prev_yr)
    / ABS(NULLIF(operating_profit_prev_yr, 0))
    * 100
    AS operating_profit_yoy_pct,
  operating_profit_3y_back,
  IF(
    operating_profit > 0
      AND operating_profit_3y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        operating_profit / operating_profit_3y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS operating_profit_cagr_3y_pct,
  operating_profit_5y_back,
  IF(
    operating_profit > 0
      AND operating_profit_5y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_5y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        operating_profit / operating_profit_5y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_5y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS operating_profit_cagr_5y_pct,
  pbdt,
  pbdt_prev_yr,
  (pbdt - pbdt_prev_yr) / ABS(NULLIF(pbdt_prev_yr, 0)) * 100 AS pbdt_yoy_pct,
  pbdt_3y_back,
  IF(
    pbdt > 0
      AND pbdt_3y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        pbdt / pbdt_3y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS pbdt_cagr_3y_pct,
  pbdt_5y_back,
  IF(
    pbdt > 0
      AND pbdt_5y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_5y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        pbdt / pbdt_5y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_5y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS pbdt_cagr_5y_pct,
  profit_before_tax,
  profit_before_tax_prev_yr,
  (profit_before_tax - profit_before_tax_prev_yr)
    / ABS(NULLIF(profit_before_tax_prev_yr, 0))
    * 100
    AS profit_before_tax_yoy_pct,
  profit_before_tax_3y_back,
  IF(
    profit_before_tax > 0
      AND profit_before_tax_3y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        profit_before_tax / profit_before_tax_3y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS profit_before_tax_cagr_3y_pct,
  profit_before_tax_5y_back,
  IF(
    profit_before_tax > 0
      AND profit_before_tax_5y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_5y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        profit_before_tax / profit_before_tax_5y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_5y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS profit_before_tax_cagr_5y_pct,
  profit_after_tax,
  profit_after_tax_prev_yr,
  (profit_after_tax - profit_after_tax_prev_yr)
    / ABS(NULLIF(profit_after_tax_prev_yr, 0))
    * 100
    AS profit_after_tax_yoy_pct,
  profit_after_tax_3y_back,
  IF(
    profit_after_tax > 0
      AND profit_after_tax_3y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        profit_after_tax / profit_after_tax_3y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS profit_after_tax_cagr_3y_pct,
  profit_after_tax_5y_back,
  IF(
    profit_after_tax > 0
      AND profit_after_tax_5y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_5y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        profit_after_tax / profit_after_tax_5y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_5y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS profit_after_tax_cagr_5y_pct,
  earnings_per_share_calculated,
  earnings_per_share_calculated_prev_yr,
  (earnings_per_share_calculated - earnings_per_share_calculated_prev_yr)
    / ABS(NULLIF(earnings_per_share_calculated_prev_yr, 0))
    * 100
    AS earnings_per_share_calculated_yoy_pct,
  earnings_per_share_calculated_3y_back,
  IF(
    earnings_per_share_calculated > 0
      AND earnings_per_share_calculated_3y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        earnings_per_share_calculated / earnings_per_share_calculated_3y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS earnings_per_share_calculated_cagr_3y_pct,
  earnings_per_share_calculated_5y_back,
  IF(
    earnings_per_share_calculated > 0
      AND earnings_per_share_calculated_5y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        earnings_per_share_calculated / earnings_per_share_calculated_5y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_5y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS earnings_per_share_calculated_cagr_5y_pct,
  adjusted_eps,
  adjusted_eps_prev_yr,
  (adjusted_eps - adjusted_eps_prev_yr)
    / ABS(NULLIF(adjusted_eps_prev_yr, 0))
    * 100
    AS adjusted_eps_yoy_pct,
  adjusted_eps_3y_back,
  IF(
    adjusted_eps > 0
      AND adjusted_eps_3y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        adjusted_eps / adjusted_eps_3y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS adjusted_eps_cagr_3y_pct,
  adjusted_eps_5y_back,
  IF(
    adjusted_eps > 0
      AND adjusted_eps_5y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_5y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        adjusted_eps / adjusted_eps_5y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_5y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS adjusted_eps_cagr_5y_pct,
  eps_basic_reported,
  eps_basic_reported_prev_yr,
  (eps_basic_reported - eps_basic_reported_prev_yr)
    / ABS(NULLIF(eps_basic_reported_prev_yr, 0))
    * 100
    AS eps_basic_reported_yoy_pct,
  eps_basic_reported_3y_back,
  IF(
    eps_basic_reported > 0
      AND eps_basic_reported_3y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        eps_basic_reported / eps_basic_reported_3y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS eps_basic_reported_cagr_3y_pct,
  eps_basic_reported_5y_back,
  IF(
    eps_basic_reported > 0
      AND eps_basic_reported_5y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_5y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        eps_basic_reported / eps_basic_reported_5y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_5y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS eps_basic_reported_cagr_5y_pct,
  eps_diluted_reported,
  eps_diluted_reported_prev_yr,
  (eps_diluted_reported - eps_diluted_reported_prev_yr)
    / ABS(NULLIF(eps_diluted_reported_prev_yr, 0))
    * 100
    AS eps_diluted_reported_yoy_pct,
  eps_diluted_reported_3y_back,
  IF(
    eps_diluted_reported > 0
      AND eps_diluted_reported_3y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        eps_diluted_reported / eps_diluted_reported_3y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS eps_diluted_reported_cagr_3y_pct,
  eps_diluted_reported_5y_back,
  IF(
    eps_diluted_reported > 0
      AND eps_diluted_reported_5y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_5y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        eps_diluted_reported / eps_diluted_reported_5y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_5y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS eps_diluted_reported_cagr_5y_pct
FROM lagged;

END
