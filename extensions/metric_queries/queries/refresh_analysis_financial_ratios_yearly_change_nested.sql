-- Routine: silverzone.refresh_analysis_financial_ratios_yearly_change_nested
-- Source: capable-code-486208-j8.silverzone

BEGIN
-- silverzone.analysis_financial_ratios_yearly_change_nested
-- Full nested yearly-change table generated from silverzone.financial_ratios_nested schema.
-- Financial-ratio leaves use point change: current minus previous year.
-- Each metric leaf is emitted as STRUCT(value, prev_yr, yoy_chg) for point-change
-- metrics or STRUCT(value, prev_yr, yoy_pct) for absolute-value growth metrics.
CREATE OR REPLACE TABLE silverzone.analysis_financial_ratios_yearly_change_nested
CLUSTER BY company_id, yyyymm AS
WITH base AS (
  SELECT
    company_id,
    company_name,
    yyyymm,
    financial_ratios.operational_and_financial_ratios.value AS operational_and_financial_ratios__value,
    financial_ratios.operational_and_financial_ratios.earnings_per_share_rs AS operational_and_financial_ratios__earnings_per_share_rs,
    financial_ratios.operational_and_financial_ratios.adjusted_eps_rs AS operational_and_financial_ratios__adjusted_eps_rs,
    financial_ratios.operational_and_financial_ratios.ceps_rs AS operational_and_financial_ratios__ceps_rs,
    financial_ratios.operational_and_financial_ratios.dps_rs AS operational_and_financial_ratios__dps_rs,
    financial_ratios.operational_and_financial_ratios.adj_dps_rs AS operational_and_financial_ratios__adj_dps_rs,
    financial_ratios.operational_and_financial_ratios.book_value_rs AS operational_and_financial_ratios__book_value_rs,
    financial_ratios.operational_and_financial_ratios.adjusted_book_value_rs AS operational_and_financial_ratios__adjusted_book_value_rs,
    financial_ratios.operational_and_financial_ratios.tax_rate AS operational_and_financial_ratios__tax_rate,
    financial_ratios.operational_and_financial_ratios.dividend_pay_out_ratio AS operational_and_financial_ratios__dividend_pay_out_ratio,
    financial_ratios.margin_ratios.value AS margin_ratios__value,
    financial_ratios.margin_ratios.gpm AS margin_ratios__gpm,
    financial_ratios.margin_ratios.pbidtm AS margin_ratios__pbidtm,
    financial_ratios.margin_ratios.ebitm AS margin_ratios__ebitm,
    financial_ratios.margin_ratios.pre_tax_margin AS margin_ratios__pre_tax_margin,
    financial_ratios.margin_ratios.patm AS margin_ratios__patm,
    financial_ratios.margin_ratios.cpm AS margin_ratios__cpm,
    financial_ratios.performance_ratios.value AS performance_ratios__value,
    financial_ratios.performance_ratios.roa AS performance_ratios__roa,
    financial_ratios.performance_ratios.roe AS performance_ratios__roe,
    financial_ratios.performance_ratios.roce AS performance_ratios__roce,
    financial_ratios.performance_ratios.asset_turnover_x AS performance_ratios__asset_turnover_x,
    financial_ratios.performance_ratios.inventory_turnover_x AS performance_ratios__inventory_turnover_x,
    financial_ratios.performance_ratios.debtors_turnover_x AS performance_ratios__debtors_turnover_x,
    financial_ratios.performance_ratios.fixed_asset_turnover_x AS performance_ratios__fixed_asset_turnover_x,
    financial_ratios.performance_ratios.sales_x_working_capital AS performance_ratios__sales_x_working_capital,
    financial_ratios.efficiency_ratios.value AS efficiency_ratios__value,
    financial_ratios.efficiency_ratios.fixed_capital_sales_x AS efficiency_ratios__fixed_capital_sales_x,
    financial_ratios.efficiency_ratios.receivable_days AS efficiency_ratios__receivable_days,
    financial_ratios.efficiency_ratios.inventory_days AS efficiency_ratios__inventory_days,
    financial_ratios.efficiency_ratios.payable_days AS efficiency_ratios__payable_days,
    financial_ratios.growth_ratio.value AS growth_ratio__value,
    financial_ratios.growth_ratio.net_sales_growth AS growth_ratio__net_sales_growth,
    financial_ratios.growth_ratio.core_ebitda_growth AS growth_ratio__core_ebitda_growth,
    financial_ratios.growth_ratio.ebit_growth AS growth_ratio__ebit_growth,
    financial_ratios.growth_ratio.pat_growth AS growth_ratio__pat_growth,
    financial_ratios.growth_ratio.adj_eps_growth AS growth_ratio__adj_eps_growth,
    financial_ratios.financial_stability_ratios.value AS financial_stability_ratios__value,
    financial_ratios.financial_stability_ratios.total_debt_equity_x AS financial_stability_ratios__total_debt_equity_x,
    financial_ratios.financial_stability_ratios.current_ratio_x AS financial_stability_ratios__current_ratio_x,
    financial_ratios.financial_stability_ratios.quick_ratio_x AS financial_stability_ratios__quick_ratio_x,
    financial_ratios.financial_stability_ratios.interest_cover_x AS financial_stability_ratios__interest_cover_x,
    financial_ratios.financial_stability_ratios.total_debt_mcap_x AS financial_stability_ratios__total_debt_mcap_x
  FROM silverzone.financial_ratios_nested
),
lagged AS (
  SELECT
    *,
    LAG(yyyymm) OVER w AS prev_yyyymm,
    LAG(operational_and_financial_ratios__value) OVER w AS operational_and_financial_ratios__value_prev_yr,
    LAG(operational_and_financial_ratios__earnings_per_share_rs) OVER w AS operational_and_financial_ratios__earnings_per_share_rs_prev_yr,
    LAG(operational_and_financial_ratios__adjusted_eps_rs) OVER w AS operational_and_financial_ratios__adjusted_eps_rs_prev_yr,
    LAG(operational_and_financial_ratios__ceps_rs) OVER w AS operational_and_financial_ratios__ceps_rs_prev_yr,
    LAG(operational_and_financial_ratios__dps_rs) OVER w AS operational_and_financial_ratios__dps_rs_prev_yr,
    LAG(operational_and_financial_ratios__adj_dps_rs) OVER w AS operational_and_financial_ratios__adj_dps_rs_prev_yr,
    LAG(operational_and_financial_ratios__book_value_rs) OVER w AS operational_and_financial_ratios__book_value_rs_prev_yr,
    LAG(operational_and_financial_ratios__adjusted_book_value_rs) OVER w AS operational_and_financial_ratios__adjusted_book_value_rs_prev_yr,
    LAG(operational_and_financial_ratios__tax_rate) OVER w AS operational_and_financial_ratios__tax_rate_prev_yr,
    LAG(operational_and_financial_ratios__dividend_pay_out_ratio) OVER w AS operational_and_financial_ratios__dividend_pay_out_ratio_prev_yr,
    LAG(margin_ratios__value) OVER w AS margin_ratios__value_prev_yr,
    LAG(margin_ratios__gpm) OVER w AS margin_ratios__gpm_prev_yr,
    LAG(margin_ratios__pbidtm) OVER w AS margin_ratios__pbidtm_prev_yr,
    LAG(margin_ratios__ebitm) OVER w AS margin_ratios__ebitm_prev_yr,
    LAG(margin_ratios__pre_tax_margin) OVER w AS margin_ratios__pre_tax_margin_prev_yr,
    LAG(margin_ratios__patm) OVER w AS margin_ratios__patm_prev_yr,
    LAG(margin_ratios__cpm) OVER w AS margin_ratios__cpm_prev_yr,
    LAG(performance_ratios__value) OVER w AS performance_ratios__value_prev_yr,
    LAG(performance_ratios__roa) OVER w AS performance_ratios__roa_prev_yr,
    LAG(performance_ratios__roe) OVER w AS performance_ratios__roe_prev_yr,
    LAG(performance_ratios__roce) OVER w AS performance_ratios__roce_prev_yr,
    LAG(performance_ratios__asset_turnover_x) OVER w AS performance_ratios__asset_turnover_x_prev_yr,
    LAG(performance_ratios__inventory_turnover_x) OVER w AS performance_ratios__inventory_turnover_x_prev_yr,
    LAG(performance_ratios__debtors_turnover_x) OVER w AS performance_ratios__debtors_turnover_x_prev_yr,
    LAG(performance_ratios__fixed_asset_turnover_x) OVER w AS performance_ratios__fixed_asset_turnover_x_prev_yr,
    LAG(performance_ratios__sales_x_working_capital) OVER w AS performance_ratios__sales_x_working_capital_prev_yr,
    LAG(efficiency_ratios__value) OVER w AS efficiency_ratios__value_prev_yr,
    LAG(efficiency_ratios__fixed_capital_sales_x) OVER w AS efficiency_ratios__fixed_capital_sales_x_prev_yr,
    LAG(efficiency_ratios__receivable_days) OVER w AS efficiency_ratios__receivable_days_prev_yr,
    LAG(efficiency_ratios__inventory_days) OVER w AS efficiency_ratios__inventory_days_prev_yr,
    LAG(efficiency_ratios__payable_days) OVER w AS efficiency_ratios__payable_days_prev_yr,
    LAG(growth_ratio__value) OVER w AS growth_ratio__value_prev_yr,
    LAG(growth_ratio__net_sales_growth) OVER w AS growth_ratio__net_sales_growth_prev_yr,
    LAG(growth_ratio__core_ebitda_growth) OVER w AS growth_ratio__core_ebitda_growth_prev_yr,
    LAG(growth_ratio__ebit_growth) OVER w AS growth_ratio__ebit_growth_prev_yr,
    LAG(growth_ratio__pat_growth) OVER w AS growth_ratio__pat_growth_prev_yr,
    LAG(growth_ratio__adj_eps_growth) OVER w AS growth_ratio__adj_eps_growth_prev_yr,
    LAG(financial_stability_ratios__value) OVER w AS financial_stability_ratios__value_prev_yr,
    LAG(financial_stability_ratios__total_debt_equity_x) OVER w AS financial_stability_ratios__total_debt_equity_x_prev_yr,
    LAG(financial_stability_ratios__current_ratio_x) OVER w AS financial_stability_ratios__current_ratio_x_prev_yr,
    LAG(financial_stability_ratios__quick_ratio_x) OVER w AS financial_stability_ratios__quick_ratio_x_prev_yr,
    LAG(financial_stability_ratios__interest_cover_x) OVER w AS financial_stability_ratios__interest_cover_x_prev_yr,
    LAG(financial_stability_ratios__total_debt_mcap_x) OVER w AS financial_stability_ratios__total_debt_mcap_x_prev_yr
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
        l.operational_and_financial_ratios__value AS value,
        l.operational_and_financial_ratios__value_prev_yr AS prev_yr,
        l.operational_and_financial_ratios__value - l.operational_and_financial_ratios__value_prev_yr AS yoy_chg
      ) AS value,
      STRUCT(
        l.operational_and_financial_ratios__earnings_per_share_rs AS value,
        l.operational_and_financial_ratios__earnings_per_share_rs_prev_yr AS prev_yr,
        l.operational_and_financial_ratios__earnings_per_share_rs - l.operational_and_financial_ratios__earnings_per_share_rs_prev_yr AS yoy_chg
      ) AS earnings_per_share_rs,
      STRUCT(
        l.operational_and_financial_ratios__adjusted_eps_rs AS value,
        l.operational_and_financial_ratios__adjusted_eps_rs_prev_yr AS prev_yr,
        l.operational_and_financial_ratios__adjusted_eps_rs - l.operational_and_financial_ratios__adjusted_eps_rs_prev_yr AS yoy_chg
      ) AS adjusted_eps_rs,
      STRUCT(
        l.operational_and_financial_ratios__ceps_rs AS value,
        l.operational_and_financial_ratios__ceps_rs_prev_yr AS prev_yr,
        l.operational_and_financial_ratios__ceps_rs - l.operational_and_financial_ratios__ceps_rs_prev_yr AS yoy_chg
      ) AS ceps_rs,
      STRUCT(
        l.operational_and_financial_ratios__dps_rs AS value,
        l.operational_and_financial_ratios__dps_rs_prev_yr AS prev_yr,
        l.operational_and_financial_ratios__dps_rs - l.operational_and_financial_ratios__dps_rs_prev_yr AS yoy_chg
      ) AS dps_rs,
      STRUCT(
        l.operational_and_financial_ratios__adj_dps_rs AS value,
        l.operational_and_financial_ratios__adj_dps_rs_prev_yr AS prev_yr,
        l.operational_and_financial_ratios__adj_dps_rs - l.operational_and_financial_ratios__adj_dps_rs_prev_yr AS yoy_chg
      ) AS adj_dps_rs,
      STRUCT(
        l.operational_and_financial_ratios__book_value_rs AS value,
        l.operational_and_financial_ratios__book_value_rs_prev_yr AS prev_yr,
        l.operational_and_financial_ratios__book_value_rs - l.operational_and_financial_ratios__book_value_rs_prev_yr AS yoy_chg
      ) AS book_value_rs,
      STRUCT(
        l.operational_and_financial_ratios__adjusted_book_value_rs AS value,
        l.operational_and_financial_ratios__adjusted_book_value_rs_prev_yr AS prev_yr,
        l.operational_and_financial_ratios__adjusted_book_value_rs - l.operational_and_financial_ratios__adjusted_book_value_rs_prev_yr AS yoy_chg
      ) AS adjusted_book_value_rs,
      STRUCT(
        l.operational_and_financial_ratios__tax_rate AS value,
        l.operational_and_financial_ratios__tax_rate_prev_yr AS prev_yr,
        l.operational_and_financial_ratios__tax_rate - l.operational_and_financial_ratios__tax_rate_prev_yr AS yoy_chg
      ) AS tax_rate,
      STRUCT(
        l.operational_and_financial_ratios__dividend_pay_out_ratio AS value,
        l.operational_and_financial_ratios__dividend_pay_out_ratio_prev_yr AS prev_yr,
        l.operational_and_financial_ratios__dividend_pay_out_ratio - l.operational_and_financial_ratios__dividend_pay_out_ratio_prev_yr AS yoy_chg
      ) AS dividend_pay_out_ratio
    ) AS operational_and_financial_ratios,
    STRUCT(
      STRUCT(
        l.margin_ratios__value AS value,
        l.margin_ratios__value_prev_yr AS prev_yr,
        l.margin_ratios__value - l.margin_ratios__value_prev_yr AS yoy_chg
      ) AS value,
      STRUCT(
        l.margin_ratios__gpm AS value,
        l.margin_ratios__gpm_prev_yr AS prev_yr,
        l.margin_ratios__gpm - l.margin_ratios__gpm_prev_yr AS yoy_chg
      ) AS gpm,
      STRUCT(
        l.margin_ratios__pbidtm AS value,
        l.margin_ratios__pbidtm_prev_yr AS prev_yr,
        l.margin_ratios__pbidtm - l.margin_ratios__pbidtm_prev_yr AS yoy_chg
      ) AS pbidtm,
      STRUCT(
        l.margin_ratios__ebitm AS value,
        l.margin_ratios__ebitm_prev_yr AS prev_yr,
        l.margin_ratios__ebitm - l.margin_ratios__ebitm_prev_yr AS yoy_chg
      ) AS ebitm,
      STRUCT(
        l.margin_ratios__pre_tax_margin AS value,
        l.margin_ratios__pre_tax_margin_prev_yr AS prev_yr,
        l.margin_ratios__pre_tax_margin - l.margin_ratios__pre_tax_margin_prev_yr AS yoy_chg
      ) AS pre_tax_margin,
      STRUCT(
        l.margin_ratios__patm AS value,
        l.margin_ratios__patm_prev_yr AS prev_yr,
        l.margin_ratios__patm - l.margin_ratios__patm_prev_yr AS yoy_chg
      ) AS patm,
      STRUCT(
        l.margin_ratios__cpm AS value,
        l.margin_ratios__cpm_prev_yr AS prev_yr,
        l.margin_ratios__cpm - l.margin_ratios__cpm_prev_yr AS yoy_chg
      ) AS cpm
    ) AS margin_ratios,
    STRUCT(
      STRUCT(
        l.performance_ratios__value AS value,
        l.performance_ratios__value_prev_yr AS prev_yr,
        l.performance_ratios__value - l.performance_ratios__value_prev_yr AS yoy_chg
      ) AS value,
      STRUCT(
        l.performance_ratios__roa AS value,
        l.performance_ratios__roa_prev_yr AS prev_yr,
        l.performance_ratios__roa - l.performance_ratios__roa_prev_yr AS yoy_chg
      ) AS roa,
      STRUCT(
        l.performance_ratios__roe AS value,
        l.performance_ratios__roe_prev_yr AS prev_yr,
        l.performance_ratios__roe - l.performance_ratios__roe_prev_yr AS yoy_chg
      ) AS roe,
      STRUCT(
        l.performance_ratios__roce AS value,
        l.performance_ratios__roce_prev_yr AS prev_yr,
        l.performance_ratios__roce - l.performance_ratios__roce_prev_yr AS yoy_chg
      ) AS roce,
      STRUCT(
        l.performance_ratios__asset_turnover_x AS value,
        l.performance_ratios__asset_turnover_x_prev_yr AS prev_yr,
        l.performance_ratios__asset_turnover_x - l.performance_ratios__asset_turnover_x_prev_yr AS yoy_chg
      ) AS asset_turnover_x,
      STRUCT(
        l.performance_ratios__inventory_turnover_x AS value,
        l.performance_ratios__inventory_turnover_x_prev_yr AS prev_yr,
        l.performance_ratios__inventory_turnover_x - l.performance_ratios__inventory_turnover_x_prev_yr AS yoy_chg
      ) AS inventory_turnover_x,
      STRUCT(
        l.performance_ratios__debtors_turnover_x AS value,
        l.performance_ratios__debtors_turnover_x_prev_yr AS prev_yr,
        l.performance_ratios__debtors_turnover_x - l.performance_ratios__debtors_turnover_x_prev_yr AS yoy_chg
      ) AS debtors_turnover_x,
      STRUCT(
        l.performance_ratios__fixed_asset_turnover_x AS value,
        l.performance_ratios__fixed_asset_turnover_x_prev_yr AS prev_yr,
        l.performance_ratios__fixed_asset_turnover_x - l.performance_ratios__fixed_asset_turnover_x_prev_yr AS yoy_chg
      ) AS fixed_asset_turnover_x,
      STRUCT(
        l.performance_ratios__sales_x_working_capital AS value,
        l.performance_ratios__sales_x_working_capital_prev_yr AS prev_yr,
        l.performance_ratios__sales_x_working_capital - l.performance_ratios__sales_x_working_capital_prev_yr AS yoy_chg
      ) AS sales_x_working_capital
    ) AS performance_ratios,
    STRUCT(
      STRUCT(
        l.efficiency_ratios__value AS value,
        l.efficiency_ratios__value_prev_yr AS prev_yr,
        l.efficiency_ratios__value - l.efficiency_ratios__value_prev_yr AS yoy_chg
      ) AS value,
      STRUCT(
        l.efficiency_ratios__fixed_capital_sales_x AS value,
        l.efficiency_ratios__fixed_capital_sales_x_prev_yr AS prev_yr,
        l.efficiency_ratios__fixed_capital_sales_x - l.efficiency_ratios__fixed_capital_sales_x_prev_yr AS yoy_chg
      ) AS fixed_capital_sales_x,
      STRUCT(
        l.efficiency_ratios__receivable_days AS value,
        l.efficiency_ratios__receivable_days_prev_yr AS prev_yr,
        l.efficiency_ratios__receivable_days - l.efficiency_ratios__receivable_days_prev_yr AS yoy_chg
      ) AS receivable_days,
      STRUCT(
        l.efficiency_ratios__inventory_days AS value,
        l.efficiency_ratios__inventory_days_prev_yr AS prev_yr,
        l.efficiency_ratios__inventory_days - l.efficiency_ratios__inventory_days_prev_yr AS yoy_chg
      ) AS inventory_days,
      STRUCT(
        l.efficiency_ratios__payable_days AS value,
        l.efficiency_ratios__payable_days_prev_yr AS prev_yr,
        l.efficiency_ratios__payable_days - l.efficiency_ratios__payable_days_prev_yr AS yoy_chg
      ) AS payable_days
    ) AS efficiency_ratios,
    STRUCT(
      STRUCT(
        l.growth_ratio__value AS value,
        l.growth_ratio__value_prev_yr AS prev_yr,
        l.growth_ratio__value - l.growth_ratio__value_prev_yr AS yoy_chg
      ) AS value,
      STRUCT(
        l.growth_ratio__net_sales_growth AS value,
        l.growth_ratio__net_sales_growth_prev_yr AS prev_yr,
        l.growth_ratio__net_sales_growth - l.growth_ratio__net_sales_growth_prev_yr AS yoy_chg
      ) AS net_sales_growth,
      STRUCT(
        l.growth_ratio__core_ebitda_growth AS value,
        l.growth_ratio__core_ebitda_growth_prev_yr AS prev_yr,
        l.growth_ratio__core_ebitda_growth - l.growth_ratio__core_ebitda_growth_prev_yr AS yoy_chg
      ) AS core_ebitda_growth,
      STRUCT(
        l.growth_ratio__ebit_growth AS value,
        l.growth_ratio__ebit_growth_prev_yr AS prev_yr,
        l.growth_ratio__ebit_growth - l.growth_ratio__ebit_growth_prev_yr AS yoy_chg
      ) AS ebit_growth,
      STRUCT(
        l.growth_ratio__pat_growth AS value,
        l.growth_ratio__pat_growth_prev_yr AS prev_yr,
        l.growth_ratio__pat_growth - l.growth_ratio__pat_growth_prev_yr AS yoy_chg
      ) AS pat_growth,
      STRUCT(
        l.growth_ratio__adj_eps_growth AS value,
        l.growth_ratio__adj_eps_growth_prev_yr AS prev_yr,
        l.growth_ratio__adj_eps_growth - l.growth_ratio__adj_eps_growth_prev_yr AS yoy_chg
      ) AS adj_eps_growth
    ) AS growth_ratio,
    STRUCT(
      STRUCT(
        l.financial_stability_ratios__value AS value,
        l.financial_stability_ratios__value_prev_yr AS prev_yr,
        l.financial_stability_ratios__value - l.financial_stability_ratios__value_prev_yr AS yoy_chg
      ) AS value,
      STRUCT(
        l.financial_stability_ratios__total_debt_equity_x AS value,
        l.financial_stability_ratios__total_debt_equity_x_prev_yr AS prev_yr,
        l.financial_stability_ratios__total_debt_equity_x - l.financial_stability_ratios__total_debt_equity_x_prev_yr AS yoy_chg
      ) AS total_debt_equity_x,
      STRUCT(
        l.financial_stability_ratios__current_ratio_x AS value,
        l.financial_stability_ratios__current_ratio_x_prev_yr AS prev_yr,
        l.financial_stability_ratios__current_ratio_x - l.financial_stability_ratios__current_ratio_x_prev_yr AS yoy_chg
      ) AS current_ratio_x,
      STRUCT(
        l.financial_stability_ratios__quick_ratio_x AS value,
        l.financial_stability_ratios__quick_ratio_x_prev_yr AS prev_yr,
        l.financial_stability_ratios__quick_ratio_x - l.financial_stability_ratios__quick_ratio_x_prev_yr AS yoy_chg
      ) AS quick_ratio_x,
      STRUCT(
        l.financial_stability_ratios__interest_cover_x AS value,
        l.financial_stability_ratios__interest_cover_x_prev_yr AS prev_yr,
        l.financial_stability_ratios__interest_cover_x - l.financial_stability_ratios__interest_cover_x_prev_yr AS yoy_chg
      ) AS interest_cover_x,
      STRUCT(
        l.financial_stability_ratios__total_debt_mcap_x AS value,
        l.financial_stability_ratios__total_debt_mcap_x_prev_yr AS prev_yr,
        l.financial_stability_ratios__total_debt_mcap_x - l.financial_stability_ratios__total_debt_mcap_x_prev_yr AS yoy_chg
      ) AS total_debt_mcap_x
    ) AS financial_stability_ratios
  ) AS financial_ratios_change
FROM lagged l;
END
