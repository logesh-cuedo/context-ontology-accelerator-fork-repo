-- Routine: silverzone.refresh_analysis_financial_ratios_yearly_change
-- Source: capable-code-486208-j8.silverzone

BEGIN
CREATE OR REPLACE TABLE silverzone.analysis_financial_ratios_yearly_change
  CLUSTER BY company_id, yyyymm
AS
WITH
  lagged AS (
    SELECT
      company_id,
      company_name,
      sector,
      subsector,
      flag_yearly AS flag,
      yyyymm,
      highlights_roce,
      highlights_ronw,
      highlights_debt_to_equity,
      ratios_roe,
      ratios_roce,
      interest_cover_x,
      ratios_roa,
      ratios_pbidtm,
      ratios_ebitm,
      ebit_growth,
      ratios_total_debt_equity,
      ratios_patm,
      cash_profit,
      pbit,
      net_worth,
      capital_employed,
      LAG(yyyymm) OVER w AS prev_yyyymm,
      LAG(highlights_roce) OVER w AS highlights_roce_prev_yr,
      LAG(highlights_ronw) OVER w AS highlights_ronw_prev_yr,
      LAG(highlights_debt_to_equity)
        OVER w AS highlights_debt_to_equity_prev_yr,
      LAG(ratios_roe) OVER w AS ratios_roe_prev_yr,
      LAG(ratios_roce) OVER w AS ratios_roce_prev_yr,
      LAG(interest_cover_x) OVER w AS interest_cover_x_prev_yr,
      LAG(ratios_roa) OVER w AS ratios_roa_prev_yr,
      LAG(ratios_pbidtm) OVER w AS ratios_pbidtm_prev_yr,
      LAG(ratios_ebitm) OVER w AS ratios_ebitm_prev_yr,
      LAG(ebit_growth) OVER w AS ebit_growth_prev_yr,
      LAG(ratios_total_debt_equity) OVER w AS ratios_total_debt_equity_prev_yr,
      LAG(ratios_patm) OVER w AS ratios_patm_prev_yr,
      LAG(cash_profit) OVER w AS cash_profit_prev_yr,
      LAG(pbit) OVER w AS pbit_prev_yr,
      LAG(net_worth) OVER w AS net_worth_prev_yr,
      LAG(capital_employed) OVER w AS capital_employed_prev_yr
    FROM silverzone.finance_metrics_financial_ratios_yearly
    WINDOW w AS (PARTITION BY company_id, flag_yearly ORDER BY yyyymm)
  )
SELECT
  company_id,
  company_name,
  sector,
  subsector,
  flag,
  yyyymm,
  prev_yyyymm,
  highlights_roce,
  highlights_roce_prev_yr,
  highlights_roce - highlights_roce_prev_yr AS highlights_roce_yoy_chg,
  highlights_ronw,
  highlights_ronw_prev_yr,
  highlights_ronw - highlights_ronw_prev_yr AS highlights_ronw_yoy_chg,
  highlights_debt_to_equity,
  highlights_debt_to_equity_prev_yr,
  highlights_debt_to_equity - highlights_debt_to_equity_prev_yr
    AS highlights_debt_to_equity_yoy_chg,
  ratios_roe,
  ratios_roe_prev_yr,
  ratios_roe - ratios_roe_prev_yr AS ratios_roe_yoy_chg,
  ratios_roce,
  ratios_roce_prev_yr,
  ratios_roce - ratios_roce_prev_yr AS ratios_roce_yoy_chg,
  interest_cover_x,
  interest_cover_x_prev_yr,
  interest_cover_x - interest_cover_x_prev_yr AS interest_cover_x_yoy_chg,
  ratios_roa,
  ratios_roa_prev_yr,
  ratios_roa - ratios_roa_prev_yr AS ratios_roa_yoy_chg,
  ratios_pbidtm,
  ratios_pbidtm_prev_yr,
  ratios_pbidtm - ratios_pbidtm_prev_yr AS ratios_pbidtm_yoy_chg,
  ratios_ebitm,
  ratios_ebitm_prev_yr,
  ratios_ebitm - ratios_ebitm_prev_yr AS ratios_ebitm_yoy_chg,
  ebit_growth,
  ebit_growth_prev_yr,
  ebit_growth - ebit_growth_prev_yr AS ebit_growth_yoy_chg,
  ratios_total_debt_equity,
  ratios_total_debt_equity_prev_yr,
  ratios_total_debt_equity - ratios_total_debt_equity_prev_yr
    AS ratios_total_debt_equity_yoy_chg,
  ratios_patm,
  ratios_patm_prev_yr,
  ratios_patm - ratios_patm_prev_yr AS ratios_patm_yoy_chg,
  cash_profit,
  cash_profit_prev_yr,
  (cash_profit - cash_profit_prev_yr)
    / ABS(NULLIF(cash_profit_prev_yr, 0))
    * 100
    AS cash_profit_yoy_pct,
  pbit,
  pbit_prev_yr,
  (pbit - pbit_prev_yr) / ABS(NULLIF(pbit_prev_yr, 0)) * 100 AS pbit_yoy_pct,
  net_worth,
  net_worth_prev_yr,
  (net_worth - net_worth_prev_yr) / ABS(NULLIF(net_worth_prev_yr, 0)) * 100
    AS net_worth_yoy_pct,
  capital_employed,
  capital_employed_prev_yr,
  (capital_employed - capital_employed_prev_yr)
    / ABS(NULLIF(capital_employed_prev_yr, 0))
    * 100
    AS capital_employed_yoy_pct
FROM lagged;

END
