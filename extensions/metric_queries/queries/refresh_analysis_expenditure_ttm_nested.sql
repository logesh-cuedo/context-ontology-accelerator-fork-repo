-- Routine: silverzone.refresh_analysis_expenditure_ttm_nested
-- Source: capable-code-486208-j8.silverzone

BEGIN
-- silverzone.analysis_expenditure_ttm_nested
-- Full nested expenditure TTM table.
-- Generated from silverzone.profit_and_loss_quarterly_expenditure_nested schema.
-- Covers every numeric leaf under expenditure, including children and grandchildren.
-- Each metric leaf is emitted as STRUCT(value, ttm), where ttm is the rolling
-- trailing-four-quarter sum over complete consecutive quarter windows.
CREATE OR REPLACE TABLE silverzone.analysis_expenditure_ttm_nested
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
)
SELECT
  company_id,
  company_name,
  sector,
  subsector,
  flag,
  yyyymm,
  value_basis,
  unit,
  MIN(yyyymm) OVER w AS ttm_start_yyyymm,
  STRUCT(
    STRUCT(
      STRUCT(
        operating_expenditure__value AS value,
        SUM(operating_expenditure__value) OVER w AS ttm
      ) AS value,
      STRUCT(
        operating_expenditure__increase_decrease_in_stocks AS value,
        SUM(operating_expenditure__increase_decrease_in_stocks) OVER w AS ttm
      ) AS increase_decrease_in_stocks,
      STRUCT(
        operating_expenditure__cost_of_services_raw_materials AS value,
        SUM(operating_expenditure__cost_of_services_raw_materials) OVER w AS ttm
      ) AS cost_of_services_raw_materials,
      STRUCT(
        operating_expenditure__purchase_of_finished_goods AS value,
        SUM(operating_expenditure__purchase_of_finished_goods) OVER w AS ttm
      ) AS purchase_of_finished_goods,
      STRUCT(
        operating_expenditure__electricity_power_fuel_cost AS value,
        SUM(operating_expenditure__electricity_power_fuel_cost) OVER w AS ttm
      ) AS electricity_power_fuel_cost,
      STRUCT(
        operating_expenditure__employee_cost AS value,
        SUM(operating_expenditure__employee_cost) OVER w AS ttm
      ) AS employee_cost,
      STRUCT(
        operating_expenditure__operating_manufacturing_expenses AS value,
        SUM(operating_expenditure__operating_manufacturing_expenses) OVER w AS ttm
      ) AS operating_manufacturing_expenses,
      STRUCT(
        operating_expenditure__general_administration_expenses AS value,
        SUM(operating_expenditure__general_administration_expenses) OVER w AS ttm
      ) AS general_administration_expenses,
      STRUCT(
        operating_expenditure__selling_distribution_expenses AS value,
        SUM(operating_expenditure__selling_distribution_expenses) OVER w AS ttm
      ) AS selling_distribution_expenses,
      STRUCT(
        operating_expenditure__miscellaneous_expenses AS value,
        SUM(operating_expenditure__miscellaneous_expenses) OVER w AS ttm
      ) AS miscellaneous_expenses,
      STRUCT(
        operating_expenditure__misc_expenses_written_off AS value,
        SUM(operating_expenditure__misc_expenses_written_off) OVER w AS ttm
      ) AS misc_expenses_written_off,
      STRUCT(
        operating_expenditure__other_operating_expenses AS value,
        SUM(operating_expenditure__other_operating_expenses) OVER w AS ttm
      ) AS other_operating_expenses,
      STRUCT(
        operating_expenditure__operating_expenses AS value,
        SUM(operating_expenditure__operating_expenses) OVER w AS ttm
      ) AS operating_expenses,
      STRUCT(
        operating_expenditure__payment_to_provisions_for_employees AS value,
        SUM(operating_expenditure__payment_to_provisions_for_employees) OVER w AS ttm
      ) AS payment_to_provisions_for_employees,
      STRUCT(
        operating_expenditure__provisions_and_contingencies AS value,
        SUM(operating_expenditure__provisions_and_contingencies) OVER w AS ttm
      ) AS provisions_and_contingencies,
      STRUCT(
        operating_expenditure__prior_period_expenses AS value,
        SUM(operating_expenditure__prior_period_expenses) OVER w AS ttm
      ) AS prior_period_expenses,
      STRUCT(
        operating_expenditure__employees_separation_compensation AS value,
        SUM(operating_expenditure__employees_separation_compensation) OVER w AS ttm
      ) AS employees_separation_compensation,
      STRUCT(
        operating_expenditure__loss_on_foreign_exchange AS value,
        SUM(operating_expenditure__loss_on_foreign_exchange) OVER w AS ttm
      ) AS loss_on_foreign_exchange,
      STRUCT(
        operating_expenditure__loss_on_foreign_exchange_loan AS value,
        SUM(operating_expenditure__loss_on_foreign_exchange_loan) OVER w AS ttm
      ) AS loss_on_foreign_exchange_loan,
      STRUCT(
        operating_expenditure__provision_for_dimulation_in_investment_assets AS value,
        SUM(operating_expenditure__provision_for_dimulation_in_investment_assets) OVER w AS ttm
      ) AS provision_for_dimulation_in_investment_assets,
      STRUCT(
        operating_expenditure__provision_for_impairment_od_assets AS value,
        SUM(operating_expenditure__provision_for_impairment_od_assets) OVER w AS ttm
      ) AS provision_for_impairment_od_assets,
      STRUCT(
        operating_expenditure__profit_loss_due_to_exchange_rate AS value,
        SUM(operating_expenditure__profit_loss_due_to_exchange_rate) OVER w AS ttm
      ) AS profit_loss_due_to_exchange_rate,
      STRUCT(
        operating_expenditure__other_related_items AS value,
        SUM(operating_expenditure__other_related_items) OVER w AS ttm
      ) AS other_related_items,
      STRUCT(
        operating_expenditure__other_adjustments AS value,
        SUM(operating_expenditure__other_adjustments) OVER w AS ttm
      ) AS other_adjustments
    ) AS operating_expenditure,
    STRUCT(
      STRUCT(
        profit_waterfall__value AS value,
        SUM(profit_waterfall__value) OVER w AS ttm
      ) AS value,
      STRUCT(
        profit_waterfall__operating_profit AS value,
        SUM(profit_waterfall__operating_profit) OVER w AS ttm
      ) AS operating_profit,
      STRUCT(
        profit_waterfall__operating_profit_before_prov_cont AS value,
        SUM(profit_waterfall__operating_profit_before_prov_cont) OVER w AS ttm
      ) AS operating_profit_before_prov_cont,
      STRUCT(
        profit_waterfall__pbidt_excl_oi AS value,
        SUM(profit_waterfall__pbidt_excl_oi) OVER w AS ttm
      ) AS pbidt_excl_oi,
      STRUCT(
        profit_waterfall__pbdt AS value,
        SUM(profit_waterfall__pbdt) OVER w AS ttm
      ) AS pbdt,
      STRUCT(
        profit_waterfall__depreciation AS value,
        SUM(profit_waterfall__depreciation) OVER w AS ttm
      ) AS depreciation,
      STRUCT(
        profit_waterfall__interest AS value,
        SUM(profit_waterfall__interest) OVER w AS ttm
      ) AS interest,
      STRUCT(
        profit_waterfall__interest_expended AS value,
        SUM(profit_waterfall__interest_expended) OVER w AS ttm
      ) AS interest_expended,
      STRUCT(
        profit_waterfall__pbt AS value,
        SUM(profit_waterfall__pbt) OVER w AS ttm
      ) AS pbt,
      STRUCT(
        profit_waterfall__exceptional_items AS value,
        SUM(profit_waterfall__exceptional_items) OVER w AS ttm
      ) AS exceptional_items,
      STRUCT(
        profit_waterfall__other_exceoptional_items AS value,
        SUM(profit_waterfall__other_exceoptional_items) OVER w AS ttm
      ) AS other_exceoptional_items,
      STRUCT(
        profit_waterfall__extraordinary_items AS value,
        SUM(profit_waterfall__extraordinary_items) OVER w AS ttm
      ) AS extraordinary_items,
      STRUCT(
        profit_waterfall__other_exceptional_items AS value,
        SUM(profit_waterfall__other_exceptional_items) OVER w AS ttm
      ) AS other_exceptional_items,
      STRUCT(
        profit_waterfall__prior_period_items AS value,
        SUM(profit_waterfall__prior_period_items) OVER w AS ttm
      ) AS prior_period_items,
      STRUCT(
        profit_waterfall__prior_period_year_tax AS value,
        SUM(profit_waterfall__prior_period_year_tax) OVER w AS ttm
      ) AS prior_period_year_tax,
      STRUCT(
        profit_waterfall__current_tax AS value,
        SUM(profit_waterfall__current_tax) OVER w AS ttm
      ) AS current_tax,
      STRUCT(
        profit_waterfall__deferred_tax AS value,
        SUM(profit_waterfall__deferred_tax) OVER w AS ttm
      ) AS deferred_tax,
      STRUCT(
        profit_waterfall__mat_credit AS value,
        SUM(profit_waterfall__mat_credit) OVER w AS ttm
      ) AS mat_credit,
      STRUCT(
        profit_waterfall__fringe_benefit_tax AS value,
        SUM(profit_waterfall__fringe_benefit_tax) OVER w AS ttm
      ) AS fringe_benefit_tax,
      STRUCT(
        profit_waterfall__other_taxes AS value,
        SUM(profit_waterfall__other_taxes) OVER w AS ttm
      ) AS other_taxes,
      STRUCT(
        profit_waterfall__tax AS value,
        SUM(profit_waterfall__tax) OVER w AS ttm
      ) AS tax,
      STRUCT(
        profit_waterfall__minority_interest AS value,
        SUM(profit_waterfall__minority_interest) OVER w AS ttm
      ) AS minority_interest,
      STRUCT(
        profit_waterfall__minority_interest_comprehensive_income AS value,
        SUM(profit_waterfall__minority_interest_comprehensive_income) OVER w AS ttm
      ) AS minority_interest_comprehensive_income,
      STRUCT(
        profit_waterfall__shares_of_associates AS value,
        SUM(profit_waterfall__shares_of_associates) OVER w AS ttm
      ) AS shares_of_associates,
      STRUCT(
        profit_waterfall__consolidated_net_profit AS value,
        SUM(profit_waterfall__consolidated_net_profit) OVER w AS ttm
      ) AS consolidated_net_profit,
      STRUCT(
        profit_waterfall__net_profit_after_extrodinary_items AS value,
        SUM(profit_waterfall__net_profit_after_extrodinary_items) OVER w AS ttm
      ) AS net_profit_after_extrodinary_items,
      STRUCT(
        profit_waterfall__net_profit_after_extraordinary_items AS value,
        SUM(profit_waterfall__net_profit_after_extraordinary_items) OVER w AS ttm
      ) AS net_profit_after_extraordinary_items,
      STRUCT(
        profit_waterfall__net_profit_after_extraodinary_items AS value,
        SUM(profit_waterfall__net_profit_after_extraodinary_items) OVER w AS ttm
      ) AS net_profit_after_extraodinary_items,
      STRUCT(
        profit_waterfall__discontinued_operation_net_of_tax AS value,
        SUM(profit_waterfall__discontinued_operation_net_of_tax) OVER w AS ttm
      ) AS discontinued_operation_net_of_tax,
      STRUCT(
        profit_waterfall__other_comprehensive_incomes_net_of_tax AS value,
        SUM(profit_waterfall__other_comprehensive_incomes_net_of_tax) OVER w AS ttm
      ) AS other_comprehensive_incomes_net_of_tax,
      STRUCT(
        profit_waterfall__total_comprehensive_income AS value,
        SUM(profit_waterfall__total_comprehensive_income) OVER w AS ttm
      ) AS total_comprehensive_income
    ) AS profit_waterfall,
    STRUCT(
      STRUCT(
        margins_eps__value AS value,
        SUM(margins_eps__value) OVER w AS ttm
      ) AS value,
      STRUCT(
        margins_eps__pbtm AS value,
        SUM(margins_eps__pbtm) OVER w AS ttm
      ) AS pbtm,
      STRUCT(
        margins_eps__pbdtm AS value,
        SUM(margins_eps__pbdtm) OVER w AS ttm
      ) AS pbdtm,
      STRUCT(
        margins_eps__pbidtm AS value,
        SUM(margins_eps__pbidtm) OVER w AS ttm
      ) AS pbidtm,
      STRUCT(
        margins_eps__pbidtm_excl_oi AS value,
        SUM(margins_eps__pbidtm_excl_oi) OVER w AS ttm
      ) AS pbidtm_excl_oi,
      STRUCT(
        margins_eps__patm AS value,
        SUM(margins_eps__patm) OVER w AS ttm
      ) AS patm,
      STRUCT(
        margins_eps__return_on_assets AS value,
        SUM(margins_eps__return_on_assets) OVER w AS ttm
      ) AS return_on_assets,
      STRUCT(
        margins_eps__adj_calculated_eps_unit_curr AS value,
        SUM(margins_eps__adj_calculated_eps_unit_curr) OVER w AS ttm
      ) AS adj_calculated_eps_unit_curr,
      STRUCT(
        margins_eps__calculated_eps_unit_curr AS value,
        SUM(margins_eps__calculated_eps_unit_curr) OVER w AS ttm
      ) AS calculated_eps_unit_curr,
      STRUCT(
        margins_eps__basic_eps_after_extraordinary_items AS value,
        SUM(margins_eps__basic_eps_after_extraordinary_items) OVER w AS ttm
      ) AS basic_eps_after_extraordinary_items,
      STRUCT(
        margins_eps__basic_eps_before_extraordinary_items AS value,
        SUM(margins_eps__basic_eps_before_extraordinary_items) OVER w AS ttm
      ) AS basic_eps_before_extraordinary_items,
      STRUCT(
        margins_eps__basic_eps_after_extraodinary_items AS value,
        SUM(margins_eps__basic_eps_after_extraodinary_items) OVER w AS ttm
      ) AS basic_eps_after_extraodinary_items,
      STRUCT(
        margins_eps__basic_eps_before_extraodinary_items AS value,
        SUM(margins_eps__basic_eps_before_extraodinary_items) OVER w AS ttm
      ) AS basic_eps_before_extraodinary_items,
      STRUCT(
        margins_eps__diluted_eps_after_extraordinary_items AS value,
        SUM(margins_eps__diluted_eps_after_extraordinary_items) OVER w AS ttm
      ) AS diluted_eps_after_extraordinary_items,
      STRUCT(
        margins_eps__diluted_eps_before_extraordinary_items AS value,
        SUM(margins_eps__diluted_eps_before_extraordinary_items) OVER w AS ttm
      ) AS diluted_eps_before_extraordinary_items,
      STRUCT(
        margins_eps__diluted_eps_after_extraodinary_items AS value,
        SUM(margins_eps__diluted_eps_after_extraodinary_items) OVER w AS ttm
      ) AS diluted_eps_after_extraodinary_items,
      STRUCT(
        margins_eps__diluted_eps_before_extraodinary_items AS value,
        SUM(margins_eps__diluted_eps_before_extraodinary_items) OVER w AS ttm
      ) AS diluted_eps_before_extraodinary_items,
      STRUCT(
        margins_eps__equity_capital AS value,
        SUM(margins_eps__equity_capital) OVER w AS ttm
      ) AS equity_capital,
      STRUCT(
        margins_eps__face_value AS value,
        SUM(margins_eps__face_value) OVER w AS ttm
      ) AS face_value,
      STRUCT(
        margins_eps__face_value_in_rs AS value,
        SUM(margins_eps__face_value_in_rs) OVER w AS ttm
      ) AS face_value_in_rs,
      STRUCT(
        margins_eps__reserves AS value,
        SUM(margins_eps__reserves) OVER w AS ttm
      ) AS reserves
    ) AS margins_eps,
    STRUCT(
      STRUCT(
        banking_metrics__value AS value,
        SUM(banking_metrics__value) OVER w AS ttm
      ) AS value,
      STRUCT(
        banking_metrics__of_gross_npas AS value,
        SUM(banking_metrics__of_gross_npas) OVER w AS ttm
      ) AS of_gross_npas,
      STRUCT(
        banking_metrics__of_net_npas AS value,
        SUM(banking_metrics__of_net_npas) OVER w AS ttm
      ) AS of_net_npas,
      STRUCT(
        banking_metrics__amount_of_gross_npa AS value,
        SUM(banking_metrics__amount_of_gross_npa) OVER w AS ttm
      ) AS amount_of_gross_npa,
      STRUCT(
        banking_metrics__amount_of_net_npa AS value,
        SUM(banking_metrics__amount_of_net_npa) OVER w AS ttm
      ) AS amount_of_net_npa,
      STRUCT(
        banking_metrics__gross_net_npa AS value,
        SUM(banking_metrics__gross_net_npa) OVER w AS ttm
      ) AS gross_net_npa,
      STRUCT(
        banking_metrics__percentage_of_gross_net_npa AS value,
        SUM(banking_metrics__percentage_of_gross_net_npa) OVER w AS ttm
      ) AS percentage_of_gross_net_npa,
      STRUCT(
        banking_metrics__provisions_coverage AS value,
        SUM(banking_metrics__provisions_coverage) OVER w AS ttm
      ) AS provisions_coverage,
      STRUCT(
        banking_metrics__nim AS value,
        SUM(banking_metrics__nim) OVER w AS ttm
      ) AS nim,
      STRUCT(
        banking_metrics__no_of_atms AS value,
        SUM(banking_metrics__no_of_atms) OVER w AS ttm
      ) AS no_of_atms,
      STRUCT(
        banking_metrics__no_of_branches AS value,
        SUM(banking_metrics__no_of_branches) OVER w AS ttm
      ) AS no_of_branches,
      STRUCT(
        banking_metrics__no_of_employees AS value,
        SUM(banking_metrics__no_of_employees) OVER w AS ttm
      ) AS no_of_employees,
      STRUCT(
        banking_metrics__capital_adeqacy_ratio_basel_i AS value,
        SUM(banking_metrics__capital_adeqacy_ratio_basel_i) OVER w AS ttm
      ) AS capital_adeqacy_ratio_basel_i,
      STRUCT(
        banking_metrics__capital_adeqacy_ratio_basel_ii AS value,
        SUM(banking_metrics__capital_adeqacy_ratio_basel_ii) OVER w AS ttm
      ) AS capital_adeqacy_ratio_basel_ii,
      STRUCT(
        banking_metrics__capital_adeqacy_ratio_basel_iii AS value,
        SUM(banking_metrics__capital_adeqacy_ratio_basel_iii) OVER w AS ttm
      ) AS capital_adeqacy_ratio_basel_iii,
      STRUCT(
        banking_metrics__tier_i_basel_i AS value,
        SUM(banking_metrics__tier_i_basel_i) OVER w AS ttm
      ) AS tier_i_basel_i,
      STRUCT(
        banking_metrics__tier_2_basel_i AS value,
        SUM(banking_metrics__tier_2_basel_i) OVER w AS ttm
      ) AS tier_2_basel_i,
      STRUCT(
        banking_metrics__tier_i_basel_ii AS value,
        SUM(banking_metrics__tier_i_basel_ii) OVER w AS ttm
      ) AS tier_i_basel_ii,
      STRUCT(
        banking_metrics__tier_2_basel_ii AS value,
        SUM(banking_metrics__tier_2_basel_ii) OVER w AS ttm
      ) AS tier_2_basel_ii,
      STRUCT(
        banking_metrics__tier_i_basel_iii AS value,
        SUM(banking_metrics__tier_i_basel_iii) OVER w AS ttm
      ) AS tier_i_basel_iii,
      STRUCT(
        banking_metrics__tier_2_basel_iii AS value,
        SUM(banking_metrics__tier_2_basel_iii) OVER w AS ttm
      ) AS tier_2_basel_iii,
      STRUCT(
        banking_metrics__casa AS value,
        SUM(banking_metrics__casa) OVER w AS ttm
      ) AS casa,
      STRUCT(
        banking_metrics__casa_amount AS value,
        SUM(banking_metrics__casa_amount) OVER w AS ttm
      ) AS casa_amount,
      STRUCT(
        banking_metrics__interest_earned AS value,
        SUM(banking_metrics__interest_earned) OVER w AS ttm
      ) AS interest_earned,
      STRUCT(
        banking_metrics__interest_discount_on_advances_bills AS value,
        SUM(banking_metrics__interest_discount_on_advances_bills) OVER w AS ttm
      ) AS interest_discount_on_advances_bills,
      STRUCT(
        banking_metrics__interest_on_balances_with_rbi_other_inter_bank_funds AS value,
        SUM(banking_metrics__interest_on_balances_with_rbi_other_inter_bank_funds) OVER w AS ttm
      ) AS interest_on_balances_with_rbi_other_inter_bank_funds
    ) AS banking_metrics
  ) AS expenditure_ttm
FROM base
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
