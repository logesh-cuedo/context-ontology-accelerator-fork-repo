-- Routine: silverzone.refresh_analysis_income_yearly_growth
-- Source: capable-code-486208-j8.silverzone

BEGIN
CREATE OR REPLACE TABLE silverzone.analysis_income_yearly_growth
  CLUSTER BY company_id, yyyymm
AS
WITH
  lagged AS (
    SELECT
      *,
      LAG(yyyymm) OVER w AS prev_yyyymm,
      LAG(yyyymm, 3) OVER w AS yyyymm_3y_back,
      LAG(yyyymm, 5) OVER w AS yyyymm_5y_back,
      LAG(gross_sales) OVER w AS gross_sales_prev_yr,
      LAG(gross_sales, 3) OVER w AS gross_sales_3y_back,
      LAG(gross_sales, 5) OVER w AS gross_sales_5y_back,
      LAG(less_inter_divisional_transfers)
        OVER w AS less_inter_divisional_transfers_prev_yr,
      LAG(less_inter_divisional_transfers, 3)
        OVER w AS less_inter_divisional_transfers_3y_back,
      LAG(less_inter_divisional_transfers, 5)
        OVER w AS less_inter_divisional_transfers_5y_back,
      LAG(less_sales_returns) OVER w AS less_sales_returns_prev_yr,
      LAG(less_sales_returns, 3) OVER w AS less_sales_returns_3y_back,
      LAG(less_sales_returns, 5) OVER w AS less_sales_returns_5y_back,
      LAG(less_excise_gst) OVER w AS less_excise_gst_prev_yr,
      LAG(less_excise_gst, 3) OVER w AS less_excise_gst_3y_back,
      LAG(less_excise_gst, 5) OVER w AS less_excise_gst_5y_back,
      LAG(less_excise_duty) OVER w AS less_excise_duty_prev_yr,
      LAG(less_excise_duty, 3) OVER w AS less_excise_duty_3y_back,
      LAG(less_excise_duty, 5) OVER w AS less_excise_duty_5y_back,
      LAG(net_sales) OVER w AS net_sales_prev_yr,
      LAG(net_sales, 3) OVER w AS net_sales_3y_back,
      LAG(net_sales, 5) OVER w AS net_sales_5y_back
    FROM silverzone.combined_profit_and_loss_income_quarterly_merged
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
  gross_sales,
  gross_sales_prev_yr,
  (gross_sales - gross_sales_prev_yr)
    / ABS(NULLIF(gross_sales_prev_yr, 0))
    * 100
    AS gross_sales_yoy_pct,
  gross_sales_3y_back,
  IF(
    gross_sales > 0
      AND gross_sales_3y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        gross_sales / gross_sales_3y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS gross_sales_cagr_3y_pct,
  gross_sales_5y_back,
  IF(
    gross_sales > 0
      AND gross_sales_5y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_5y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        gross_sales / gross_sales_5y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_5y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS gross_sales_cagr_5y_pct,
  less_inter_divisional_transfers,
  less_inter_divisional_transfers_prev_yr,
  (less_inter_divisional_transfers - less_inter_divisional_transfers_prev_yr)
    / ABS(NULLIF(less_inter_divisional_transfers_prev_yr, 0))
    * 100
    AS less_inter_divisional_transfers_yoy_pct,
  less_inter_divisional_transfers_3y_back,
  IF(
    less_inter_divisional_transfers > 0
      AND less_inter_divisional_transfers_3y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        less_inter_divisional_transfers
          / less_inter_divisional_transfers_3y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS less_inter_divisional_transfers_cagr_3y_pct,
  less_inter_divisional_transfers_5y_back,
  IF(
    less_inter_divisional_transfers > 0
      AND less_inter_divisional_transfers_5y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_5y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        less_inter_divisional_transfers
          / less_inter_divisional_transfers_5y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_5y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS less_inter_divisional_transfers_cagr_5y_pct,
  less_sales_returns,
  less_sales_returns_prev_yr,
  (less_sales_returns - less_sales_returns_prev_yr)
    / ABS(NULLIF(less_sales_returns_prev_yr, 0))
    * 100
    AS less_sales_returns_yoy_pct,
  less_sales_returns_3y_back,
  IF(
    less_sales_returns > 0
      AND less_sales_returns_3y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        less_sales_returns / less_sales_returns_3y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS less_sales_returns_cagr_3y_pct,
  less_sales_returns_5y_back,
  IF(
    less_sales_returns > 0
      AND less_sales_returns_5y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_5y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        less_sales_returns / less_sales_returns_5y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_5y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS less_sales_returns_cagr_5y_pct,
  less_excise_gst,
  less_excise_gst_prev_yr,
  (less_excise_gst - less_excise_gst_prev_yr)
    / ABS(NULLIF(less_excise_gst_prev_yr, 0))
    * 100
    AS less_excise_gst_yoy_pct,
  less_excise_gst_3y_back,
  IF(
    less_excise_gst > 0
      AND less_excise_gst_3y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        less_excise_gst / less_excise_gst_3y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS less_excise_gst_cagr_3y_pct,
  less_excise_gst_5y_back,
  IF(
    less_excise_gst > 0
      AND less_excise_gst_5y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_5y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        less_excise_gst / less_excise_gst_5y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_5y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS less_excise_gst_cagr_5y_pct,
  less_excise_duty,
  less_excise_duty_prev_yr,
  (less_excise_duty - less_excise_duty_prev_yr)
    / ABS(NULLIF(less_excise_duty_prev_yr, 0))
    * 100
    AS less_excise_duty_yoy_pct,
  less_excise_duty_3y_back,
  IF(
    less_excise_duty > 0
      AND less_excise_duty_3y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        less_excise_duty / less_excise_duty_3y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS less_excise_duty_cagr_3y_pct,
  less_excise_duty_5y_back,
  IF(
    less_excise_duty > 0
      AND less_excise_duty_5y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_5y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        less_excise_duty / less_excise_duty_5y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_5y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS less_excise_duty_cagr_5y_pct,
  net_sales,
  net_sales_prev_yr,
  (net_sales - net_sales_prev_yr) / ABS(NULLIF(net_sales_prev_yr, 0)) * 100
    AS net_sales_yoy_pct,
  net_sales_3y_back,
  IF(
    net_sales > 0
      AND net_sales_3y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        net_sales / net_sales_3y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS net_sales_cagr_3y_pct,
  net_sales_5y_back,
  IF(
    net_sales > 0
      AND net_sales_5y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_5y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        net_sales / net_sales_5y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_5y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS net_sales_cagr_5y_pct
FROM lagged;

END
