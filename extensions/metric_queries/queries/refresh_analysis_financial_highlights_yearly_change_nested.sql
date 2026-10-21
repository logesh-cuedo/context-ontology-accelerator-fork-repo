-- Routine: silverzone.refresh_analysis_financial_highlights_yearly_change_nested
-- Source: capable-code-486208-j8.silverzone

BEGIN
-- silverzone.analysis_financial_highlights_yearly_change_nested
-- Full nested yearly-change table generated from silverzone.financial_highlights_nested schema.
-- Absolute financial-highlight leaves use percent growth; ratio-like leaves use point change.
-- Each metric leaf is emitted as STRUCT(value, prev_yr, yoy_chg) for point-change
-- metrics or STRUCT(value, prev_yr, yoy_pct) for absolute-value growth metrics.
CREATE OR REPLACE TABLE silverzone.analysis_financial_highlights_yearly_change_nested
CLUSTER BY company_id, yyyymm AS
WITH base AS (
  SELECT
    company_id,
    company_name,
    yyyymm,
    financial_highlights.inc_exp_performance.value AS inc_exp_performance__value,
    financial_highlights.inc_exp_performance.gross_sales AS inc_exp_performance__gross_sales,
    financial_highlights.inc_exp_performance.total_income AS inc_exp_performance__total_income,
    financial_highlights.inc_exp_performance.total_expenditure AS inc_exp_performance__total_expenditure,
    financial_highlights.inc_exp_performance.gross_profit AS inc_exp_performance__gross_profit,
    financial_highlights.inc_exp_performance.pbidt AS inc_exp_performance__pbidt,
    financial_highlights.inc_exp_performance.pbit AS inc_exp_performance__pbit,
    financial_highlights.inc_exp_performance.pbt AS inc_exp_performance__pbt,
    financial_highlights.inc_exp_performance.pat AS inc_exp_performance__pat,
    financial_highlights.inc_exp_performance.cash_profit AS inc_exp_performance__cash_profit,
    financial_highlights.sources_of_funds.value AS sources_of_funds__value,
    financial_highlights.sources_of_funds.equity_paid_up AS sources_of_funds__equity_paid_up,
    financial_highlights.sources_of_funds.reserves_and_surplus AS sources_of_funds__reserves_and_surplus,
    financial_highlights.sources_of_funds.net_worth AS sources_of_funds__net_worth,
    financial_highlights.sources_of_funds.total_debt AS sources_of_funds__total_debt,
    financial_highlights.sources_of_funds.capital_employed AS sources_of_funds__capital_employed,
    financial_highlights.application_of_funds.value AS application_of_funds__value,
    financial_highlights.application_of_funds.gross_block AS application_of_funds__gross_block,
    financial_highlights.application_of_funds.investments AS application_of_funds__investments,
    financial_highlights.application_of_funds.cash_and_bank_balance AS application_of_funds__cash_and_bank_balance,
    financial_highlights.application_of_funds.net_current_assets AS application_of_funds__net_current_assets,
    financial_highlights.application_of_funds.total_current_liabilities AS application_of_funds__total_current_liabilities,
    financial_highlights.application_of_funds.total_assets AS application_of_funds__total_assets,
    financial_highlights.cash_flow.value AS cash_flow__value,
    financial_highlights.cash_flow.cash_flow_from_operations AS cash_flow__cash_flow_from_operations,
    financial_highlights.cash_flow.cash_flow_from_investing_activities AS cash_flow__cash_flow_from_investing_activities,
    financial_highlights.cash_flow.cash_flow_from_finance_activities AS cash_flow__cash_flow_from_finance_activities,
    financial_highlights.cash_flow.free_cash_flow AS cash_flow__free_cash_flow,
    financial_highlights.key_ratios.value AS key_ratios__value,
    financial_highlights.key_ratios.debt_to_equity_x AS key_ratios__debt_to_equity_x,
    financial_highlights.key_ratios.current_ratio_x AS key_ratios__current_ratio_x,
    financial_highlights.key_ratios.roce AS key_ratios__roce,
    financial_highlights.key_ratios.ronw AS key_ratios__ronw,
    financial_highlights.key_ratios.gpm AS key_ratios__gpm,
    financial_highlights.key_ratios.pbidtm AS key_ratios__pbidtm,
    financial_highlights.key_ratios.patm AS key_ratios__patm,
    financial_highlights.key_ratios.cpm AS key_ratios__cpm,
    financial_highlights.market_cues.value AS market_cues__value,
    financial_highlights.market_cues.close_price_unit_curr AS market_cues__close_price_unit_curr,
    financial_highlights.market_cues.high_price_unit_curr AS market_cues__high_price_unit_curr,
    financial_highlights.market_cues.low_price_unit_curr AS market_cues__low_price_unit_curr,
    financial_highlights.market_capitalization.value AS market_capitalization__value,
    financial_highlights.market_capitalization.adjusted_eps AS market_capitalization__adjusted_eps,
    financial_highlights.market_capitalization.price_book_value_x AS market_capitalization__price_book_value_x,
    financial_highlights.market_capitalization.ceps AS market_capitalization__ceps,
    financial_highlights.market_capitalization.equity_dividend AS market_capitalization__equity_dividend,
    financial_highlights.market_capitalization.enterprise_value AS market_capitalization__enterprise_value,
    financial_highlights.market_capitalization.dividend_yield AS market_capitalization__dividend_yield,
    financial_highlights.market_capitalization.pe_x AS market_capitalization__pe_x
  FROM silverzone.financial_highlights_nested
),
lagged AS (
  SELECT
    *,
    LAG(yyyymm) OVER w AS prev_yyyymm,
    LAG(inc_exp_performance__value) OVER w AS inc_exp_performance__value_prev_yr,
    LAG(inc_exp_performance__gross_sales) OVER w AS inc_exp_performance__gross_sales_prev_yr,
    LAG(inc_exp_performance__total_income) OVER w AS inc_exp_performance__total_income_prev_yr,
    LAG(inc_exp_performance__total_expenditure) OVER w AS inc_exp_performance__total_expenditure_prev_yr,
    LAG(inc_exp_performance__gross_profit) OVER w AS inc_exp_performance__gross_profit_prev_yr,
    LAG(inc_exp_performance__pbidt) OVER w AS inc_exp_performance__pbidt_prev_yr,
    LAG(inc_exp_performance__pbit) OVER w AS inc_exp_performance__pbit_prev_yr,
    LAG(inc_exp_performance__pbt) OVER w AS inc_exp_performance__pbt_prev_yr,
    LAG(inc_exp_performance__pat) OVER w AS inc_exp_performance__pat_prev_yr,
    LAG(inc_exp_performance__cash_profit) OVER w AS inc_exp_performance__cash_profit_prev_yr,
    LAG(sources_of_funds__value) OVER w AS sources_of_funds__value_prev_yr,
    LAG(sources_of_funds__equity_paid_up) OVER w AS sources_of_funds__equity_paid_up_prev_yr,
    LAG(sources_of_funds__reserves_and_surplus) OVER w AS sources_of_funds__reserves_and_surplus_prev_yr,
    LAG(sources_of_funds__net_worth) OVER w AS sources_of_funds__net_worth_prev_yr,
    LAG(sources_of_funds__total_debt) OVER w AS sources_of_funds__total_debt_prev_yr,
    LAG(sources_of_funds__capital_employed) OVER w AS sources_of_funds__capital_employed_prev_yr,
    LAG(application_of_funds__value) OVER w AS application_of_funds__value_prev_yr,
    LAG(application_of_funds__gross_block) OVER w AS application_of_funds__gross_block_prev_yr,
    LAG(application_of_funds__investments) OVER w AS application_of_funds__investments_prev_yr,
    LAG(application_of_funds__cash_and_bank_balance) OVER w AS application_of_funds__cash_and_bank_balance_prev_yr,
    LAG(application_of_funds__net_current_assets) OVER w AS application_of_funds__net_current_assets_prev_yr,
    LAG(application_of_funds__total_current_liabilities) OVER w AS application_of_funds__total_current_liabilities_prev_yr,
    LAG(application_of_funds__total_assets) OVER w AS application_of_funds__total_assets_prev_yr,
    LAG(cash_flow__value) OVER w AS cash_flow__value_prev_yr,
    LAG(cash_flow__cash_flow_from_operations) OVER w AS cash_flow__cash_flow_from_operations_prev_yr,
    LAG(cash_flow__cash_flow_from_investing_activities) OVER w AS cash_flow__cash_flow_from_investing_activities_prev_yr,
    LAG(cash_flow__cash_flow_from_finance_activities) OVER w AS cash_flow__cash_flow_from_finance_activities_prev_yr,
    LAG(cash_flow__free_cash_flow) OVER w AS cash_flow__free_cash_flow_prev_yr,
    LAG(key_ratios__value) OVER w AS key_ratios__value_prev_yr,
    LAG(key_ratios__debt_to_equity_x) OVER w AS key_ratios__debt_to_equity_x_prev_yr,
    LAG(key_ratios__current_ratio_x) OVER w AS key_ratios__current_ratio_x_prev_yr,
    LAG(key_ratios__roce) OVER w AS key_ratios__roce_prev_yr,
    LAG(key_ratios__ronw) OVER w AS key_ratios__ronw_prev_yr,
    LAG(key_ratios__gpm) OVER w AS key_ratios__gpm_prev_yr,
    LAG(key_ratios__pbidtm) OVER w AS key_ratios__pbidtm_prev_yr,
    LAG(key_ratios__patm) OVER w AS key_ratios__patm_prev_yr,
    LAG(key_ratios__cpm) OVER w AS key_ratios__cpm_prev_yr,
    LAG(market_cues__value) OVER w AS market_cues__value_prev_yr,
    LAG(market_cues__close_price_unit_curr) OVER w AS market_cues__close_price_unit_curr_prev_yr,
    LAG(market_cues__high_price_unit_curr) OVER w AS market_cues__high_price_unit_curr_prev_yr,
    LAG(market_cues__low_price_unit_curr) OVER w AS market_cues__low_price_unit_curr_prev_yr,
    LAG(market_capitalization__value) OVER w AS market_capitalization__value_prev_yr,
    LAG(market_capitalization__adjusted_eps) OVER w AS market_capitalization__adjusted_eps_prev_yr,
    LAG(market_capitalization__price_book_value_x) OVER w AS market_capitalization__price_book_value_x_prev_yr,
    LAG(market_capitalization__ceps) OVER w AS market_capitalization__ceps_prev_yr,
    LAG(market_capitalization__equity_dividend) OVER w AS market_capitalization__equity_dividend_prev_yr,
    LAG(market_capitalization__enterprise_value) OVER w AS market_capitalization__enterprise_value_prev_yr,
    LAG(market_capitalization__dividend_yield) OVER w AS market_capitalization__dividend_yield_prev_yr,
    LAG(market_capitalization__pe_x) OVER w AS market_capitalization__pe_x_prev_yr
  FROM base
  WINDOW w AS (PARTITION BY company_id ORDER BY yyyymm)
)
SELECT
  l.company_id,
  l.company_name,
  l.yyyymm,
  l.prev_yyyymm,
  STRUCT(
    STRUCT(
      STRUCT(
        l.inc_exp_performance__value AS value,
        l.inc_exp_performance__value_prev_yr AS prev_yr,
        (l.inc_exp_performance__value - l.inc_exp_performance__value_prev_yr) / ABS(NULLIF(l.inc_exp_performance__value_prev_yr, 0)) * 100 AS yoy_pct
      ) AS value,
      STRUCT(
        l.inc_exp_performance__gross_sales AS value,
        l.inc_exp_performance__gross_sales_prev_yr AS prev_yr,
        (l.inc_exp_performance__gross_sales - l.inc_exp_performance__gross_sales_prev_yr) / ABS(NULLIF(l.inc_exp_performance__gross_sales_prev_yr, 0)) * 100 AS yoy_pct
      ) AS gross_sales,
      STRUCT(
        l.inc_exp_performance__total_income AS value,
        l.inc_exp_performance__total_income_prev_yr AS prev_yr,
        (l.inc_exp_performance__total_income - l.inc_exp_performance__total_income_prev_yr) / ABS(NULLIF(l.inc_exp_performance__total_income_prev_yr, 0)) * 100 AS yoy_pct
      ) AS total_income,
      STRUCT(
        l.inc_exp_performance__total_expenditure AS value,
        l.inc_exp_performance__total_expenditure_prev_yr AS prev_yr,
        (l.inc_exp_performance__total_expenditure - l.inc_exp_performance__total_expenditure_prev_yr) / ABS(NULLIF(l.inc_exp_performance__total_expenditure_prev_yr, 0)) * 100 AS yoy_pct
      ) AS total_expenditure,
      STRUCT(
        l.inc_exp_performance__gross_profit AS value,
        l.inc_exp_performance__gross_profit_prev_yr AS prev_yr,
        (l.inc_exp_performance__gross_profit - l.inc_exp_performance__gross_profit_prev_yr) / ABS(NULLIF(l.inc_exp_performance__gross_profit_prev_yr, 0)) * 100 AS yoy_pct
      ) AS gross_profit,
      STRUCT(
        l.inc_exp_performance__pbidt AS value,
        l.inc_exp_performance__pbidt_prev_yr AS prev_yr,
        (l.inc_exp_performance__pbidt - l.inc_exp_performance__pbidt_prev_yr) / ABS(NULLIF(l.inc_exp_performance__pbidt_prev_yr, 0)) * 100 AS yoy_pct
      ) AS pbidt,
      STRUCT(
        l.inc_exp_performance__pbit AS value,
        l.inc_exp_performance__pbit_prev_yr AS prev_yr,
        (l.inc_exp_performance__pbit - l.inc_exp_performance__pbit_prev_yr) / ABS(NULLIF(l.inc_exp_performance__pbit_prev_yr, 0)) * 100 AS yoy_pct
      ) AS pbit,
      STRUCT(
        l.inc_exp_performance__pbt AS value,
        l.inc_exp_performance__pbt_prev_yr AS prev_yr,
        (l.inc_exp_performance__pbt - l.inc_exp_performance__pbt_prev_yr) / ABS(NULLIF(l.inc_exp_performance__pbt_prev_yr, 0)) * 100 AS yoy_pct
      ) AS pbt,
      STRUCT(
        l.inc_exp_performance__pat AS value,
        l.inc_exp_performance__pat_prev_yr AS prev_yr,
        (l.inc_exp_performance__pat - l.inc_exp_performance__pat_prev_yr) / ABS(NULLIF(l.inc_exp_performance__pat_prev_yr, 0)) * 100 AS yoy_pct
      ) AS pat,
      STRUCT(
        l.inc_exp_performance__cash_profit AS value,
        l.inc_exp_performance__cash_profit_prev_yr AS prev_yr,
        (l.inc_exp_performance__cash_profit - l.inc_exp_performance__cash_profit_prev_yr) / ABS(NULLIF(l.inc_exp_performance__cash_profit_prev_yr, 0)) * 100 AS yoy_pct
      ) AS cash_profit
    ) AS inc_exp_performance,
    STRUCT(
      STRUCT(
        l.sources_of_funds__value AS value,
        l.sources_of_funds__value_prev_yr AS prev_yr,
        (l.sources_of_funds__value - l.sources_of_funds__value_prev_yr) / ABS(NULLIF(l.sources_of_funds__value_prev_yr, 0)) * 100 AS yoy_pct
      ) AS value,
      STRUCT(
        l.sources_of_funds__equity_paid_up AS value,
        l.sources_of_funds__equity_paid_up_prev_yr AS prev_yr,
        (l.sources_of_funds__equity_paid_up - l.sources_of_funds__equity_paid_up_prev_yr) / ABS(NULLIF(l.sources_of_funds__equity_paid_up_prev_yr, 0)) * 100 AS yoy_pct
      ) AS equity_paid_up,
      STRUCT(
        l.sources_of_funds__reserves_and_surplus AS value,
        l.sources_of_funds__reserves_and_surplus_prev_yr AS prev_yr,
        (l.sources_of_funds__reserves_and_surplus - l.sources_of_funds__reserves_and_surplus_prev_yr) / ABS(NULLIF(l.sources_of_funds__reserves_and_surplus_prev_yr, 0)) * 100 AS yoy_pct
      ) AS reserves_and_surplus,
      STRUCT(
        l.sources_of_funds__net_worth AS value,
        l.sources_of_funds__net_worth_prev_yr AS prev_yr,
        (l.sources_of_funds__net_worth - l.sources_of_funds__net_worth_prev_yr) / ABS(NULLIF(l.sources_of_funds__net_worth_prev_yr, 0)) * 100 AS yoy_pct
      ) AS net_worth,
      STRUCT(
        l.sources_of_funds__total_debt AS value,
        l.sources_of_funds__total_debt_prev_yr AS prev_yr,
        (l.sources_of_funds__total_debt - l.sources_of_funds__total_debt_prev_yr) / ABS(NULLIF(l.sources_of_funds__total_debt_prev_yr, 0)) * 100 AS yoy_pct
      ) AS total_debt,
      STRUCT(
        l.sources_of_funds__capital_employed AS value,
        l.sources_of_funds__capital_employed_prev_yr AS prev_yr,
        (l.sources_of_funds__capital_employed - l.sources_of_funds__capital_employed_prev_yr) / ABS(NULLIF(l.sources_of_funds__capital_employed_prev_yr, 0)) * 100 AS yoy_pct
      ) AS capital_employed
    ) AS sources_of_funds,
    STRUCT(
      STRUCT(
        l.application_of_funds__value AS value,
        l.application_of_funds__value_prev_yr AS prev_yr,
        (l.application_of_funds__value - l.application_of_funds__value_prev_yr) / ABS(NULLIF(l.application_of_funds__value_prev_yr, 0)) * 100 AS yoy_pct
      ) AS value,
      STRUCT(
        l.application_of_funds__gross_block AS value,
        l.application_of_funds__gross_block_prev_yr AS prev_yr,
        (l.application_of_funds__gross_block - l.application_of_funds__gross_block_prev_yr) / ABS(NULLIF(l.application_of_funds__gross_block_prev_yr, 0)) * 100 AS yoy_pct
      ) AS gross_block,
      STRUCT(
        l.application_of_funds__investments AS value,
        l.application_of_funds__investments_prev_yr AS prev_yr,
        (l.application_of_funds__investments - l.application_of_funds__investments_prev_yr) / ABS(NULLIF(l.application_of_funds__investments_prev_yr, 0)) * 100 AS yoy_pct
      ) AS investments,
      STRUCT(
        l.application_of_funds__cash_and_bank_balance AS value,
        l.application_of_funds__cash_and_bank_balance_prev_yr AS prev_yr,
        (l.application_of_funds__cash_and_bank_balance - l.application_of_funds__cash_and_bank_balance_prev_yr) / ABS(NULLIF(l.application_of_funds__cash_and_bank_balance_prev_yr, 0)) * 100 AS yoy_pct
      ) AS cash_and_bank_balance,
      STRUCT(
        l.application_of_funds__net_current_assets AS value,
        l.application_of_funds__net_current_assets_prev_yr AS prev_yr,
        (l.application_of_funds__net_current_assets - l.application_of_funds__net_current_assets_prev_yr) / ABS(NULLIF(l.application_of_funds__net_current_assets_prev_yr, 0)) * 100 AS yoy_pct
      ) AS net_current_assets,
      STRUCT(
        l.application_of_funds__total_current_liabilities AS value,
        l.application_of_funds__total_current_liabilities_prev_yr AS prev_yr,
        (l.application_of_funds__total_current_liabilities - l.application_of_funds__total_current_liabilities_prev_yr) / ABS(NULLIF(l.application_of_funds__total_current_liabilities_prev_yr, 0)) * 100 AS yoy_pct
      ) AS total_current_liabilities,
      STRUCT(
        l.application_of_funds__total_assets AS value,
        l.application_of_funds__total_assets_prev_yr AS prev_yr,
        (l.application_of_funds__total_assets - l.application_of_funds__total_assets_prev_yr) / ABS(NULLIF(l.application_of_funds__total_assets_prev_yr, 0)) * 100 AS yoy_pct
      ) AS total_assets
    ) AS application_of_funds,
    STRUCT(
      STRUCT(
        l.cash_flow__value AS value,
        l.cash_flow__value_prev_yr AS prev_yr,
        (l.cash_flow__value - l.cash_flow__value_prev_yr) / ABS(NULLIF(l.cash_flow__value_prev_yr, 0)) * 100 AS yoy_pct
      ) AS value,
      STRUCT(
        l.cash_flow__cash_flow_from_operations AS value,
        l.cash_flow__cash_flow_from_operations_prev_yr AS prev_yr,
        (l.cash_flow__cash_flow_from_operations - l.cash_flow__cash_flow_from_operations_prev_yr) / ABS(NULLIF(l.cash_flow__cash_flow_from_operations_prev_yr, 0)) * 100 AS yoy_pct
      ) AS cash_flow_from_operations,
      STRUCT(
        l.cash_flow__cash_flow_from_investing_activities AS value,
        l.cash_flow__cash_flow_from_investing_activities_prev_yr AS prev_yr,
        (l.cash_flow__cash_flow_from_investing_activities - l.cash_flow__cash_flow_from_investing_activities_prev_yr) / ABS(NULLIF(l.cash_flow__cash_flow_from_investing_activities_prev_yr, 0)) * 100 AS yoy_pct
      ) AS cash_flow_from_investing_activities,
      STRUCT(
        l.cash_flow__cash_flow_from_finance_activities AS value,
        l.cash_flow__cash_flow_from_finance_activities_prev_yr AS prev_yr,
        (l.cash_flow__cash_flow_from_finance_activities - l.cash_flow__cash_flow_from_finance_activities_prev_yr) / ABS(NULLIF(l.cash_flow__cash_flow_from_finance_activities_prev_yr, 0)) * 100 AS yoy_pct
      ) AS cash_flow_from_finance_activities,
      STRUCT(
        l.cash_flow__free_cash_flow AS value,
        l.cash_flow__free_cash_flow_prev_yr AS prev_yr,
        (l.cash_flow__free_cash_flow - l.cash_flow__free_cash_flow_prev_yr) / ABS(NULLIF(l.cash_flow__free_cash_flow_prev_yr, 0)) * 100 AS yoy_pct
      ) AS free_cash_flow
    ) AS cash_flow,
    STRUCT(
      STRUCT(
        l.key_ratios__value AS value,
        l.key_ratios__value_prev_yr AS prev_yr,
        l.key_ratios__value - l.key_ratios__value_prev_yr AS yoy_chg
      ) AS value,
      STRUCT(
        l.key_ratios__debt_to_equity_x AS value,
        l.key_ratios__debt_to_equity_x_prev_yr AS prev_yr,
        l.key_ratios__debt_to_equity_x - l.key_ratios__debt_to_equity_x_prev_yr AS yoy_chg
      ) AS debt_to_equity_x,
      STRUCT(
        l.key_ratios__current_ratio_x AS value,
        l.key_ratios__current_ratio_x_prev_yr AS prev_yr,
        l.key_ratios__current_ratio_x - l.key_ratios__current_ratio_x_prev_yr AS yoy_chg
      ) AS current_ratio_x,
      STRUCT(
        l.key_ratios__roce AS value,
        l.key_ratios__roce_prev_yr AS prev_yr,
        l.key_ratios__roce - l.key_ratios__roce_prev_yr AS yoy_chg
      ) AS roce,
      STRUCT(
        l.key_ratios__ronw AS value,
        l.key_ratios__ronw_prev_yr AS prev_yr,
        l.key_ratios__ronw - l.key_ratios__ronw_prev_yr AS yoy_chg
      ) AS ronw,
      STRUCT(
        l.key_ratios__gpm AS value,
        l.key_ratios__gpm_prev_yr AS prev_yr,
        l.key_ratios__gpm - l.key_ratios__gpm_prev_yr AS yoy_chg
      ) AS gpm,
      STRUCT(
        l.key_ratios__pbidtm AS value,
        l.key_ratios__pbidtm_prev_yr AS prev_yr,
        l.key_ratios__pbidtm - l.key_ratios__pbidtm_prev_yr AS yoy_chg
      ) AS pbidtm,
      STRUCT(
        l.key_ratios__patm AS value,
        l.key_ratios__patm_prev_yr AS prev_yr,
        l.key_ratios__patm - l.key_ratios__patm_prev_yr AS yoy_chg
      ) AS patm,
      STRUCT(
        l.key_ratios__cpm AS value,
        l.key_ratios__cpm_prev_yr AS prev_yr,
        l.key_ratios__cpm - l.key_ratios__cpm_prev_yr AS yoy_chg
      ) AS cpm
    ) AS key_ratios,
    STRUCT(
      STRUCT(
        l.market_cues__value AS value,
        l.market_cues__value_prev_yr AS prev_yr,
        (l.market_cues__value - l.market_cues__value_prev_yr) / ABS(NULLIF(l.market_cues__value_prev_yr, 0)) * 100 AS yoy_pct
      ) AS value,
      STRUCT(
        l.market_cues__close_price_unit_curr AS value,
        l.market_cues__close_price_unit_curr_prev_yr AS prev_yr,
        (l.market_cues__close_price_unit_curr - l.market_cues__close_price_unit_curr_prev_yr) / ABS(NULLIF(l.market_cues__close_price_unit_curr_prev_yr, 0)) * 100 AS yoy_pct
      ) AS close_price_unit_curr,
      STRUCT(
        l.market_cues__high_price_unit_curr AS value,
        l.market_cues__high_price_unit_curr_prev_yr AS prev_yr,
        (l.market_cues__high_price_unit_curr - l.market_cues__high_price_unit_curr_prev_yr) / ABS(NULLIF(l.market_cues__high_price_unit_curr_prev_yr, 0)) * 100 AS yoy_pct
      ) AS high_price_unit_curr,
      STRUCT(
        l.market_cues__low_price_unit_curr AS value,
        l.market_cues__low_price_unit_curr_prev_yr AS prev_yr,
        (l.market_cues__low_price_unit_curr - l.market_cues__low_price_unit_curr_prev_yr) / ABS(NULLIF(l.market_cues__low_price_unit_curr_prev_yr, 0)) * 100 AS yoy_pct
      ) AS low_price_unit_curr
    ) AS market_cues,
    STRUCT(
      STRUCT(
        l.market_capitalization__value AS value,
        l.market_capitalization__value_prev_yr AS prev_yr,
        (l.market_capitalization__value - l.market_capitalization__value_prev_yr) / ABS(NULLIF(l.market_capitalization__value_prev_yr, 0)) * 100 AS yoy_pct
      ) AS value,
      STRUCT(
        l.market_capitalization__adjusted_eps AS value,
        l.market_capitalization__adjusted_eps_prev_yr AS prev_yr,
        (l.market_capitalization__adjusted_eps - l.market_capitalization__adjusted_eps_prev_yr) / ABS(NULLIF(l.market_capitalization__adjusted_eps_prev_yr, 0)) * 100 AS yoy_pct
      ) AS adjusted_eps,
      STRUCT(
        l.market_capitalization__price_book_value_x AS value,
        l.market_capitalization__price_book_value_x_prev_yr AS prev_yr,
        l.market_capitalization__price_book_value_x - l.market_capitalization__price_book_value_x_prev_yr AS yoy_chg
      ) AS price_book_value_x,
      STRUCT(
        l.market_capitalization__ceps AS value,
        l.market_capitalization__ceps_prev_yr AS prev_yr,
        (l.market_capitalization__ceps - l.market_capitalization__ceps_prev_yr) / ABS(NULLIF(l.market_capitalization__ceps_prev_yr, 0)) * 100 AS yoy_pct
      ) AS ceps,
      STRUCT(
        l.market_capitalization__equity_dividend AS value,
        l.market_capitalization__equity_dividend_prev_yr AS prev_yr,
        (l.market_capitalization__equity_dividend - l.market_capitalization__equity_dividend_prev_yr) / ABS(NULLIF(l.market_capitalization__equity_dividend_prev_yr, 0)) * 100 AS yoy_pct
      ) AS equity_dividend,
      STRUCT(
        l.market_capitalization__enterprise_value AS value,
        l.market_capitalization__enterprise_value_prev_yr AS prev_yr,
        (l.market_capitalization__enterprise_value - l.market_capitalization__enterprise_value_prev_yr) / ABS(NULLIF(l.market_capitalization__enterprise_value_prev_yr, 0)) * 100 AS yoy_pct
      ) AS enterprise_value,
      STRUCT(
        l.market_capitalization__dividend_yield AS value,
        l.market_capitalization__dividend_yield_prev_yr AS prev_yr,
        l.market_capitalization__dividend_yield - l.market_capitalization__dividend_yield_prev_yr AS yoy_chg
      ) AS dividend_yield,
      STRUCT(
        l.market_capitalization__pe_x AS value,
        l.market_capitalization__pe_x_prev_yr AS prev_yr,
        l.market_capitalization__pe_x - l.market_capitalization__pe_x_prev_yr AS yoy_chg
      ) AS pe_x
    ) AS market_capitalization
  ) AS financial_highlights_change
FROM lagged l;
END
