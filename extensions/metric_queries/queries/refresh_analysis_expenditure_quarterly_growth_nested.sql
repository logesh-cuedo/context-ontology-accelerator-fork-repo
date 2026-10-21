-- Routine: silverzone.refresh_analysis_expenditure_quarterly_growth_nested
-- Source: capable-code-486208-j8.silverzone

BEGIN
-- silverzone.analysis_expenditure_quarterly_growth_nested
-- Full nested expenditure quarterly growth table.
-- Generated from silverzone.profit_and_loss_quarterly_expenditure_nested schema.
-- Covers every numeric leaf under expenditure, including children and grandchildren.
-- Each metric leaf is emitted as STRUCT(value, prev_q, qoq_pct, prior_yr_q, yoy_pct).
-- Growth convention: (cur - prev) / ABS(NULLIF(prev, 0)) * 100.
CREATE OR REPLACE TABLE silverzone.analysis_expenditure_quarterly_growth_nested
CLUSTER BY company_id, yyyymm AS
WITH base AS (
  SELECT
    company_id,
    company_name,
    sector,
    subsector,
    flag,
    yyyymm,
    value_basis,
    unit,
    expenditure.operating_expenditure.value AS operating_expenditure__value,
    expenditure.operating_expenditure.increase_decrease_in_stocks AS operating_expenditure__increase_decrease_in_stocks,
    expenditure.operating_expenditure.cost_of_services_raw_materials AS operating_expenditure__cost_of_services_raw_materials,
    expenditure.operating_expenditure.purchase_of_finished_goods AS operating_expenditure__purchase_of_finished_goods,
    expenditure.operating_expenditure.electricity_power_fuel_cost AS operating_expenditure__electricity_power_fuel_cost,
    expenditure.operating_expenditure.employee_cost AS operating_expenditure__employee_cost,
    expenditure.operating_expenditure.operating_manufacturing_expenses AS operating_expenditure__operating_manufacturing_expenses,
    expenditure.operating_expenditure.general_administration_expenses AS operating_expenditure__general_administration_expenses,
    expenditure.operating_expenditure.selling_distribution_expenses AS operating_expenditure__selling_distribution_expenses,
    expenditure.operating_expenditure.miscellaneous_expenses AS operating_expenditure__miscellaneous_expenses,
    expenditure.operating_expenditure.misc_expenses_written_off AS operating_expenditure__misc_expenses_written_off,
    expenditure.operating_expenditure.other_operating_expenses AS operating_expenditure__other_operating_expenses,
    expenditure.operating_expenditure.operating_expenses AS operating_expenditure__operating_expenses,
    expenditure.operating_expenditure.payment_to_provisions_for_employees AS operating_expenditure__payment_to_provisions_for_employees,
    expenditure.operating_expenditure.provisions_and_contingencies AS operating_expenditure__provisions_and_contingencies,
    expenditure.operating_expenditure.prior_period_expenses AS operating_expenditure__prior_period_expenses,
    expenditure.operating_expenditure.employees_separation_compensation AS operating_expenditure__employees_separation_compensation,
    expenditure.operating_expenditure.loss_on_foreign_exchange AS operating_expenditure__loss_on_foreign_exchange,
    expenditure.operating_expenditure.loss_on_foreign_exchange_loan AS operating_expenditure__loss_on_foreign_exchange_loan,
    expenditure.operating_expenditure.provision_for_dimulation_in_investment_assets AS operating_expenditure__provision_for_dimulation_in_investment_assets,
    expenditure.operating_expenditure.provision_for_impairment_od_assets AS operating_expenditure__provision_for_impairment_od_assets,
    expenditure.operating_expenditure.profit_loss_due_to_exchange_rate AS operating_expenditure__profit_loss_due_to_exchange_rate,
    expenditure.operating_expenditure.other_related_items AS operating_expenditure__other_related_items,
    expenditure.operating_expenditure.other_adjustments AS operating_expenditure__other_adjustments,
    expenditure.profit_waterfall.value AS profit_waterfall__value,
    expenditure.profit_waterfall.operating_profit AS profit_waterfall__operating_profit,
    expenditure.profit_waterfall.operating_profit_before_prov_cont AS profit_waterfall__operating_profit_before_prov_cont,
    expenditure.profit_waterfall.pbidt_excl_oi AS profit_waterfall__pbidt_excl_oi,
    expenditure.profit_waterfall.pbdt AS profit_waterfall__pbdt,
    expenditure.profit_waterfall.depreciation AS profit_waterfall__depreciation,
    expenditure.profit_waterfall.interest AS profit_waterfall__interest,
    expenditure.profit_waterfall.interest_expended AS profit_waterfall__interest_expended,
    expenditure.profit_waterfall.pbt AS profit_waterfall__pbt,
    expenditure.profit_waterfall.exceptional_items AS profit_waterfall__exceptional_items,
    expenditure.profit_waterfall.other_exceoptional_items AS profit_waterfall__other_exceoptional_items,
    expenditure.profit_waterfall.extraordinary_items AS profit_waterfall__extraordinary_items,
    expenditure.profit_waterfall.other_exceptional_items AS profit_waterfall__other_exceptional_items,
    expenditure.profit_waterfall.prior_period_items AS profit_waterfall__prior_period_items,
    expenditure.profit_waterfall.prior_period_year_tax AS profit_waterfall__prior_period_year_tax,
    expenditure.profit_waterfall.current_tax AS profit_waterfall__current_tax,
    expenditure.profit_waterfall.deferred_tax AS profit_waterfall__deferred_tax,
    expenditure.profit_waterfall.mat_credit AS profit_waterfall__mat_credit,
    expenditure.profit_waterfall.fringe_benefit_tax AS profit_waterfall__fringe_benefit_tax,
    expenditure.profit_waterfall.other_taxes AS profit_waterfall__other_taxes,
    expenditure.profit_waterfall.tax AS profit_waterfall__tax,
    expenditure.profit_waterfall.minority_interest AS profit_waterfall__minority_interest,
    expenditure.profit_waterfall.minority_interest_comprehensive_income AS profit_waterfall__minority_interest_comprehensive_income,
    expenditure.profit_waterfall.shares_of_associates AS profit_waterfall__shares_of_associates,
    expenditure.profit_waterfall.consolidated_net_profit AS profit_waterfall__consolidated_net_profit,
    expenditure.profit_waterfall.net_profit_after_extrodinary_items AS profit_waterfall__net_profit_after_extrodinary_items,
    expenditure.profit_waterfall.net_profit_after_extraordinary_items AS profit_waterfall__net_profit_after_extraordinary_items,
    expenditure.profit_waterfall.net_profit_after_extraodinary_items AS profit_waterfall__net_profit_after_extraodinary_items,
    expenditure.profit_waterfall.discontinued_operation_net_of_tax AS profit_waterfall__discontinued_operation_net_of_tax,
    expenditure.profit_waterfall.other_comprehensive_incomes_net_of_tax AS profit_waterfall__other_comprehensive_incomes_net_of_tax,
    expenditure.profit_waterfall.total_comprehensive_income AS profit_waterfall__total_comprehensive_income,
    expenditure.margins_eps.value AS margins_eps__value,
    expenditure.margins_eps.pbtm AS margins_eps__pbtm,
    expenditure.margins_eps.pbdtm AS margins_eps__pbdtm,
    expenditure.margins_eps.pbidtm AS margins_eps__pbidtm,
    expenditure.margins_eps.pbidtm_excl_oi AS margins_eps__pbidtm_excl_oi,
    expenditure.margins_eps.patm AS margins_eps__patm,
    expenditure.margins_eps.return_on_assets AS margins_eps__return_on_assets,
    expenditure.margins_eps.adj_calculated_eps_unit_curr AS margins_eps__adj_calculated_eps_unit_curr,
    expenditure.margins_eps.calculated_eps_unit_curr AS margins_eps__calculated_eps_unit_curr,
    expenditure.margins_eps.basic_eps_after_extraordinary_items AS margins_eps__basic_eps_after_extraordinary_items,
    expenditure.margins_eps.basic_eps_before_extraordinary_items AS margins_eps__basic_eps_before_extraordinary_items,
    expenditure.margins_eps.basic_eps_after_extraodinary_items AS margins_eps__basic_eps_after_extraodinary_items,
    expenditure.margins_eps.basic_eps_before_extraodinary_items AS margins_eps__basic_eps_before_extraodinary_items,
    expenditure.margins_eps.diluted_eps_after_extraordinary_items AS margins_eps__diluted_eps_after_extraordinary_items,
    expenditure.margins_eps.diluted_eps_before_extraordinary_items AS margins_eps__diluted_eps_before_extraordinary_items,
    expenditure.margins_eps.diluted_eps_after_extraodinary_items AS margins_eps__diluted_eps_after_extraodinary_items,
    expenditure.margins_eps.diluted_eps_before_extraodinary_items AS margins_eps__diluted_eps_before_extraodinary_items,
    expenditure.margins_eps.equity_capital AS margins_eps__equity_capital,
    expenditure.margins_eps.face_value AS margins_eps__face_value,
    expenditure.margins_eps.face_value_in_rs AS margins_eps__face_value_in_rs,
    expenditure.margins_eps.reserves AS margins_eps__reserves,
    expenditure.banking_metrics.value AS banking_metrics__value,
    expenditure.banking_metrics.of_gross_npas AS banking_metrics__of_gross_npas,
    expenditure.banking_metrics.of_net_npas AS banking_metrics__of_net_npas,
    expenditure.banking_metrics.amount_of_gross_npa AS banking_metrics__amount_of_gross_npa,
    expenditure.banking_metrics.amount_of_net_npa AS banking_metrics__amount_of_net_npa,
    expenditure.banking_metrics.gross_net_npa AS banking_metrics__gross_net_npa,
    expenditure.banking_metrics.percentage_of_gross_net_npa AS banking_metrics__percentage_of_gross_net_npa,
    expenditure.banking_metrics.provisions_coverage AS banking_metrics__provisions_coverage,
    expenditure.banking_metrics.nim AS banking_metrics__nim,
    expenditure.banking_metrics.no_of_atms AS banking_metrics__no_of_atms,
    expenditure.banking_metrics.no_of_branches AS banking_metrics__no_of_branches,
    expenditure.banking_metrics.no_of_employees AS banking_metrics__no_of_employees,
    expenditure.banking_metrics.capital_adeqacy_ratio_basel_i AS banking_metrics__capital_adeqacy_ratio_basel_i,
    expenditure.banking_metrics.capital_adeqacy_ratio_basel_ii AS banking_metrics__capital_adeqacy_ratio_basel_ii,
    expenditure.banking_metrics.capital_adeqacy_ratio_basel_iii AS banking_metrics__capital_adeqacy_ratio_basel_iii,
    expenditure.banking_metrics.tier_i_basel_i AS banking_metrics__tier_i_basel_i,
    expenditure.banking_metrics.tier_2_basel_i AS banking_metrics__tier_2_basel_i,
    expenditure.banking_metrics.tier_i_basel_ii AS banking_metrics__tier_i_basel_ii,
    expenditure.banking_metrics.tier_2_basel_ii AS banking_metrics__tier_2_basel_ii,
    expenditure.banking_metrics.tier_i_basel_iii AS banking_metrics__tier_i_basel_iii,
    expenditure.banking_metrics.tier_2_basel_iii AS banking_metrics__tier_2_basel_iii,
    expenditure.banking_metrics.casa AS banking_metrics__casa,
    expenditure.banking_metrics.casa_amount AS banking_metrics__casa_amount,
    expenditure.banking_metrics.interest_earned AS banking_metrics__interest_earned,
    expenditure.banking_metrics.interest_discount_on_advances_bills AS banking_metrics__interest_discount_on_advances_bills,
    expenditure.banking_metrics.interest_on_balances_with_rbi_other_inter_bank_funds AS banking_metrics__interest_on_balances_with_rbi_other_inter_bank_funds
  FROM silverzone.profit_and_loss_quarterly_expenditure_nested
),
lagged AS (
  SELECT
    *,
    LAG(yyyymm) OVER w AS prev_yyyymm,
    LAG(operating_expenditure__value) OVER w AS operating_expenditure__value_prev_q,
    LAG(operating_expenditure__increase_decrease_in_stocks) OVER w AS operating_expenditure__increase_decrease_in_stocks_prev_q,
    LAG(operating_expenditure__cost_of_services_raw_materials) OVER w AS operating_expenditure__cost_of_services_raw_materials_prev_q,
    LAG(operating_expenditure__purchase_of_finished_goods) OVER w AS operating_expenditure__purchase_of_finished_goods_prev_q,
    LAG(operating_expenditure__electricity_power_fuel_cost) OVER w AS operating_expenditure__electricity_power_fuel_cost_prev_q,
    LAG(operating_expenditure__employee_cost) OVER w AS operating_expenditure__employee_cost_prev_q,
    LAG(operating_expenditure__operating_manufacturing_expenses) OVER w AS operating_expenditure__operating_manufacturing_expenses_prev_q,
    LAG(operating_expenditure__general_administration_expenses) OVER w AS operating_expenditure__general_administration_expenses_prev_q,
    LAG(operating_expenditure__selling_distribution_expenses) OVER w AS operating_expenditure__selling_distribution_expenses_prev_q,
    LAG(operating_expenditure__miscellaneous_expenses) OVER w AS operating_expenditure__miscellaneous_expenses_prev_q,
    LAG(operating_expenditure__misc_expenses_written_off) OVER w AS operating_expenditure__misc_expenses_written_off_prev_q,
    LAG(operating_expenditure__other_operating_expenses) OVER w AS operating_expenditure__other_operating_expenses_prev_q,
    LAG(operating_expenditure__operating_expenses) OVER w AS operating_expenditure__operating_expenses_prev_q,
    LAG(operating_expenditure__payment_to_provisions_for_employees) OVER w AS operating_expenditure__payment_to_provisions_for_employees_prev_q,
    LAG(operating_expenditure__provisions_and_contingencies) OVER w AS operating_expenditure__provisions_and_contingencies_prev_q,
    LAG(operating_expenditure__prior_period_expenses) OVER w AS operating_expenditure__prior_period_expenses_prev_q,
    LAG(operating_expenditure__employees_separation_compensation) OVER w AS operating_expenditure__employees_separation_compensation_prev_q,
    LAG(operating_expenditure__loss_on_foreign_exchange) OVER w AS operating_expenditure__loss_on_foreign_exchange_prev_q,
    LAG(operating_expenditure__loss_on_foreign_exchange_loan) OVER w AS operating_expenditure__loss_on_foreign_exchange_loan_prev_q,
    LAG(operating_expenditure__provision_for_dimulation_in_investment_assets) OVER w AS operating_expenditure__provision_for_dimulation_in_investment_assets_prev_q,
    LAG(operating_expenditure__provision_for_impairment_od_assets) OVER w AS operating_expenditure__provision_for_impairment_od_assets_prev_q,
    LAG(operating_expenditure__profit_loss_due_to_exchange_rate) OVER w AS operating_expenditure__profit_loss_due_to_exchange_rate_prev_q,
    LAG(operating_expenditure__other_related_items) OVER w AS operating_expenditure__other_related_items_prev_q,
    LAG(operating_expenditure__other_adjustments) OVER w AS operating_expenditure__other_adjustments_prev_q,
    LAG(profit_waterfall__value) OVER w AS profit_waterfall__value_prev_q,
    LAG(profit_waterfall__operating_profit) OVER w AS profit_waterfall__operating_profit_prev_q,
    LAG(profit_waterfall__operating_profit_before_prov_cont) OVER w AS profit_waterfall__operating_profit_before_prov_cont_prev_q,
    LAG(profit_waterfall__pbidt_excl_oi) OVER w AS profit_waterfall__pbidt_excl_oi_prev_q,
    LAG(profit_waterfall__pbdt) OVER w AS profit_waterfall__pbdt_prev_q,
    LAG(profit_waterfall__depreciation) OVER w AS profit_waterfall__depreciation_prev_q,
    LAG(profit_waterfall__interest) OVER w AS profit_waterfall__interest_prev_q,
    LAG(profit_waterfall__interest_expended) OVER w AS profit_waterfall__interest_expended_prev_q,
    LAG(profit_waterfall__pbt) OVER w AS profit_waterfall__pbt_prev_q,
    LAG(profit_waterfall__exceptional_items) OVER w AS profit_waterfall__exceptional_items_prev_q,
    LAG(profit_waterfall__other_exceoptional_items) OVER w AS profit_waterfall__other_exceoptional_items_prev_q,
    LAG(profit_waterfall__extraordinary_items) OVER w AS profit_waterfall__extraordinary_items_prev_q,
    LAG(profit_waterfall__other_exceptional_items) OVER w AS profit_waterfall__other_exceptional_items_prev_q,
    LAG(profit_waterfall__prior_period_items) OVER w AS profit_waterfall__prior_period_items_prev_q,
    LAG(profit_waterfall__prior_period_year_tax) OVER w AS profit_waterfall__prior_period_year_tax_prev_q,
    LAG(profit_waterfall__current_tax) OVER w AS profit_waterfall__current_tax_prev_q,
    LAG(profit_waterfall__deferred_tax) OVER w AS profit_waterfall__deferred_tax_prev_q,
    LAG(profit_waterfall__mat_credit) OVER w AS profit_waterfall__mat_credit_prev_q,
    LAG(profit_waterfall__fringe_benefit_tax) OVER w AS profit_waterfall__fringe_benefit_tax_prev_q,
    LAG(profit_waterfall__other_taxes) OVER w AS profit_waterfall__other_taxes_prev_q,
    LAG(profit_waterfall__tax) OVER w AS profit_waterfall__tax_prev_q,
    LAG(profit_waterfall__minority_interest) OVER w AS profit_waterfall__minority_interest_prev_q,
    LAG(profit_waterfall__minority_interest_comprehensive_income) OVER w AS profit_waterfall__minority_interest_comprehensive_income_prev_q,
    LAG(profit_waterfall__shares_of_associates) OVER w AS profit_waterfall__shares_of_associates_prev_q,
    LAG(profit_waterfall__consolidated_net_profit) OVER w AS profit_waterfall__consolidated_net_profit_prev_q,
    LAG(profit_waterfall__net_profit_after_extrodinary_items) OVER w AS profit_waterfall__net_profit_after_extrodinary_items_prev_q,
    LAG(profit_waterfall__net_profit_after_extraordinary_items) OVER w AS profit_waterfall__net_profit_after_extraordinary_items_prev_q,
    LAG(profit_waterfall__net_profit_after_extraodinary_items) OVER w AS profit_waterfall__net_profit_after_extraodinary_items_prev_q,
    LAG(profit_waterfall__discontinued_operation_net_of_tax) OVER w AS profit_waterfall__discontinued_operation_net_of_tax_prev_q,
    LAG(profit_waterfall__other_comprehensive_incomes_net_of_tax) OVER w AS profit_waterfall__other_comprehensive_incomes_net_of_tax_prev_q,
    LAG(profit_waterfall__total_comprehensive_income) OVER w AS profit_waterfall__total_comprehensive_income_prev_q,
    LAG(margins_eps__value) OVER w AS margins_eps__value_prev_q,
    LAG(margins_eps__pbtm) OVER w AS margins_eps__pbtm_prev_q,
    LAG(margins_eps__pbdtm) OVER w AS margins_eps__pbdtm_prev_q,
    LAG(margins_eps__pbidtm) OVER w AS margins_eps__pbidtm_prev_q,
    LAG(margins_eps__pbidtm_excl_oi) OVER w AS margins_eps__pbidtm_excl_oi_prev_q,
    LAG(margins_eps__patm) OVER w AS margins_eps__patm_prev_q,
    LAG(margins_eps__return_on_assets) OVER w AS margins_eps__return_on_assets_prev_q,
    LAG(margins_eps__adj_calculated_eps_unit_curr) OVER w AS margins_eps__adj_calculated_eps_unit_curr_prev_q,
    LAG(margins_eps__calculated_eps_unit_curr) OVER w AS margins_eps__calculated_eps_unit_curr_prev_q,
    LAG(margins_eps__basic_eps_after_extraordinary_items) OVER w AS margins_eps__basic_eps_after_extraordinary_items_prev_q,
    LAG(margins_eps__basic_eps_before_extraordinary_items) OVER w AS margins_eps__basic_eps_before_extraordinary_items_prev_q,
    LAG(margins_eps__basic_eps_after_extraodinary_items) OVER w AS margins_eps__basic_eps_after_extraodinary_items_prev_q,
    LAG(margins_eps__basic_eps_before_extraodinary_items) OVER w AS margins_eps__basic_eps_before_extraodinary_items_prev_q,
    LAG(margins_eps__diluted_eps_after_extraordinary_items) OVER w AS margins_eps__diluted_eps_after_extraordinary_items_prev_q,
    LAG(margins_eps__diluted_eps_before_extraordinary_items) OVER w AS margins_eps__diluted_eps_before_extraordinary_items_prev_q,
    LAG(margins_eps__diluted_eps_after_extraodinary_items) OVER w AS margins_eps__diluted_eps_after_extraodinary_items_prev_q,
    LAG(margins_eps__diluted_eps_before_extraodinary_items) OVER w AS margins_eps__diluted_eps_before_extraodinary_items_prev_q,
    LAG(margins_eps__equity_capital) OVER w AS margins_eps__equity_capital_prev_q,
    LAG(margins_eps__face_value) OVER w AS margins_eps__face_value_prev_q,
    LAG(margins_eps__face_value_in_rs) OVER w AS margins_eps__face_value_in_rs_prev_q,
    LAG(margins_eps__reserves) OVER w AS margins_eps__reserves_prev_q,
    LAG(banking_metrics__value) OVER w AS banking_metrics__value_prev_q,
    LAG(banking_metrics__of_gross_npas) OVER w AS banking_metrics__of_gross_npas_prev_q,
    LAG(banking_metrics__of_net_npas) OVER w AS banking_metrics__of_net_npas_prev_q,
    LAG(banking_metrics__amount_of_gross_npa) OVER w AS banking_metrics__amount_of_gross_npa_prev_q,
    LAG(banking_metrics__amount_of_net_npa) OVER w AS banking_metrics__amount_of_net_npa_prev_q,
    LAG(banking_metrics__gross_net_npa) OVER w AS banking_metrics__gross_net_npa_prev_q,
    LAG(banking_metrics__percentage_of_gross_net_npa) OVER w AS banking_metrics__percentage_of_gross_net_npa_prev_q,
    LAG(banking_metrics__provisions_coverage) OVER w AS banking_metrics__provisions_coverage_prev_q,
    LAG(banking_metrics__nim) OVER w AS banking_metrics__nim_prev_q,
    LAG(banking_metrics__no_of_atms) OVER w AS banking_metrics__no_of_atms_prev_q,
    LAG(banking_metrics__no_of_branches) OVER w AS banking_metrics__no_of_branches_prev_q,
    LAG(banking_metrics__no_of_employees) OVER w AS banking_metrics__no_of_employees_prev_q,
    LAG(banking_metrics__capital_adeqacy_ratio_basel_i) OVER w AS banking_metrics__capital_adeqacy_ratio_basel_i_prev_q,
    LAG(banking_metrics__capital_adeqacy_ratio_basel_ii) OVER w AS banking_metrics__capital_adeqacy_ratio_basel_ii_prev_q,
    LAG(banking_metrics__capital_adeqacy_ratio_basel_iii) OVER w AS banking_metrics__capital_adeqacy_ratio_basel_iii_prev_q,
    LAG(banking_metrics__tier_i_basel_i) OVER w AS banking_metrics__tier_i_basel_i_prev_q,
    LAG(banking_metrics__tier_2_basel_i) OVER w AS banking_metrics__tier_2_basel_i_prev_q,
    LAG(banking_metrics__tier_i_basel_ii) OVER w AS banking_metrics__tier_i_basel_ii_prev_q,
    LAG(banking_metrics__tier_2_basel_ii) OVER w AS banking_metrics__tier_2_basel_ii_prev_q,
    LAG(banking_metrics__tier_i_basel_iii) OVER w AS banking_metrics__tier_i_basel_iii_prev_q,
    LAG(banking_metrics__tier_2_basel_iii) OVER w AS banking_metrics__tier_2_basel_iii_prev_q,
    LAG(banking_metrics__casa) OVER w AS banking_metrics__casa_prev_q,
    LAG(banking_metrics__casa_amount) OVER w AS banking_metrics__casa_amount_prev_q,
    LAG(banking_metrics__interest_earned) OVER w AS banking_metrics__interest_earned_prev_q,
    LAG(banking_metrics__interest_discount_on_advances_bills) OVER w AS banking_metrics__interest_discount_on_advances_bills_prev_q,
    LAG(banking_metrics__interest_on_balances_with_rbi_other_inter_bank_funds) OVER w AS banking_metrics__interest_on_balances_with_rbi_other_inter_bank_funds_prev_q
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
  l.value_basis,
  l.unit,
  l.prev_yyyymm,
  p.yyyymm AS prior_yr_yyyymm,
  STRUCT(
    STRUCT(
      STRUCT(
        l.operating_expenditure__value AS value,
        l.operating_expenditure__value_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.operating_expenditure__value - l.operating_expenditure__value_prev_q) / ABS(NULLIF(l.operating_expenditure__value_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.operating_expenditure__value AS prior_yr_q,
        (l.operating_expenditure__value - p.operating_expenditure__value) / ABS(NULLIF(p.operating_expenditure__value, 0)) * 100 AS yoy_pct
      ) AS value,
      STRUCT(
        l.operating_expenditure__increase_decrease_in_stocks AS value,
        l.operating_expenditure__increase_decrease_in_stocks_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.operating_expenditure__increase_decrease_in_stocks - l.operating_expenditure__increase_decrease_in_stocks_prev_q) / ABS(NULLIF(l.operating_expenditure__increase_decrease_in_stocks_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.operating_expenditure__increase_decrease_in_stocks AS prior_yr_q,
        (l.operating_expenditure__increase_decrease_in_stocks - p.operating_expenditure__increase_decrease_in_stocks) / ABS(NULLIF(p.operating_expenditure__increase_decrease_in_stocks, 0)) * 100 AS yoy_pct
      ) AS increase_decrease_in_stocks,
      STRUCT(
        l.operating_expenditure__cost_of_services_raw_materials AS value,
        l.operating_expenditure__cost_of_services_raw_materials_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.operating_expenditure__cost_of_services_raw_materials - l.operating_expenditure__cost_of_services_raw_materials_prev_q) / ABS(NULLIF(l.operating_expenditure__cost_of_services_raw_materials_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.operating_expenditure__cost_of_services_raw_materials AS prior_yr_q,
        (l.operating_expenditure__cost_of_services_raw_materials - p.operating_expenditure__cost_of_services_raw_materials) / ABS(NULLIF(p.operating_expenditure__cost_of_services_raw_materials, 0)) * 100 AS yoy_pct
      ) AS cost_of_services_raw_materials,
      STRUCT(
        l.operating_expenditure__purchase_of_finished_goods AS value,
        l.operating_expenditure__purchase_of_finished_goods_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.operating_expenditure__purchase_of_finished_goods - l.operating_expenditure__purchase_of_finished_goods_prev_q) / ABS(NULLIF(l.operating_expenditure__purchase_of_finished_goods_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.operating_expenditure__purchase_of_finished_goods AS prior_yr_q,
        (l.operating_expenditure__purchase_of_finished_goods - p.operating_expenditure__purchase_of_finished_goods) / ABS(NULLIF(p.operating_expenditure__purchase_of_finished_goods, 0)) * 100 AS yoy_pct
      ) AS purchase_of_finished_goods,
      STRUCT(
        l.operating_expenditure__electricity_power_fuel_cost AS value,
        l.operating_expenditure__electricity_power_fuel_cost_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.operating_expenditure__electricity_power_fuel_cost - l.operating_expenditure__electricity_power_fuel_cost_prev_q) / ABS(NULLIF(l.operating_expenditure__electricity_power_fuel_cost_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.operating_expenditure__electricity_power_fuel_cost AS prior_yr_q,
        (l.operating_expenditure__electricity_power_fuel_cost - p.operating_expenditure__electricity_power_fuel_cost) / ABS(NULLIF(p.operating_expenditure__electricity_power_fuel_cost, 0)) * 100 AS yoy_pct
      ) AS electricity_power_fuel_cost,
      STRUCT(
        l.operating_expenditure__employee_cost AS value,
        l.operating_expenditure__employee_cost_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.operating_expenditure__employee_cost - l.operating_expenditure__employee_cost_prev_q) / ABS(NULLIF(l.operating_expenditure__employee_cost_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.operating_expenditure__employee_cost AS prior_yr_q,
        (l.operating_expenditure__employee_cost - p.operating_expenditure__employee_cost) / ABS(NULLIF(p.operating_expenditure__employee_cost, 0)) * 100 AS yoy_pct
      ) AS employee_cost,
      STRUCT(
        l.operating_expenditure__operating_manufacturing_expenses AS value,
        l.operating_expenditure__operating_manufacturing_expenses_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.operating_expenditure__operating_manufacturing_expenses - l.operating_expenditure__operating_manufacturing_expenses_prev_q) / ABS(NULLIF(l.operating_expenditure__operating_manufacturing_expenses_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.operating_expenditure__operating_manufacturing_expenses AS prior_yr_q,
        (l.operating_expenditure__operating_manufacturing_expenses - p.operating_expenditure__operating_manufacturing_expenses) / ABS(NULLIF(p.operating_expenditure__operating_manufacturing_expenses, 0)) * 100 AS yoy_pct
      ) AS operating_manufacturing_expenses,
      STRUCT(
        l.operating_expenditure__general_administration_expenses AS value,
        l.operating_expenditure__general_administration_expenses_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.operating_expenditure__general_administration_expenses - l.operating_expenditure__general_administration_expenses_prev_q) / ABS(NULLIF(l.operating_expenditure__general_administration_expenses_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.operating_expenditure__general_administration_expenses AS prior_yr_q,
        (l.operating_expenditure__general_administration_expenses - p.operating_expenditure__general_administration_expenses) / ABS(NULLIF(p.operating_expenditure__general_administration_expenses, 0)) * 100 AS yoy_pct
      ) AS general_administration_expenses,
      STRUCT(
        l.operating_expenditure__selling_distribution_expenses AS value,
        l.operating_expenditure__selling_distribution_expenses_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.operating_expenditure__selling_distribution_expenses - l.operating_expenditure__selling_distribution_expenses_prev_q) / ABS(NULLIF(l.operating_expenditure__selling_distribution_expenses_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.operating_expenditure__selling_distribution_expenses AS prior_yr_q,
        (l.operating_expenditure__selling_distribution_expenses - p.operating_expenditure__selling_distribution_expenses) / ABS(NULLIF(p.operating_expenditure__selling_distribution_expenses, 0)) * 100 AS yoy_pct
      ) AS selling_distribution_expenses,
      STRUCT(
        l.operating_expenditure__miscellaneous_expenses AS value,
        l.operating_expenditure__miscellaneous_expenses_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.operating_expenditure__miscellaneous_expenses - l.operating_expenditure__miscellaneous_expenses_prev_q) / ABS(NULLIF(l.operating_expenditure__miscellaneous_expenses_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.operating_expenditure__miscellaneous_expenses AS prior_yr_q,
        (l.operating_expenditure__miscellaneous_expenses - p.operating_expenditure__miscellaneous_expenses) / ABS(NULLIF(p.operating_expenditure__miscellaneous_expenses, 0)) * 100 AS yoy_pct
      ) AS miscellaneous_expenses,
      STRUCT(
        l.operating_expenditure__misc_expenses_written_off AS value,
        l.operating_expenditure__misc_expenses_written_off_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.operating_expenditure__misc_expenses_written_off - l.operating_expenditure__misc_expenses_written_off_prev_q) / ABS(NULLIF(l.operating_expenditure__misc_expenses_written_off_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.operating_expenditure__misc_expenses_written_off AS prior_yr_q,
        (l.operating_expenditure__misc_expenses_written_off - p.operating_expenditure__misc_expenses_written_off) / ABS(NULLIF(p.operating_expenditure__misc_expenses_written_off, 0)) * 100 AS yoy_pct
      ) AS misc_expenses_written_off,
      STRUCT(
        l.operating_expenditure__other_operating_expenses AS value,
        l.operating_expenditure__other_operating_expenses_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.operating_expenditure__other_operating_expenses - l.operating_expenditure__other_operating_expenses_prev_q) / ABS(NULLIF(l.operating_expenditure__other_operating_expenses_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.operating_expenditure__other_operating_expenses AS prior_yr_q,
        (l.operating_expenditure__other_operating_expenses - p.operating_expenditure__other_operating_expenses) / ABS(NULLIF(p.operating_expenditure__other_operating_expenses, 0)) * 100 AS yoy_pct
      ) AS other_operating_expenses,
      STRUCT(
        l.operating_expenditure__operating_expenses AS value,
        l.operating_expenditure__operating_expenses_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.operating_expenditure__operating_expenses - l.operating_expenditure__operating_expenses_prev_q) / ABS(NULLIF(l.operating_expenditure__operating_expenses_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.operating_expenditure__operating_expenses AS prior_yr_q,
        (l.operating_expenditure__operating_expenses - p.operating_expenditure__operating_expenses) / ABS(NULLIF(p.operating_expenditure__operating_expenses, 0)) * 100 AS yoy_pct
      ) AS operating_expenses,
      STRUCT(
        l.operating_expenditure__payment_to_provisions_for_employees AS value,
        l.operating_expenditure__payment_to_provisions_for_employees_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.operating_expenditure__payment_to_provisions_for_employees - l.operating_expenditure__payment_to_provisions_for_employees_prev_q) / ABS(NULLIF(l.operating_expenditure__payment_to_provisions_for_employees_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.operating_expenditure__payment_to_provisions_for_employees AS prior_yr_q,
        (l.operating_expenditure__payment_to_provisions_for_employees - p.operating_expenditure__payment_to_provisions_for_employees) / ABS(NULLIF(p.operating_expenditure__payment_to_provisions_for_employees, 0)) * 100 AS yoy_pct
      ) AS payment_to_provisions_for_employees,
      STRUCT(
        l.operating_expenditure__provisions_and_contingencies AS value,
        l.operating_expenditure__provisions_and_contingencies_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.operating_expenditure__provisions_and_contingencies - l.operating_expenditure__provisions_and_contingencies_prev_q) / ABS(NULLIF(l.operating_expenditure__provisions_and_contingencies_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.operating_expenditure__provisions_and_contingencies AS prior_yr_q,
        (l.operating_expenditure__provisions_and_contingencies - p.operating_expenditure__provisions_and_contingencies) / ABS(NULLIF(p.operating_expenditure__provisions_and_contingencies, 0)) * 100 AS yoy_pct
      ) AS provisions_and_contingencies,
      STRUCT(
        l.operating_expenditure__prior_period_expenses AS value,
        l.operating_expenditure__prior_period_expenses_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.operating_expenditure__prior_period_expenses - l.operating_expenditure__prior_period_expenses_prev_q) / ABS(NULLIF(l.operating_expenditure__prior_period_expenses_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.operating_expenditure__prior_period_expenses AS prior_yr_q,
        (l.operating_expenditure__prior_period_expenses - p.operating_expenditure__prior_period_expenses) / ABS(NULLIF(p.operating_expenditure__prior_period_expenses, 0)) * 100 AS yoy_pct
      ) AS prior_period_expenses,
      STRUCT(
        l.operating_expenditure__employees_separation_compensation AS value,
        l.operating_expenditure__employees_separation_compensation_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.operating_expenditure__employees_separation_compensation - l.operating_expenditure__employees_separation_compensation_prev_q) / ABS(NULLIF(l.operating_expenditure__employees_separation_compensation_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.operating_expenditure__employees_separation_compensation AS prior_yr_q,
        (l.operating_expenditure__employees_separation_compensation - p.operating_expenditure__employees_separation_compensation) / ABS(NULLIF(p.operating_expenditure__employees_separation_compensation, 0)) * 100 AS yoy_pct
      ) AS employees_separation_compensation,
      STRUCT(
        l.operating_expenditure__loss_on_foreign_exchange AS value,
        l.operating_expenditure__loss_on_foreign_exchange_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.operating_expenditure__loss_on_foreign_exchange - l.operating_expenditure__loss_on_foreign_exchange_prev_q) / ABS(NULLIF(l.operating_expenditure__loss_on_foreign_exchange_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.operating_expenditure__loss_on_foreign_exchange AS prior_yr_q,
        (l.operating_expenditure__loss_on_foreign_exchange - p.operating_expenditure__loss_on_foreign_exchange) / ABS(NULLIF(p.operating_expenditure__loss_on_foreign_exchange, 0)) * 100 AS yoy_pct
      ) AS loss_on_foreign_exchange,
      STRUCT(
        l.operating_expenditure__loss_on_foreign_exchange_loan AS value,
        l.operating_expenditure__loss_on_foreign_exchange_loan_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.operating_expenditure__loss_on_foreign_exchange_loan - l.operating_expenditure__loss_on_foreign_exchange_loan_prev_q) / ABS(NULLIF(l.operating_expenditure__loss_on_foreign_exchange_loan_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.operating_expenditure__loss_on_foreign_exchange_loan AS prior_yr_q,
        (l.operating_expenditure__loss_on_foreign_exchange_loan - p.operating_expenditure__loss_on_foreign_exchange_loan) / ABS(NULLIF(p.operating_expenditure__loss_on_foreign_exchange_loan, 0)) * 100 AS yoy_pct
      ) AS loss_on_foreign_exchange_loan,
      STRUCT(
        l.operating_expenditure__provision_for_dimulation_in_investment_assets AS value,
        l.operating_expenditure__provision_for_dimulation_in_investment_assets_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.operating_expenditure__provision_for_dimulation_in_investment_assets - l.operating_expenditure__provision_for_dimulation_in_investment_assets_prev_q) / ABS(NULLIF(l.operating_expenditure__provision_for_dimulation_in_investment_assets_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.operating_expenditure__provision_for_dimulation_in_investment_assets AS prior_yr_q,
        (l.operating_expenditure__provision_for_dimulation_in_investment_assets - p.operating_expenditure__provision_for_dimulation_in_investment_assets) / ABS(NULLIF(p.operating_expenditure__provision_for_dimulation_in_investment_assets, 0)) * 100 AS yoy_pct
      ) AS provision_for_dimulation_in_investment_assets,
      STRUCT(
        l.operating_expenditure__provision_for_impairment_od_assets AS value,
        l.operating_expenditure__provision_for_impairment_od_assets_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.operating_expenditure__provision_for_impairment_od_assets - l.operating_expenditure__provision_for_impairment_od_assets_prev_q) / ABS(NULLIF(l.operating_expenditure__provision_for_impairment_od_assets_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.operating_expenditure__provision_for_impairment_od_assets AS prior_yr_q,
        (l.operating_expenditure__provision_for_impairment_od_assets - p.operating_expenditure__provision_for_impairment_od_assets) / ABS(NULLIF(p.operating_expenditure__provision_for_impairment_od_assets, 0)) * 100 AS yoy_pct
      ) AS provision_for_impairment_od_assets,
      STRUCT(
        l.operating_expenditure__profit_loss_due_to_exchange_rate AS value,
        l.operating_expenditure__profit_loss_due_to_exchange_rate_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.operating_expenditure__profit_loss_due_to_exchange_rate - l.operating_expenditure__profit_loss_due_to_exchange_rate_prev_q) / ABS(NULLIF(l.operating_expenditure__profit_loss_due_to_exchange_rate_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.operating_expenditure__profit_loss_due_to_exchange_rate AS prior_yr_q,
        (l.operating_expenditure__profit_loss_due_to_exchange_rate - p.operating_expenditure__profit_loss_due_to_exchange_rate) / ABS(NULLIF(p.operating_expenditure__profit_loss_due_to_exchange_rate, 0)) * 100 AS yoy_pct
      ) AS profit_loss_due_to_exchange_rate,
      STRUCT(
        l.operating_expenditure__other_related_items AS value,
        l.operating_expenditure__other_related_items_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.operating_expenditure__other_related_items - l.operating_expenditure__other_related_items_prev_q) / ABS(NULLIF(l.operating_expenditure__other_related_items_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.operating_expenditure__other_related_items AS prior_yr_q,
        (l.operating_expenditure__other_related_items - p.operating_expenditure__other_related_items) / ABS(NULLIF(p.operating_expenditure__other_related_items, 0)) * 100 AS yoy_pct
      ) AS other_related_items,
      STRUCT(
        l.operating_expenditure__other_adjustments AS value,
        l.operating_expenditure__other_adjustments_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.operating_expenditure__other_adjustments - l.operating_expenditure__other_adjustments_prev_q) / ABS(NULLIF(l.operating_expenditure__other_adjustments_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.operating_expenditure__other_adjustments AS prior_yr_q,
        (l.operating_expenditure__other_adjustments - p.operating_expenditure__other_adjustments) / ABS(NULLIF(p.operating_expenditure__other_adjustments, 0)) * 100 AS yoy_pct
      ) AS other_adjustments
    ) AS operating_expenditure,
    STRUCT(
      STRUCT(
        l.profit_waterfall__value AS value,
        l.profit_waterfall__value_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.profit_waterfall__value - l.profit_waterfall__value_prev_q) / ABS(NULLIF(l.profit_waterfall__value_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.profit_waterfall__value AS prior_yr_q,
        (l.profit_waterfall__value - p.profit_waterfall__value) / ABS(NULLIF(p.profit_waterfall__value, 0)) * 100 AS yoy_pct
      ) AS value,
      STRUCT(
        l.profit_waterfall__operating_profit AS value,
        l.profit_waterfall__operating_profit_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.profit_waterfall__operating_profit - l.profit_waterfall__operating_profit_prev_q) / ABS(NULLIF(l.profit_waterfall__operating_profit_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.profit_waterfall__operating_profit AS prior_yr_q,
        (l.profit_waterfall__operating_profit - p.profit_waterfall__operating_profit) / ABS(NULLIF(p.profit_waterfall__operating_profit, 0)) * 100 AS yoy_pct
      ) AS operating_profit,
      STRUCT(
        l.profit_waterfall__operating_profit_before_prov_cont AS value,
        l.profit_waterfall__operating_profit_before_prov_cont_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.profit_waterfall__operating_profit_before_prov_cont - l.profit_waterfall__operating_profit_before_prov_cont_prev_q) / ABS(NULLIF(l.profit_waterfall__operating_profit_before_prov_cont_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.profit_waterfall__operating_profit_before_prov_cont AS prior_yr_q,
        (l.profit_waterfall__operating_profit_before_prov_cont - p.profit_waterfall__operating_profit_before_prov_cont) / ABS(NULLIF(p.profit_waterfall__operating_profit_before_prov_cont, 0)) * 100 AS yoy_pct
      ) AS operating_profit_before_prov_cont,
      STRUCT(
        l.profit_waterfall__pbidt_excl_oi AS value,
        l.profit_waterfall__pbidt_excl_oi_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.profit_waterfall__pbidt_excl_oi - l.profit_waterfall__pbidt_excl_oi_prev_q) / ABS(NULLIF(l.profit_waterfall__pbidt_excl_oi_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.profit_waterfall__pbidt_excl_oi AS prior_yr_q,
        (l.profit_waterfall__pbidt_excl_oi - p.profit_waterfall__pbidt_excl_oi) / ABS(NULLIF(p.profit_waterfall__pbidt_excl_oi, 0)) * 100 AS yoy_pct
      ) AS pbidt_excl_oi,
      STRUCT(
        l.profit_waterfall__pbdt AS value,
        l.profit_waterfall__pbdt_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.profit_waterfall__pbdt - l.profit_waterfall__pbdt_prev_q) / ABS(NULLIF(l.profit_waterfall__pbdt_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.profit_waterfall__pbdt AS prior_yr_q,
        (l.profit_waterfall__pbdt - p.profit_waterfall__pbdt) / ABS(NULLIF(p.profit_waterfall__pbdt, 0)) * 100 AS yoy_pct
      ) AS pbdt,
      STRUCT(
        l.profit_waterfall__depreciation AS value,
        l.profit_waterfall__depreciation_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.profit_waterfall__depreciation - l.profit_waterfall__depreciation_prev_q) / ABS(NULLIF(l.profit_waterfall__depreciation_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.profit_waterfall__depreciation AS prior_yr_q,
        (l.profit_waterfall__depreciation - p.profit_waterfall__depreciation) / ABS(NULLIF(p.profit_waterfall__depreciation, 0)) * 100 AS yoy_pct
      ) AS depreciation,
      STRUCT(
        l.profit_waterfall__interest AS value,
        l.profit_waterfall__interest_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.profit_waterfall__interest - l.profit_waterfall__interest_prev_q) / ABS(NULLIF(l.profit_waterfall__interest_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.profit_waterfall__interest AS prior_yr_q,
        (l.profit_waterfall__interest - p.profit_waterfall__interest) / ABS(NULLIF(p.profit_waterfall__interest, 0)) * 100 AS yoy_pct
      ) AS interest,
      STRUCT(
        l.profit_waterfall__interest_expended AS value,
        l.profit_waterfall__interest_expended_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.profit_waterfall__interest_expended - l.profit_waterfall__interest_expended_prev_q) / ABS(NULLIF(l.profit_waterfall__interest_expended_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.profit_waterfall__interest_expended AS prior_yr_q,
        (l.profit_waterfall__interest_expended - p.profit_waterfall__interest_expended) / ABS(NULLIF(p.profit_waterfall__interest_expended, 0)) * 100 AS yoy_pct
      ) AS interest_expended,
      STRUCT(
        l.profit_waterfall__pbt AS value,
        l.profit_waterfall__pbt_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.profit_waterfall__pbt - l.profit_waterfall__pbt_prev_q) / ABS(NULLIF(l.profit_waterfall__pbt_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.profit_waterfall__pbt AS prior_yr_q,
        (l.profit_waterfall__pbt - p.profit_waterfall__pbt) / ABS(NULLIF(p.profit_waterfall__pbt, 0)) * 100 AS yoy_pct
      ) AS pbt,
      STRUCT(
        l.profit_waterfall__exceptional_items AS value,
        l.profit_waterfall__exceptional_items_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.profit_waterfall__exceptional_items - l.profit_waterfall__exceptional_items_prev_q) / ABS(NULLIF(l.profit_waterfall__exceptional_items_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.profit_waterfall__exceptional_items AS prior_yr_q,
        (l.profit_waterfall__exceptional_items - p.profit_waterfall__exceptional_items) / ABS(NULLIF(p.profit_waterfall__exceptional_items, 0)) * 100 AS yoy_pct
      ) AS exceptional_items,
      STRUCT(
        l.profit_waterfall__other_exceoptional_items AS value,
        l.profit_waterfall__other_exceoptional_items_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.profit_waterfall__other_exceoptional_items - l.profit_waterfall__other_exceoptional_items_prev_q) / ABS(NULLIF(l.profit_waterfall__other_exceoptional_items_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.profit_waterfall__other_exceoptional_items AS prior_yr_q,
        (l.profit_waterfall__other_exceoptional_items - p.profit_waterfall__other_exceoptional_items) / ABS(NULLIF(p.profit_waterfall__other_exceoptional_items, 0)) * 100 AS yoy_pct
      ) AS other_exceoptional_items,
      STRUCT(
        l.profit_waterfall__extraordinary_items AS value,
        l.profit_waterfall__extraordinary_items_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.profit_waterfall__extraordinary_items - l.profit_waterfall__extraordinary_items_prev_q) / ABS(NULLIF(l.profit_waterfall__extraordinary_items_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.profit_waterfall__extraordinary_items AS prior_yr_q,
        (l.profit_waterfall__extraordinary_items - p.profit_waterfall__extraordinary_items) / ABS(NULLIF(p.profit_waterfall__extraordinary_items, 0)) * 100 AS yoy_pct
      ) AS extraordinary_items,
      STRUCT(
        l.profit_waterfall__other_exceptional_items AS value,
        l.profit_waterfall__other_exceptional_items_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.profit_waterfall__other_exceptional_items - l.profit_waterfall__other_exceptional_items_prev_q) / ABS(NULLIF(l.profit_waterfall__other_exceptional_items_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.profit_waterfall__other_exceptional_items AS prior_yr_q,
        (l.profit_waterfall__other_exceptional_items - p.profit_waterfall__other_exceptional_items) / ABS(NULLIF(p.profit_waterfall__other_exceptional_items, 0)) * 100 AS yoy_pct
      ) AS other_exceptional_items,
      STRUCT(
        l.profit_waterfall__prior_period_items AS value,
        l.profit_waterfall__prior_period_items_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.profit_waterfall__prior_period_items - l.profit_waterfall__prior_period_items_prev_q) / ABS(NULLIF(l.profit_waterfall__prior_period_items_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.profit_waterfall__prior_period_items AS prior_yr_q,
        (l.profit_waterfall__prior_period_items - p.profit_waterfall__prior_period_items) / ABS(NULLIF(p.profit_waterfall__prior_period_items, 0)) * 100 AS yoy_pct
      ) AS prior_period_items,
      STRUCT(
        l.profit_waterfall__prior_period_year_tax AS value,
        l.profit_waterfall__prior_period_year_tax_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.profit_waterfall__prior_period_year_tax - l.profit_waterfall__prior_period_year_tax_prev_q) / ABS(NULLIF(l.profit_waterfall__prior_period_year_tax_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.profit_waterfall__prior_period_year_tax AS prior_yr_q,
        (l.profit_waterfall__prior_period_year_tax - p.profit_waterfall__prior_period_year_tax) / ABS(NULLIF(p.profit_waterfall__prior_period_year_tax, 0)) * 100 AS yoy_pct
      ) AS prior_period_year_tax,
      STRUCT(
        l.profit_waterfall__current_tax AS value,
        l.profit_waterfall__current_tax_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.profit_waterfall__current_tax - l.profit_waterfall__current_tax_prev_q) / ABS(NULLIF(l.profit_waterfall__current_tax_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.profit_waterfall__current_tax AS prior_yr_q,
        (l.profit_waterfall__current_tax - p.profit_waterfall__current_tax) / ABS(NULLIF(p.profit_waterfall__current_tax, 0)) * 100 AS yoy_pct
      ) AS current_tax,
      STRUCT(
        l.profit_waterfall__deferred_tax AS value,
        l.profit_waterfall__deferred_tax_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.profit_waterfall__deferred_tax - l.profit_waterfall__deferred_tax_prev_q) / ABS(NULLIF(l.profit_waterfall__deferred_tax_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.profit_waterfall__deferred_tax AS prior_yr_q,
        (l.profit_waterfall__deferred_tax - p.profit_waterfall__deferred_tax) / ABS(NULLIF(p.profit_waterfall__deferred_tax, 0)) * 100 AS yoy_pct
      ) AS deferred_tax,
      STRUCT(
        l.profit_waterfall__mat_credit AS value,
        l.profit_waterfall__mat_credit_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.profit_waterfall__mat_credit - l.profit_waterfall__mat_credit_prev_q) / ABS(NULLIF(l.profit_waterfall__mat_credit_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.profit_waterfall__mat_credit AS prior_yr_q,
        (l.profit_waterfall__mat_credit - p.profit_waterfall__mat_credit) / ABS(NULLIF(p.profit_waterfall__mat_credit, 0)) * 100 AS yoy_pct
      ) AS mat_credit,
      STRUCT(
        l.profit_waterfall__fringe_benefit_tax AS value,
        l.profit_waterfall__fringe_benefit_tax_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.profit_waterfall__fringe_benefit_tax - l.profit_waterfall__fringe_benefit_tax_prev_q) / ABS(NULLIF(l.profit_waterfall__fringe_benefit_tax_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.profit_waterfall__fringe_benefit_tax AS prior_yr_q,
        (l.profit_waterfall__fringe_benefit_tax - p.profit_waterfall__fringe_benefit_tax) / ABS(NULLIF(p.profit_waterfall__fringe_benefit_tax, 0)) * 100 AS yoy_pct
      ) AS fringe_benefit_tax,
      STRUCT(
        l.profit_waterfall__other_taxes AS value,
        l.profit_waterfall__other_taxes_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.profit_waterfall__other_taxes - l.profit_waterfall__other_taxes_prev_q) / ABS(NULLIF(l.profit_waterfall__other_taxes_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.profit_waterfall__other_taxes AS prior_yr_q,
        (l.profit_waterfall__other_taxes - p.profit_waterfall__other_taxes) / ABS(NULLIF(p.profit_waterfall__other_taxes, 0)) * 100 AS yoy_pct
      ) AS other_taxes,
      STRUCT(
        l.profit_waterfall__tax AS value,
        l.profit_waterfall__tax_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.profit_waterfall__tax - l.profit_waterfall__tax_prev_q) / ABS(NULLIF(l.profit_waterfall__tax_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.profit_waterfall__tax AS prior_yr_q,
        (l.profit_waterfall__tax - p.profit_waterfall__tax) / ABS(NULLIF(p.profit_waterfall__tax, 0)) * 100 AS yoy_pct
      ) AS tax,
      STRUCT(
        l.profit_waterfall__minority_interest AS value,
        l.profit_waterfall__minority_interest_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.profit_waterfall__minority_interest - l.profit_waterfall__minority_interest_prev_q) / ABS(NULLIF(l.profit_waterfall__minority_interest_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.profit_waterfall__minority_interest AS prior_yr_q,
        (l.profit_waterfall__minority_interest - p.profit_waterfall__minority_interest) / ABS(NULLIF(p.profit_waterfall__minority_interest, 0)) * 100 AS yoy_pct
      ) AS minority_interest,
      STRUCT(
        l.profit_waterfall__minority_interest_comprehensive_income AS value,
        l.profit_waterfall__minority_interest_comprehensive_income_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.profit_waterfall__minority_interest_comprehensive_income - l.profit_waterfall__minority_interest_comprehensive_income_prev_q) / ABS(NULLIF(l.profit_waterfall__minority_interest_comprehensive_income_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.profit_waterfall__minority_interest_comprehensive_income AS prior_yr_q,
        (l.profit_waterfall__minority_interest_comprehensive_income - p.profit_waterfall__minority_interest_comprehensive_income) / ABS(NULLIF(p.profit_waterfall__minority_interest_comprehensive_income, 0)) * 100 AS yoy_pct
      ) AS minority_interest_comprehensive_income,
      STRUCT(
        l.profit_waterfall__shares_of_associates AS value,
        l.profit_waterfall__shares_of_associates_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.profit_waterfall__shares_of_associates - l.profit_waterfall__shares_of_associates_prev_q) / ABS(NULLIF(l.profit_waterfall__shares_of_associates_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.profit_waterfall__shares_of_associates AS prior_yr_q,
        (l.profit_waterfall__shares_of_associates - p.profit_waterfall__shares_of_associates) / ABS(NULLIF(p.profit_waterfall__shares_of_associates, 0)) * 100 AS yoy_pct
      ) AS shares_of_associates,
      STRUCT(
        l.profit_waterfall__consolidated_net_profit AS value,
        l.profit_waterfall__consolidated_net_profit_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.profit_waterfall__consolidated_net_profit - l.profit_waterfall__consolidated_net_profit_prev_q) / ABS(NULLIF(l.profit_waterfall__consolidated_net_profit_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.profit_waterfall__consolidated_net_profit AS prior_yr_q,
        (l.profit_waterfall__consolidated_net_profit - p.profit_waterfall__consolidated_net_profit) / ABS(NULLIF(p.profit_waterfall__consolidated_net_profit, 0)) * 100 AS yoy_pct
      ) AS consolidated_net_profit,
      STRUCT(
        l.profit_waterfall__net_profit_after_extrodinary_items AS value,
        l.profit_waterfall__net_profit_after_extrodinary_items_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.profit_waterfall__net_profit_after_extrodinary_items - l.profit_waterfall__net_profit_after_extrodinary_items_prev_q) / ABS(NULLIF(l.profit_waterfall__net_profit_after_extrodinary_items_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.profit_waterfall__net_profit_after_extrodinary_items AS prior_yr_q,
        (l.profit_waterfall__net_profit_after_extrodinary_items - p.profit_waterfall__net_profit_after_extrodinary_items) / ABS(NULLIF(p.profit_waterfall__net_profit_after_extrodinary_items, 0)) * 100 AS yoy_pct
      ) AS net_profit_after_extrodinary_items,
      STRUCT(
        l.profit_waterfall__net_profit_after_extraordinary_items AS value,
        l.profit_waterfall__net_profit_after_extraordinary_items_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.profit_waterfall__net_profit_after_extraordinary_items - l.profit_waterfall__net_profit_after_extraordinary_items_prev_q) / ABS(NULLIF(l.profit_waterfall__net_profit_after_extraordinary_items_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.profit_waterfall__net_profit_after_extraordinary_items AS prior_yr_q,
        (l.profit_waterfall__net_profit_after_extraordinary_items - p.profit_waterfall__net_profit_after_extraordinary_items) / ABS(NULLIF(p.profit_waterfall__net_profit_after_extraordinary_items, 0)) * 100 AS yoy_pct
      ) AS net_profit_after_extraordinary_items,
      STRUCT(
        l.profit_waterfall__net_profit_after_extraodinary_items AS value,
        l.profit_waterfall__net_profit_after_extraodinary_items_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.profit_waterfall__net_profit_after_extraodinary_items - l.profit_waterfall__net_profit_after_extraodinary_items_prev_q) / ABS(NULLIF(l.profit_waterfall__net_profit_after_extraodinary_items_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.profit_waterfall__net_profit_after_extraodinary_items AS prior_yr_q,
        (l.profit_waterfall__net_profit_after_extraodinary_items - p.profit_waterfall__net_profit_after_extraodinary_items) / ABS(NULLIF(p.profit_waterfall__net_profit_after_extraodinary_items, 0)) * 100 AS yoy_pct
      ) AS net_profit_after_extraodinary_items,
      STRUCT(
        l.profit_waterfall__discontinued_operation_net_of_tax AS value,
        l.profit_waterfall__discontinued_operation_net_of_tax_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.profit_waterfall__discontinued_operation_net_of_tax - l.profit_waterfall__discontinued_operation_net_of_tax_prev_q) / ABS(NULLIF(l.profit_waterfall__discontinued_operation_net_of_tax_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.profit_waterfall__discontinued_operation_net_of_tax AS prior_yr_q,
        (l.profit_waterfall__discontinued_operation_net_of_tax - p.profit_waterfall__discontinued_operation_net_of_tax) / ABS(NULLIF(p.profit_waterfall__discontinued_operation_net_of_tax, 0)) * 100 AS yoy_pct
      ) AS discontinued_operation_net_of_tax,
      STRUCT(
        l.profit_waterfall__other_comprehensive_incomes_net_of_tax AS value,
        l.profit_waterfall__other_comprehensive_incomes_net_of_tax_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.profit_waterfall__other_comprehensive_incomes_net_of_tax - l.profit_waterfall__other_comprehensive_incomes_net_of_tax_prev_q) / ABS(NULLIF(l.profit_waterfall__other_comprehensive_incomes_net_of_tax_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.profit_waterfall__other_comprehensive_incomes_net_of_tax AS prior_yr_q,
        (l.profit_waterfall__other_comprehensive_incomes_net_of_tax - p.profit_waterfall__other_comprehensive_incomes_net_of_tax) / ABS(NULLIF(p.profit_waterfall__other_comprehensive_incomes_net_of_tax, 0)) * 100 AS yoy_pct
      ) AS other_comprehensive_incomes_net_of_tax,
      STRUCT(
        l.profit_waterfall__total_comprehensive_income AS value,
        l.profit_waterfall__total_comprehensive_income_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.profit_waterfall__total_comprehensive_income - l.profit_waterfall__total_comprehensive_income_prev_q) / ABS(NULLIF(l.profit_waterfall__total_comprehensive_income_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.profit_waterfall__total_comprehensive_income AS prior_yr_q,
        (l.profit_waterfall__total_comprehensive_income - p.profit_waterfall__total_comprehensive_income) / ABS(NULLIF(p.profit_waterfall__total_comprehensive_income, 0)) * 100 AS yoy_pct
      ) AS total_comprehensive_income
    ) AS profit_waterfall,
    STRUCT(
      STRUCT(
        l.margins_eps__value AS value,
        l.margins_eps__value_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.margins_eps__value - l.margins_eps__value_prev_q) / ABS(NULLIF(l.margins_eps__value_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.margins_eps__value AS prior_yr_q,
        (l.margins_eps__value - p.margins_eps__value) / ABS(NULLIF(p.margins_eps__value, 0)) * 100 AS yoy_pct
      ) AS value,
      STRUCT(
        l.margins_eps__pbtm AS value,
        l.margins_eps__pbtm_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.margins_eps__pbtm - l.margins_eps__pbtm_prev_q) / ABS(NULLIF(l.margins_eps__pbtm_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.margins_eps__pbtm AS prior_yr_q,
        (l.margins_eps__pbtm - p.margins_eps__pbtm) / ABS(NULLIF(p.margins_eps__pbtm, 0)) * 100 AS yoy_pct
      ) AS pbtm,
      STRUCT(
        l.margins_eps__pbdtm AS value,
        l.margins_eps__pbdtm_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.margins_eps__pbdtm - l.margins_eps__pbdtm_prev_q) / ABS(NULLIF(l.margins_eps__pbdtm_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.margins_eps__pbdtm AS prior_yr_q,
        (l.margins_eps__pbdtm - p.margins_eps__pbdtm) / ABS(NULLIF(p.margins_eps__pbdtm, 0)) * 100 AS yoy_pct
      ) AS pbdtm,
      STRUCT(
        l.margins_eps__pbidtm AS value,
        l.margins_eps__pbidtm_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.margins_eps__pbidtm - l.margins_eps__pbidtm_prev_q) / ABS(NULLIF(l.margins_eps__pbidtm_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.margins_eps__pbidtm AS prior_yr_q,
        (l.margins_eps__pbidtm - p.margins_eps__pbidtm) / ABS(NULLIF(p.margins_eps__pbidtm, 0)) * 100 AS yoy_pct
      ) AS pbidtm,
      STRUCT(
        l.margins_eps__pbidtm_excl_oi AS value,
        l.margins_eps__pbidtm_excl_oi_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.margins_eps__pbidtm_excl_oi - l.margins_eps__pbidtm_excl_oi_prev_q) / ABS(NULLIF(l.margins_eps__pbidtm_excl_oi_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.margins_eps__pbidtm_excl_oi AS prior_yr_q,
        (l.margins_eps__pbidtm_excl_oi - p.margins_eps__pbidtm_excl_oi) / ABS(NULLIF(p.margins_eps__pbidtm_excl_oi, 0)) * 100 AS yoy_pct
      ) AS pbidtm_excl_oi,
      STRUCT(
        l.margins_eps__patm AS value,
        l.margins_eps__patm_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.margins_eps__patm - l.margins_eps__patm_prev_q) / ABS(NULLIF(l.margins_eps__patm_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.margins_eps__patm AS prior_yr_q,
        (l.margins_eps__patm - p.margins_eps__patm) / ABS(NULLIF(p.margins_eps__patm, 0)) * 100 AS yoy_pct
      ) AS patm,
      STRUCT(
        l.margins_eps__return_on_assets AS value,
        l.margins_eps__return_on_assets_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.margins_eps__return_on_assets - l.margins_eps__return_on_assets_prev_q) / ABS(NULLIF(l.margins_eps__return_on_assets_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.margins_eps__return_on_assets AS prior_yr_q,
        (l.margins_eps__return_on_assets - p.margins_eps__return_on_assets) / ABS(NULLIF(p.margins_eps__return_on_assets, 0)) * 100 AS yoy_pct
      ) AS return_on_assets,
      STRUCT(
        l.margins_eps__adj_calculated_eps_unit_curr AS value,
        l.margins_eps__adj_calculated_eps_unit_curr_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.margins_eps__adj_calculated_eps_unit_curr - l.margins_eps__adj_calculated_eps_unit_curr_prev_q) / ABS(NULLIF(l.margins_eps__adj_calculated_eps_unit_curr_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.margins_eps__adj_calculated_eps_unit_curr AS prior_yr_q,
        (l.margins_eps__adj_calculated_eps_unit_curr - p.margins_eps__adj_calculated_eps_unit_curr) / ABS(NULLIF(p.margins_eps__adj_calculated_eps_unit_curr, 0)) * 100 AS yoy_pct
      ) AS adj_calculated_eps_unit_curr,
      STRUCT(
        l.margins_eps__calculated_eps_unit_curr AS value,
        l.margins_eps__calculated_eps_unit_curr_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.margins_eps__calculated_eps_unit_curr - l.margins_eps__calculated_eps_unit_curr_prev_q) / ABS(NULLIF(l.margins_eps__calculated_eps_unit_curr_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.margins_eps__calculated_eps_unit_curr AS prior_yr_q,
        (l.margins_eps__calculated_eps_unit_curr - p.margins_eps__calculated_eps_unit_curr) / ABS(NULLIF(p.margins_eps__calculated_eps_unit_curr, 0)) * 100 AS yoy_pct
      ) AS calculated_eps_unit_curr,
      STRUCT(
        l.margins_eps__basic_eps_after_extraordinary_items AS value,
        l.margins_eps__basic_eps_after_extraordinary_items_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.margins_eps__basic_eps_after_extraordinary_items - l.margins_eps__basic_eps_after_extraordinary_items_prev_q) / ABS(NULLIF(l.margins_eps__basic_eps_after_extraordinary_items_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.margins_eps__basic_eps_after_extraordinary_items AS prior_yr_q,
        (l.margins_eps__basic_eps_after_extraordinary_items - p.margins_eps__basic_eps_after_extraordinary_items) / ABS(NULLIF(p.margins_eps__basic_eps_after_extraordinary_items, 0)) * 100 AS yoy_pct
      ) AS basic_eps_after_extraordinary_items,
      STRUCT(
        l.margins_eps__basic_eps_before_extraordinary_items AS value,
        l.margins_eps__basic_eps_before_extraordinary_items_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.margins_eps__basic_eps_before_extraordinary_items - l.margins_eps__basic_eps_before_extraordinary_items_prev_q) / ABS(NULLIF(l.margins_eps__basic_eps_before_extraordinary_items_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.margins_eps__basic_eps_before_extraordinary_items AS prior_yr_q,
        (l.margins_eps__basic_eps_before_extraordinary_items - p.margins_eps__basic_eps_before_extraordinary_items) / ABS(NULLIF(p.margins_eps__basic_eps_before_extraordinary_items, 0)) * 100 AS yoy_pct
      ) AS basic_eps_before_extraordinary_items,
      STRUCT(
        l.margins_eps__basic_eps_after_extraodinary_items AS value,
        l.margins_eps__basic_eps_after_extraodinary_items_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.margins_eps__basic_eps_after_extraodinary_items - l.margins_eps__basic_eps_after_extraodinary_items_prev_q) / ABS(NULLIF(l.margins_eps__basic_eps_after_extraodinary_items_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.margins_eps__basic_eps_after_extraodinary_items AS prior_yr_q,
        (l.margins_eps__basic_eps_after_extraodinary_items - p.margins_eps__basic_eps_after_extraodinary_items) / ABS(NULLIF(p.margins_eps__basic_eps_after_extraodinary_items, 0)) * 100 AS yoy_pct
      ) AS basic_eps_after_extraodinary_items,
      STRUCT(
        l.margins_eps__basic_eps_before_extraodinary_items AS value,
        l.margins_eps__basic_eps_before_extraodinary_items_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.margins_eps__basic_eps_before_extraodinary_items - l.margins_eps__basic_eps_before_extraodinary_items_prev_q) / ABS(NULLIF(l.margins_eps__basic_eps_before_extraodinary_items_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.margins_eps__basic_eps_before_extraodinary_items AS prior_yr_q,
        (l.margins_eps__basic_eps_before_extraodinary_items - p.margins_eps__basic_eps_before_extraodinary_items) / ABS(NULLIF(p.margins_eps__basic_eps_before_extraodinary_items, 0)) * 100 AS yoy_pct
      ) AS basic_eps_before_extraodinary_items,
      STRUCT(
        l.margins_eps__diluted_eps_after_extraordinary_items AS value,
        l.margins_eps__diluted_eps_after_extraordinary_items_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.margins_eps__diluted_eps_after_extraordinary_items - l.margins_eps__diluted_eps_after_extraordinary_items_prev_q) / ABS(NULLIF(l.margins_eps__diluted_eps_after_extraordinary_items_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.margins_eps__diluted_eps_after_extraordinary_items AS prior_yr_q,
        (l.margins_eps__diluted_eps_after_extraordinary_items - p.margins_eps__diluted_eps_after_extraordinary_items) / ABS(NULLIF(p.margins_eps__diluted_eps_after_extraordinary_items, 0)) * 100 AS yoy_pct
      ) AS diluted_eps_after_extraordinary_items,
      STRUCT(
        l.margins_eps__diluted_eps_before_extraordinary_items AS value,
        l.margins_eps__diluted_eps_before_extraordinary_items_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.margins_eps__diluted_eps_before_extraordinary_items - l.margins_eps__diluted_eps_before_extraordinary_items_prev_q) / ABS(NULLIF(l.margins_eps__diluted_eps_before_extraordinary_items_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.margins_eps__diluted_eps_before_extraordinary_items AS prior_yr_q,
        (l.margins_eps__diluted_eps_before_extraordinary_items - p.margins_eps__diluted_eps_before_extraordinary_items) / ABS(NULLIF(p.margins_eps__diluted_eps_before_extraordinary_items, 0)) * 100 AS yoy_pct
      ) AS diluted_eps_before_extraordinary_items,
      STRUCT(
        l.margins_eps__diluted_eps_after_extraodinary_items AS value,
        l.margins_eps__diluted_eps_after_extraodinary_items_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.margins_eps__diluted_eps_after_extraodinary_items - l.margins_eps__diluted_eps_after_extraodinary_items_prev_q) / ABS(NULLIF(l.margins_eps__diluted_eps_after_extraodinary_items_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.margins_eps__diluted_eps_after_extraodinary_items AS prior_yr_q,
        (l.margins_eps__diluted_eps_after_extraodinary_items - p.margins_eps__diluted_eps_after_extraodinary_items) / ABS(NULLIF(p.margins_eps__diluted_eps_after_extraodinary_items, 0)) * 100 AS yoy_pct
      ) AS diluted_eps_after_extraodinary_items,
      STRUCT(
        l.margins_eps__diluted_eps_before_extraodinary_items AS value,
        l.margins_eps__diluted_eps_before_extraodinary_items_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.margins_eps__diluted_eps_before_extraodinary_items - l.margins_eps__diluted_eps_before_extraodinary_items_prev_q) / ABS(NULLIF(l.margins_eps__diluted_eps_before_extraodinary_items_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.margins_eps__diluted_eps_before_extraodinary_items AS prior_yr_q,
        (l.margins_eps__diluted_eps_before_extraodinary_items - p.margins_eps__diluted_eps_before_extraodinary_items) / ABS(NULLIF(p.margins_eps__diluted_eps_before_extraodinary_items, 0)) * 100 AS yoy_pct
      ) AS diluted_eps_before_extraodinary_items,
      STRUCT(
        l.margins_eps__equity_capital AS value,
        l.margins_eps__equity_capital_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.margins_eps__equity_capital - l.margins_eps__equity_capital_prev_q) / ABS(NULLIF(l.margins_eps__equity_capital_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.margins_eps__equity_capital AS prior_yr_q,
        (l.margins_eps__equity_capital - p.margins_eps__equity_capital) / ABS(NULLIF(p.margins_eps__equity_capital, 0)) * 100 AS yoy_pct
      ) AS equity_capital,
      STRUCT(
        l.margins_eps__face_value AS value,
        l.margins_eps__face_value_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.margins_eps__face_value - l.margins_eps__face_value_prev_q) / ABS(NULLIF(l.margins_eps__face_value_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.margins_eps__face_value AS prior_yr_q,
        (l.margins_eps__face_value - p.margins_eps__face_value) / ABS(NULLIF(p.margins_eps__face_value, 0)) * 100 AS yoy_pct
      ) AS face_value,
      STRUCT(
        l.margins_eps__face_value_in_rs AS value,
        l.margins_eps__face_value_in_rs_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.margins_eps__face_value_in_rs - l.margins_eps__face_value_in_rs_prev_q) / ABS(NULLIF(l.margins_eps__face_value_in_rs_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.margins_eps__face_value_in_rs AS prior_yr_q,
        (l.margins_eps__face_value_in_rs - p.margins_eps__face_value_in_rs) / ABS(NULLIF(p.margins_eps__face_value_in_rs, 0)) * 100 AS yoy_pct
      ) AS face_value_in_rs,
      STRUCT(
        l.margins_eps__reserves AS value,
        l.margins_eps__reserves_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.margins_eps__reserves - l.margins_eps__reserves_prev_q) / ABS(NULLIF(l.margins_eps__reserves_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.margins_eps__reserves AS prior_yr_q,
        (l.margins_eps__reserves - p.margins_eps__reserves) / ABS(NULLIF(p.margins_eps__reserves, 0)) * 100 AS yoy_pct
      ) AS reserves
    ) AS margins_eps,
    STRUCT(
      STRUCT(
        l.banking_metrics__value AS value,
        l.banking_metrics__value_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.banking_metrics__value - l.banking_metrics__value_prev_q) / ABS(NULLIF(l.banking_metrics__value_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.banking_metrics__value AS prior_yr_q,
        (l.banking_metrics__value - p.banking_metrics__value) / ABS(NULLIF(p.banking_metrics__value, 0)) * 100 AS yoy_pct
      ) AS value,
      STRUCT(
        l.banking_metrics__of_gross_npas AS value,
        l.banking_metrics__of_gross_npas_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.banking_metrics__of_gross_npas - l.banking_metrics__of_gross_npas_prev_q) / ABS(NULLIF(l.banking_metrics__of_gross_npas_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.banking_metrics__of_gross_npas AS prior_yr_q,
        (l.banking_metrics__of_gross_npas - p.banking_metrics__of_gross_npas) / ABS(NULLIF(p.banking_metrics__of_gross_npas, 0)) * 100 AS yoy_pct
      ) AS of_gross_npas,
      STRUCT(
        l.banking_metrics__of_net_npas AS value,
        l.banking_metrics__of_net_npas_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.banking_metrics__of_net_npas - l.banking_metrics__of_net_npas_prev_q) / ABS(NULLIF(l.banking_metrics__of_net_npas_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.banking_metrics__of_net_npas AS prior_yr_q,
        (l.banking_metrics__of_net_npas - p.banking_metrics__of_net_npas) / ABS(NULLIF(p.banking_metrics__of_net_npas, 0)) * 100 AS yoy_pct
      ) AS of_net_npas,
      STRUCT(
        l.banking_metrics__amount_of_gross_npa AS value,
        l.banking_metrics__amount_of_gross_npa_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.banking_metrics__amount_of_gross_npa - l.banking_metrics__amount_of_gross_npa_prev_q) / ABS(NULLIF(l.banking_metrics__amount_of_gross_npa_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.banking_metrics__amount_of_gross_npa AS prior_yr_q,
        (l.banking_metrics__amount_of_gross_npa - p.banking_metrics__amount_of_gross_npa) / ABS(NULLIF(p.banking_metrics__amount_of_gross_npa, 0)) * 100 AS yoy_pct
      ) AS amount_of_gross_npa,
      STRUCT(
        l.banking_metrics__amount_of_net_npa AS value,
        l.banking_metrics__amount_of_net_npa_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.banking_metrics__amount_of_net_npa - l.banking_metrics__amount_of_net_npa_prev_q) / ABS(NULLIF(l.banking_metrics__amount_of_net_npa_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.banking_metrics__amount_of_net_npa AS prior_yr_q,
        (l.banking_metrics__amount_of_net_npa - p.banking_metrics__amount_of_net_npa) / ABS(NULLIF(p.banking_metrics__amount_of_net_npa, 0)) * 100 AS yoy_pct
      ) AS amount_of_net_npa,
      STRUCT(
        l.banking_metrics__gross_net_npa AS value,
        l.banking_metrics__gross_net_npa_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.banking_metrics__gross_net_npa - l.banking_metrics__gross_net_npa_prev_q) / ABS(NULLIF(l.banking_metrics__gross_net_npa_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.banking_metrics__gross_net_npa AS prior_yr_q,
        (l.banking_metrics__gross_net_npa - p.banking_metrics__gross_net_npa) / ABS(NULLIF(p.banking_metrics__gross_net_npa, 0)) * 100 AS yoy_pct
      ) AS gross_net_npa,
      STRUCT(
        l.banking_metrics__percentage_of_gross_net_npa AS value,
        l.banking_metrics__percentage_of_gross_net_npa_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.banking_metrics__percentage_of_gross_net_npa - l.banking_metrics__percentage_of_gross_net_npa_prev_q) / ABS(NULLIF(l.banking_metrics__percentage_of_gross_net_npa_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.banking_metrics__percentage_of_gross_net_npa AS prior_yr_q,
        (l.banking_metrics__percentage_of_gross_net_npa - p.banking_metrics__percentage_of_gross_net_npa) / ABS(NULLIF(p.banking_metrics__percentage_of_gross_net_npa, 0)) * 100 AS yoy_pct
      ) AS percentage_of_gross_net_npa,
      STRUCT(
        l.banking_metrics__provisions_coverage AS value,
        l.banking_metrics__provisions_coverage_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.banking_metrics__provisions_coverage - l.banking_metrics__provisions_coverage_prev_q) / ABS(NULLIF(l.banking_metrics__provisions_coverage_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.banking_metrics__provisions_coverage AS prior_yr_q,
        (l.banking_metrics__provisions_coverage - p.banking_metrics__provisions_coverage) / ABS(NULLIF(p.banking_metrics__provisions_coverage, 0)) * 100 AS yoy_pct
      ) AS provisions_coverage,
      STRUCT(
        l.banking_metrics__nim AS value,
        l.banking_metrics__nim_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.banking_metrics__nim - l.banking_metrics__nim_prev_q) / ABS(NULLIF(l.banking_metrics__nim_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.banking_metrics__nim AS prior_yr_q,
        (l.banking_metrics__nim - p.banking_metrics__nim) / ABS(NULLIF(p.banking_metrics__nim, 0)) * 100 AS yoy_pct
      ) AS nim,
      STRUCT(
        l.banking_metrics__no_of_atms AS value,
        l.banking_metrics__no_of_atms_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.banking_metrics__no_of_atms - l.banking_metrics__no_of_atms_prev_q) / ABS(NULLIF(l.banking_metrics__no_of_atms_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.banking_metrics__no_of_atms AS prior_yr_q,
        (l.banking_metrics__no_of_atms - p.banking_metrics__no_of_atms) / ABS(NULLIF(p.banking_metrics__no_of_atms, 0)) * 100 AS yoy_pct
      ) AS no_of_atms,
      STRUCT(
        l.banking_metrics__no_of_branches AS value,
        l.banking_metrics__no_of_branches_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.banking_metrics__no_of_branches - l.banking_metrics__no_of_branches_prev_q) / ABS(NULLIF(l.banking_metrics__no_of_branches_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.banking_metrics__no_of_branches AS prior_yr_q,
        (l.banking_metrics__no_of_branches - p.banking_metrics__no_of_branches) / ABS(NULLIF(p.banking_metrics__no_of_branches, 0)) * 100 AS yoy_pct
      ) AS no_of_branches,
      STRUCT(
        l.banking_metrics__no_of_employees AS value,
        l.banking_metrics__no_of_employees_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.banking_metrics__no_of_employees - l.banking_metrics__no_of_employees_prev_q) / ABS(NULLIF(l.banking_metrics__no_of_employees_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.banking_metrics__no_of_employees AS prior_yr_q,
        (l.banking_metrics__no_of_employees - p.banking_metrics__no_of_employees) / ABS(NULLIF(p.banking_metrics__no_of_employees, 0)) * 100 AS yoy_pct
      ) AS no_of_employees,
      STRUCT(
        l.banking_metrics__capital_adeqacy_ratio_basel_i AS value,
        l.banking_metrics__capital_adeqacy_ratio_basel_i_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.banking_metrics__capital_adeqacy_ratio_basel_i - l.banking_metrics__capital_adeqacy_ratio_basel_i_prev_q) / ABS(NULLIF(l.banking_metrics__capital_adeqacy_ratio_basel_i_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.banking_metrics__capital_adeqacy_ratio_basel_i AS prior_yr_q,
        (l.banking_metrics__capital_adeqacy_ratio_basel_i - p.banking_metrics__capital_adeqacy_ratio_basel_i) / ABS(NULLIF(p.banking_metrics__capital_adeqacy_ratio_basel_i, 0)) * 100 AS yoy_pct
      ) AS capital_adeqacy_ratio_basel_i,
      STRUCT(
        l.banking_metrics__capital_adeqacy_ratio_basel_ii AS value,
        l.banking_metrics__capital_adeqacy_ratio_basel_ii_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.banking_metrics__capital_adeqacy_ratio_basel_ii - l.banking_metrics__capital_adeqacy_ratio_basel_ii_prev_q) / ABS(NULLIF(l.banking_metrics__capital_adeqacy_ratio_basel_ii_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.banking_metrics__capital_adeqacy_ratio_basel_ii AS prior_yr_q,
        (l.banking_metrics__capital_adeqacy_ratio_basel_ii - p.banking_metrics__capital_adeqacy_ratio_basel_ii) / ABS(NULLIF(p.banking_metrics__capital_adeqacy_ratio_basel_ii, 0)) * 100 AS yoy_pct
      ) AS capital_adeqacy_ratio_basel_ii,
      STRUCT(
        l.banking_metrics__capital_adeqacy_ratio_basel_iii AS value,
        l.banking_metrics__capital_adeqacy_ratio_basel_iii_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.banking_metrics__capital_adeqacy_ratio_basel_iii - l.banking_metrics__capital_adeqacy_ratio_basel_iii_prev_q) / ABS(NULLIF(l.banking_metrics__capital_adeqacy_ratio_basel_iii_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.banking_metrics__capital_adeqacy_ratio_basel_iii AS prior_yr_q,
        (l.banking_metrics__capital_adeqacy_ratio_basel_iii - p.banking_metrics__capital_adeqacy_ratio_basel_iii) / ABS(NULLIF(p.banking_metrics__capital_adeqacy_ratio_basel_iii, 0)) * 100 AS yoy_pct
      ) AS capital_adeqacy_ratio_basel_iii,
      STRUCT(
        l.banking_metrics__tier_i_basel_i AS value,
        l.banking_metrics__tier_i_basel_i_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.banking_metrics__tier_i_basel_i - l.banking_metrics__tier_i_basel_i_prev_q) / ABS(NULLIF(l.banking_metrics__tier_i_basel_i_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.banking_metrics__tier_i_basel_i AS prior_yr_q,
        (l.banking_metrics__tier_i_basel_i - p.banking_metrics__tier_i_basel_i) / ABS(NULLIF(p.banking_metrics__tier_i_basel_i, 0)) * 100 AS yoy_pct
      ) AS tier_i_basel_i,
      STRUCT(
        l.banking_metrics__tier_2_basel_i AS value,
        l.banking_metrics__tier_2_basel_i_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.banking_metrics__tier_2_basel_i - l.banking_metrics__tier_2_basel_i_prev_q) / ABS(NULLIF(l.banking_metrics__tier_2_basel_i_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.banking_metrics__tier_2_basel_i AS prior_yr_q,
        (l.banking_metrics__tier_2_basel_i - p.banking_metrics__tier_2_basel_i) / ABS(NULLIF(p.banking_metrics__tier_2_basel_i, 0)) * 100 AS yoy_pct
      ) AS tier_2_basel_i,
      STRUCT(
        l.banking_metrics__tier_i_basel_ii AS value,
        l.banking_metrics__tier_i_basel_ii_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.banking_metrics__tier_i_basel_ii - l.banking_metrics__tier_i_basel_ii_prev_q) / ABS(NULLIF(l.banking_metrics__tier_i_basel_ii_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.banking_metrics__tier_i_basel_ii AS prior_yr_q,
        (l.banking_metrics__tier_i_basel_ii - p.banking_metrics__tier_i_basel_ii) / ABS(NULLIF(p.banking_metrics__tier_i_basel_ii, 0)) * 100 AS yoy_pct
      ) AS tier_i_basel_ii,
      STRUCT(
        l.banking_metrics__tier_2_basel_ii AS value,
        l.banking_metrics__tier_2_basel_ii_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.banking_metrics__tier_2_basel_ii - l.banking_metrics__tier_2_basel_ii_prev_q) / ABS(NULLIF(l.banking_metrics__tier_2_basel_ii_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.banking_metrics__tier_2_basel_ii AS prior_yr_q,
        (l.banking_metrics__tier_2_basel_ii - p.banking_metrics__tier_2_basel_ii) / ABS(NULLIF(p.banking_metrics__tier_2_basel_ii, 0)) * 100 AS yoy_pct
      ) AS tier_2_basel_ii,
      STRUCT(
        l.banking_metrics__tier_i_basel_iii AS value,
        l.banking_metrics__tier_i_basel_iii_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.banking_metrics__tier_i_basel_iii - l.banking_metrics__tier_i_basel_iii_prev_q) / ABS(NULLIF(l.banking_metrics__tier_i_basel_iii_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.banking_metrics__tier_i_basel_iii AS prior_yr_q,
        (l.banking_metrics__tier_i_basel_iii - p.banking_metrics__tier_i_basel_iii) / ABS(NULLIF(p.banking_metrics__tier_i_basel_iii, 0)) * 100 AS yoy_pct
      ) AS tier_i_basel_iii,
      STRUCT(
        l.banking_metrics__tier_2_basel_iii AS value,
        l.banking_metrics__tier_2_basel_iii_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.banking_metrics__tier_2_basel_iii - l.banking_metrics__tier_2_basel_iii_prev_q) / ABS(NULLIF(l.banking_metrics__tier_2_basel_iii_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.banking_metrics__tier_2_basel_iii AS prior_yr_q,
        (l.banking_metrics__tier_2_basel_iii - p.banking_metrics__tier_2_basel_iii) / ABS(NULLIF(p.banking_metrics__tier_2_basel_iii, 0)) * 100 AS yoy_pct
      ) AS tier_2_basel_iii,
      STRUCT(
        l.banking_metrics__casa AS value,
        l.banking_metrics__casa_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.banking_metrics__casa - l.banking_metrics__casa_prev_q) / ABS(NULLIF(l.banking_metrics__casa_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.banking_metrics__casa AS prior_yr_q,
        (l.banking_metrics__casa - p.banking_metrics__casa) / ABS(NULLIF(p.banking_metrics__casa, 0)) * 100 AS yoy_pct
      ) AS casa,
      STRUCT(
        l.banking_metrics__casa_amount AS value,
        l.banking_metrics__casa_amount_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.banking_metrics__casa_amount - l.banking_metrics__casa_amount_prev_q) / ABS(NULLIF(l.banking_metrics__casa_amount_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.banking_metrics__casa_amount AS prior_yr_q,
        (l.banking_metrics__casa_amount - p.banking_metrics__casa_amount) / ABS(NULLIF(p.banking_metrics__casa_amount, 0)) * 100 AS yoy_pct
      ) AS casa_amount,
      STRUCT(
        l.banking_metrics__interest_earned AS value,
        l.banking_metrics__interest_earned_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.banking_metrics__interest_earned - l.banking_metrics__interest_earned_prev_q) / ABS(NULLIF(l.banking_metrics__interest_earned_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.banking_metrics__interest_earned AS prior_yr_q,
        (l.banking_metrics__interest_earned - p.banking_metrics__interest_earned) / ABS(NULLIF(p.banking_metrics__interest_earned, 0)) * 100 AS yoy_pct
      ) AS interest_earned,
      STRUCT(
        l.banking_metrics__interest_discount_on_advances_bills AS value,
        l.banking_metrics__interest_discount_on_advances_bills_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.banking_metrics__interest_discount_on_advances_bills - l.banking_metrics__interest_discount_on_advances_bills_prev_q) / ABS(NULLIF(l.banking_metrics__interest_discount_on_advances_bills_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.banking_metrics__interest_discount_on_advances_bills AS prior_yr_q,
        (l.banking_metrics__interest_discount_on_advances_bills - p.banking_metrics__interest_discount_on_advances_bills) / ABS(NULLIF(p.banking_metrics__interest_discount_on_advances_bills, 0)) * 100 AS yoy_pct
      ) AS interest_discount_on_advances_bills,
      STRUCT(
        l.banking_metrics__interest_on_balances_with_rbi_other_inter_bank_funds AS value,
        l.banking_metrics__interest_on_balances_with_rbi_other_inter_bank_funds_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.banking_metrics__interest_on_balances_with_rbi_other_inter_bank_funds - l.banking_metrics__interest_on_balances_with_rbi_other_inter_bank_funds_prev_q) / ABS(NULLIF(l.banking_metrics__interest_on_balances_with_rbi_other_inter_bank_funds_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.banking_metrics__interest_on_balances_with_rbi_other_inter_bank_funds AS prior_yr_q,
        (l.banking_metrics__interest_on_balances_with_rbi_other_inter_bank_funds - p.banking_metrics__interest_on_balances_with_rbi_other_inter_bank_funds) / ABS(NULLIF(p.banking_metrics__interest_on_balances_with_rbi_other_inter_bank_funds, 0)) * 100 AS yoy_pct
      ) AS interest_on_balances_with_rbi_other_inter_bank_funds
    ) AS banking_metrics
  ) AS expenditure_growth
FROM lagged l
LEFT JOIN base p
  ON p.company_id = l.company_id
 AND COALESCE(p.flag, '') = COALESCE(l.flag, '')
 AND p.yyyymm = l.yyyymm - 100;
END
