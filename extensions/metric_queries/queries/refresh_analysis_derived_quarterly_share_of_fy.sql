-- Routine: silverzone.refresh_analysis_derived_quarterly_share_of_fy
-- Source: capable-code-486208-j8.silverzone

BEGIN
CREATE OR REPLACE TABLE silverzone.analysis_derived_quarterly_share_of_fy
  CLUSTER BY company_id, yyyymm
AS
WITH
  q AS (
    SELECT *, DIV(yyyymm, 100) + IF(MOD(yyyymm, 100) >= 4, 1, 0) AS fiscal_year
    FROM silverzone.combined_profit_and_loss_derived_quarterly
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
  operating_profit_excl_oi,
  SUM(operating_profit_excl_oi) OVER fy AS operating_profit_excl_oi_fy_total,
  IF(
    ABS(SUM(operating_profit_excl_oi) OVER fy) < 1e-6,
    NULL,
    operating_profit_excl_oi / SUM(operating_profit_excl_oi) OVER fy * 100)
    AS operating_profit_excl_oi_pct_of_fy,
  operating_profit,
  SUM(operating_profit) OVER fy AS operating_profit_fy_total,
  IF(
    ABS(SUM(operating_profit) OVER fy) < 1e-6,
    NULL,
    operating_profit / SUM(operating_profit) OVER fy * 100)
    AS operating_profit_pct_of_fy,
  pbdt,
  SUM(pbdt) OVER fy AS pbdt_fy_total,
  IF(ABS(SUM(pbdt) OVER fy) < 1e-6, NULL, pbdt / SUM(pbdt) OVER fy * 100)
    AS pbdt_pct_of_fy,
  profit_before_tax,
  SUM(profit_before_tax) OVER fy AS profit_before_tax_fy_total,
  IF(
    ABS(SUM(profit_before_tax) OVER fy) < 1e-6,
    NULL,
    profit_before_tax / SUM(profit_before_tax) OVER fy * 100)
    AS profit_before_tax_pct_of_fy,
  profit_after_tax,
  SUM(profit_after_tax) OVER fy AS profit_after_tax_fy_total,
  IF(
    ABS(SUM(profit_after_tax) OVER fy) < 1e-6,
    NULL,
    profit_after_tax / SUM(profit_after_tax) OVER fy * 100)
    AS profit_after_tax_pct_of_fy,
  earnings_per_share_calculated,
  SUM(earnings_per_share_calculated)
    OVER fy AS earnings_per_share_calculated_fy_total,
  IF(
    ABS(SUM(earnings_per_share_calculated) OVER fy) < 1e-6,
    NULL,
    earnings_per_share_calculated
      / SUM(earnings_per_share_calculated) OVER fy
      * 100)
    AS earnings_per_share_calculated_pct_of_fy,
  adjusted_eps,
  SUM(adjusted_eps) OVER fy AS adjusted_eps_fy_total,
  IF(
    ABS(SUM(adjusted_eps) OVER fy) < 1e-6,
    NULL,
    adjusted_eps / SUM(adjusted_eps) OVER fy * 100)
    AS adjusted_eps_pct_of_fy,
  eps_basic_reported,
  SUM(eps_basic_reported) OVER fy AS eps_basic_reported_fy_total,
  IF(
    ABS(SUM(eps_basic_reported) OVER fy) < 1e-6,
    NULL,
    eps_basic_reported / SUM(eps_basic_reported) OVER fy * 100)
    AS eps_basic_reported_pct_of_fy,
  eps_diluted_reported,
  SUM(eps_diluted_reported) OVER fy AS eps_diluted_reported_fy_total,
  IF(
    ABS(SUM(eps_diluted_reported) OVER fy) < 1e-6,
    NULL,
    eps_diluted_reported / SUM(eps_diluted_reported) OVER fy * 100)
    AS eps_diluted_reported_pct_of_fy
FROM q
QUALIFY COUNT(*) OVER fy = 4
WINDOW fy AS (PARTITION BY company_id, flag, fiscal_year);

END
