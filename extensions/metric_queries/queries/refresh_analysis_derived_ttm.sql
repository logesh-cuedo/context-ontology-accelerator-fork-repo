-- Routine: silverzone.refresh_analysis_derived_ttm
-- Source: capable-code-486208-j8.silverzone

BEGIN
CREATE OR REPLACE TABLE silverzone.analysis_derived_ttm
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
  operating_profit_excl_oi,
  SUM(operating_profit_excl_oi) OVER w AS operating_profit_excl_oi_ttm,
  operating_profit,
  SUM(operating_profit) OVER w AS operating_profit_ttm,
  pbdt,
  SUM(pbdt) OVER w AS pbdt_ttm,
  profit_before_tax,
  SUM(profit_before_tax) OVER w AS profit_before_tax_ttm,
  profit_after_tax,
  SUM(profit_after_tax) OVER w AS profit_after_tax_ttm,
  earnings_per_share_calculated,
  SUM(earnings_per_share_calculated)
    OVER w AS earnings_per_share_calculated_ttm,
  adjusted_eps,
  SUM(adjusted_eps) OVER w AS adjusted_eps_ttm,
  eps_basic_reported,
  SUM(eps_basic_reported) OVER w AS eps_basic_reported_ttm,
  eps_diluted_reported,
  SUM(eps_diluted_reported) OVER w AS eps_diluted_reported_ttm
FROM silverzone.combined_profit_and_loss_derived_quarterly
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
