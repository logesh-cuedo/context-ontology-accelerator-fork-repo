-- Routine: silverzone.refresh_analysis_expenditure_yearly_growth_nested
-- Source: capable-code-486208-j8.silverzone

BEGIN
-- silverzone.analysis_expenditure_yearly_growth_nested
-- Full nested expenditure yearly growth table.
-- Generated from silverzone.profit_and_loss_yearly_expenditure_nested_merged schema.
-- Covers every numeric leaf under expenditure, including children and grandchildren.
-- Each metric leaf is emitted as STRUCT(value, prev_yr, yoy_pct, value_3y_back,
-- cagr_3y_pct, value_5y_back, cagr_5y_pct).
-- Growth convention: (cur - prev) / ABS(NULLIF(prev, 0)) * 100.
-- CAGR is positive-base only and uses the actual month span between period ends.
CREATE OR REPLACE TABLE silverzone.analysis_expenditure_yearly_growth_nested
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
    expenditure.increase_decrease_in_stock.value AS increase_decrease_in_stock__value,
    expenditure.increase_decrease_in_stock.opening_work_in_progress AS increase_decrease_in_stock__opening_work_in_progress,
    expenditure.increase_decrease_in_stock.opening_finished_goods AS increase_decrease_in_stock__opening_finished_goods,
    expenditure.increase_decrease_in_stock.opening_shares_units_and_bonds AS increase_decrease_in_stock__opening_shares_units_and_bonds,
    expenditure.increase_decrease_in_stock.other_opening_balances AS increase_decrease_in_stock__other_opening_balances,
    expenditure.increase_decrease_in_stock.less_closing_work_in_progress AS increase_decrease_in_stock__less_closing_work_in_progress,
    expenditure.increase_decrease_in_stock.less_closing_finished_goods AS increase_decrease_in_stock__less_closing_finished_goods,
    expenditure.increase_decrease_in_stock.less_closing_shares_units_and_bonds AS increase_decrease_in_stock__less_closing_shares_units_and_bonds,
    expenditure.increase_decrease_in_stock.less_other_closing_balances AS increase_decrease_in_stock__less_other_closing_balances,
    expenditure.increase_decrease_in_stock.inter_division_transfer_in_transits AS increase_decrease_in_stock__inter_division_transfer_in_transits,
    expenditure.increase_decrease_in_stock.excise_duty_on_stock_adjustments AS increase_decrease_in_stock__excise_duty_on_stock_adjustments,
    expenditure.increase_decrease_in_stock.stock_capitalised AS increase_decrease_in_stock__stock_capitalised,
    expenditure.raw_material_consumed.value AS raw_material_consumed__value,
    expenditure.raw_material_consumed.opening_raw_materials AS raw_material_consumed__opening_raw_materials,
    expenditure.raw_material_consumed.purchases_raw_materials AS raw_material_consumed__purchases_raw_materials,
    expenditure.raw_material_consumed.closing_raw_materials AS raw_material_consumed__closing_raw_materials,
    expenditure.raw_material_consumed.other_direct_purchases_brought_in_cost AS raw_material_consumed__other_direct_purchases_brought_in_cost,
    expenditure.raw_material_consumed.stock_on_amalgamation AS raw_material_consumed__stock_on_amalgamation,
    expenditure.raw_material_consumed.other_raw_material_cost AS raw_material_consumed__other_raw_material_cost,
    expenditure.raw_material_consumed.raw_material_consumed_capitalised AS raw_material_consumed__raw_material_consumed_capitalised,
    expenditure.power_fuel_cost AS power_fuel_cost,
    expenditure.electricity_power AS electricity_power,
    expenditure.less_captive_consumption_of_power AS less_captive_consumption_of_power,
    expenditure.oil_fuel_natural_gas AS oil_fuel_natural_gas,
    expenditure.less_captive_consumption_of_fuel AS less_captive_consumption_of_fuel,
    expenditure.coals_etc AS coals_etc,
    expenditure.other_power_fuel AS other_power_fuel,
    expenditure.power_fuel_capitalised AS power_fuel_capitalised,
    expenditure.employee_cost.value AS employee_cost__value,
    expenditure.employee_cost.salaries_wages_bonus AS employee_cost__salaries_wages_bonus,
    expenditure.employee_cost.contributions_to_epf_pension_funds AS employee_cost__contributions_to_epf_pension_funds,
    expenditure.employee_cost.workmen_and_staff_welfare_expenses AS employee_cost__workmen_and_staff_welfare_expenses,
    expenditure.employee_cost.gratuity_ex_gratia AS employee_cost__gratuity_ex_gratia,
    expenditure.employee_cost.retrenchment_workers_vrs AS employee_cost__retrenchment_workers_vrs,
    expenditure.employee_cost.leave_travel_allowance AS employee_cost__leave_travel_allowance,
    expenditure.employee_cost.leave_encashment AS employee_cost__leave_encashment,
    expenditure.employee_cost.amortisation_of_deferred_stock_compensation_cost AS employee_cost__amortisation_of_deferred_stock_compensation_cost,
    expenditure.employee_cost.other_employees_cost AS employee_cost__other_employees_cost,
    expenditure.employee_cost.employee_cost_capitalised AS employee_cost__employee_cost_capitalised,
    expenditure.other_manufacturing_expenses.value AS other_manufacturing_expenses__value,
    expenditure.other_manufacturing_expenses.sub_contracted_outsourced_services AS other_manufacturing_expenses__sub_contracted_outsourced_services,
    expenditure.other_manufacturing_expenses.processing_charges AS other_manufacturing_expenses__processing_charges,
    expenditure.other_manufacturing_expenses.repairs_and_maintenance.value AS other_manufacturing_expenses__repairs_and_maintenance__value,
    expenditure.other_manufacturing_expenses.repairs_and_maintenance.building_premises AS other_manufacturing_expenses__repairs_and_maintenance__building_premises,
    expenditure.other_manufacturing_expenses.repairs_and_maintenance.plant_machinery AS other_manufacturing_expenses__repairs_and_maintenance__plant_machinery,
    expenditure.other_manufacturing_expenses.repairs_and_maintenance.other_repairs AS other_manufacturing_expenses__repairs_and_maintenance__other_repairs,
    expenditure.other_manufacturing_expenses.research_development AS other_manufacturing_expenses__research_development,
    expenditure.other_manufacturing_expenses.plant_machinery_hire_charges AS other_manufacturing_expenses__plant_machinery_hire_charges,
    expenditure.other_manufacturing_expenses.royalty AS other_manufacturing_expenses__royalty,
    expenditure.other_manufacturing_expenses.freight_transportation_port_charges AS other_manufacturing_expenses__freight_transportation_port_charges,
    expenditure.other_manufacturing_expenses.packing_material_consumed AS other_manufacturing_expenses__packing_material_consumed,
    expenditure.other_manufacturing_expenses.stores_spare_parts_and_tools_consumed AS other_manufacturing_expenses__stores_spare_parts_and_tools_consumed,
    expenditure.other_manufacturing_expenses.up_keep_and_maintenance_charges AS other_manufacturing_expenses__up_keep_and_maintenance_charges,
    expenditure.other_manufacturing_expenses.project_expenses AS other_manufacturing_expenses__project_expenses,
    expenditure.other_manufacturing_expenses.hire_charges_mfg AS other_manufacturing_expenses__hire_charges_mfg,
    expenditure.other_manufacturing_expenses.other_mfg_exp AS other_manufacturing_expenses__other_mfg_exp,
    expenditure.other_manufacturing_expenses.manufacturing_expenses_capitalised AS other_manufacturing_expenses__manufacturing_expenses_capitalised,
    expenditure.general_and_administration_expenses.value AS general_and_administration_expenses__value,
    expenditure.general_and_administration_expenses.rent_rates_taxes AS general_and_administration_expenses__rent_rates_taxes,
    expenditure.general_and_administration_expenses.insurance AS general_and_administration_expenses__insurance,
    expenditure.general_and_administration_expenses.repairs_maintenance_others AS general_and_administration_expenses__repairs_maintenance_others,
    expenditure.general_and_administration_expenses.printing_and_stationery AS general_and_administration_expenses__printing_and_stationery,
    expenditure.general_and_administration_expenses.professional_and_legal_fees AS general_and_administration_expenses__professional_and_legal_fees,
    expenditure.general_and_administration_expenses.traveling_and_conveyance AS general_and_administration_expenses__traveling_and_conveyance,
    expenditure.general_and_administration_expenses.payment_to_auditors AS general_and_administration_expenses__payment_to_auditors,
    expenditure.general_and_administration_expenses.hire_charges_admin AS general_and_administration_expenses__hire_charges_admin,
    expenditure.general_and_administration_expenses.packing_expenses AS general_and_administration_expenses__packing_expenses,
    expenditure.general_and_administration_expenses.communication_expenses AS general_and_administration_expenses__communication_expenses,
    expenditure.general_and_administration_expenses.training_expenses AS general_and_administration_expenses__training_expenses,
    expenditure.general_and_administration_expenses.wealth_tax AS general_and_administration_expenses__wealth_tax,
    expenditure.general_and_administration_expenses.director_s_remuneration AS general_and_administration_expenses__director_s_remuneration,
    expenditure.general_and_administration_expenses.other_administration AS general_and_administration_expenses__other_administration,
    expenditure.general_and_administration_expenses.administration_expenses_capitalised AS general_and_administration_expenses__administration_expenses_capitalised,
    expenditure.rent AS rent,
    expenditure.rates_taxes AS rates_taxes,
    expenditure.other_rent AS other_rent,
    expenditure.selling_and_distribution_expenses.value AS selling_and_distribution_expenses__value,
    expenditure.selling_and_distribution_expenses.distribution_expenses AS selling_and_distribution_expenses__distribution_expenses,
    expenditure.selling_and_distribution_expenses.advertisement_sales_promotion AS selling_and_distribution_expenses__advertisement_sales_promotion,
    expenditure.selling_and_distribution_expenses.sales_commissions_and_incentives AS selling_and_distribution_expenses__sales_commissions_and_incentives,
    expenditure.selling_and_distribution_expenses.brokerages AS selling_and_distribution_expenses__brokerages,
    expenditure.selling_and_distribution_expenses.discounts_rebates_s_d AS selling_and_distribution_expenses__discounts_rebates_s_d,
    expenditure.selling_and_distribution_expenses.freight_and_forwarding AS selling_and_distribution_expenses__freight_and_forwarding,
    expenditure.selling_and_distribution_expenses.handling_and_clearing_charges AS selling_and_distribution_expenses__handling_and_clearing_charges,
    expenditure.selling_and_distribution_expenses.sales_tax AS selling_and_distribution_expenses__sales_tax,
    expenditure.selling_and_distribution_expenses.other_selling_expenses AS selling_and_distribution_expenses__other_selling_expenses,
    expenditure.selling_and_distribution_expenses.selling_expenses_capitalised AS selling_and_distribution_expenses__selling_expenses_capitalised,
    expenditure.miscellaneous_expenses.value AS miscellaneous_expenses__value,
    expenditure.miscellaneous_expenses.deferred_revenue_expenditure_written_off AS miscellaneous_expenses__deferred_revenue_expenditure_written_off,
    expenditure.miscellaneous_expenses.bad_debts_advances_written_off AS miscellaneous_expenses__bad_debts_advances_written_off,
    expenditure.miscellaneous_expenses.provision_for_doubtful_debts AS miscellaneous_expenses__provision_for_doubtful_debts,
    expenditure.miscellaneous_expenses.loss_on_disposal_of_fixed_assets_net AS miscellaneous_expenses__loss_on_disposal_of_fixed_assets_net,
    expenditure.miscellaneous_expenses.loss_on_foreign_exchange_fluctuations AS miscellaneous_expenses__loss_on_foreign_exchange_fluctuations,
    expenditure.miscellaneous_expenses.loss_on_sale_of_non_trade_current_investments AS miscellaneous_expenses__loss_on_sale_of_non_trade_current_investments,
    expenditure.miscellaneous_expenses.diminution_in_the_value_of_long_term_investments AS miscellaneous_expenses__diminution_in_the_value_of_long_term_investments,
    expenditure.miscellaneous_expenses.provisions_write_off AS miscellaneous_expenses__provisions_write_off,
    expenditure.miscellaneous_expenses.loss_on_future_and_options AS miscellaneous_expenses__loss_on_future_and_options,
    expenditure.miscellaneous_expenses.donations AS miscellaneous_expenses__donations,
    expenditure.miscellaneous_expenses.loss_on_buy_back_of_shares_debentures AS miscellaneous_expenses__loss_on_buy_back_of_shares_debentures,
    expenditure.miscellaneous_expenses.other_miscellaneous_expenses AS miscellaneous_expenses__other_miscellaneous_expenses,
    expenditure.miscellaneous_expenses.miscellaneous_expenses_capitalised AS miscellaneous_expenses__miscellaneous_expenses_capitalised,
    expenditure.less_expenses_capitalised AS less_expenses_capitalised,
    expenditure.total_expenditure AS total_expenditure,
    expenditure.operating_profit_excl_oi AS operating_profit_excl_oi,
    expenditure.other_income.value AS other_income__value,
    expenditure.other_income.interest_received.value AS other_income__interest_received__value,
    expenditure.other_income.interest_received.interest_on_deposits AS other_income__interest_received__interest_on_deposits,
    expenditure.other_income.interest_received.interest_on_debentures_bonds AS other_income__interest_received__interest_on_debentures_bonds,
    expenditure.other_income.interest_received.interest_on_others AS other_income__interest_received__interest_on_others,
    expenditure.other_income.dividend_received AS other_income__dividend_received,
    expenditure.other_income.commission_received AS other_income__commission_received,
    expenditure.other_income.export_incentives AS other_income__export_incentives,
    expenditure.other_income.discounts AS other_income__discounts,
    expenditure.other_income.profit_on_sale_of_fixed_assets AS other_income__profit_on_sale_of_fixed_assets,
    expenditure.other_income.profits_on_sale_of_investments AS other_income__profits_on_sale_of_investments,
    expenditure.other_income.income_from_mutual_funds AS other_income__income_from_mutual_funds,
    expenditure.other_income.income_from_other_investments AS other_income__income_from_other_investments,
    expenditure.other_income.diminution_in_carrying_cost_of_investments AS other_income__diminution_in_carrying_cost_of_investments,
    expenditure.other_income.sale_of_scrap_other_income AS other_income__sale_of_scrap_other_income,
    expenditure.other_income.service_fee AS other_income__service_fee,
    expenditure.other_income.gain_on_forward_contracts_forex AS other_income__gain_on_forward_contracts_forex,
    expenditure.other_income.foreign_exchange_gains AS other_income__foreign_exchange_gains,
    expenditure.other_income.lease_rental_income AS other_income__lease_rental_income,
    expenditure.other_income.grants_from_government AS other_income__grants_from_government,
    expenditure.other_income.transfer_from_capital_reserve_capital_grants AS other_income__transfer_from_capital_reserve_capital_grants,
    expenditure.other_income.bad_debts_recovered AS other_income__bad_debts_recovered,
    expenditure.other_income.provision_written_back AS other_income__provision_written_back,
    expenditure.other_income.claims_received AS other_income__claims_received,
    expenditure.other_income.sale_of_power AS other_income__sale_of_power,
    expenditure.other_income.others AS other_income__others,
    expenditure.operating_profit AS operating_profit,
    expenditure.interest.value AS interest__value,
    expenditure.interest.interest_on_debenture_bonds AS interest__interest_on_debenture_bonds,
    expenditure.interest.interest_on_term_loan AS interest__interest_on_term_loan,
    expenditure.interest.interest_on_fixed_deposits AS interest__interest_on_fixed_deposits,
    expenditure.interest.interest_on_vehicle_loan AS interest__interest_on_vehicle_loan,
    expenditure.interest.interest_on_cash_credits_packing_credits AS interest__interest_on_cash_credits_packing_credits,
    expenditure.interest.interest_on_working_capital_loans AS interest__interest_on_working_capital_loans,
    expenditure.interest.bank_charges_etc AS interest__bank_charges_etc,
    expenditure.interest.other_interest AS interest__other_interest,
    expenditure.interest.interest_capitalised AS interest__interest_capitalised,
    expenditure.pbdt AS pbdt,
    expenditure.depreciation AS depreciation,
    expenditure.profit_before_taxation_exceptional_items AS profit_before_taxation_exceptional_items,
    expenditure.share_of_profit_loss_of_jv_associates AS share_of_profit_loss_of_jv_associates,
    expenditure.exceptional_income_expenses.value AS exceptional_income_expenses__value,
    expenditure.exceptional_income_expenses.profit_loss_on_sale_of_fixed_assets AS exceptional_income_expenses__profit_loss_on_sale_of_fixed_assets,
    expenditure.exceptional_income_expenses.profit_loss_on_sale_of_investments AS exceptional_income_expenses__profit_loss_on_sale_of_investments,
    expenditure.exceptional_income_expenses.restructuring_cost_reversal_of_provisions AS exceptional_income_expenses__restructuring_cost_reversal_of_provisions,
    expenditure.exceptional_income_expenses.accidental_loss_damages AS exceptional_income_expenses__accidental_loss_damages,
    expenditure.exceptional_income_expenses.inventory_write_off AS exceptional_income_expenses__inventory_write_off,
    expenditure.exceptional_income_expenses.other_exceptional_expenses AS exceptional_income_expenses__other_exceptional_expenses,
    expenditure.exceptional_income_expenses.other_exceptional_income AS exceptional_income_expenses__other_exceptional_income,
    expenditure.profit_before_tax AS profit_before_tax,
    expenditure.provision_for_tax.value AS provision_for_tax__value,
    expenditure.provision_for_tax.current_income_tax AS provision_for_tax__current_income_tax,
    expenditure.provision_for_tax.deferred_tax AS provision_for_tax__deferred_tax,
    expenditure.provision_for_tax.fringe_benefit_tax AS provision_for_tax__fringe_benefit_tax,
    expenditure.provision_for_tax.mat_credit_entitlement AS provision_for_tax__mat_credit_entitlement,
    expenditure.provision_for_tax.other_taxes AS provision_for_tax__other_taxes,
    expenditure.profit_after_tax AS profit_after_tax,
    expenditure.profit_before_tax_from_discontinued_operations AS profit_before_tax_from_discontinued_operations,
    expenditure.tax_from_discontinued_operations AS tax_from_discontinued_operations,
    expenditure.profit_after_tax_from_discontinued_operations AS profit_after_tax_from_discontinued_operations,
    expenditure.extra_items AS extra_items,
    expenditure.minority_interest AS minority_interest,
    expenditure.share_of_associate AS share_of_associate,
    expenditure.other_consolidated_items AS other_consolidated_items,
    expenditure.consolidated_net_profit AS consolidated_net_profit,
    expenditure.adjustments_to_pat AS adjustments_to_pat,
    expenditure.profit_balance_b_f AS profit_balance_b_f,
    expenditure.appropriations.value AS appropriations__value,
    expenditure.appropriations.general_reserve AS appropriations__general_reserve,
    expenditure.appropriations.interim_dividend_equity AS appropriations__interim_dividend_equity,
    expenditure.appropriations.proposed_equity_dividend AS appropriations__proposed_equity_dividend,
    expenditure.appropriations.preference_dividend AS appropriations__preference_dividend,
    expenditure.appropriations.corporate_dividend_tax AS appropriations__corporate_dividend_tax,
    expenditure.appropriations.statutory_reserve AS appropriations__statutory_reserve,
    expenditure.appropriations.other_appropriation AS appropriations__other_appropriation,
    expenditure.appropriations.capital_redemption_reserve AS appropriations__capital_redemption_reserve,
    expenditure.appropriations.profit_loss_balance_c_f AS appropriations__profit_loss_balance_c_f,
    expenditure.equity_dividend AS equity_dividend,
    expenditure.earnings_per_share_calculated AS earnings_per_share_calculated,
    expenditure.adjusted_eps AS adjusted_eps,
    expenditure.eps_basic_reported AS eps_basic_reported,
    expenditure.eps_diluted_reported AS eps_diluted_reported,
    expenditure.others_2 AS others_2,
    expenditure.commission_brokerage_discounts AS commission_brokerage_discounts,
    expenditure.other_operating_expenses AS other_operating_expenses,
    expenditure.director_s_remunerations AS director_s_remunerations,
    expenditure.income_from_investments AS income_from_investments,
    expenditure.current_incometax AS current_incometax,
    expenditure.deferredtax AS deferredtax
  FROM silverzone.profit_and_loss_yearly_expenditure_nested_merged
),
lagged AS (
  SELECT
    *,
    LAG(yyyymm) OVER w AS prev_yyyymm,
    LAG(yyyymm, 3) OVER w AS yyyymm_3y_back,
    LAG(yyyymm, 5) OVER w AS yyyymm_5y_back,
    LAG(increase_decrease_in_stock__value) OVER w AS increase_decrease_in_stock__value_prev_yr,
    LAG(increase_decrease_in_stock__value, 3) OVER w AS increase_decrease_in_stock__value_3y_back,
    LAG(increase_decrease_in_stock__value, 5) OVER w AS increase_decrease_in_stock__value_5y_back,
    LAG(increase_decrease_in_stock__opening_work_in_progress) OVER w AS increase_decrease_in_stock__opening_work_in_progress_prev_yr,
    LAG(increase_decrease_in_stock__opening_work_in_progress, 3) OVER w AS increase_decrease_in_stock__opening_work_in_progress_3y_back,
    LAG(increase_decrease_in_stock__opening_work_in_progress, 5) OVER w AS increase_decrease_in_stock__opening_work_in_progress_5y_back,
    LAG(increase_decrease_in_stock__opening_finished_goods) OVER w AS increase_decrease_in_stock__opening_finished_goods_prev_yr,
    LAG(increase_decrease_in_stock__opening_finished_goods, 3) OVER w AS increase_decrease_in_stock__opening_finished_goods_3y_back,
    LAG(increase_decrease_in_stock__opening_finished_goods, 5) OVER w AS increase_decrease_in_stock__opening_finished_goods_5y_back,
    LAG(increase_decrease_in_stock__opening_shares_units_and_bonds) OVER w AS increase_decrease_in_stock__opening_shares_units_and_bonds_prev_yr,
    LAG(increase_decrease_in_stock__opening_shares_units_and_bonds, 3) OVER w AS increase_decrease_in_stock__opening_shares_units_and_bonds_3y_back,
    LAG(increase_decrease_in_stock__opening_shares_units_and_bonds, 5) OVER w AS increase_decrease_in_stock__opening_shares_units_and_bonds_5y_back,
    LAG(increase_decrease_in_stock__other_opening_balances) OVER w AS increase_decrease_in_stock__other_opening_balances_prev_yr,
    LAG(increase_decrease_in_stock__other_opening_balances, 3) OVER w AS increase_decrease_in_stock__other_opening_balances_3y_back,
    LAG(increase_decrease_in_stock__other_opening_balances, 5) OVER w AS increase_decrease_in_stock__other_opening_balances_5y_back,
    LAG(increase_decrease_in_stock__less_closing_work_in_progress) OVER w AS increase_decrease_in_stock__less_closing_work_in_progress_prev_yr,
    LAG(increase_decrease_in_stock__less_closing_work_in_progress, 3) OVER w AS increase_decrease_in_stock__less_closing_work_in_progress_3y_back,
    LAG(increase_decrease_in_stock__less_closing_work_in_progress, 5) OVER w AS increase_decrease_in_stock__less_closing_work_in_progress_5y_back,
    LAG(increase_decrease_in_stock__less_closing_finished_goods) OVER w AS increase_decrease_in_stock__less_closing_finished_goods_prev_yr,
    LAG(increase_decrease_in_stock__less_closing_finished_goods, 3) OVER w AS increase_decrease_in_stock__less_closing_finished_goods_3y_back,
    LAG(increase_decrease_in_stock__less_closing_finished_goods, 5) OVER w AS increase_decrease_in_stock__less_closing_finished_goods_5y_back,
    LAG(increase_decrease_in_stock__less_closing_shares_units_and_bonds) OVER w AS increase_decrease_in_stock__less_closing_shares_units_and_bonds_prev_yr,
    LAG(increase_decrease_in_stock__less_closing_shares_units_and_bonds, 3) OVER w AS increase_decrease_in_stock__less_closing_shares_units_and_bonds_3y_back,
    LAG(increase_decrease_in_stock__less_closing_shares_units_and_bonds, 5) OVER w AS increase_decrease_in_stock__less_closing_shares_units_and_bonds_5y_back,
    LAG(increase_decrease_in_stock__less_other_closing_balances) OVER w AS increase_decrease_in_stock__less_other_closing_balances_prev_yr,
    LAG(increase_decrease_in_stock__less_other_closing_balances, 3) OVER w AS increase_decrease_in_stock__less_other_closing_balances_3y_back,
    LAG(increase_decrease_in_stock__less_other_closing_balances, 5) OVER w AS increase_decrease_in_stock__less_other_closing_balances_5y_back,
    LAG(increase_decrease_in_stock__inter_division_transfer_in_transits) OVER w AS increase_decrease_in_stock__inter_division_transfer_in_transits_prev_yr,
    LAG(increase_decrease_in_stock__inter_division_transfer_in_transits, 3) OVER w AS increase_decrease_in_stock__inter_division_transfer_in_transits_3y_back,
    LAG(increase_decrease_in_stock__inter_division_transfer_in_transits, 5) OVER w AS increase_decrease_in_stock__inter_division_transfer_in_transits_5y_back,
    LAG(increase_decrease_in_stock__excise_duty_on_stock_adjustments) OVER w AS increase_decrease_in_stock__excise_duty_on_stock_adjustments_prev_yr,
    LAG(increase_decrease_in_stock__excise_duty_on_stock_adjustments, 3) OVER w AS increase_decrease_in_stock__excise_duty_on_stock_adjustments_3y_back,
    LAG(increase_decrease_in_stock__excise_duty_on_stock_adjustments, 5) OVER w AS increase_decrease_in_stock__excise_duty_on_stock_adjustments_5y_back,
    LAG(increase_decrease_in_stock__stock_capitalised) OVER w AS increase_decrease_in_stock__stock_capitalised_prev_yr,
    LAG(increase_decrease_in_stock__stock_capitalised, 3) OVER w AS increase_decrease_in_stock__stock_capitalised_3y_back,
    LAG(increase_decrease_in_stock__stock_capitalised, 5) OVER w AS increase_decrease_in_stock__stock_capitalised_5y_back,
    LAG(raw_material_consumed__value) OVER w AS raw_material_consumed__value_prev_yr,
    LAG(raw_material_consumed__value, 3) OVER w AS raw_material_consumed__value_3y_back,
    LAG(raw_material_consumed__value, 5) OVER w AS raw_material_consumed__value_5y_back,
    LAG(raw_material_consumed__opening_raw_materials) OVER w AS raw_material_consumed__opening_raw_materials_prev_yr,
    LAG(raw_material_consumed__opening_raw_materials, 3) OVER w AS raw_material_consumed__opening_raw_materials_3y_back,
    LAG(raw_material_consumed__opening_raw_materials, 5) OVER w AS raw_material_consumed__opening_raw_materials_5y_back,
    LAG(raw_material_consumed__purchases_raw_materials) OVER w AS raw_material_consumed__purchases_raw_materials_prev_yr,
    LAG(raw_material_consumed__purchases_raw_materials, 3) OVER w AS raw_material_consumed__purchases_raw_materials_3y_back,
    LAG(raw_material_consumed__purchases_raw_materials, 5) OVER w AS raw_material_consumed__purchases_raw_materials_5y_back,
    LAG(raw_material_consumed__closing_raw_materials) OVER w AS raw_material_consumed__closing_raw_materials_prev_yr,
    LAG(raw_material_consumed__closing_raw_materials, 3) OVER w AS raw_material_consumed__closing_raw_materials_3y_back,
    LAG(raw_material_consumed__closing_raw_materials, 5) OVER w AS raw_material_consumed__closing_raw_materials_5y_back,
    LAG(raw_material_consumed__other_direct_purchases_brought_in_cost) OVER w AS raw_material_consumed__other_direct_purchases_brought_in_cost_prev_yr,
    LAG(raw_material_consumed__other_direct_purchases_brought_in_cost, 3) OVER w AS raw_material_consumed__other_direct_purchases_brought_in_cost_3y_back,
    LAG(raw_material_consumed__other_direct_purchases_brought_in_cost, 5) OVER w AS raw_material_consumed__other_direct_purchases_brought_in_cost_5y_back,
    LAG(raw_material_consumed__stock_on_amalgamation) OVER w AS raw_material_consumed__stock_on_amalgamation_prev_yr,
    LAG(raw_material_consumed__stock_on_amalgamation, 3) OVER w AS raw_material_consumed__stock_on_amalgamation_3y_back,
    LAG(raw_material_consumed__stock_on_amalgamation, 5) OVER w AS raw_material_consumed__stock_on_amalgamation_5y_back,
    LAG(raw_material_consumed__other_raw_material_cost) OVER w AS raw_material_consumed__other_raw_material_cost_prev_yr,
    LAG(raw_material_consumed__other_raw_material_cost, 3) OVER w AS raw_material_consumed__other_raw_material_cost_3y_back,
    LAG(raw_material_consumed__other_raw_material_cost, 5) OVER w AS raw_material_consumed__other_raw_material_cost_5y_back,
    LAG(raw_material_consumed__raw_material_consumed_capitalised) OVER w AS raw_material_consumed__raw_material_consumed_capitalised_prev_yr,
    LAG(raw_material_consumed__raw_material_consumed_capitalised, 3) OVER w AS raw_material_consumed__raw_material_consumed_capitalised_3y_back,
    LAG(raw_material_consumed__raw_material_consumed_capitalised, 5) OVER w AS raw_material_consumed__raw_material_consumed_capitalised_5y_back,
    LAG(power_fuel_cost) OVER w AS power_fuel_cost_prev_yr,
    LAG(power_fuel_cost, 3) OVER w AS power_fuel_cost_3y_back,
    LAG(power_fuel_cost, 5) OVER w AS power_fuel_cost_5y_back,
    LAG(electricity_power) OVER w AS electricity_power_prev_yr,
    LAG(electricity_power, 3) OVER w AS electricity_power_3y_back,
    LAG(electricity_power, 5) OVER w AS electricity_power_5y_back,
    LAG(less_captive_consumption_of_power) OVER w AS less_captive_consumption_of_power_prev_yr,
    LAG(less_captive_consumption_of_power, 3) OVER w AS less_captive_consumption_of_power_3y_back,
    LAG(less_captive_consumption_of_power, 5) OVER w AS less_captive_consumption_of_power_5y_back,
    LAG(oil_fuel_natural_gas) OVER w AS oil_fuel_natural_gas_prev_yr,
    LAG(oil_fuel_natural_gas, 3) OVER w AS oil_fuel_natural_gas_3y_back,
    LAG(oil_fuel_natural_gas, 5) OVER w AS oil_fuel_natural_gas_5y_back,
    LAG(less_captive_consumption_of_fuel) OVER w AS less_captive_consumption_of_fuel_prev_yr,
    LAG(less_captive_consumption_of_fuel, 3) OVER w AS less_captive_consumption_of_fuel_3y_back,
    LAG(less_captive_consumption_of_fuel, 5) OVER w AS less_captive_consumption_of_fuel_5y_back,
    LAG(coals_etc) OVER w AS coals_etc_prev_yr,
    LAG(coals_etc, 3) OVER w AS coals_etc_3y_back,
    LAG(coals_etc, 5) OVER w AS coals_etc_5y_back,
    LAG(other_power_fuel) OVER w AS other_power_fuel_prev_yr,
    LAG(other_power_fuel, 3) OVER w AS other_power_fuel_3y_back,
    LAG(other_power_fuel, 5) OVER w AS other_power_fuel_5y_back,
    LAG(power_fuel_capitalised) OVER w AS power_fuel_capitalised_prev_yr,
    LAG(power_fuel_capitalised, 3) OVER w AS power_fuel_capitalised_3y_back,
    LAG(power_fuel_capitalised, 5) OVER w AS power_fuel_capitalised_5y_back,
    LAG(employee_cost__value) OVER w AS employee_cost__value_prev_yr,
    LAG(employee_cost__value, 3) OVER w AS employee_cost__value_3y_back,
    LAG(employee_cost__value, 5) OVER w AS employee_cost__value_5y_back,
    LAG(employee_cost__salaries_wages_bonus) OVER w AS employee_cost__salaries_wages_bonus_prev_yr,
    LAG(employee_cost__salaries_wages_bonus, 3) OVER w AS employee_cost__salaries_wages_bonus_3y_back,
    LAG(employee_cost__salaries_wages_bonus, 5) OVER w AS employee_cost__salaries_wages_bonus_5y_back,
    LAG(employee_cost__contributions_to_epf_pension_funds) OVER w AS employee_cost__contributions_to_epf_pension_funds_prev_yr,
    LAG(employee_cost__contributions_to_epf_pension_funds, 3) OVER w AS employee_cost__contributions_to_epf_pension_funds_3y_back,
    LAG(employee_cost__contributions_to_epf_pension_funds, 5) OVER w AS employee_cost__contributions_to_epf_pension_funds_5y_back,
    LAG(employee_cost__workmen_and_staff_welfare_expenses) OVER w AS employee_cost__workmen_and_staff_welfare_expenses_prev_yr,
    LAG(employee_cost__workmen_and_staff_welfare_expenses, 3) OVER w AS employee_cost__workmen_and_staff_welfare_expenses_3y_back,
    LAG(employee_cost__workmen_and_staff_welfare_expenses, 5) OVER w AS employee_cost__workmen_and_staff_welfare_expenses_5y_back,
    LAG(employee_cost__gratuity_ex_gratia) OVER w AS employee_cost__gratuity_ex_gratia_prev_yr,
    LAG(employee_cost__gratuity_ex_gratia, 3) OVER w AS employee_cost__gratuity_ex_gratia_3y_back,
    LAG(employee_cost__gratuity_ex_gratia, 5) OVER w AS employee_cost__gratuity_ex_gratia_5y_back,
    LAG(employee_cost__retrenchment_workers_vrs) OVER w AS employee_cost__retrenchment_workers_vrs_prev_yr,
    LAG(employee_cost__retrenchment_workers_vrs, 3) OVER w AS employee_cost__retrenchment_workers_vrs_3y_back,
    LAG(employee_cost__retrenchment_workers_vrs, 5) OVER w AS employee_cost__retrenchment_workers_vrs_5y_back,
    LAG(employee_cost__leave_travel_allowance) OVER w AS employee_cost__leave_travel_allowance_prev_yr,
    LAG(employee_cost__leave_travel_allowance, 3) OVER w AS employee_cost__leave_travel_allowance_3y_back,
    LAG(employee_cost__leave_travel_allowance, 5) OVER w AS employee_cost__leave_travel_allowance_5y_back,
    LAG(employee_cost__leave_encashment) OVER w AS employee_cost__leave_encashment_prev_yr,
    LAG(employee_cost__leave_encashment, 3) OVER w AS employee_cost__leave_encashment_3y_back,
    LAG(employee_cost__leave_encashment, 5) OVER w AS employee_cost__leave_encashment_5y_back,
    LAG(employee_cost__amortisation_of_deferred_stock_compensation_cost) OVER w AS employee_cost__amortisation_of_deferred_stock_compensation_cost_prev_yr,
    LAG(employee_cost__amortisation_of_deferred_stock_compensation_cost, 3) OVER w AS employee_cost__amortisation_of_deferred_stock_compensation_cost_3y_back,
    LAG(employee_cost__amortisation_of_deferred_stock_compensation_cost, 5) OVER w AS employee_cost__amortisation_of_deferred_stock_compensation_cost_5y_back,
    LAG(employee_cost__other_employees_cost) OVER w AS employee_cost__other_employees_cost_prev_yr,
    LAG(employee_cost__other_employees_cost, 3) OVER w AS employee_cost__other_employees_cost_3y_back,
    LAG(employee_cost__other_employees_cost, 5) OVER w AS employee_cost__other_employees_cost_5y_back,
    LAG(employee_cost__employee_cost_capitalised) OVER w AS employee_cost__employee_cost_capitalised_prev_yr,
    LAG(employee_cost__employee_cost_capitalised, 3) OVER w AS employee_cost__employee_cost_capitalised_3y_back,
    LAG(employee_cost__employee_cost_capitalised, 5) OVER w AS employee_cost__employee_cost_capitalised_5y_back,
    LAG(other_manufacturing_expenses__value) OVER w AS other_manufacturing_expenses__value_prev_yr,
    LAG(other_manufacturing_expenses__value, 3) OVER w AS other_manufacturing_expenses__value_3y_back,
    LAG(other_manufacturing_expenses__value, 5) OVER w AS other_manufacturing_expenses__value_5y_back,
    LAG(other_manufacturing_expenses__sub_contracted_outsourced_services) OVER w AS other_manufacturing_expenses__sub_contracted_outsourced_services_prev_yr,
    LAG(other_manufacturing_expenses__sub_contracted_outsourced_services, 3) OVER w AS other_manufacturing_expenses__sub_contracted_outsourced_services_3y_back,
    LAG(other_manufacturing_expenses__sub_contracted_outsourced_services, 5) OVER w AS other_manufacturing_expenses__sub_contracted_outsourced_services_5y_back,
    LAG(other_manufacturing_expenses__processing_charges) OVER w AS other_manufacturing_expenses__processing_charges_prev_yr,
    LAG(other_manufacturing_expenses__processing_charges, 3) OVER w AS other_manufacturing_expenses__processing_charges_3y_back,
    LAG(other_manufacturing_expenses__processing_charges, 5) OVER w AS other_manufacturing_expenses__processing_charges_5y_back,
    LAG(other_manufacturing_expenses__repairs_and_maintenance__value) OVER w AS other_manufacturing_expenses__repairs_and_maintenance__value_prev_yr,
    LAG(other_manufacturing_expenses__repairs_and_maintenance__value, 3) OVER w AS other_manufacturing_expenses__repairs_and_maintenance__value_3y_back,
    LAG(other_manufacturing_expenses__repairs_and_maintenance__value, 5) OVER w AS other_manufacturing_expenses__repairs_and_maintenance__value_5y_back,
    LAG(other_manufacturing_expenses__repairs_and_maintenance__building_premises) OVER w AS other_manufacturing_expenses__repairs_and_maintenance__building_premises_prev_yr,
    LAG(other_manufacturing_expenses__repairs_and_maintenance__building_premises, 3) OVER w AS other_manufacturing_expenses__repairs_and_maintenance__building_premises_3y_back,
    LAG(other_manufacturing_expenses__repairs_and_maintenance__building_premises, 5) OVER w AS other_manufacturing_expenses__repairs_and_maintenance__building_premises_5y_back,
    LAG(other_manufacturing_expenses__repairs_and_maintenance__plant_machinery) OVER w AS other_manufacturing_expenses__repairs_and_maintenance__plant_machinery_prev_yr,
    LAG(other_manufacturing_expenses__repairs_and_maintenance__plant_machinery, 3) OVER w AS other_manufacturing_expenses__repairs_and_maintenance__plant_machinery_3y_back,
    LAG(other_manufacturing_expenses__repairs_and_maintenance__plant_machinery, 5) OVER w AS other_manufacturing_expenses__repairs_and_maintenance__plant_machinery_5y_back,
    LAG(other_manufacturing_expenses__repairs_and_maintenance__other_repairs) OVER w AS other_manufacturing_expenses__repairs_and_maintenance__other_repairs_prev_yr,
    LAG(other_manufacturing_expenses__repairs_and_maintenance__other_repairs, 3) OVER w AS other_manufacturing_expenses__repairs_and_maintenance__other_repairs_3y_back,
    LAG(other_manufacturing_expenses__repairs_and_maintenance__other_repairs, 5) OVER w AS other_manufacturing_expenses__repairs_and_maintenance__other_repairs_5y_back,
    LAG(other_manufacturing_expenses__research_development) OVER w AS other_manufacturing_expenses__research_development_prev_yr,
    LAG(other_manufacturing_expenses__research_development, 3) OVER w AS other_manufacturing_expenses__research_development_3y_back,
    LAG(other_manufacturing_expenses__research_development, 5) OVER w AS other_manufacturing_expenses__research_development_5y_back,
    LAG(other_manufacturing_expenses__plant_machinery_hire_charges) OVER w AS other_manufacturing_expenses__plant_machinery_hire_charges_prev_yr,
    LAG(other_manufacturing_expenses__plant_machinery_hire_charges, 3) OVER w AS other_manufacturing_expenses__plant_machinery_hire_charges_3y_back,
    LAG(other_manufacturing_expenses__plant_machinery_hire_charges, 5) OVER w AS other_manufacturing_expenses__plant_machinery_hire_charges_5y_back,
    LAG(other_manufacturing_expenses__royalty) OVER w AS other_manufacturing_expenses__royalty_prev_yr,
    LAG(other_manufacturing_expenses__royalty, 3) OVER w AS other_manufacturing_expenses__royalty_3y_back,
    LAG(other_manufacturing_expenses__royalty, 5) OVER w AS other_manufacturing_expenses__royalty_5y_back,
    LAG(other_manufacturing_expenses__freight_transportation_port_charges) OVER w AS other_manufacturing_expenses__freight_transportation_port_charges_prev_yr,
    LAG(other_manufacturing_expenses__freight_transportation_port_charges, 3) OVER w AS other_manufacturing_expenses__freight_transportation_port_charges_3y_back,
    LAG(other_manufacturing_expenses__freight_transportation_port_charges, 5) OVER w AS other_manufacturing_expenses__freight_transportation_port_charges_5y_back,
    LAG(other_manufacturing_expenses__packing_material_consumed) OVER w AS other_manufacturing_expenses__packing_material_consumed_prev_yr,
    LAG(other_manufacturing_expenses__packing_material_consumed, 3) OVER w AS other_manufacturing_expenses__packing_material_consumed_3y_back,
    LAG(other_manufacturing_expenses__packing_material_consumed, 5) OVER w AS other_manufacturing_expenses__packing_material_consumed_5y_back,
    LAG(other_manufacturing_expenses__stores_spare_parts_and_tools_consumed) OVER w AS other_manufacturing_expenses__stores_spare_parts_and_tools_consumed_prev_yr,
    LAG(other_manufacturing_expenses__stores_spare_parts_and_tools_consumed, 3) OVER w AS other_manufacturing_expenses__stores_spare_parts_and_tools_consumed_3y_back,
    LAG(other_manufacturing_expenses__stores_spare_parts_and_tools_consumed, 5) OVER w AS other_manufacturing_expenses__stores_spare_parts_and_tools_consumed_5y_back,
    LAG(other_manufacturing_expenses__up_keep_and_maintenance_charges) OVER w AS other_manufacturing_expenses__up_keep_and_maintenance_charges_prev_yr,
    LAG(other_manufacturing_expenses__up_keep_and_maintenance_charges, 3) OVER w AS other_manufacturing_expenses__up_keep_and_maintenance_charges_3y_back,
    LAG(other_manufacturing_expenses__up_keep_and_maintenance_charges, 5) OVER w AS other_manufacturing_expenses__up_keep_and_maintenance_charges_5y_back,
    LAG(other_manufacturing_expenses__project_expenses) OVER w AS other_manufacturing_expenses__project_expenses_prev_yr,
    LAG(other_manufacturing_expenses__project_expenses, 3) OVER w AS other_manufacturing_expenses__project_expenses_3y_back,
    LAG(other_manufacturing_expenses__project_expenses, 5) OVER w AS other_manufacturing_expenses__project_expenses_5y_back,
    LAG(other_manufacturing_expenses__hire_charges_mfg) OVER w AS other_manufacturing_expenses__hire_charges_mfg_prev_yr,
    LAG(other_manufacturing_expenses__hire_charges_mfg, 3) OVER w AS other_manufacturing_expenses__hire_charges_mfg_3y_back,
    LAG(other_manufacturing_expenses__hire_charges_mfg, 5) OVER w AS other_manufacturing_expenses__hire_charges_mfg_5y_back,
    LAG(other_manufacturing_expenses__other_mfg_exp) OVER w AS other_manufacturing_expenses__other_mfg_exp_prev_yr,
    LAG(other_manufacturing_expenses__other_mfg_exp, 3) OVER w AS other_manufacturing_expenses__other_mfg_exp_3y_back,
    LAG(other_manufacturing_expenses__other_mfg_exp, 5) OVER w AS other_manufacturing_expenses__other_mfg_exp_5y_back,
    LAG(other_manufacturing_expenses__manufacturing_expenses_capitalised) OVER w AS other_manufacturing_expenses__manufacturing_expenses_capitalised_prev_yr,
    LAG(other_manufacturing_expenses__manufacturing_expenses_capitalised, 3) OVER w AS other_manufacturing_expenses__manufacturing_expenses_capitalised_3y_back,
    LAG(other_manufacturing_expenses__manufacturing_expenses_capitalised, 5) OVER w AS other_manufacturing_expenses__manufacturing_expenses_capitalised_5y_back,
    LAG(general_and_administration_expenses__value) OVER w AS general_and_administration_expenses__value_prev_yr,
    LAG(general_and_administration_expenses__value, 3) OVER w AS general_and_administration_expenses__value_3y_back,
    LAG(general_and_administration_expenses__value, 5) OVER w AS general_and_administration_expenses__value_5y_back,
    LAG(general_and_administration_expenses__rent_rates_taxes) OVER w AS general_and_administration_expenses__rent_rates_taxes_prev_yr,
    LAG(general_and_administration_expenses__rent_rates_taxes, 3) OVER w AS general_and_administration_expenses__rent_rates_taxes_3y_back,
    LAG(general_and_administration_expenses__rent_rates_taxes, 5) OVER w AS general_and_administration_expenses__rent_rates_taxes_5y_back,
    LAG(general_and_administration_expenses__insurance) OVER w AS general_and_administration_expenses__insurance_prev_yr,
    LAG(general_and_administration_expenses__insurance, 3) OVER w AS general_and_administration_expenses__insurance_3y_back,
    LAG(general_and_administration_expenses__insurance, 5) OVER w AS general_and_administration_expenses__insurance_5y_back,
    LAG(general_and_administration_expenses__repairs_maintenance_others) OVER w AS general_and_administration_expenses__repairs_maintenance_others_prev_yr,
    LAG(general_and_administration_expenses__repairs_maintenance_others, 3) OVER w AS general_and_administration_expenses__repairs_maintenance_others_3y_back,
    LAG(general_and_administration_expenses__repairs_maintenance_others, 5) OVER w AS general_and_administration_expenses__repairs_maintenance_others_5y_back,
    LAG(general_and_administration_expenses__printing_and_stationery) OVER w AS general_and_administration_expenses__printing_and_stationery_prev_yr,
    LAG(general_and_administration_expenses__printing_and_stationery, 3) OVER w AS general_and_administration_expenses__printing_and_stationery_3y_back,
    LAG(general_and_administration_expenses__printing_and_stationery, 5) OVER w AS general_and_administration_expenses__printing_and_stationery_5y_back,
    LAG(general_and_administration_expenses__professional_and_legal_fees) OVER w AS general_and_administration_expenses__professional_and_legal_fees_prev_yr,
    LAG(general_and_administration_expenses__professional_and_legal_fees, 3) OVER w AS general_and_administration_expenses__professional_and_legal_fees_3y_back,
    LAG(general_and_administration_expenses__professional_and_legal_fees, 5) OVER w AS general_and_administration_expenses__professional_and_legal_fees_5y_back,
    LAG(general_and_administration_expenses__traveling_and_conveyance) OVER w AS general_and_administration_expenses__traveling_and_conveyance_prev_yr,
    LAG(general_and_administration_expenses__traveling_and_conveyance, 3) OVER w AS general_and_administration_expenses__traveling_and_conveyance_3y_back,
    LAG(general_and_administration_expenses__traveling_and_conveyance, 5) OVER w AS general_and_administration_expenses__traveling_and_conveyance_5y_back,
    LAG(general_and_administration_expenses__payment_to_auditors) OVER w AS general_and_administration_expenses__payment_to_auditors_prev_yr,
    LAG(general_and_administration_expenses__payment_to_auditors, 3) OVER w AS general_and_administration_expenses__payment_to_auditors_3y_back,
    LAG(general_and_administration_expenses__payment_to_auditors, 5) OVER w AS general_and_administration_expenses__payment_to_auditors_5y_back,
    LAG(general_and_administration_expenses__hire_charges_admin) OVER w AS general_and_administration_expenses__hire_charges_admin_prev_yr,
    LAG(general_and_administration_expenses__hire_charges_admin, 3) OVER w AS general_and_administration_expenses__hire_charges_admin_3y_back,
    LAG(general_and_administration_expenses__hire_charges_admin, 5) OVER w AS general_and_administration_expenses__hire_charges_admin_5y_back,
    LAG(general_and_administration_expenses__packing_expenses) OVER w AS general_and_administration_expenses__packing_expenses_prev_yr,
    LAG(general_and_administration_expenses__packing_expenses, 3) OVER w AS general_and_administration_expenses__packing_expenses_3y_back,
    LAG(general_and_administration_expenses__packing_expenses, 5) OVER w AS general_and_administration_expenses__packing_expenses_5y_back,
    LAG(general_and_administration_expenses__communication_expenses) OVER w AS general_and_administration_expenses__communication_expenses_prev_yr,
    LAG(general_and_administration_expenses__communication_expenses, 3) OVER w AS general_and_administration_expenses__communication_expenses_3y_back,
    LAG(general_and_administration_expenses__communication_expenses, 5) OVER w AS general_and_administration_expenses__communication_expenses_5y_back,
    LAG(general_and_administration_expenses__training_expenses) OVER w AS general_and_administration_expenses__training_expenses_prev_yr,
    LAG(general_and_administration_expenses__training_expenses, 3) OVER w AS general_and_administration_expenses__training_expenses_3y_back,
    LAG(general_and_administration_expenses__training_expenses, 5) OVER w AS general_and_administration_expenses__training_expenses_5y_back,
    LAG(general_and_administration_expenses__wealth_tax) OVER w AS general_and_administration_expenses__wealth_tax_prev_yr,
    LAG(general_and_administration_expenses__wealth_tax, 3) OVER w AS general_and_administration_expenses__wealth_tax_3y_back,
    LAG(general_and_administration_expenses__wealth_tax, 5) OVER w AS general_and_administration_expenses__wealth_tax_5y_back,
    LAG(general_and_administration_expenses__director_s_remuneration) OVER w AS general_and_administration_expenses__director_s_remuneration_prev_yr,
    LAG(general_and_administration_expenses__director_s_remuneration, 3) OVER w AS general_and_administration_expenses__director_s_remuneration_3y_back,
    LAG(general_and_administration_expenses__director_s_remuneration, 5) OVER w AS general_and_administration_expenses__director_s_remuneration_5y_back,
    LAG(general_and_administration_expenses__other_administration) OVER w AS general_and_administration_expenses__other_administration_prev_yr,
    LAG(general_and_administration_expenses__other_administration, 3) OVER w AS general_and_administration_expenses__other_administration_3y_back,
    LAG(general_and_administration_expenses__other_administration, 5) OVER w AS general_and_administration_expenses__other_administration_5y_back,
    LAG(general_and_administration_expenses__administration_expenses_capitalised) OVER w AS general_and_administration_expenses__administration_expenses_capitalised_prev_yr,
    LAG(general_and_administration_expenses__administration_expenses_capitalised, 3) OVER w AS general_and_administration_expenses__administration_expenses_capitalised_3y_back,
    LAG(general_and_administration_expenses__administration_expenses_capitalised, 5) OVER w AS general_and_administration_expenses__administration_expenses_capitalised_5y_back,
    LAG(rent) OVER w AS rent_prev_yr,
    LAG(rent, 3) OVER w AS rent_3y_back,
    LAG(rent, 5) OVER w AS rent_5y_back,
    LAG(rates_taxes) OVER w AS rates_taxes_prev_yr,
    LAG(rates_taxes, 3) OVER w AS rates_taxes_3y_back,
    LAG(rates_taxes, 5) OVER w AS rates_taxes_5y_back,
    LAG(other_rent) OVER w AS other_rent_prev_yr,
    LAG(other_rent, 3) OVER w AS other_rent_3y_back,
    LAG(other_rent, 5) OVER w AS other_rent_5y_back,
    LAG(selling_and_distribution_expenses__value) OVER w AS selling_and_distribution_expenses__value_prev_yr,
    LAG(selling_and_distribution_expenses__value, 3) OVER w AS selling_and_distribution_expenses__value_3y_back,
    LAG(selling_and_distribution_expenses__value, 5) OVER w AS selling_and_distribution_expenses__value_5y_back,
    LAG(selling_and_distribution_expenses__distribution_expenses) OVER w AS selling_and_distribution_expenses__distribution_expenses_prev_yr,
    LAG(selling_and_distribution_expenses__distribution_expenses, 3) OVER w AS selling_and_distribution_expenses__distribution_expenses_3y_back,
    LAG(selling_and_distribution_expenses__distribution_expenses, 5) OVER w AS selling_and_distribution_expenses__distribution_expenses_5y_back,
    LAG(selling_and_distribution_expenses__advertisement_sales_promotion) OVER w AS selling_and_distribution_expenses__advertisement_sales_promotion_prev_yr,
    LAG(selling_and_distribution_expenses__advertisement_sales_promotion, 3) OVER w AS selling_and_distribution_expenses__advertisement_sales_promotion_3y_back,
    LAG(selling_and_distribution_expenses__advertisement_sales_promotion, 5) OVER w AS selling_and_distribution_expenses__advertisement_sales_promotion_5y_back,
    LAG(selling_and_distribution_expenses__sales_commissions_and_incentives) OVER w AS selling_and_distribution_expenses__sales_commissions_and_incentives_prev_yr,
    LAG(selling_and_distribution_expenses__sales_commissions_and_incentives, 3) OVER w AS selling_and_distribution_expenses__sales_commissions_and_incentives_3y_back,
    LAG(selling_and_distribution_expenses__sales_commissions_and_incentives, 5) OVER w AS selling_and_distribution_expenses__sales_commissions_and_incentives_5y_back,
    LAG(selling_and_distribution_expenses__brokerages) OVER w AS selling_and_distribution_expenses__brokerages_prev_yr,
    LAG(selling_and_distribution_expenses__brokerages, 3) OVER w AS selling_and_distribution_expenses__brokerages_3y_back,
    LAG(selling_and_distribution_expenses__brokerages, 5) OVER w AS selling_and_distribution_expenses__brokerages_5y_back,
    LAG(selling_and_distribution_expenses__discounts_rebates_s_d) OVER w AS selling_and_distribution_expenses__discounts_rebates_s_d_prev_yr,
    LAG(selling_and_distribution_expenses__discounts_rebates_s_d, 3) OVER w AS selling_and_distribution_expenses__discounts_rebates_s_d_3y_back,
    LAG(selling_and_distribution_expenses__discounts_rebates_s_d, 5) OVER w AS selling_and_distribution_expenses__discounts_rebates_s_d_5y_back,
    LAG(selling_and_distribution_expenses__freight_and_forwarding) OVER w AS selling_and_distribution_expenses__freight_and_forwarding_prev_yr,
    LAG(selling_and_distribution_expenses__freight_and_forwarding, 3) OVER w AS selling_and_distribution_expenses__freight_and_forwarding_3y_back,
    LAG(selling_and_distribution_expenses__freight_and_forwarding, 5) OVER w AS selling_and_distribution_expenses__freight_and_forwarding_5y_back,
    LAG(selling_and_distribution_expenses__handling_and_clearing_charges) OVER w AS selling_and_distribution_expenses__handling_and_clearing_charges_prev_yr,
    LAG(selling_and_distribution_expenses__handling_and_clearing_charges, 3) OVER w AS selling_and_distribution_expenses__handling_and_clearing_charges_3y_back,
    LAG(selling_and_distribution_expenses__handling_and_clearing_charges, 5) OVER w AS selling_and_distribution_expenses__handling_and_clearing_charges_5y_back,
    LAG(selling_and_distribution_expenses__sales_tax) OVER w AS selling_and_distribution_expenses__sales_tax_prev_yr,
    LAG(selling_and_distribution_expenses__sales_tax, 3) OVER w AS selling_and_distribution_expenses__sales_tax_3y_back,
    LAG(selling_and_distribution_expenses__sales_tax, 5) OVER w AS selling_and_distribution_expenses__sales_tax_5y_back,
    LAG(selling_and_distribution_expenses__other_selling_expenses) OVER w AS selling_and_distribution_expenses__other_selling_expenses_prev_yr,
    LAG(selling_and_distribution_expenses__other_selling_expenses, 3) OVER w AS selling_and_distribution_expenses__other_selling_expenses_3y_back,
    LAG(selling_and_distribution_expenses__other_selling_expenses, 5) OVER w AS selling_and_distribution_expenses__other_selling_expenses_5y_back,
    LAG(selling_and_distribution_expenses__selling_expenses_capitalised) OVER w AS selling_and_distribution_expenses__selling_expenses_capitalised_prev_yr,
    LAG(selling_and_distribution_expenses__selling_expenses_capitalised, 3) OVER w AS selling_and_distribution_expenses__selling_expenses_capitalised_3y_back,
    LAG(selling_and_distribution_expenses__selling_expenses_capitalised, 5) OVER w AS selling_and_distribution_expenses__selling_expenses_capitalised_5y_back,
    LAG(miscellaneous_expenses__value) OVER w AS miscellaneous_expenses__value_prev_yr,
    LAG(miscellaneous_expenses__value, 3) OVER w AS miscellaneous_expenses__value_3y_back,
    LAG(miscellaneous_expenses__value, 5) OVER w AS miscellaneous_expenses__value_5y_back,
    LAG(miscellaneous_expenses__deferred_revenue_expenditure_written_off) OVER w AS miscellaneous_expenses__deferred_revenue_expenditure_written_off_prev_yr,
    LAG(miscellaneous_expenses__deferred_revenue_expenditure_written_off, 3) OVER w AS miscellaneous_expenses__deferred_revenue_expenditure_written_off_3y_back,
    LAG(miscellaneous_expenses__deferred_revenue_expenditure_written_off, 5) OVER w AS miscellaneous_expenses__deferred_revenue_expenditure_written_off_5y_back,
    LAG(miscellaneous_expenses__bad_debts_advances_written_off) OVER w AS miscellaneous_expenses__bad_debts_advances_written_off_prev_yr,
    LAG(miscellaneous_expenses__bad_debts_advances_written_off, 3) OVER w AS miscellaneous_expenses__bad_debts_advances_written_off_3y_back,
    LAG(miscellaneous_expenses__bad_debts_advances_written_off, 5) OVER w AS miscellaneous_expenses__bad_debts_advances_written_off_5y_back,
    LAG(miscellaneous_expenses__provision_for_doubtful_debts) OVER w AS miscellaneous_expenses__provision_for_doubtful_debts_prev_yr,
    LAG(miscellaneous_expenses__provision_for_doubtful_debts, 3) OVER w AS miscellaneous_expenses__provision_for_doubtful_debts_3y_back,
    LAG(miscellaneous_expenses__provision_for_doubtful_debts, 5) OVER w AS miscellaneous_expenses__provision_for_doubtful_debts_5y_back,
    LAG(miscellaneous_expenses__loss_on_disposal_of_fixed_assets_net) OVER w AS miscellaneous_expenses__loss_on_disposal_of_fixed_assets_net_prev_yr,
    LAG(miscellaneous_expenses__loss_on_disposal_of_fixed_assets_net, 3) OVER w AS miscellaneous_expenses__loss_on_disposal_of_fixed_assets_net_3y_back,
    LAG(miscellaneous_expenses__loss_on_disposal_of_fixed_assets_net, 5) OVER w AS miscellaneous_expenses__loss_on_disposal_of_fixed_assets_net_5y_back,
    LAG(miscellaneous_expenses__loss_on_foreign_exchange_fluctuations) OVER w AS miscellaneous_expenses__loss_on_foreign_exchange_fluctuations_prev_yr,
    LAG(miscellaneous_expenses__loss_on_foreign_exchange_fluctuations, 3) OVER w AS miscellaneous_expenses__loss_on_foreign_exchange_fluctuations_3y_back,
    LAG(miscellaneous_expenses__loss_on_foreign_exchange_fluctuations, 5) OVER w AS miscellaneous_expenses__loss_on_foreign_exchange_fluctuations_5y_back,
    LAG(miscellaneous_expenses__loss_on_sale_of_non_trade_current_investments) OVER w AS miscellaneous_expenses__loss_on_sale_of_non_trade_current_investments_prev_yr,
    LAG(miscellaneous_expenses__loss_on_sale_of_non_trade_current_investments, 3) OVER w AS miscellaneous_expenses__loss_on_sale_of_non_trade_current_investments_3y_back,
    LAG(miscellaneous_expenses__loss_on_sale_of_non_trade_current_investments, 5) OVER w AS miscellaneous_expenses__loss_on_sale_of_non_trade_current_investments_5y_back,
    LAG(miscellaneous_expenses__diminution_in_the_value_of_long_term_investments) OVER w AS miscellaneous_expenses__diminution_in_the_value_of_long_term_investments_prev_yr,
    LAG(miscellaneous_expenses__diminution_in_the_value_of_long_term_investments, 3) OVER w AS miscellaneous_expenses__diminution_in_the_value_of_long_term_investments_3y_back,
    LAG(miscellaneous_expenses__diminution_in_the_value_of_long_term_investments, 5) OVER w AS miscellaneous_expenses__diminution_in_the_value_of_long_term_investments_5y_back,
    LAG(miscellaneous_expenses__provisions_write_off) OVER w AS miscellaneous_expenses__provisions_write_off_prev_yr,
    LAG(miscellaneous_expenses__provisions_write_off, 3) OVER w AS miscellaneous_expenses__provisions_write_off_3y_back,
    LAG(miscellaneous_expenses__provisions_write_off, 5) OVER w AS miscellaneous_expenses__provisions_write_off_5y_back,
    LAG(miscellaneous_expenses__loss_on_future_and_options) OVER w AS miscellaneous_expenses__loss_on_future_and_options_prev_yr,
    LAG(miscellaneous_expenses__loss_on_future_and_options, 3) OVER w AS miscellaneous_expenses__loss_on_future_and_options_3y_back,
    LAG(miscellaneous_expenses__loss_on_future_and_options, 5) OVER w AS miscellaneous_expenses__loss_on_future_and_options_5y_back,
    LAG(miscellaneous_expenses__donations) OVER w AS miscellaneous_expenses__donations_prev_yr,
    LAG(miscellaneous_expenses__donations, 3) OVER w AS miscellaneous_expenses__donations_3y_back,
    LAG(miscellaneous_expenses__donations, 5) OVER w AS miscellaneous_expenses__donations_5y_back,
    LAG(miscellaneous_expenses__loss_on_buy_back_of_shares_debentures) OVER w AS miscellaneous_expenses__loss_on_buy_back_of_shares_debentures_prev_yr,
    LAG(miscellaneous_expenses__loss_on_buy_back_of_shares_debentures, 3) OVER w AS miscellaneous_expenses__loss_on_buy_back_of_shares_debentures_3y_back,
    LAG(miscellaneous_expenses__loss_on_buy_back_of_shares_debentures, 5) OVER w AS miscellaneous_expenses__loss_on_buy_back_of_shares_debentures_5y_back,
    LAG(miscellaneous_expenses__other_miscellaneous_expenses) OVER w AS miscellaneous_expenses__other_miscellaneous_expenses_prev_yr,
    LAG(miscellaneous_expenses__other_miscellaneous_expenses, 3) OVER w AS miscellaneous_expenses__other_miscellaneous_expenses_3y_back,
    LAG(miscellaneous_expenses__other_miscellaneous_expenses, 5) OVER w AS miscellaneous_expenses__other_miscellaneous_expenses_5y_back,
    LAG(miscellaneous_expenses__miscellaneous_expenses_capitalised) OVER w AS miscellaneous_expenses__miscellaneous_expenses_capitalised_prev_yr,
    LAG(miscellaneous_expenses__miscellaneous_expenses_capitalised, 3) OVER w AS miscellaneous_expenses__miscellaneous_expenses_capitalised_3y_back,
    LAG(miscellaneous_expenses__miscellaneous_expenses_capitalised, 5) OVER w AS miscellaneous_expenses__miscellaneous_expenses_capitalised_5y_back,
    LAG(less_expenses_capitalised) OVER w AS less_expenses_capitalised_prev_yr,
    LAG(less_expenses_capitalised, 3) OVER w AS less_expenses_capitalised_3y_back,
    LAG(less_expenses_capitalised, 5) OVER w AS less_expenses_capitalised_5y_back,
    LAG(total_expenditure) OVER w AS total_expenditure_prev_yr,
    LAG(total_expenditure, 3) OVER w AS total_expenditure_3y_back,
    LAG(total_expenditure, 5) OVER w AS total_expenditure_5y_back,
    LAG(operating_profit_excl_oi) OVER w AS operating_profit_excl_oi_prev_yr,
    LAG(operating_profit_excl_oi, 3) OVER w AS operating_profit_excl_oi_3y_back,
    LAG(operating_profit_excl_oi, 5) OVER w AS operating_profit_excl_oi_5y_back,
    LAG(other_income__value) OVER w AS other_income__value_prev_yr,
    LAG(other_income__value, 3) OVER w AS other_income__value_3y_back,
    LAG(other_income__value, 5) OVER w AS other_income__value_5y_back,
    LAG(other_income__interest_received__value) OVER w AS other_income__interest_received__value_prev_yr,
    LAG(other_income__interest_received__value, 3) OVER w AS other_income__interest_received__value_3y_back,
    LAG(other_income__interest_received__value, 5) OVER w AS other_income__interest_received__value_5y_back,
    LAG(other_income__interest_received__interest_on_deposits) OVER w AS other_income__interest_received__interest_on_deposits_prev_yr,
    LAG(other_income__interest_received__interest_on_deposits, 3) OVER w AS other_income__interest_received__interest_on_deposits_3y_back,
    LAG(other_income__interest_received__interest_on_deposits, 5) OVER w AS other_income__interest_received__interest_on_deposits_5y_back,
    LAG(other_income__interest_received__interest_on_debentures_bonds) OVER w AS other_income__interest_received__interest_on_debentures_bonds_prev_yr,
    LAG(other_income__interest_received__interest_on_debentures_bonds, 3) OVER w AS other_income__interest_received__interest_on_debentures_bonds_3y_back,
    LAG(other_income__interest_received__interest_on_debentures_bonds, 5) OVER w AS other_income__interest_received__interest_on_debentures_bonds_5y_back,
    LAG(other_income__interest_received__interest_on_others) OVER w AS other_income__interest_received__interest_on_others_prev_yr,
    LAG(other_income__interest_received__interest_on_others, 3) OVER w AS other_income__interest_received__interest_on_others_3y_back,
    LAG(other_income__interest_received__interest_on_others, 5) OVER w AS other_income__interest_received__interest_on_others_5y_back,
    LAG(other_income__dividend_received) OVER w AS other_income__dividend_received_prev_yr,
    LAG(other_income__dividend_received, 3) OVER w AS other_income__dividend_received_3y_back,
    LAG(other_income__dividend_received, 5) OVER w AS other_income__dividend_received_5y_back,
    LAG(other_income__commission_received) OVER w AS other_income__commission_received_prev_yr,
    LAG(other_income__commission_received, 3) OVER w AS other_income__commission_received_3y_back,
    LAG(other_income__commission_received, 5) OVER w AS other_income__commission_received_5y_back,
    LAG(other_income__export_incentives) OVER w AS other_income__export_incentives_prev_yr,
    LAG(other_income__export_incentives, 3) OVER w AS other_income__export_incentives_3y_back,
    LAG(other_income__export_incentives, 5) OVER w AS other_income__export_incentives_5y_back,
    LAG(other_income__discounts) OVER w AS other_income__discounts_prev_yr,
    LAG(other_income__discounts, 3) OVER w AS other_income__discounts_3y_back,
    LAG(other_income__discounts, 5) OVER w AS other_income__discounts_5y_back,
    LAG(other_income__profit_on_sale_of_fixed_assets) OVER w AS other_income__profit_on_sale_of_fixed_assets_prev_yr,
    LAG(other_income__profit_on_sale_of_fixed_assets, 3) OVER w AS other_income__profit_on_sale_of_fixed_assets_3y_back,
    LAG(other_income__profit_on_sale_of_fixed_assets, 5) OVER w AS other_income__profit_on_sale_of_fixed_assets_5y_back,
    LAG(other_income__profits_on_sale_of_investments) OVER w AS other_income__profits_on_sale_of_investments_prev_yr,
    LAG(other_income__profits_on_sale_of_investments, 3) OVER w AS other_income__profits_on_sale_of_investments_3y_back,
    LAG(other_income__profits_on_sale_of_investments, 5) OVER w AS other_income__profits_on_sale_of_investments_5y_back,
    LAG(other_income__income_from_mutual_funds) OVER w AS other_income__income_from_mutual_funds_prev_yr,
    LAG(other_income__income_from_mutual_funds, 3) OVER w AS other_income__income_from_mutual_funds_3y_back,
    LAG(other_income__income_from_mutual_funds, 5) OVER w AS other_income__income_from_mutual_funds_5y_back,
    LAG(other_income__income_from_other_investments) OVER w AS other_income__income_from_other_investments_prev_yr,
    LAG(other_income__income_from_other_investments, 3) OVER w AS other_income__income_from_other_investments_3y_back,
    LAG(other_income__income_from_other_investments, 5) OVER w AS other_income__income_from_other_investments_5y_back,
    LAG(other_income__diminution_in_carrying_cost_of_investments) OVER w AS other_income__diminution_in_carrying_cost_of_investments_prev_yr,
    LAG(other_income__diminution_in_carrying_cost_of_investments, 3) OVER w AS other_income__diminution_in_carrying_cost_of_investments_3y_back,
    LAG(other_income__diminution_in_carrying_cost_of_investments, 5) OVER w AS other_income__diminution_in_carrying_cost_of_investments_5y_back,
    LAG(other_income__sale_of_scrap_other_income) OVER w AS other_income__sale_of_scrap_other_income_prev_yr,
    LAG(other_income__sale_of_scrap_other_income, 3) OVER w AS other_income__sale_of_scrap_other_income_3y_back,
    LAG(other_income__sale_of_scrap_other_income, 5) OVER w AS other_income__sale_of_scrap_other_income_5y_back,
    LAG(other_income__service_fee) OVER w AS other_income__service_fee_prev_yr,
    LAG(other_income__service_fee, 3) OVER w AS other_income__service_fee_3y_back,
    LAG(other_income__service_fee, 5) OVER w AS other_income__service_fee_5y_back,
    LAG(other_income__gain_on_forward_contracts_forex) OVER w AS other_income__gain_on_forward_contracts_forex_prev_yr,
    LAG(other_income__gain_on_forward_contracts_forex, 3) OVER w AS other_income__gain_on_forward_contracts_forex_3y_back,
    LAG(other_income__gain_on_forward_contracts_forex, 5) OVER w AS other_income__gain_on_forward_contracts_forex_5y_back,
    LAG(other_income__foreign_exchange_gains) OVER w AS other_income__foreign_exchange_gains_prev_yr,
    LAG(other_income__foreign_exchange_gains, 3) OVER w AS other_income__foreign_exchange_gains_3y_back,
    LAG(other_income__foreign_exchange_gains, 5) OVER w AS other_income__foreign_exchange_gains_5y_back,
    LAG(other_income__lease_rental_income) OVER w AS other_income__lease_rental_income_prev_yr,
    LAG(other_income__lease_rental_income, 3) OVER w AS other_income__lease_rental_income_3y_back,
    LAG(other_income__lease_rental_income, 5) OVER w AS other_income__lease_rental_income_5y_back,
    LAG(other_income__grants_from_government) OVER w AS other_income__grants_from_government_prev_yr,
    LAG(other_income__grants_from_government, 3) OVER w AS other_income__grants_from_government_3y_back,
    LAG(other_income__grants_from_government, 5) OVER w AS other_income__grants_from_government_5y_back,
    LAG(other_income__transfer_from_capital_reserve_capital_grants) OVER w AS other_income__transfer_from_capital_reserve_capital_grants_prev_yr,
    LAG(other_income__transfer_from_capital_reserve_capital_grants, 3) OVER w AS other_income__transfer_from_capital_reserve_capital_grants_3y_back,
    LAG(other_income__transfer_from_capital_reserve_capital_grants, 5) OVER w AS other_income__transfer_from_capital_reserve_capital_grants_5y_back,
    LAG(other_income__bad_debts_recovered) OVER w AS other_income__bad_debts_recovered_prev_yr,
    LAG(other_income__bad_debts_recovered, 3) OVER w AS other_income__bad_debts_recovered_3y_back,
    LAG(other_income__bad_debts_recovered, 5) OVER w AS other_income__bad_debts_recovered_5y_back,
    LAG(other_income__provision_written_back) OVER w AS other_income__provision_written_back_prev_yr,
    LAG(other_income__provision_written_back, 3) OVER w AS other_income__provision_written_back_3y_back,
    LAG(other_income__provision_written_back, 5) OVER w AS other_income__provision_written_back_5y_back,
    LAG(other_income__claims_received) OVER w AS other_income__claims_received_prev_yr,
    LAG(other_income__claims_received, 3) OVER w AS other_income__claims_received_3y_back,
    LAG(other_income__claims_received, 5) OVER w AS other_income__claims_received_5y_back,
    LAG(other_income__sale_of_power) OVER w AS other_income__sale_of_power_prev_yr,
    LAG(other_income__sale_of_power, 3) OVER w AS other_income__sale_of_power_3y_back,
    LAG(other_income__sale_of_power, 5) OVER w AS other_income__sale_of_power_5y_back,
    LAG(other_income__others) OVER w AS other_income__others_prev_yr,
    LAG(other_income__others, 3) OVER w AS other_income__others_3y_back,
    LAG(other_income__others, 5) OVER w AS other_income__others_5y_back,
    LAG(operating_profit) OVER w AS operating_profit_prev_yr,
    LAG(operating_profit, 3) OVER w AS operating_profit_3y_back,
    LAG(operating_profit, 5) OVER w AS operating_profit_5y_back,
    LAG(interest__value) OVER w AS interest__value_prev_yr,
    LAG(interest__value, 3) OVER w AS interest__value_3y_back,
    LAG(interest__value, 5) OVER w AS interest__value_5y_back,
    LAG(interest__interest_on_debenture_bonds) OVER w AS interest__interest_on_debenture_bonds_prev_yr,
    LAG(interest__interest_on_debenture_bonds, 3) OVER w AS interest__interest_on_debenture_bonds_3y_back,
    LAG(interest__interest_on_debenture_bonds, 5) OVER w AS interest__interest_on_debenture_bonds_5y_back,
    LAG(interest__interest_on_term_loan) OVER w AS interest__interest_on_term_loan_prev_yr,
    LAG(interest__interest_on_term_loan, 3) OVER w AS interest__interest_on_term_loan_3y_back,
    LAG(interest__interest_on_term_loan, 5) OVER w AS interest__interest_on_term_loan_5y_back,
    LAG(interest__interest_on_fixed_deposits) OVER w AS interest__interest_on_fixed_deposits_prev_yr,
    LAG(interest__interest_on_fixed_deposits, 3) OVER w AS interest__interest_on_fixed_deposits_3y_back,
    LAG(interest__interest_on_fixed_deposits, 5) OVER w AS interest__interest_on_fixed_deposits_5y_back,
    LAG(interest__interest_on_vehicle_loan) OVER w AS interest__interest_on_vehicle_loan_prev_yr,
    LAG(interest__interest_on_vehicle_loan, 3) OVER w AS interest__interest_on_vehicle_loan_3y_back,
    LAG(interest__interest_on_vehicle_loan, 5) OVER w AS interest__interest_on_vehicle_loan_5y_back,
    LAG(interest__interest_on_cash_credits_packing_credits) OVER w AS interest__interest_on_cash_credits_packing_credits_prev_yr,
    LAG(interest__interest_on_cash_credits_packing_credits, 3) OVER w AS interest__interest_on_cash_credits_packing_credits_3y_back,
    LAG(interest__interest_on_cash_credits_packing_credits, 5) OVER w AS interest__interest_on_cash_credits_packing_credits_5y_back,
    LAG(interest__interest_on_working_capital_loans) OVER w AS interest__interest_on_working_capital_loans_prev_yr,
    LAG(interest__interest_on_working_capital_loans, 3) OVER w AS interest__interest_on_working_capital_loans_3y_back,
    LAG(interest__interest_on_working_capital_loans, 5) OVER w AS interest__interest_on_working_capital_loans_5y_back,
    LAG(interest__bank_charges_etc) OVER w AS interest__bank_charges_etc_prev_yr,
    LAG(interest__bank_charges_etc, 3) OVER w AS interest__bank_charges_etc_3y_back,
    LAG(interest__bank_charges_etc, 5) OVER w AS interest__bank_charges_etc_5y_back,
    LAG(interest__other_interest) OVER w AS interest__other_interest_prev_yr,
    LAG(interest__other_interest, 3) OVER w AS interest__other_interest_3y_back,
    LAG(interest__other_interest, 5) OVER w AS interest__other_interest_5y_back,
    LAG(interest__interest_capitalised) OVER w AS interest__interest_capitalised_prev_yr,
    LAG(interest__interest_capitalised, 3) OVER w AS interest__interest_capitalised_3y_back,
    LAG(interest__interest_capitalised, 5) OVER w AS interest__interest_capitalised_5y_back,
    LAG(pbdt) OVER w AS pbdt_prev_yr,
    LAG(pbdt, 3) OVER w AS pbdt_3y_back,
    LAG(pbdt, 5) OVER w AS pbdt_5y_back,
    LAG(depreciation) OVER w AS depreciation_prev_yr,
    LAG(depreciation, 3) OVER w AS depreciation_3y_back,
    LAG(depreciation, 5) OVER w AS depreciation_5y_back,
    LAG(profit_before_taxation_exceptional_items) OVER w AS profit_before_taxation_exceptional_items_prev_yr,
    LAG(profit_before_taxation_exceptional_items, 3) OVER w AS profit_before_taxation_exceptional_items_3y_back,
    LAG(profit_before_taxation_exceptional_items, 5) OVER w AS profit_before_taxation_exceptional_items_5y_back,
    LAG(share_of_profit_loss_of_jv_associates) OVER w AS share_of_profit_loss_of_jv_associates_prev_yr,
    LAG(share_of_profit_loss_of_jv_associates, 3) OVER w AS share_of_profit_loss_of_jv_associates_3y_back,
    LAG(share_of_profit_loss_of_jv_associates, 5) OVER w AS share_of_profit_loss_of_jv_associates_5y_back,
    LAG(exceptional_income_expenses__value) OVER w AS exceptional_income_expenses__value_prev_yr,
    LAG(exceptional_income_expenses__value, 3) OVER w AS exceptional_income_expenses__value_3y_back,
    LAG(exceptional_income_expenses__value, 5) OVER w AS exceptional_income_expenses__value_5y_back,
    LAG(exceptional_income_expenses__profit_loss_on_sale_of_fixed_assets) OVER w AS exceptional_income_expenses__profit_loss_on_sale_of_fixed_assets_prev_yr,
    LAG(exceptional_income_expenses__profit_loss_on_sale_of_fixed_assets, 3) OVER w AS exceptional_income_expenses__profit_loss_on_sale_of_fixed_assets_3y_back,
    LAG(exceptional_income_expenses__profit_loss_on_sale_of_fixed_assets, 5) OVER w AS exceptional_income_expenses__profit_loss_on_sale_of_fixed_assets_5y_back,
    LAG(exceptional_income_expenses__profit_loss_on_sale_of_investments) OVER w AS exceptional_income_expenses__profit_loss_on_sale_of_investments_prev_yr,
    LAG(exceptional_income_expenses__profit_loss_on_sale_of_investments, 3) OVER w AS exceptional_income_expenses__profit_loss_on_sale_of_investments_3y_back,
    LAG(exceptional_income_expenses__profit_loss_on_sale_of_investments, 5) OVER w AS exceptional_income_expenses__profit_loss_on_sale_of_investments_5y_back,
    LAG(exceptional_income_expenses__restructuring_cost_reversal_of_provisions) OVER w AS exceptional_income_expenses__restructuring_cost_reversal_of_provisions_prev_yr,
    LAG(exceptional_income_expenses__restructuring_cost_reversal_of_provisions, 3) OVER w AS exceptional_income_expenses__restructuring_cost_reversal_of_provisions_3y_back,
    LAG(exceptional_income_expenses__restructuring_cost_reversal_of_provisions, 5) OVER w AS exceptional_income_expenses__restructuring_cost_reversal_of_provisions_5y_back,
    LAG(exceptional_income_expenses__accidental_loss_damages) OVER w AS exceptional_income_expenses__accidental_loss_damages_prev_yr,
    LAG(exceptional_income_expenses__accidental_loss_damages, 3) OVER w AS exceptional_income_expenses__accidental_loss_damages_3y_back,
    LAG(exceptional_income_expenses__accidental_loss_damages, 5) OVER w AS exceptional_income_expenses__accidental_loss_damages_5y_back,
    LAG(exceptional_income_expenses__inventory_write_off) OVER w AS exceptional_income_expenses__inventory_write_off_prev_yr,
    LAG(exceptional_income_expenses__inventory_write_off, 3) OVER w AS exceptional_income_expenses__inventory_write_off_3y_back,
    LAG(exceptional_income_expenses__inventory_write_off, 5) OVER w AS exceptional_income_expenses__inventory_write_off_5y_back,
    LAG(exceptional_income_expenses__other_exceptional_expenses) OVER w AS exceptional_income_expenses__other_exceptional_expenses_prev_yr,
    LAG(exceptional_income_expenses__other_exceptional_expenses, 3) OVER w AS exceptional_income_expenses__other_exceptional_expenses_3y_back,
    LAG(exceptional_income_expenses__other_exceptional_expenses, 5) OVER w AS exceptional_income_expenses__other_exceptional_expenses_5y_back,
    LAG(exceptional_income_expenses__other_exceptional_income) OVER w AS exceptional_income_expenses__other_exceptional_income_prev_yr,
    LAG(exceptional_income_expenses__other_exceptional_income, 3) OVER w AS exceptional_income_expenses__other_exceptional_income_3y_back,
    LAG(exceptional_income_expenses__other_exceptional_income, 5) OVER w AS exceptional_income_expenses__other_exceptional_income_5y_back,
    LAG(profit_before_tax) OVER w AS profit_before_tax_prev_yr,
    LAG(profit_before_tax, 3) OVER w AS profit_before_tax_3y_back,
    LAG(profit_before_tax, 5) OVER w AS profit_before_tax_5y_back,
    LAG(provision_for_tax__value) OVER w AS provision_for_tax__value_prev_yr,
    LAG(provision_for_tax__value, 3) OVER w AS provision_for_tax__value_3y_back,
    LAG(provision_for_tax__value, 5) OVER w AS provision_for_tax__value_5y_back,
    LAG(provision_for_tax__current_income_tax) OVER w AS provision_for_tax__current_income_tax_prev_yr,
    LAG(provision_for_tax__current_income_tax, 3) OVER w AS provision_for_tax__current_income_tax_3y_back,
    LAG(provision_for_tax__current_income_tax, 5) OVER w AS provision_for_tax__current_income_tax_5y_back,
    LAG(provision_for_tax__deferred_tax) OVER w AS provision_for_tax__deferred_tax_prev_yr,
    LAG(provision_for_tax__deferred_tax, 3) OVER w AS provision_for_tax__deferred_tax_3y_back,
    LAG(provision_for_tax__deferred_tax, 5) OVER w AS provision_for_tax__deferred_tax_5y_back,
    LAG(provision_for_tax__fringe_benefit_tax) OVER w AS provision_for_tax__fringe_benefit_tax_prev_yr,
    LAG(provision_for_tax__fringe_benefit_tax, 3) OVER w AS provision_for_tax__fringe_benefit_tax_3y_back,
    LAG(provision_for_tax__fringe_benefit_tax, 5) OVER w AS provision_for_tax__fringe_benefit_tax_5y_back,
    LAG(provision_for_tax__mat_credit_entitlement) OVER w AS provision_for_tax__mat_credit_entitlement_prev_yr,
    LAG(provision_for_tax__mat_credit_entitlement, 3) OVER w AS provision_for_tax__mat_credit_entitlement_3y_back,
    LAG(provision_for_tax__mat_credit_entitlement, 5) OVER w AS provision_for_tax__mat_credit_entitlement_5y_back,
    LAG(provision_for_tax__other_taxes) OVER w AS provision_for_tax__other_taxes_prev_yr,
    LAG(provision_for_tax__other_taxes, 3) OVER w AS provision_for_tax__other_taxes_3y_back,
    LAG(provision_for_tax__other_taxes, 5) OVER w AS provision_for_tax__other_taxes_5y_back,
    LAG(profit_after_tax) OVER w AS profit_after_tax_prev_yr,
    LAG(profit_after_tax, 3) OVER w AS profit_after_tax_3y_back,
    LAG(profit_after_tax, 5) OVER w AS profit_after_tax_5y_back,
    LAG(profit_before_tax_from_discontinued_operations) OVER w AS profit_before_tax_from_discontinued_operations_prev_yr,
    LAG(profit_before_tax_from_discontinued_operations, 3) OVER w AS profit_before_tax_from_discontinued_operations_3y_back,
    LAG(profit_before_tax_from_discontinued_operations, 5) OVER w AS profit_before_tax_from_discontinued_operations_5y_back,
    LAG(tax_from_discontinued_operations) OVER w AS tax_from_discontinued_operations_prev_yr,
    LAG(tax_from_discontinued_operations, 3) OVER w AS tax_from_discontinued_operations_3y_back,
    LAG(tax_from_discontinued_operations, 5) OVER w AS tax_from_discontinued_operations_5y_back,
    LAG(profit_after_tax_from_discontinued_operations) OVER w AS profit_after_tax_from_discontinued_operations_prev_yr,
    LAG(profit_after_tax_from_discontinued_operations, 3) OVER w AS profit_after_tax_from_discontinued_operations_3y_back,
    LAG(profit_after_tax_from_discontinued_operations, 5) OVER w AS profit_after_tax_from_discontinued_operations_5y_back,
    LAG(extra_items) OVER w AS extra_items_prev_yr,
    LAG(extra_items, 3) OVER w AS extra_items_3y_back,
    LAG(extra_items, 5) OVER w AS extra_items_5y_back,
    LAG(minority_interest) OVER w AS minority_interest_prev_yr,
    LAG(minority_interest, 3) OVER w AS minority_interest_3y_back,
    LAG(minority_interest, 5) OVER w AS minority_interest_5y_back,
    LAG(share_of_associate) OVER w AS share_of_associate_prev_yr,
    LAG(share_of_associate, 3) OVER w AS share_of_associate_3y_back,
    LAG(share_of_associate, 5) OVER w AS share_of_associate_5y_back,
    LAG(other_consolidated_items) OVER w AS other_consolidated_items_prev_yr,
    LAG(other_consolidated_items, 3) OVER w AS other_consolidated_items_3y_back,
    LAG(other_consolidated_items, 5) OVER w AS other_consolidated_items_5y_back,
    LAG(consolidated_net_profit) OVER w AS consolidated_net_profit_prev_yr,
    LAG(consolidated_net_profit, 3) OVER w AS consolidated_net_profit_3y_back,
    LAG(consolidated_net_profit, 5) OVER w AS consolidated_net_profit_5y_back,
    LAG(adjustments_to_pat) OVER w AS adjustments_to_pat_prev_yr,
    LAG(adjustments_to_pat, 3) OVER w AS adjustments_to_pat_3y_back,
    LAG(adjustments_to_pat, 5) OVER w AS adjustments_to_pat_5y_back,
    LAG(profit_balance_b_f) OVER w AS profit_balance_b_f_prev_yr,
    LAG(profit_balance_b_f, 3) OVER w AS profit_balance_b_f_3y_back,
    LAG(profit_balance_b_f, 5) OVER w AS profit_balance_b_f_5y_back,
    LAG(appropriations__value) OVER w AS appropriations__value_prev_yr,
    LAG(appropriations__value, 3) OVER w AS appropriations__value_3y_back,
    LAG(appropriations__value, 5) OVER w AS appropriations__value_5y_back,
    LAG(appropriations__general_reserve) OVER w AS appropriations__general_reserve_prev_yr,
    LAG(appropriations__general_reserve, 3) OVER w AS appropriations__general_reserve_3y_back,
    LAG(appropriations__general_reserve, 5) OVER w AS appropriations__general_reserve_5y_back,
    LAG(appropriations__interim_dividend_equity) OVER w AS appropriations__interim_dividend_equity_prev_yr,
    LAG(appropriations__interim_dividend_equity, 3) OVER w AS appropriations__interim_dividend_equity_3y_back,
    LAG(appropriations__interim_dividend_equity, 5) OVER w AS appropriations__interim_dividend_equity_5y_back,
    LAG(appropriations__proposed_equity_dividend) OVER w AS appropriations__proposed_equity_dividend_prev_yr,
    LAG(appropriations__proposed_equity_dividend, 3) OVER w AS appropriations__proposed_equity_dividend_3y_back,
    LAG(appropriations__proposed_equity_dividend, 5) OVER w AS appropriations__proposed_equity_dividend_5y_back,
    LAG(appropriations__preference_dividend) OVER w AS appropriations__preference_dividend_prev_yr,
    LAG(appropriations__preference_dividend, 3) OVER w AS appropriations__preference_dividend_3y_back,
    LAG(appropriations__preference_dividend, 5) OVER w AS appropriations__preference_dividend_5y_back,
    LAG(appropriations__corporate_dividend_tax) OVER w AS appropriations__corporate_dividend_tax_prev_yr,
    LAG(appropriations__corporate_dividend_tax, 3) OVER w AS appropriations__corporate_dividend_tax_3y_back,
    LAG(appropriations__corporate_dividend_tax, 5) OVER w AS appropriations__corporate_dividend_tax_5y_back,
    LAG(appropriations__statutory_reserve) OVER w AS appropriations__statutory_reserve_prev_yr,
    LAG(appropriations__statutory_reserve, 3) OVER w AS appropriations__statutory_reserve_3y_back,
    LAG(appropriations__statutory_reserve, 5) OVER w AS appropriations__statutory_reserve_5y_back,
    LAG(appropriations__other_appropriation) OVER w AS appropriations__other_appropriation_prev_yr,
    LAG(appropriations__other_appropriation, 3) OVER w AS appropriations__other_appropriation_3y_back,
    LAG(appropriations__other_appropriation, 5) OVER w AS appropriations__other_appropriation_5y_back,
    LAG(appropriations__capital_redemption_reserve) OVER w AS appropriations__capital_redemption_reserve_prev_yr,
    LAG(appropriations__capital_redemption_reserve, 3) OVER w AS appropriations__capital_redemption_reserve_3y_back,
    LAG(appropriations__capital_redemption_reserve, 5) OVER w AS appropriations__capital_redemption_reserve_5y_back,
    LAG(appropriations__profit_loss_balance_c_f) OVER w AS appropriations__profit_loss_balance_c_f_prev_yr,
    LAG(appropriations__profit_loss_balance_c_f, 3) OVER w AS appropriations__profit_loss_balance_c_f_3y_back,
    LAG(appropriations__profit_loss_balance_c_f, 5) OVER w AS appropriations__profit_loss_balance_c_f_5y_back,
    LAG(equity_dividend) OVER w AS equity_dividend_prev_yr,
    LAG(equity_dividend, 3) OVER w AS equity_dividend_3y_back,
    LAG(equity_dividend, 5) OVER w AS equity_dividend_5y_back,
    LAG(earnings_per_share_calculated) OVER w AS earnings_per_share_calculated_prev_yr,
    LAG(earnings_per_share_calculated, 3) OVER w AS earnings_per_share_calculated_3y_back,
    LAG(earnings_per_share_calculated, 5) OVER w AS earnings_per_share_calculated_5y_back,
    LAG(adjusted_eps) OVER w AS adjusted_eps_prev_yr,
    LAG(adjusted_eps, 3) OVER w AS adjusted_eps_3y_back,
    LAG(adjusted_eps, 5) OVER w AS adjusted_eps_5y_back,
    LAG(eps_basic_reported) OVER w AS eps_basic_reported_prev_yr,
    LAG(eps_basic_reported, 3) OVER w AS eps_basic_reported_3y_back,
    LAG(eps_basic_reported, 5) OVER w AS eps_basic_reported_5y_back,
    LAG(eps_diluted_reported) OVER w AS eps_diluted_reported_prev_yr,
    LAG(eps_diluted_reported, 3) OVER w AS eps_diluted_reported_3y_back,
    LAG(eps_diluted_reported, 5) OVER w AS eps_diluted_reported_5y_back,
    LAG(others_2) OVER w AS others_2_prev_yr,
    LAG(others_2, 3) OVER w AS others_2_3y_back,
    LAG(others_2, 5) OVER w AS others_2_5y_back,
    LAG(commission_brokerage_discounts) OVER w AS commission_brokerage_discounts_prev_yr,
    LAG(commission_brokerage_discounts, 3) OVER w AS commission_brokerage_discounts_3y_back,
    LAG(commission_brokerage_discounts, 5) OVER w AS commission_brokerage_discounts_5y_back,
    LAG(other_operating_expenses) OVER w AS other_operating_expenses_prev_yr,
    LAG(other_operating_expenses, 3) OVER w AS other_operating_expenses_3y_back,
    LAG(other_operating_expenses, 5) OVER w AS other_operating_expenses_5y_back,
    LAG(director_s_remunerations) OVER w AS director_s_remunerations_prev_yr,
    LAG(director_s_remunerations, 3) OVER w AS director_s_remunerations_3y_back,
    LAG(director_s_remunerations, 5) OVER w AS director_s_remunerations_5y_back,
    LAG(income_from_investments) OVER w AS income_from_investments_prev_yr,
    LAG(income_from_investments, 3) OVER w AS income_from_investments_3y_back,
    LAG(income_from_investments, 5) OVER w AS income_from_investments_5y_back,
    LAG(current_incometax) OVER w AS current_incometax_prev_yr,
    LAG(current_incometax, 3) OVER w AS current_incometax_3y_back,
    LAG(current_incometax, 5) OVER w AS current_incometax_5y_back,
    LAG(deferredtax) OVER w AS deferredtax_prev_yr,
    LAG(deferredtax, 3) OVER w AS deferredtax_3y_back,
    LAG(deferredtax, 5) OVER w AS deferredtax_5y_back
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
  l.yyyymm_3y_back,
  l.yyyymm_5y_back,
  STRUCT(
    STRUCT(
      STRUCT(
        l.increase_decrease_in_stock__value AS value,
        l.increase_decrease_in_stock__value_prev_yr AS prev_yr,
        (l.increase_decrease_in_stock__value - l.increase_decrease_in_stock__value_prev_yr) / ABS(NULLIF(l.increase_decrease_in_stock__value_prev_yr, 0)) * 100 AS yoy_pct,
        l.increase_decrease_in_stock__value_3y_back AS value_3y_back,
        IF(
        l.increase_decrease_in_stock__value > 0
          AND l.increase_decrease_in_stock__value_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.increase_decrease_in_stock__value / l.increase_decrease_in_stock__value_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.increase_decrease_in_stock__value_5y_back AS value_5y_back,
        IF(
        l.increase_decrease_in_stock__value > 0
          AND l.increase_decrease_in_stock__value_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.increase_decrease_in_stock__value / l.increase_decrease_in_stock__value_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS value,
      STRUCT(
        l.increase_decrease_in_stock__opening_work_in_progress AS value,
        l.increase_decrease_in_stock__opening_work_in_progress_prev_yr AS prev_yr,
        (l.increase_decrease_in_stock__opening_work_in_progress - l.increase_decrease_in_stock__opening_work_in_progress_prev_yr) / ABS(NULLIF(l.increase_decrease_in_stock__opening_work_in_progress_prev_yr, 0)) * 100 AS yoy_pct,
        l.increase_decrease_in_stock__opening_work_in_progress_3y_back AS value_3y_back,
        IF(
        l.increase_decrease_in_stock__opening_work_in_progress > 0
          AND l.increase_decrease_in_stock__opening_work_in_progress_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.increase_decrease_in_stock__opening_work_in_progress / l.increase_decrease_in_stock__opening_work_in_progress_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.increase_decrease_in_stock__opening_work_in_progress_5y_back AS value_5y_back,
        IF(
        l.increase_decrease_in_stock__opening_work_in_progress > 0
          AND l.increase_decrease_in_stock__opening_work_in_progress_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.increase_decrease_in_stock__opening_work_in_progress / l.increase_decrease_in_stock__opening_work_in_progress_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS opening_work_in_progress,
      STRUCT(
        l.increase_decrease_in_stock__opening_finished_goods AS value,
        l.increase_decrease_in_stock__opening_finished_goods_prev_yr AS prev_yr,
        (l.increase_decrease_in_stock__opening_finished_goods - l.increase_decrease_in_stock__opening_finished_goods_prev_yr) / ABS(NULLIF(l.increase_decrease_in_stock__opening_finished_goods_prev_yr, 0)) * 100 AS yoy_pct,
        l.increase_decrease_in_stock__opening_finished_goods_3y_back AS value_3y_back,
        IF(
        l.increase_decrease_in_stock__opening_finished_goods > 0
          AND l.increase_decrease_in_stock__opening_finished_goods_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.increase_decrease_in_stock__opening_finished_goods / l.increase_decrease_in_stock__opening_finished_goods_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.increase_decrease_in_stock__opening_finished_goods_5y_back AS value_5y_back,
        IF(
        l.increase_decrease_in_stock__opening_finished_goods > 0
          AND l.increase_decrease_in_stock__opening_finished_goods_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.increase_decrease_in_stock__opening_finished_goods / l.increase_decrease_in_stock__opening_finished_goods_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS opening_finished_goods,
      STRUCT(
        l.increase_decrease_in_stock__opening_shares_units_and_bonds AS value,
        l.increase_decrease_in_stock__opening_shares_units_and_bonds_prev_yr AS prev_yr,
        (l.increase_decrease_in_stock__opening_shares_units_and_bonds - l.increase_decrease_in_stock__opening_shares_units_and_bonds_prev_yr) / ABS(NULLIF(l.increase_decrease_in_stock__opening_shares_units_and_bonds_prev_yr, 0)) * 100 AS yoy_pct,
        l.increase_decrease_in_stock__opening_shares_units_and_bonds_3y_back AS value_3y_back,
        IF(
        l.increase_decrease_in_stock__opening_shares_units_and_bonds > 0
          AND l.increase_decrease_in_stock__opening_shares_units_and_bonds_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.increase_decrease_in_stock__opening_shares_units_and_bonds / l.increase_decrease_in_stock__opening_shares_units_and_bonds_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.increase_decrease_in_stock__opening_shares_units_and_bonds_5y_back AS value_5y_back,
        IF(
        l.increase_decrease_in_stock__opening_shares_units_and_bonds > 0
          AND l.increase_decrease_in_stock__opening_shares_units_and_bonds_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.increase_decrease_in_stock__opening_shares_units_and_bonds / l.increase_decrease_in_stock__opening_shares_units_and_bonds_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS opening_shares_units_and_bonds,
      STRUCT(
        l.increase_decrease_in_stock__other_opening_balances AS value,
        l.increase_decrease_in_stock__other_opening_balances_prev_yr AS prev_yr,
        (l.increase_decrease_in_stock__other_opening_balances - l.increase_decrease_in_stock__other_opening_balances_prev_yr) / ABS(NULLIF(l.increase_decrease_in_stock__other_opening_balances_prev_yr, 0)) * 100 AS yoy_pct,
        l.increase_decrease_in_stock__other_opening_balances_3y_back AS value_3y_back,
        IF(
        l.increase_decrease_in_stock__other_opening_balances > 0
          AND l.increase_decrease_in_stock__other_opening_balances_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.increase_decrease_in_stock__other_opening_balances / l.increase_decrease_in_stock__other_opening_balances_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.increase_decrease_in_stock__other_opening_balances_5y_back AS value_5y_back,
        IF(
        l.increase_decrease_in_stock__other_opening_balances > 0
          AND l.increase_decrease_in_stock__other_opening_balances_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.increase_decrease_in_stock__other_opening_balances / l.increase_decrease_in_stock__other_opening_balances_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS other_opening_balances,
      STRUCT(
        l.increase_decrease_in_stock__less_closing_work_in_progress AS value,
        l.increase_decrease_in_stock__less_closing_work_in_progress_prev_yr AS prev_yr,
        (l.increase_decrease_in_stock__less_closing_work_in_progress - l.increase_decrease_in_stock__less_closing_work_in_progress_prev_yr) / ABS(NULLIF(l.increase_decrease_in_stock__less_closing_work_in_progress_prev_yr, 0)) * 100 AS yoy_pct,
        l.increase_decrease_in_stock__less_closing_work_in_progress_3y_back AS value_3y_back,
        IF(
        l.increase_decrease_in_stock__less_closing_work_in_progress > 0
          AND l.increase_decrease_in_stock__less_closing_work_in_progress_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.increase_decrease_in_stock__less_closing_work_in_progress / l.increase_decrease_in_stock__less_closing_work_in_progress_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.increase_decrease_in_stock__less_closing_work_in_progress_5y_back AS value_5y_back,
        IF(
        l.increase_decrease_in_stock__less_closing_work_in_progress > 0
          AND l.increase_decrease_in_stock__less_closing_work_in_progress_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.increase_decrease_in_stock__less_closing_work_in_progress / l.increase_decrease_in_stock__less_closing_work_in_progress_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS less_closing_work_in_progress,
      STRUCT(
        l.increase_decrease_in_stock__less_closing_finished_goods AS value,
        l.increase_decrease_in_stock__less_closing_finished_goods_prev_yr AS prev_yr,
        (l.increase_decrease_in_stock__less_closing_finished_goods - l.increase_decrease_in_stock__less_closing_finished_goods_prev_yr) / ABS(NULLIF(l.increase_decrease_in_stock__less_closing_finished_goods_prev_yr, 0)) * 100 AS yoy_pct,
        l.increase_decrease_in_stock__less_closing_finished_goods_3y_back AS value_3y_back,
        IF(
        l.increase_decrease_in_stock__less_closing_finished_goods > 0
          AND l.increase_decrease_in_stock__less_closing_finished_goods_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.increase_decrease_in_stock__less_closing_finished_goods / l.increase_decrease_in_stock__less_closing_finished_goods_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.increase_decrease_in_stock__less_closing_finished_goods_5y_back AS value_5y_back,
        IF(
        l.increase_decrease_in_stock__less_closing_finished_goods > 0
          AND l.increase_decrease_in_stock__less_closing_finished_goods_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.increase_decrease_in_stock__less_closing_finished_goods / l.increase_decrease_in_stock__less_closing_finished_goods_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS less_closing_finished_goods,
      STRUCT(
        l.increase_decrease_in_stock__less_closing_shares_units_and_bonds AS value,
        l.increase_decrease_in_stock__less_closing_shares_units_and_bonds_prev_yr AS prev_yr,
        (l.increase_decrease_in_stock__less_closing_shares_units_and_bonds - l.increase_decrease_in_stock__less_closing_shares_units_and_bonds_prev_yr) / ABS(NULLIF(l.increase_decrease_in_stock__less_closing_shares_units_and_bonds_prev_yr, 0)) * 100 AS yoy_pct,
        l.increase_decrease_in_stock__less_closing_shares_units_and_bonds_3y_back AS value_3y_back,
        IF(
        l.increase_decrease_in_stock__less_closing_shares_units_and_bonds > 0
          AND l.increase_decrease_in_stock__less_closing_shares_units_and_bonds_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.increase_decrease_in_stock__less_closing_shares_units_and_bonds / l.increase_decrease_in_stock__less_closing_shares_units_and_bonds_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.increase_decrease_in_stock__less_closing_shares_units_and_bonds_5y_back AS value_5y_back,
        IF(
        l.increase_decrease_in_stock__less_closing_shares_units_and_bonds > 0
          AND l.increase_decrease_in_stock__less_closing_shares_units_and_bonds_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.increase_decrease_in_stock__less_closing_shares_units_and_bonds / l.increase_decrease_in_stock__less_closing_shares_units_and_bonds_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS less_closing_shares_units_and_bonds,
      STRUCT(
        l.increase_decrease_in_stock__less_other_closing_balances AS value,
        l.increase_decrease_in_stock__less_other_closing_balances_prev_yr AS prev_yr,
        (l.increase_decrease_in_stock__less_other_closing_balances - l.increase_decrease_in_stock__less_other_closing_balances_prev_yr) / ABS(NULLIF(l.increase_decrease_in_stock__less_other_closing_balances_prev_yr, 0)) * 100 AS yoy_pct,
        l.increase_decrease_in_stock__less_other_closing_balances_3y_back AS value_3y_back,
        IF(
        l.increase_decrease_in_stock__less_other_closing_balances > 0
          AND l.increase_decrease_in_stock__less_other_closing_balances_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.increase_decrease_in_stock__less_other_closing_balances / l.increase_decrease_in_stock__less_other_closing_balances_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.increase_decrease_in_stock__less_other_closing_balances_5y_back AS value_5y_back,
        IF(
        l.increase_decrease_in_stock__less_other_closing_balances > 0
          AND l.increase_decrease_in_stock__less_other_closing_balances_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.increase_decrease_in_stock__less_other_closing_balances / l.increase_decrease_in_stock__less_other_closing_balances_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS less_other_closing_balances,
      STRUCT(
        l.increase_decrease_in_stock__inter_division_transfer_in_transits AS value,
        l.increase_decrease_in_stock__inter_division_transfer_in_transits_prev_yr AS prev_yr,
        (l.increase_decrease_in_stock__inter_division_transfer_in_transits - l.increase_decrease_in_stock__inter_division_transfer_in_transits_prev_yr) / ABS(NULLIF(l.increase_decrease_in_stock__inter_division_transfer_in_transits_prev_yr, 0)) * 100 AS yoy_pct,
        l.increase_decrease_in_stock__inter_division_transfer_in_transits_3y_back AS value_3y_back,
        IF(
        l.increase_decrease_in_stock__inter_division_transfer_in_transits > 0
          AND l.increase_decrease_in_stock__inter_division_transfer_in_transits_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.increase_decrease_in_stock__inter_division_transfer_in_transits / l.increase_decrease_in_stock__inter_division_transfer_in_transits_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.increase_decrease_in_stock__inter_division_transfer_in_transits_5y_back AS value_5y_back,
        IF(
        l.increase_decrease_in_stock__inter_division_transfer_in_transits > 0
          AND l.increase_decrease_in_stock__inter_division_transfer_in_transits_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.increase_decrease_in_stock__inter_division_transfer_in_transits / l.increase_decrease_in_stock__inter_division_transfer_in_transits_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS inter_division_transfer_in_transits,
      STRUCT(
        l.increase_decrease_in_stock__excise_duty_on_stock_adjustments AS value,
        l.increase_decrease_in_stock__excise_duty_on_stock_adjustments_prev_yr AS prev_yr,
        (l.increase_decrease_in_stock__excise_duty_on_stock_adjustments - l.increase_decrease_in_stock__excise_duty_on_stock_adjustments_prev_yr) / ABS(NULLIF(l.increase_decrease_in_stock__excise_duty_on_stock_adjustments_prev_yr, 0)) * 100 AS yoy_pct,
        l.increase_decrease_in_stock__excise_duty_on_stock_adjustments_3y_back AS value_3y_back,
        IF(
        l.increase_decrease_in_stock__excise_duty_on_stock_adjustments > 0
          AND l.increase_decrease_in_stock__excise_duty_on_stock_adjustments_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.increase_decrease_in_stock__excise_duty_on_stock_adjustments / l.increase_decrease_in_stock__excise_duty_on_stock_adjustments_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.increase_decrease_in_stock__excise_duty_on_stock_adjustments_5y_back AS value_5y_back,
        IF(
        l.increase_decrease_in_stock__excise_duty_on_stock_adjustments > 0
          AND l.increase_decrease_in_stock__excise_duty_on_stock_adjustments_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.increase_decrease_in_stock__excise_duty_on_stock_adjustments / l.increase_decrease_in_stock__excise_duty_on_stock_adjustments_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS excise_duty_on_stock_adjustments,
      STRUCT(
        l.increase_decrease_in_stock__stock_capitalised AS value,
        l.increase_decrease_in_stock__stock_capitalised_prev_yr AS prev_yr,
        (l.increase_decrease_in_stock__stock_capitalised - l.increase_decrease_in_stock__stock_capitalised_prev_yr) / ABS(NULLIF(l.increase_decrease_in_stock__stock_capitalised_prev_yr, 0)) * 100 AS yoy_pct,
        l.increase_decrease_in_stock__stock_capitalised_3y_back AS value_3y_back,
        IF(
        l.increase_decrease_in_stock__stock_capitalised > 0
          AND l.increase_decrease_in_stock__stock_capitalised_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.increase_decrease_in_stock__stock_capitalised / l.increase_decrease_in_stock__stock_capitalised_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.increase_decrease_in_stock__stock_capitalised_5y_back AS value_5y_back,
        IF(
        l.increase_decrease_in_stock__stock_capitalised > 0
          AND l.increase_decrease_in_stock__stock_capitalised_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.increase_decrease_in_stock__stock_capitalised / l.increase_decrease_in_stock__stock_capitalised_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS stock_capitalised
    ) AS increase_decrease_in_stock,
    STRUCT(
      STRUCT(
        l.raw_material_consumed__value AS value,
        l.raw_material_consumed__value_prev_yr AS prev_yr,
        (l.raw_material_consumed__value - l.raw_material_consumed__value_prev_yr) / ABS(NULLIF(l.raw_material_consumed__value_prev_yr, 0)) * 100 AS yoy_pct,
        l.raw_material_consumed__value_3y_back AS value_3y_back,
        IF(
        l.raw_material_consumed__value > 0
          AND l.raw_material_consumed__value_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.raw_material_consumed__value / l.raw_material_consumed__value_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.raw_material_consumed__value_5y_back AS value_5y_back,
        IF(
        l.raw_material_consumed__value > 0
          AND l.raw_material_consumed__value_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.raw_material_consumed__value / l.raw_material_consumed__value_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS value,
      STRUCT(
        l.raw_material_consumed__opening_raw_materials AS value,
        l.raw_material_consumed__opening_raw_materials_prev_yr AS prev_yr,
        (l.raw_material_consumed__opening_raw_materials - l.raw_material_consumed__opening_raw_materials_prev_yr) / ABS(NULLIF(l.raw_material_consumed__opening_raw_materials_prev_yr, 0)) * 100 AS yoy_pct,
        l.raw_material_consumed__opening_raw_materials_3y_back AS value_3y_back,
        IF(
        l.raw_material_consumed__opening_raw_materials > 0
          AND l.raw_material_consumed__opening_raw_materials_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.raw_material_consumed__opening_raw_materials / l.raw_material_consumed__opening_raw_materials_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.raw_material_consumed__opening_raw_materials_5y_back AS value_5y_back,
        IF(
        l.raw_material_consumed__opening_raw_materials > 0
          AND l.raw_material_consumed__opening_raw_materials_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.raw_material_consumed__opening_raw_materials / l.raw_material_consumed__opening_raw_materials_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS opening_raw_materials,
      STRUCT(
        l.raw_material_consumed__purchases_raw_materials AS value,
        l.raw_material_consumed__purchases_raw_materials_prev_yr AS prev_yr,
        (l.raw_material_consumed__purchases_raw_materials - l.raw_material_consumed__purchases_raw_materials_prev_yr) / ABS(NULLIF(l.raw_material_consumed__purchases_raw_materials_prev_yr, 0)) * 100 AS yoy_pct,
        l.raw_material_consumed__purchases_raw_materials_3y_back AS value_3y_back,
        IF(
        l.raw_material_consumed__purchases_raw_materials > 0
          AND l.raw_material_consumed__purchases_raw_materials_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.raw_material_consumed__purchases_raw_materials / l.raw_material_consumed__purchases_raw_materials_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.raw_material_consumed__purchases_raw_materials_5y_back AS value_5y_back,
        IF(
        l.raw_material_consumed__purchases_raw_materials > 0
          AND l.raw_material_consumed__purchases_raw_materials_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.raw_material_consumed__purchases_raw_materials / l.raw_material_consumed__purchases_raw_materials_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS purchases_raw_materials,
      STRUCT(
        l.raw_material_consumed__closing_raw_materials AS value,
        l.raw_material_consumed__closing_raw_materials_prev_yr AS prev_yr,
        (l.raw_material_consumed__closing_raw_materials - l.raw_material_consumed__closing_raw_materials_prev_yr) / ABS(NULLIF(l.raw_material_consumed__closing_raw_materials_prev_yr, 0)) * 100 AS yoy_pct,
        l.raw_material_consumed__closing_raw_materials_3y_back AS value_3y_back,
        IF(
        l.raw_material_consumed__closing_raw_materials > 0
          AND l.raw_material_consumed__closing_raw_materials_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.raw_material_consumed__closing_raw_materials / l.raw_material_consumed__closing_raw_materials_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.raw_material_consumed__closing_raw_materials_5y_back AS value_5y_back,
        IF(
        l.raw_material_consumed__closing_raw_materials > 0
          AND l.raw_material_consumed__closing_raw_materials_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.raw_material_consumed__closing_raw_materials / l.raw_material_consumed__closing_raw_materials_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS closing_raw_materials,
      STRUCT(
        l.raw_material_consumed__other_direct_purchases_brought_in_cost AS value,
        l.raw_material_consumed__other_direct_purchases_brought_in_cost_prev_yr AS prev_yr,
        (l.raw_material_consumed__other_direct_purchases_brought_in_cost - l.raw_material_consumed__other_direct_purchases_brought_in_cost_prev_yr) / ABS(NULLIF(l.raw_material_consumed__other_direct_purchases_brought_in_cost_prev_yr, 0)) * 100 AS yoy_pct,
        l.raw_material_consumed__other_direct_purchases_brought_in_cost_3y_back AS value_3y_back,
        IF(
        l.raw_material_consumed__other_direct_purchases_brought_in_cost > 0
          AND l.raw_material_consumed__other_direct_purchases_brought_in_cost_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.raw_material_consumed__other_direct_purchases_brought_in_cost / l.raw_material_consumed__other_direct_purchases_brought_in_cost_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.raw_material_consumed__other_direct_purchases_brought_in_cost_5y_back AS value_5y_back,
        IF(
        l.raw_material_consumed__other_direct_purchases_brought_in_cost > 0
          AND l.raw_material_consumed__other_direct_purchases_brought_in_cost_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.raw_material_consumed__other_direct_purchases_brought_in_cost / l.raw_material_consumed__other_direct_purchases_brought_in_cost_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS other_direct_purchases_brought_in_cost,
      STRUCT(
        l.raw_material_consumed__stock_on_amalgamation AS value,
        l.raw_material_consumed__stock_on_amalgamation_prev_yr AS prev_yr,
        (l.raw_material_consumed__stock_on_amalgamation - l.raw_material_consumed__stock_on_amalgamation_prev_yr) / ABS(NULLIF(l.raw_material_consumed__stock_on_amalgamation_prev_yr, 0)) * 100 AS yoy_pct,
        l.raw_material_consumed__stock_on_amalgamation_3y_back AS value_3y_back,
        IF(
        l.raw_material_consumed__stock_on_amalgamation > 0
          AND l.raw_material_consumed__stock_on_amalgamation_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.raw_material_consumed__stock_on_amalgamation / l.raw_material_consumed__stock_on_amalgamation_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.raw_material_consumed__stock_on_amalgamation_5y_back AS value_5y_back,
        IF(
        l.raw_material_consumed__stock_on_amalgamation > 0
          AND l.raw_material_consumed__stock_on_amalgamation_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.raw_material_consumed__stock_on_amalgamation / l.raw_material_consumed__stock_on_amalgamation_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS stock_on_amalgamation,
      STRUCT(
        l.raw_material_consumed__other_raw_material_cost AS value,
        l.raw_material_consumed__other_raw_material_cost_prev_yr AS prev_yr,
        (l.raw_material_consumed__other_raw_material_cost - l.raw_material_consumed__other_raw_material_cost_prev_yr) / ABS(NULLIF(l.raw_material_consumed__other_raw_material_cost_prev_yr, 0)) * 100 AS yoy_pct,
        l.raw_material_consumed__other_raw_material_cost_3y_back AS value_3y_back,
        IF(
        l.raw_material_consumed__other_raw_material_cost > 0
          AND l.raw_material_consumed__other_raw_material_cost_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.raw_material_consumed__other_raw_material_cost / l.raw_material_consumed__other_raw_material_cost_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.raw_material_consumed__other_raw_material_cost_5y_back AS value_5y_back,
        IF(
        l.raw_material_consumed__other_raw_material_cost > 0
          AND l.raw_material_consumed__other_raw_material_cost_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.raw_material_consumed__other_raw_material_cost / l.raw_material_consumed__other_raw_material_cost_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS other_raw_material_cost,
      STRUCT(
        l.raw_material_consumed__raw_material_consumed_capitalised AS value,
        l.raw_material_consumed__raw_material_consumed_capitalised_prev_yr AS prev_yr,
        (l.raw_material_consumed__raw_material_consumed_capitalised - l.raw_material_consumed__raw_material_consumed_capitalised_prev_yr) / ABS(NULLIF(l.raw_material_consumed__raw_material_consumed_capitalised_prev_yr, 0)) * 100 AS yoy_pct,
        l.raw_material_consumed__raw_material_consumed_capitalised_3y_back AS value_3y_back,
        IF(
        l.raw_material_consumed__raw_material_consumed_capitalised > 0
          AND l.raw_material_consumed__raw_material_consumed_capitalised_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.raw_material_consumed__raw_material_consumed_capitalised / l.raw_material_consumed__raw_material_consumed_capitalised_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.raw_material_consumed__raw_material_consumed_capitalised_5y_back AS value_5y_back,
        IF(
        l.raw_material_consumed__raw_material_consumed_capitalised > 0
          AND l.raw_material_consumed__raw_material_consumed_capitalised_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.raw_material_consumed__raw_material_consumed_capitalised / l.raw_material_consumed__raw_material_consumed_capitalised_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS raw_material_consumed_capitalised
    ) AS raw_material_consumed,
    STRUCT(
      l.power_fuel_cost AS value,
      l.power_fuel_cost_prev_yr AS prev_yr,
      (l.power_fuel_cost - l.power_fuel_cost_prev_yr) / ABS(NULLIF(l.power_fuel_cost_prev_yr, 0)) * 100 AS yoy_pct,
      l.power_fuel_cost_3y_back AS value_3y_back,
      IF(
      l.power_fuel_cost > 0
        AND l.power_fuel_cost_3y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.power_fuel_cost / l.power_fuel_cost_3y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_3y_pct,
      l.power_fuel_cost_5y_back AS value_5y_back,
      IF(
      l.power_fuel_cost > 0
        AND l.power_fuel_cost_5y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.power_fuel_cost / l.power_fuel_cost_5y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_5y_pct
    ) AS power_fuel_cost,
    STRUCT(
      l.electricity_power AS value,
      l.electricity_power_prev_yr AS prev_yr,
      (l.electricity_power - l.electricity_power_prev_yr) / ABS(NULLIF(l.electricity_power_prev_yr, 0)) * 100 AS yoy_pct,
      l.electricity_power_3y_back AS value_3y_back,
      IF(
      l.electricity_power > 0
        AND l.electricity_power_3y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.electricity_power / l.electricity_power_3y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_3y_pct,
      l.electricity_power_5y_back AS value_5y_back,
      IF(
      l.electricity_power > 0
        AND l.electricity_power_5y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.electricity_power / l.electricity_power_5y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_5y_pct
    ) AS electricity_power,
    STRUCT(
      l.less_captive_consumption_of_power AS value,
      l.less_captive_consumption_of_power_prev_yr AS prev_yr,
      (l.less_captive_consumption_of_power - l.less_captive_consumption_of_power_prev_yr) / ABS(NULLIF(l.less_captive_consumption_of_power_prev_yr, 0)) * 100 AS yoy_pct,
      l.less_captive_consumption_of_power_3y_back AS value_3y_back,
      IF(
      l.less_captive_consumption_of_power > 0
        AND l.less_captive_consumption_of_power_3y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.less_captive_consumption_of_power / l.less_captive_consumption_of_power_3y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_3y_pct,
      l.less_captive_consumption_of_power_5y_back AS value_5y_back,
      IF(
      l.less_captive_consumption_of_power > 0
        AND l.less_captive_consumption_of_power_5y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.less_captive_consumption_of_power / l.less_captive_consumption_of_power_5y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_5y_pct
    ) AS less_captive_consumption_of_power,
    STRUCT(
      l.oil_fuel_natural_gas AS value,
      l.oil_fuel_natural_gas_prev_yr AS prev_yr,
      (l.oil_fuel_natural_gas - l.oil_fuel_natural_gas_prev_yr) / ABS(NULLIF(l.oil_fuel_natural_gas_prev_yr, 0)) * 100 AS yoy_pct,
      l.oil_fuel_natural_gas_3y_back AS value_3y_back,
      IF(
      l.oil_fuel_natural_gas > 0
        AND l.oil_fuel_natural_gas_3y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.oil_fuel_natural_gas / l.oil_fuel_natural_gas_3y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_3y_pct,
      l.oil_fuel_natural_gas_5y_back AS value_5y_back,
      IF(
      l.oil_fuel_natural_gas > 0
        AND l.oil_fuel_natural_gas_5y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.oil_fuel_natural_gas / l.oil_fuel_natural_gas_5y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_5y_pct
    ) AS oil_fuel_natural_gas,
    STRUCT(
      l.less_captive_consumption_of_fuel AS value,
      l.less_captive_consumption_of_fuel_prev_yr AS prev_yr,
      (l.less_captive_consumption_of_fuel - l.less_captive_consumption_of_fuel_prev_yr) / ABS(NULLIF(l.less_captive_consumption_of_fuel_prev_yr, 0)) * 100 AS yoy_pct,
      l.less_captive_consumption_of_fuel_3y_back AS value_3y_back,
      IF(
      l.less_captive_consumption_of_fuel > 0
        AND l.less_captive_consumption_of_fuel_3y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.less_captive_consumption_of_fuel / l.less_captive_consumption_of_fuel_3y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_3y_pct,
      l.less_captive_consumption_of_fuel_5y_back AS value_5y_back,
      IF(
      l.less_captive_consumption_of_fuel > 0
        AND l.less_captive_consumption_of_fuel_5y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.less_captive_consumption_of_fuel / l.less_captive_consumption_of_fuel_5y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_5y_pct
    ) AS less_captive_consumption_of_fuel,
    STRUCT(
      l.coals_etc AS value,
      l.coals_etc_prev_yr AS prev_yr,
      (l.coals_etc - l.coals_etc_prev_yr) / ABS(NULLIF(l.coals_etc_prev_yr, 0)) * 100 AS yoy_pct,
      l.coals_etc_3y_back AS value_3y_back,
      IF(
      l.coals_etc > 0
        AND l.coals_etc_3y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.coals_etc / l.coals_etc_3y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_3y_pct,
      l.coals_etc_5y_back AS value_5y_back,
      IF(
      l.coals_etc > 0
        AND l.coals_etc_5y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.coals_etc / l.coals_etc_5y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_5y_pct
    ) AS coals_etc,
    STRUCT(
      l.other_power_fuel AS value,
      l.other_power_fuel_prev_yr AS prev_yr,
      (l.other_power_fuel - l.other_power_fuel_prev_yr) / ABS(NULLIF(l.other_power_fuel_prev_yr, 0)) * 100 AS yoy_pct,
      l.other_power_fuel_3y_back AS value_3y_back,
      IF(
      l.other_power_fuel > 0
        AND l.other_power_fuel_3y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.other_power_fuel / l.other_power_fuel_3y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_3y_pct,
      l.other_power_fuel_5y_back AS value_5y_back,
      IF(
      l.other_power_fuel > 0
        AND l.other_power_fuel_5y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.other_power_fuel / l.other_power_fuel_5y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_5y_pct
    ) AS other_power_fuel,
    STRUCT(
      l.power_fuel_capitalised AS value,
      l.power_fuel_capitalised_prev_yr AS prev_yr,
      (l.power_fuel_capitalised - l.power_fuel_capitalised_prev_yr) / ABS(NULLIF(l.power_fuel_capitalised_prev_yr, 0)) * 100 AS yoy_pct,
      l.power_fuel_capitalised_3y_back AS value_3y_back,
      IF(
      l.power_fuel_capitalised > 0
        AND l.power_fuel_capitalised_3y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.power_fuel_capitalised / l.power_fuel_capitalised_3y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_3y_pct,
      l.power_fuel_capitalised_5y_back AS value_5y_back,
      IF(
      l.power_fuel_capitalised > 0
        AND l.power_fuel_capitalised_5y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.power_fuel_capitalised / l.power_fuel_capitalised_5y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_5y_pct
    ) AS power_fuel_capitalised,
    STRUCT(
      STRUCT(
        l.employee_cost__value AS value,
        l.employee_cost__value_prev_yr AS prev_yr,
        (l.employee_cost__value - l.employee_cost__value_prev_yr) / ABS(NULLIF(l.employee_cost__value_prev_yr, 0)) * 100 AS yoy_pct,
        l.employee_cost__value_3y_back AS value_3y_back,
        IF(
        l.employee_cost__value > 0
          AND l.employee_cost__value_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.employee_cost__value / l.employee_cost__value_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.employee_cost__value_5y_back AS value_5y_back,
        IF(
        l.employee_cost__value > 0
          AND l.employee_cost__value_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.employee_cost__value / l.employee_cost__value_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS value,
      STRUCT(
        l.employee_cost__salaries_wages_bonus AS value,
        l.employee_cost__salaries_wages_bonus_prev_yr AS prev_yr,
        (l.employee_cost__salaries_wages_bonus - l.employee_cost__salaries_wages_bonus_prev_yr) / ABS(NULLIF(l.employee_cost__salaries_wages_bonus_prev_yr, 0)) * 100 AS yoy_pct,
        l.employee_cost__salaries_wages_bonus_3y_back AS value_3y_back,
        IF(
        l.employee_cost__salaries_wages_bonus > 0
          AND l.employee_cost__salaries_wages_bonus_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.employee_cost__salaries_wages_bonus / l.employee_cost__salaries_wages_bonus_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.employee_cost__salaries_wages_bonus_5y_back AS value_5y_back,
        IF(
        l.employee_cost__salaries_wages_bonus > 0
          AND l.employee_cost__salaries_wages_bonus_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.employee_cost__salaries_wages_bonus / l.employee_cost__salaries_wages_bonus_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS salaries_wages_bonus,
      STRUCT(
        l.employee_cost__contributions_to_epf_pension_funds AS value,
        l.employee_cost__contributions_to_epf_pension_funds_prev_yr AS prev_yr,
        (l.employee_cost__contributions_to_epf_pension_funds - l.employee_cost__contributions_to_epf_pension_funds_prev_yr) / ABS(NULLIF(l.employee_cost__contributions_to_epf_pension_funds_prev_yr, 0)) * 100 AS yoy_pct,
        l.employee_cost__contributions_to_epf_pension_funds_3y_back AS value_3y_back,
        IF(
        l.employee_cost__contributions_to_epf_pension_funds > 0
          AND l.employee_cost__contributions_to_epf_pension_funds_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.employee_cost__contributions_to_epf_pension_funds / l.employee_cost__contributions_to_epf_pension_funds_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.employee_cost__contributions_to_epf_pension_funds_5y_back AS value_5y_back,
        IF(
        l.employee_cost__contributions_to_epf_pension_funds > 0
          AND l.employee_cost__contributions_to_epf_pension_funds_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.employee_cost__contributions_to_epf_pension_funds / l.employee_cost__contributions_to_epf_pension_funds_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS contributions_to_epf_pension_funds,
      STRUCT(
        l.employee_cost__workmen_and_staff_welfare_expenses AS value,
        l.employee_cost__workmen_and_staff_welfare_expenses_prev_yr AS prev_yr,
        (l.employee_cost__workmen_and_staff_welfare_expenses - l.employee_cost__workmen_and_staff_welfare_expenses_prev_yr) / ABS(NULLIF(l.employee_cost__workmen_and_staff_welfare_expenses_prev_yr, 0)) * 100 AS yoy_pct,
        l.employee_cost__workmen_and_staff_welfare_expenses_3y_back AS value_3y_back,
        IF(
        l.employee_cost__workmen_and_staff_welfare_expenses > 0
          AND l.employee_cost__workmen_and_staff_welfare_expenses_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.employee_cost__workmen_and_staff_welfare_expenses / l.employee_cost__workmen_and_staff_welfare_expenses_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.employee_cost__workmen_and_staff_welfare_expenses_5y_back AS value_5y_back,
        IF(
        l.employee_cost__workmen_and_staff_welfare_expenses > 0
          AND l.employee_cost__workmen_and_staff_welfare_expenses_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.employee_cost__workmen_and_staff_welfare_expenses / l.employee_cost__workmen_and_staff_welfare_expenses_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS workmen_and_staff_welfare_expenses,
      STRUCT(
        l.employee_cost__gratuity_ex_gratia AS value,
        l.employee_cost__gratuity_ex_gratia_prev_yr AS prev_yr,
        (l.employee_cost__gratuity_ex_gratia - l.employee_cost__gratuity_ex_gratia_prev_yr) / ABS(NULLIF(l.employee_cost__gratuity_ex_gratia_prev_yr, 0)) * 100 AS yoy_pct,
        l.employee_cost__gratuity_ex_gratia_3y_back AS value_3y_back,
        IF(
        l.employee_cost__gratuity_ex_gratia > 0
          AND l.employee_cost__gratuity_ex_gratia_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.employee_cost__gratuity_ex_gratia / l.employee_cost__gratuity_ex_gratia_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.employee_cost__gratuity_ex_gratia_5y_back AS value_5y_back,
        IF(
        l.employee_cost__gratuity_ex_gratia > 0
          AND l.employee_cost__gratuity_ex_gratia_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.employee_cost__gratuity_ex_gratia / l.employee_cost__gratuity_ex_gratia_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS gratuity_ex_gratia,
      STRUCT(
        l.employee_cost__retrenchment_workers_vrs AS value,
        l.employee_cost__retrenchment_workers_vrs_prev_yr AS prev_yr,
        (l.employee_cost__retrenchment_workers_vrs - l.employee_cost__retrenchment_workers_vrs_prev_yr) / ABS(NULLIF(l.employee_cost__retrenchment_workers_vrs_prev_yr, 0)) * 100 AS yoy_pct,
        l.employee_cost__retrenchment_workers_vrs_3y_back AS value_3y_back,
        IF(
        l.employee_cost__retrenchment_workers_vrs > 0
          AND l.employee_cost__retrenchment_workers_vrs_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.employee_cost__retrenchment_workers_vrs / l.employee_cost__retrenchment_workers_vrs_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.employee_cost__retrenchment_workers_vrs_5y_back AS value_5y_back,
        IF(
        l.employee_cost__retrenchment_workers_vrs > 0
          AND l.employee_cost__retrenchment_workers_vrs_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.employee_cost__retrenchment_workers_vrs / l.employee_cost__retrenchment_workers_vrs_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS retrenchment_workers_vrs,
      STRUCT(
        l.employee_cost__leave_travel_allowance AS value,
        l.employee_cost__leave_travel_allowance_prev_yr AS prev_yr,
        (l.employee_cost__leave_travel_allowance - l.employee_cost__leave_travel_allowance_prev_yr) / ABS(NULLIF(l.employee_cost__leave_travel_allowance_prev_yr, 0)) * 100 AS yoy_pct,
        l.employee_cost__leave_travel_allowance_3y_back AS value_3y_back,
        IF(
        l.employee_cost__leave_travel_allowance > 0
          AND l.employee_cost__leave_travel_allowance_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.employee_cost__leave_travel_allowance / l.employee_cost__leave_travel_allowance_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.employee_cost__leave_travel_allowance_5y_back AS value_5y_back,
        IF(
        l.employee_cost__leave_travel_allowance > 0
          AND l.employee_cost__leave_travel_allowance_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.employee_cost__leave_travel_allowance / l.employee_cost__leave_travel_allowance_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS leave_travel_allowance,
      STRUCT(
        l.employee_cost__leave_encashment AS value,
        l.employee_cost__leave_encashment_prev_yr AS prev_yr,
        (l.employee_cost__leave_encashment - l.employee_cost__leave_encashment_prev_yr) / ABS(NULLIF(l.employee_cost__leave_encashment_prev_yr, 0)) * 100 AS yoy_pct,
        l.employee_cost__leave_encashment_3y_back AS value_3y_back,
        IF(
        l.employee_cost__leave_encashment > 0
          AND l.employee_cost__leave_encashment_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.employee_cost__leave_encashment / l.employee_cost__leave_encashment_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.employee_cost__leave_encashment_5y_back AS value_5y_back,
        IF(
        l.employee_cost__leave_encashment > 0
          AND l.employee_cost__leave_encashment_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.employee_cost__leave_encashment / l.employee_cost__leave_encashment_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS leave_encashment,
      STRUCT(
        l.employee_cost__amortisation_of_deferred_stock_compensation_cost AS value,
        l.employee_cost__amortisation_of_deferred_stock_compensation_cost_prev_yr AS prev_yr,
        (l.employee_cost__amortisation_of_deferred_stock_compensation_cost - l.employee_cost__amortisation_of_deferred_stock_compensation_cost_prev_yr) / ABS(NULLIF(l.employee_cost__amortisation_of_deferred_stock_compensation_cost_prev_yr, 0)) * 100 AS yoy_pct,
        l.employee_cost__amortisation_of_deferred_stock_compensation_cost_3y_back AS value_3y_back,
        IF(
        l.employee_cost__amortisation_of_deferred_stock_compensation_cost > 0
          AND l.employee_cost__amortisation_of_deferred_stock_compensation_cost_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.employee_cost__amortisation_of_deferred_stock_compensation_cost / l.employee_cost__amortisation_of_deferred_stock_compensation_cost_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.employee_cost__amortisation_of_deferred_stock_compensation_cost_5y_back AS value_5y_back,
        IF(
        l.employee_cost__amortisation_of_deferred_stock_compensation_cost > 0
          AND l.employee_cost__amortisation_of_deferred_stock_compensation_cost_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.employee_cost__amortisation_of_deferred_stock_compensation_cost / l.employee_cost__amortisation_of_deferred_stock_compensation_cost_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS amortisation_of_deferred_stock_compensation_cost,
      STRUCT(
        l.employee_cost__other_employees_cost AS value,
        l.employee_cost__other_employees_cost_prev_yr AS prev_yr,
        (l.employee_cost__other_employees_cost - l.employee_cost__other_employees_cost_prev_yr) / ABS(NULLIF(l.employee_cost__other_employees_cost_prev_yr, 0)) * 100 AS yoy_pct,
        l.employee_cost__other_employees_cost_3y_back AS value_3y_back,
        IF(
        l.employee_cost__other_employees_cost > 0
          AND l.employee_cost__other_employees_cost_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.employee_cost__other_employees_cost / l.employee_cost__other_employees_cost_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.employee_cost__other_employees_cost_5y_back AS value_5y_back,
        IF(
        l.employee_cost__other_employees_cost > 0
          AND l.employee_cost__other_employees_cost_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.employee_cost__other_employees_cost / l.employee_cost__other_employees_cost_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS other_employees_cost,
      STRUCT(
        l.employee_cost__employee_cost_capitalised AS value,
        l.employee_cost__employee_cost_capitalised_prev_yr AS prev_yr,
        (l.employee_cost__employee_cost_capitalised - l.employee_cost__employee_cost_capitalised_prev_yr) / ABS(NULLIF(l.employee_cost__employee_cost_capitalised_prev_yr, 0)) * 100 AS yoy_pct,
        l.employee_cost__employee_cost_capitalised_3y_back AS value_3y_back,
        IF(
        l.employee_cost__employee_cost_capitalised > 0
          AND l.employee_cost__employee_cost_capitalised_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.employee_cost__employee_cost_capitalised / l.employee_cost__employee_cost_capitalised_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.employee_cost__employee_cost_capitalised_5y_back AS value_5y_back,
        IF(
        l.employee_cost__employee_cost_capitalised > 0
          AND l.employee_cost__employee_cost_capitalised_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.employee_cost__employee_cost_capitalised / l.employee_cost__employee_cost_capitalised_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS employee_cost_capitalised
    ) AS employee_cost,
    STRUCT(
      STRUCT(
        l.other_manufacturing_expenses__value AS value,
        l.other_manufacturing_expenses__value_prev_yr AS prev_yr,
        (l.other_manufacturing_expenses__value - l.other_manufacturing_expenses__value_prev_yr) / ABS(NULLIF(l.other_manufacturing_expenses__value_prev_yr, 0)) * 100 AS yoy_pct,
        l.other_manufacturing_expenses__value_3y_back AS value_3y_back,
        IF(
        l.other_manufacturing_expenses__value > 0
          AND l.other_manufacturing_expenses__value_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_manufacturing_expenses__value / l.other_manufacturing_expenses__value_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.other_manufacturing_expenses__value_5y_back AS value_5y_back,
        IF(
        l.other_manufacturing_expenses__value > 0
          AND l.other_manufacturing_expenses__value_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_manufacturing_expenses__value / l.other_manufacturing_expenses__value_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS value,
      STRUCT(
        l.other_manufacturing_expenses__sub_contracted_outsourced_services AS value,
        l.other_manufacturing_expenses__sub_contracted_outsourced_services_prev_yr AS prev_yr,
        (l.other_manufacturing_expenses__sub_contracted_outsourced_services - l.other_manufacturing_expenses__sub_contracted_outsourced_services_prev_yr) / ABS(NULLIF(l.other_manufacturing_expenses__sub_contracted_outsourced_services_prev_yr, 0)) * 100 AS yoy_pct,
        l.other_manufacturing_expenses__sub_contracted_outsourced_services_3y_back AS value_3y_back,
        IF(
        l.other_manufacturing_expenses__sub_contracted_outsourced_services > 0
          AND l.other_manufacturing_expenses__sub_contracted_outsourced_services_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_manufacturing_expenses__sub_contracted_outsourced_services / l.other_manufacturing_expenses__sub_contracted_outsourced_services_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.other_manufacturing_expenses__sub_contracted_outsourced_services_5y_back AS value_5y_back,
        IF(
        l.other_manufacturing_expenses__sub_contracted_outsourced_services > 0
          AND l.other_manufacturing_expenses__sub_contracted_outsourced_services_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_manufacturing_expenses__sub_contracted_outsourced_services / l.other_manufacturing_expenses__sub_contracted_outsourced_services_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS sub_contracted_outsourced_services,
      STRUCT(
        l.other_manufacturing_expenses__processing_charges AS value,
        l.other_manufacturing_expenses__processing_charges_prev_yr AS prev_yr,
        (l.other_manufacturing_expenses__processing_charges - l.other_manufacturing_expenses__processing_charges_prev_yr) / ABS(NULLIF(l.other_manufacturing_expenses__processing_charges_prev_yr, 0)) * 100 AS yoy_pct,
        l.other_manufacturing_expenses__processing_charges_3y_back AS value_3y_back,
        IF(
        l.other_manufacturing_expenses__processing_charges > 0
          AND l.other_manufacturing_expenses__processing_charges_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_manufacturing_expenses__processing_charges / l.other_manufacturing_expenses__processing_charges_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.other_manufacturing_expenses__processing_charges_5y_back AS value_5y_back,
        IF(
        l.other_manufacturing_expenses__processing_charges > 0
          AND l.other_manufacturing_expenses__processing_charges_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_manufacturing_expenses__processing_charges / l.other_manufacturing_expenses__processing_charges_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS processing_charges,
      STRUCT(
        STRUCT(
          l.other_manufacturing_expenses__repairs_and_maintenance__value AS value,
          l.other_manufacturing_expenses__repairs_and_maintenance__value_prev_yr AS prev_yr,
          (l.other_manufacturing_expenses__repairs_and_maintenance__value - l.other_manufacturing_expenses__repairs_and_maintenance__value_prev_yr) / ABS(NULLIF(l.other_manufacturing_expenses__repairs_and_maintenance__value_prev_yr, 0)) * 100 AS yoy_pct,
          l.other_manufacturing_expenses__repairs_and_maintenance__value_3y_back AS value_3y_back,
          IF(
          l.other_manufacturing_expenses__repairs_and_maintenance__value > 0
            AND l.other_manufacturing_expenses__repairs_and_maintenance__value_3y_back > 0
            AND DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH)
              > 0,
          (
            POW(
              l.other_manufacturing_expenses__repairs_and_maintenance__value / l.other_manufacturing_expenses__repairs_and_maintenance__value_3y_back,
              12.0 / DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                MONTH))
            - 1)
            * 100,
          NULL) AS cagr_3y_pct,
          l.other_manufacturing_expenses__repairs_and_maintenance__value_5y_back AS value_5y_back,
          IF(
          l.other_manufacturing_expenses__repairs_and_maintenance__value > 0
            AND l.other_manufacturing_expenses__repairs_and_maintenance__value_5y_back > 0
            AND DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH)
              > 0,
          (
            POW(
              l.other_manufacturing_expenses__repairs_and_maintenance__value / l.other_manufacturing_expenses__repairs_and_maintenance__value_5y_back,
              12.0 / DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                MONTH))
            - 1)
            * 100,
          NULL) AS cagr_5y_pct
        ) AS value,
        STRUCT(
          l.other_manufacturing_expenses__repairs_and_maintenance__building_premises AS value,
          l.other_manufacturing_expenses__repairs_and_maintenance__building_premises_prev_yr AS prev_yr,
          (l.other_manufacturing_expenses__repairs_and_maintenance__building_premises - l.other_manufacturing_expenses__repairs_and_maintenance__building_premises_prev_yr) / ABS(NULLIF(l.other_manufacturing_expenses__repairs_and_maintenance__building_premises_prev_yr, 0)) * 100 AS yoy_pct,
          l.other_manufacturing_expenses__repairs_and_maintenance__building_premises_3y_back AS value_3y_back,
          IF(
          l.other_manufacturing_expenses__repairs_and_maintenance__building_premises > 0
            AND l.other_manufacturing_expenses__repairs_and_maintenance__building_premises_3y_back > 0
            AND DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH)
              > 0,
          (
            POW(
              l.other_manufacturing_expenses__repairs_and_maintenance__building_premises / l.other_manufacturing_expenses__repairs_and_maintenance__building_premises_3y_back,
              12.0 / DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                MONTH))
            - 1)
            * 100,
          NULL) AS cagr_3y_pct,
          l.other_manufacturing_expenses__repairs_and_maintenance__building_premises_5y_back AS value_5y_back,
          IF(
          l.other_manufacturing_expenses__repairs_and_maintenance__building_premises > 0
            AND l.other_manufacturing_expenses__repairs_and_maintenance__building_premises_5y_back > 0
            AND DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH)
              > 0,
          (
            POW(
              l.other_manufacturing_expenses__repairs_and_maintenance__building_premises / l.other_manufacturing_expenses__repairs_and_maintenance__building_premises_5y_back,
              12.0 / DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                MONTH))
            - 1)
            * 100,
          NULL) AS cagr_5y_pct
        ) AS building_premises,
        STRUCT(
          l.other_manufacturing_expenses__repairs_and_maintenance__plant_machinery AS value,
          l.other_manufacturing_expenses__repairs_and_maintenance__plant_machinery_prev_yr AS prev_yr,
          (l.other_manufacturing_expenses__repairs_and_maintenance__plant_machinery - l.other_manufacturing_expenses__repairs_and_maintenance__plant_machinery_prev_yr) / ABS(NULLIF(l.other_manufacturing_expenses__repairs_and_maintenance__plant_machinery_prev_yr, 0)) * 100 AS yoy_pct,
          l.other_manufacturing_expenses__repairs_and_maintenance__plant_machinery_3y_back AS value_3y_back,
          IF(
          l.other_manufacturing_expenses__repairs_and_maintenance__plant_machinery > 0
            AND l.other_manufacturing_expenses__repairs_and_maintenance__plant_machinery_3y_back > 0
            AND DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH)
              > 0,
          (
            POW(
              l.other_manufacturing_expenses__repairs_and_maintenance__plant_machinery / l.other_manufacturing_expenses__repairs_and_maintenance__plant_machinery_3y_back,
              12.0 / DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                MONTH))
            - 1)
            * 100,
          NULL) AS cagr_3y_pct,
          l.other_manufacturing_expenses__repairs_and_maintenance__plant_machinery_5y_back AS value_5y_back,
          IF(
          l.other_manufacturing_expenses__repairs_and_maintenance__plant_machinery > 0
            AND l.other_manufacturing_expenses__repairs_and_maintenance__plant_machinery_5y_back > 0
            AND DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH)
              > 0,
          (
            POW(
              l.other_manufacturing_expenses__repairs_and_maintenance__plant_machinery / l.other_manufacturing_expenses__repairs_and_maintenance__plant_machinery_5y_back,
              12.0 / DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                MONTH))
            - 1)
            * 100,
          NULL) AS cagr_5y_pct
        ) AS plant_machinery,
        STRUCT(
          l.other_manufacturing_expenses__repairs_and_maintenance__other_repairs AS value,
          l.other_manufacturing_expenses__repairs_and_maintenance__other_repairs_prev_yr AS prev_yr,
          (l.other_manufacturing_expenses__repairs_and_maintenance__other_repairs - l.other_manufacturing_expenses__repairs_and_maintenance__other_repairs_prev_yr) / ABS(NULLIF(l.other_manufacturing_expenses__repairs_and_maintenance__other_repairs_prev_yr, 0)) * 100 AS yoy_pct,
          l.other_manufacturing_expenses__repairs_and_maintenance__other_repairs_3y_back AS value_3y_back,
          IF(
          l.other_manufacturing_expenses__repairs_and_maintenance__other_repairs > 0
            AND l.other_manufacturing_expenses__repairs_and_maintenance__other_repairs_3y_back > 0
            AND DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH)
              > 0,
          (
            POW(
              l.other_manufacturing_expenses__repairs_and_maintenance__other_repairs / l.other_manufacturing_expenses__repairs_and_maintenance__other_repairs_3y_back,
              12.0 / DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                MONTH))
            - 1)
            * 100,
          NULL) AS cagr_3y_pct,
          l.other_manufacturing_expenses__repairs_and_maintenance__other_repairs_5y_back AS value_5y_back,
          IF(
          l.other_manufacturing_expenses__repairs_and_maintenance__other_repairs > 0
            AND l.other_manufacturing_expenses__repairs_and_maintenance__other_repairs_5y_back > 0
            AND DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH)
              > 0,
          (
            POW(
              l.other_manufacturing_expenses__repairs_and_maintenance__other_repairs / l.other_manufacturing_expenses__repairs_and_maintenance__other_repairs_5y_back,
              12.0 / DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                MONTH))
            - 1)
            * 100,
          NULL) AS cagr_5y_pct
        ) AS other_repairs
      ) AS repairs_and_maintenance,
      STRUCT(
        l.other_manufacturing_expenses__research_development AS value,
        l.other_manufacturing_expenses__research_development_prev_yr AS prev_yr,
        (l.other_manufacturing_expenses__research_development - l.other_manufacturing_expenses__research_development_prev_yr) / ABS(NULLIF(l.other_manufacturing_expenses__research_development_prev_yr, 0)) * 100 AS yoy_pct,
        l.other_manufacturing_expenses__research_development_3y_back AS value_3y_back,
        IF(
        l.other_manufacturing_expenses__research_development > 0
          AND l.other_manufacturing_expenses__research_development_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_manufacturing_expenses__research_development / l.other_manufacturing_expenses__research_development_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.other_manufacturing_expenses__research_development_5y_back AS value_5y_back,
        IF(
        l.other_manufacturing_expenses__research_development > 0
          AND l.other_manufacturing_expenses__research_development_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_manufacturing_expenses__research_development / l.other_manufacturing_expenses__research_development_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS research_development,
      STRUCT(
        l.other_manufacturing_expenses__plant_machinery_hire_charges AS value,
        l.other_manufacturing_expenses__plant_machinery_hire_charges_prev_yr AS prev_yr,
        (l.other_manufacturing_expenses__plant_machinery_hire_charges - l.other_manufacturing_expenses__plant_machinery_hire_charges_prev_yr) / ABS(NULLIF(l.other_manufacturing_expenses__plant_machinery_hire_charges_prev_yr, 0)) * 100 AS yoy_pct,
        l.other_manufacturing_expenses__plant_machinery_hire_charges_3y_back AS value_3y_back,
        IF(
        l.other_manufacturing_expenses__plant_machinery_hire_charges > 0
          AND l.other_manufacturing_expenses__plant_machinery_hire_charges_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_manufacturing_expenses__plant_machinery_hire_charges / l.other_manufacturing_expenses__plant_machinery_hire_charges_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.other_manufacturing_expenses__plant_machinery_hire_charges_5y_back AS value_5y_back,
        IF(
        l.other_manufacturing_expenses__plant_machinery_hire_charges > 0
          AND l.other_manufacturing_expenses__plant_machinery_hire_charges_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_manufacturing_expenses__plant_machinery_hire_charges / l.other_manufacturing_expenses__plant_machinery_hire_charges_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS plant_machinery_hire_charges,
      STRUCT(
        l.other_manufacturing_expenses__royalty AS value,
        l.other_manufacturing_expenses__royalty_prev_yr AS prev_yr,
        (l.other_manufacturing_expenses__royalty - l.other_manufacturing_expenses__royalty_prev_yr) / ABS(NULLIF(l.other_manufacturing_expenses__royalty_prev_yr, 0)) * 100 AS yoy_pct,
        l.other_manufacturing_expenses__royalty_3y_back AS value_3y_back,
        IF(
        l.other_manufacturing_expenses__royalty > 0
          AND l.other_manufacturing_expenses__royalty_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_manufacturing_expenses__royalty / l.other_manufacturing_expenses__royalty_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.other_manufacturing_expenses__royalty_5y_back AS value_5y_back,
        IF(
        l.other_manufacturing_expenses__royalty > 0
          AND l.other_manufacturing_expenses__royalty_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_manufacturing_expenses__royalty / l.other_manufacturing_expenses__royalty_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS royalty,
      STRUCT(
        l.other_manufacturing_expenses__freight_transportation_port_charges AS value,
        l.other_manufacturing_expenses__freight_transportation_port_charges_prev_yr AS prev_yr,
        (l.other_manufacturing_expenses__freight_transportation_port_charges - l.other_manufacturing_expenses__freight_transportation_port_charges_prev_yr) / ABS(NULLIF(l.other_manufacturing_expenses__freight_transportation_port_charges_prev_yr, 0)) * 100 AS yoy_pct,
        l.other_manufacturing_expenses__freight_transportation_port_charges_3y_back AS value_3y_back,
        IF(
        l.other_manufacturing_expenses__freight_transportation_port_charges > 0
          AND l.other_manufacturing_expenses__freight_transportation_port_charges_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_manufacturing_expenses__freight_transportation_port_charges / l.other_manufacturing_expenses__freight_transportation_port_charges_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.other_manufacturing_expenses__freight_transportation_port_charges_5y_back AS value_5y_back,
        IF(
        l.other_manufacturing_expenses__freight_transportation_port_charges > 0
          AND l.other_manufacturing_expenses__freight_transportation_port_charges_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_manufacturing_expenses__freight_transportation_port_charges / l.other_manufacturing_expenses__freight_transportation_port_charges_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS freight_transportation_port_charges,
      STRUCT(
        l.other_manufacturing_expenses__packing_material_consumed AS value,
        l.other_manufacturing_expenses__packing_material_consumed_prev_yr AS prev_yr,
        (l.other_manufacturing_expenses__packing_material_consumed - l.other_manufacturing_expenses__packing_material_consumed_prev_yr) / ABS(NULLIF(l.other_manufacturing_expenses__packing_material_consumed_prev_yr, 0)) * 100 AS yoy_pct,
        l.other_manufacturing_expenses__packing_material_consumed_3y_back AS value_3y_back,
        IF(
        l.other_manufacturing_expenses__packing_material_consumed > 0
          AND l.other_manufacturing_expenses__packing_material_consumed_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_manufacturing_expenses__packing_material_consumed / l.other_manufacturing_expenses__packing_material_consumed_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.other_manufacturing_expenses__packing_material_consumed_5y_back AS value_5y_back,
        IF(
        l.other_manufacturing_expenses__packing_material_consumed > 0
          AND l.other_manufacturing_expenses__packing_material_consumed_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_manufacturing_expenses__packing_material_consumed / l.other_manufacturing_expenses__packing_material_consumed_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS packing_material_consumed,
      STRUCT(
        l.other_manufacturing_expenses__stores_spare_parts_and_tools_consumed AS value,
        l.other_manufacturing_expenses__stores_spare_parts_and_tools_consumed_prev_yr AS prev_yr,
        (l.other_manufacturing_expenses__stores_spare_parts_and_tools_consumed - l.other_manufacturing_expenses__stores_spare_parts_and_tools_consumed_prev_yr) / ABS(NULLIF(l.other_manufacturing_expenses__stores_spare_parts_and_tools_consumed_prev_yr, 0)) * 100 AS yoy_pct,
        l.other_manufacturing_expenses__stores_spare_parts_and_tools_consumed_3y_back AS value_3y_back,
        IF(
        l.other_manufacturing_expenses__stores_spare_parts_and_tools_consumed > 0
          AND l.other_manufacturing_expenses__stores_spare_parts_and_tools_consumed_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_manufacturing_expenses__stores_spare_parts_and_tools_consumed / l.other_manufacturing_expenses__stores_spare_parts_and_tools_consumed_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.other_manufacturing_expenses__stores_spare_parts_and_tools_consumed_5y_back AS value_5y_back,
        IF(
        l.other_manufacturing_expenses__stores_spare_parts_and_tools_consumed > 0
          AND l.other_manufacturing_expenses__stores_spare_parts_and_tools_consumed_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_manufacturing_expenses__stores_spare_parts_and_tools_consumed / l.other_manufacturing_expenses__stores_spare_parts_and_tools_consumed_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS stores_spare_parts_and_tools_consumed,
      STRUCT(
        l.other_manufacturing_expenses__up_keep_and_maintenance_charges AS value,
        l.other_manufacturing_expenses__up_keep_and_maintenance_charges_prev_yr AS prev_yr,
        (l.other_manufacturing_expenses__up_keep_and_maintenance_charges - l.other_manufacturing_expenses__up_keep_and_maintenance_charges_prev_yr) / ABS(NULLIF(l.other_manufacturing_expenses__up_keep_and_maintenance_charges_prev_yr, 0)) * 100 AS yoy_pct,
        l.other_manufacturing_expenses__up_keep_and_maintenance_charges_3y_back AS value_3y_back,
        IF(
        l.other_manufacturing_expenses__up_keep_and_maintenance_charges > 0
          AND l.other_manufacturing_expenses__up_keep_and_maintenance_charges_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_manufacturing_expenses__up_keep_and_maintenance_charges / l.other_manufacturing_expenses__up_keep_and_maintenance_charges_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.other_manufacturing_expenses__up_keep_and_maintenance_charges_5y_back AS value_5y_back,
        IF(
        l.other_manufacturing_expenses__up_keep_and_maintenance_charges > 0
          AND l.other_manufacturing_expenses__up_keep_and_maintenance_charges_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_manufacturing_expenses__up_keep_and_maintenance_charges / l.other_manufacturing_expenses__up_keep_and_maintenance_charges_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS up_keep_and_maintenance_charges,
      STRUCT(
        l.other_manufacturing_expenses__project_expenses AS value,
        l.other_manufacturing_expenses__project_expenses_prev_yr AS prev_yr,
        (l.other_manufacturing_expenses__project_expenses - l.other_manufacturing_expenses__project_expenses_prev_yr) / ABS(NULLIF(l.other_manufacturing_expenses__project_expenses_prev_yr, 0)) * 100 AS yoy_pct,
        l.other_manufacturing_expenses__project_expenses_3y_back AS value_3y_back,
        IF(
        l.other_manufacturing_expenses__project_expenses > 0
          AND l.other_manufacturing_expenses__project_expenses_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_manufacturing_expenses__project_expenses / l.other_manufacturing_expenses__project_expenses_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.other_manufacturing_expenses__project_expenses_5y_back AS value_5y_back,
        IF(
        l.other_manufacturing_expenses__project_expenses > 0
          AND l.other_manufacturing_expenses__project_expenses_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_manufacturing_expenses__project_expenses / l.other_manufacturing_expenses__project_expenses_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS project_expenses,
      STRUCT(
        l.other_manufacturing_expenses__hire_charges_mfg AS value,
        l.other_manufacturing_expenses__hire_charges_mfg_prev_yr AS prev_yr,
        (l.other_manufacturing_expenses__hire_charges_mfg - l.other_manufacturing_expenses__hire_charges_mfg_prev_yr) / ABS(NULLIF(l.other_manufacturing_expenses__hire_charges_mfg_prev_yr, 0)) * 100 AS yoy_pct,
        l.other_manufacturing_expenses__hire_charges_mfg_3y_back AS value_3y_back,
        IF(
        l.other_manufacturing_expenses__hire_charges_mfg > 0
          AND l.other_manufacturing_expenses__hire_charges_mfg_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_manufacturing_expenses__hire_charges_mfg / l.other_manufacturing_expenses__hire_charges_mfg_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.other_manufacturing_expenses__hire_charges_mfg_5y_back AS value_5y_back,
        IF(
        l.other_manufacturing_expenses__hire_charges_mfg > 0
          AND l.other_manufacturing_expenses__hire_charges_mfg_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_manufacturing_expenses__hire_charges_mfg / l.other_manufacturing_expenses__hire_charges_mfg_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS hire_charges_mfg,
      STRUCT(
        l.other_manufacturing_expenses__other_mfg_exp AS value,
        l.other_manufacturing_expenses__other_mfg_exp_prev_yr AS prev_yr,
        (l.other_manufacturing_expenses__other_mfg_exp - l.other_manufacturing_expenses__other_mfg_exp_prev_yr) / ABS(NULLIF(l.other_manufacturing_expenses__other_mfg_exp_prev_yr, 0)) * 100 AS yoy_pct,
        l.other_manufacturing_expenses__other_mfg_exp_3y_back AS value_3y_back,
        IF(
        l.other_manufacturing_expenses__other_mfg_exp > 0
          AND l.other_manufacturing_expenses__other_mfg_exp_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_manufacturing_expenses__other_mfg_exp / l.other_manufacturing_expenses__other_mfg_exp_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.other_manufacturing_expenses__other_mfg_exp_5y_back AS value_5y_back,
        IF(
        l.other_manufacturing_expenses__other_mfg_exp > 0
          AND l.other_manufacturing_expenses__other_mfg_exp_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_manufacturing_expenses__other_mfg_exp / l.other_manufacturing_expenses__other_mfg_exp_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS other_mfg_exp,
      STRUCT(
        l.other_manufacturing_expenses__manufacturing_expenses_capitalised AS value,
        l.other_manufacturing_expenses__manufacturing_expenses_capitalised_prev_yr AS prev_yr,
        (l.other_manufacturing_expenses__manufacturing_expenses_capitalised - l.other_manufacturing_expenses__manufacturing_expenses_capitalised_prev_yr) / ABS(NULLIF(l.other_manufacturing_expenses__manufacturing_expenses_capitalised_prev_yr, 0)) * 100 AS yoy_pct,
        l.other_manufacturing_expenses__manufacturing_expenses_capitalised_3y_back AS value_3y_back,
        IF(
        l.other_manufacturing_expenses__manufacturing_expenses_capitalised > 0
          AND l.other_manufacturing_expenses__manufacturing_expenses_capitalised_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_manufacturing_expenses__manufacturing_expenses_capitalised / l.other_manufacturing_expenses__manufacturing_expenses_capitalised_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.other_manufacturing_expenses__manufacturing_expenses_capitalised_5y_back AS value_5y_back,
        IF(
        l.other_manufacturing_expenses__manufacturing_expenses_capitalised > 0
          AND l.other_manufacturing_expenses__manufacturing_expenses_capitalised_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_manufacturing_expenses__manufacturing_expenses_capitalised / l.other_manufacturing_expenses__manufacturing_expenses_capitalised_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS manufacturing_expenses_capitalised
    ) AS other_manufacturing_expenses,
    STRUCT(
      STRUCT(
        l.general_and_administration_expenses__value AS value,
        l.general_and_administration_expenses__value_prev_yr AS prev_yr,
        (l.general_and_administration_expenses__value - l.general_and_administration_expenses__value_prev_yr) / ABS(NULLIF(l.general_and_administration_expenses__value_prev_yr, 0)) * 100 AS yoy_pct,
        l.general_and_administration_expenses__value_3y_back AS value_3y_back,
        IF(
        l.general_and_administration_expenses__value > 0
          AND l.general_and_administration_expenses__value_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.general_and_administration_expenses__value / l.general_and_administration_expenses__value_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.general_and_administration_expenses__value_5y_back AS value_5y_back,
        IF(
        l.general_and_administration_expenses__value > 0
          AND l.general_and_administration_expenses__value_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.general_and_administration_expenses__value / l.general_and_administration_expenses__value_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS value,
      STRUCT(
        l.general_and_administration_expenses__rent_rates_taxes AS value,
        l.general_and_administration_expenses__rent_rates_taxes_prev_yr AS prev_yr,
        (l.general_and_administration_expenses__rent_rates_taxes - l.general_and_administration_expenses__rent_rates_taxes_prev_yr) / ABS(NULLIF(l.general_and_administration_expenses__rent_rates_taxes_prev_yr, 0)) * 100 AS yoy_pct,
        l.general_and_administration_expenses__rent_rates_taxes_3y_back AS value_3y_back,
        IF(
        l.general_and_administration_expenses__rent_rates_taxes > 0
          AND l.general_and_administration_expenses__rent_rates_taxes_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.general_and_administration_expenses__rent_rates_taxes / l.general_and_administration_expenses__rent_rates_taxes_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.general_and_administration_expenses__rent_rates_taxes_5y_back AS value_5y_back,
        IF(
        l.general_and_administration_expenses__rent_rates_taxes > 0
          AND l.general_and_administration_expenses__rent_rates_taxes_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.general_and_administration_expenses__rent_rates_taxes / l.general_and_administration_expenses__rent_rates_taxes_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS rent_rates_taxes,
      STRUCT(
        l.general_and_administration_expenses__insurance AS value,
        l.general_and_administration_expenses__insurance_prev_yr AS prev_yr,
        (l.general_and_administration_expenses__insurance - l.general_and_administration_expenses__insurance_prev_yr) / ABS(NULLIF(l.general_and_administration_expenses__insurance_prev_yr, 0)) * 100 AS yoy_pct,
        l.general_and_administration_expenses__insurance_3y_back AS value_3y_back,
        IF(
        l.general_and_administration_expenses__insurance > 0
          AND l.general_and_administration_expenses__insurance_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.general_and_administration_expenses__insurance / l.general_and_administration_expenses__insurance_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.general_and_administration_expenses__insurance_5y_back AS value_5y_back,
        IF(
        l.general_and_administration_expenses__insurance > 0
          AND l.general_and_administration_expenses__insurance_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.general_and_administration_expenses__insurance / l.general_and_administration_expenses__insurance_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS insurance,
      STRUCT(
        l.general_and_administration_expenses__repairs_maintenance_others AS value,
        l.general_and_administration_expenses__repairs_maintenance_others_prev_yr AS prev_yr,
        (l.general_and_administration_expenses__repairs_maintenance_others - l.general_and_administration_expenses__repairs_maintenance_others_prev_yr) / ABS(NULLIF(l.general_and_administration_expenses__repairs_maintenance_others_prev_yr, 0)) * 100 AS yoy_pct,
        l.general_and_administration_expenses__repairs_maintenance_others_3y_back AS value_3y_back,
        IF(
        l.general_and_administration_expenses__repairs_maintenance_others > 0
          AND l.general_and_administration_expenses__repairs_maintenance_others_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.general_and_administration_expenses__repairs_maintenance_others / l.general_and_administration_expenses__repairs_maintenance_others_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.general_and_administration_expenses__repairs_maintenance_others_5y_back AS value_5y_back,
        IF(
        l.general_and_administration_expenses__repairs_maintenance_others > 0
          AND l.general_and_administration_expenses__repairs_maintenance_others_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.general_and_administration_expenses__repairs_maintenance_others / l.general_and_administration_expenses__repairs_maintenance_others_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS repairs_maintenance_others,
      STRUCT(
        l.general_and_administration_expenses__printing_and_stationery AS value,
        l.general_and_administration_expenses__printing_and_stationery_prev_yr AS prev_yr,
        (l.general_and_administration_expenses__printing_and_stationery - l.general_and_administration_expenses__printing_and_stationery_prev_yr) / ABS(NULLIF(l.general_and_administration_expenses__printing_and_stationery_prev_yr, 0)) * 100 AS yoy_pct,
        l.general_and_administration_expenses__printing_and_stationery_3y_back AS value_3y_back,
        IF(
        l.general_and_administration_expenses__printing_and_stationery > 0
          AND l.general_and_administration_expenses__printing_and_stationery_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.general_and_administration_expenses__printing_and_stationery / l.general_and_administration_expenses__printing_and_stationery_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.general_and_administration_expenses__printing_and_stationery_5y_back AS value_5y_back,
        IF(
        l.general_and_administration_expenses__printing_and_stationery > 0
          AND l.general_and_administration_expenses__printing_and_stationery_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.general_and_administration_expenses__printing_and_stationery / l.general_and_administration_expenses__printing_and_stationery_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS printing_and_stationery,
      STRUCT(
        l.general_and_administration_expenses__professional_and_legal_fees AS value,
        l.general_and_administration_expenses__professional_and_legal_fees_prev_yr AS prev_yr,
        (l.general_and_administration_expenses__professional_and_legal_fees - l.general_and_administration_expenses__professional_and_legal_fees_prev_yr) / ABS(NULLIF(l.general_and_administration_expenses__professional_and_legal_fees_prev_yr, 0)) * 100 AS yoy_pct,
        l.general_and_administration_expenses__professional_and_legal_fees_3y_back AS value_3y_back,
        IF(
        l.general_and_administration_expenses__professional_and_legal_fees > 0
          AND l.general_and_administration_expenses__professional_and_legal_fees_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.general_and_administration_expenses__professional_and_legal_fees / l.general_and_administration_expenses__professional_and_legal_fees_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.general_and_administration_expenses__professional_and_legal_fees_5y_back AS value_5y_back,
        IF(
        l.general_and_administration_expenses__professional_and_legal_fees > 0
          AND l.general_and_administration_expenses__professional_and_legal_fees_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.general_and_administration_expenses__professional_and_legal_fees / l.general_and_administration_expenses__professional_and_legal_fees_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS professional_and_legal_fees,
      STRUCT(
        l.general_and_administration_expenses__traveling_and_conveyance AS value,
        l.general_and_administration_expenses__traveling_and_conveyance_prev_yr AS prev_yr,
        (l.general_and_administration_expenses__traveling_and_conveyance - l.general_and_administration_expenses__traveling_and_conveyance_prev_yr) / ABS(NULLIF(l.general_and_administration_expenses__traveling_and_conveyance_prev_yr, 0)) * 100 AS yoy_pct,
        l.general_and_administration_expenses__traveling_and_conveyance_3y_back AS value_3y_back,
        IF(
        l.general_and_administration_expenses__traveling_and_conveyance > 0
          AND l.general_and_administration_expenses__traveling_and_conveyance_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.general_and_administration_expenses__traveling_and_conveyance / l.general_and_administration_expenses__traveling_and_conveyance_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.general_and_administration_expenses__traveling_and_conveyance_5y_back AS value_5y_back,
        IF(
        l.general_and_administration_expenses__traveling_and_conveyance > 0
          AND l.general_and_administration_expenses__traveling_and_conveyance_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.general_and_administration_expenses__traveling_and_conveyance / l.general_and_administration_expenses__traveling_and_conveyance_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS traveling_and_conveyance,
      STRUCT(
        l.general_and_administration_expenses__payment_to_auditors AS value,
        l.general_and_administration_expenses__payment_to_auditors_prev_yr AS prev_yr,
        (l.general_and_administration_expenses__payment_to_auditors - l.general_and_administration_expenses__payment_to_auditors_prev_yr) / ABS(NULLIF(l.general_and_administration_expenses__payment_to_auditors_prev_yr, 0)) * 100 AS yoy_pct,
        l.general_and_administration_expenses__payment_to_auditors_3y_back AS value_3y_back,
        IF(
        l.general_and_administration_expenses__payment_to_auditors > 0
          AND l.general_and_administration_expenses__payment_to_auditors_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.general_and_administration_expenses__payment_to_auditors / l.general_and_administration_expenses__payment_to_auditors_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.general_and_administration_expenses__payment_to_auditors_5y_back AS value_5y_back,
        IF(
        l.general_and_administration_expenses__payment_to_auditors > 0
          AND l.general_and_administration_expenses__payment_to_auditors_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.general_and_administration_expenses__payment_to_auditors / l.general_and_administration_expenses__payment_to_auditors_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS payment_to_auditors,
      STRUCT(
        l.general_and_administration_expenses__hire_charges_admin AS value,
        l.general_and_administration_expenses__hire_charges_admin_prev_yr AS prev_yr,
        (l.general_and_administration_expenses__hire_charges_admin - l.general_and_administration_expenses__hire_charges_admin_prev_yr) / ABS(NULLIF(l.general_and_administration_expenses__hire_charges_admin_prev_yr, 0)) * 100 AS yoy_pct,
        l.general_and_administration_expenses__hire_charges_admin_3y_back AS value_3y_back,
        IF(
        l.general_and_administration_expenses__hire_charges_admin > 0
          AND l.general_and_administration_expenses__hire_charges_admin_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.general_and_administration_expenses__hire_charges_admin / l.general_and_administration_expenses__hire_charges_admin_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.general_and_administration_expenses__hire_charges_admin_5y_back AS value_5y_back,
        IF(
        l.general_and_administration_expenses__hire_charges_admin > 0
          AND l.general_and_administration_expenses__hire_charges_admin_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.general_and_administration_expenses__hire_charges_admin / l.general_and_administration_expenses__hire_charges_admin_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS hire_charges_admin,
      STRUCT(
        l.general_and_administration_expenses__packing_expenses AS value,
        l.general_and_administration_expenses__packing_expenses_prev_yr AS prev_yr,
        (l.general_and_administration_expenses__packing_expenses - l.general_and_administration_expenses__packing_expenses_prev_yr) / ABS(NULLIF(l.general_and_administration_expenses__packing_expenses_prev_yr, 0)) * 100 AS yoy_pct,
        l.general_and_administration_expenses__packing_expenses_3y_back AS value_3y_back,
        IF(
        l.general_and_administration_expenses__packing_expenses > 0
          AND l.general_and_administration_expenses__packing_expenses_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.general_and_administration_expenses__packing_expenses / l.general_and_administration_expenses__packing_expenses_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.general_and_administration_expenses__packing_expenses_5y_back AS value_5y_back,
        IF(
        l.general_and_administration_expenses__packing_expenses > 0
          AND l.general_and_administration_expenses__packing_expenses_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.general_and_administration_expenses__packing_expenses / l.general_and_administration_expenses__packing_expenses_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS packing_expenses,
      STRUCT(
        l.general_and_administration_expenses__communication_expenses AS value,
        l.general_and_administration_expenses__communication_expenses_prev_yr AS prev_yr,
        (l.general_and_administration_expenses__communication_expenses - l.general_and_administration_expenses__communication_expenses_prev_yr) / ABS(NULLIF(l.general_and_administration_expenses__communication_expenses_prev_yr, 0)) * 100 AS yoy_pct,
        l.general_and_administration_expenses__communication_expenses_3y_back AS value_3y_back,
        IF(
        l.general_and_administration_expenses__communication_expenses > 0
          AND l.general_and_administration_expenses__communication_expenses_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.general_and_administration_expenses__communication_expenses / l.general_and_administration_expenses__communication_expenses_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.general_and_administration_expenses__communication_expenses_5y_back AS value_5y_back,
        IF(
        l.general_and_administration_expenses__communication_expenses > 0
          AND l.general_and_administration_expenses__communication_expenses_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.general_and_administration_expenses__communication_expenses / l.general_and_administration_expenses__communication_expenses_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS communication_expenses,
      STRUCT(
        l.general_and_administration_expenses__training_expenses AS value,
        l.general_and_administration_expenses__training_expenses_prev_yr AS prev_yr,
        (l.general_and_administration_expenses__training_expenses - l.general_and_administration_expenses__training_expenses_prev_yr) / ABS(NULLIF(l.general_and_administration_expenses__training_expenses_prev_yr, 0)) * 100 AS yoy_pct,
        l.general_and_administration_expenses__training_expenses_3y_back AS value_3y_back,
        IF(
        l.general_and_administration_expenses__training_expenses > 0
          AND l.general_and_administration_expenses__training_expenses_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.general_and_administration_expenses__training_expenses / l.general_and_administration_expenses__training_expenses_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.general_and_administration_expenses__training_expenses_5y_back AS value_5y_back,
        IF(
        l.general_and_administration_expenses__training_expenses > 0
          AND l.general_and_administration_expenses__training_expenses_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.general_and_administration_expenses__training_expenses / l.general_and_administration_expenses__training_expenses_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS training_expenses,
      STRUCT(
        l.general_and_administration_expenses__wealth_tax AS value,
        l.general_and_administration_expenses__wealth_tax_prev_yr AS prev_yr,
        (l.general_and_administration_expenses__wealth_tax - l.general_and_administration_expenses__wealth_tax_prev_yr) / ABS(NULLIF(l.general_and_administration_expenses__wealth_tax_prev_yr, 0)) * 100 AS yoy_pct,
        l.general_and_administration_expenses__wealth_tax_3y_back AS value_3y_back,
        IF(
        l.general_and_administration_expenses__wealth_tax > 0
          AND l.general_and_administration_expenses__wealth_tax_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.general_and_administration_expenses__wealth_tax / l.general_and_administration_expenses__wealth_tax_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.general_and_administration_expenses__wealth_tax_5y_back AS value_5y_back,
        IF(
        l.general_and_administration_expenses__wealth_tax > 0
          AND l.general_and_administration_expenses__wealth_tax_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.general_and_administration_expenses__wealth_tax / l.general_and_administration_expenses__wealth_tax_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS wealth_tax,
      STRUCT(
        l.general_and_administration_expenses__director_s_remuneration AS value,
        l.general_and_administration_expenses__director_s_remuneration_prev_yr AS prev_yr,
        (l.general_and_administration_expenses__director_s_remuneration - l.general_and_administration_expenses__director_s_remuneration_prev_yr) / ABS(NULLIF(l.general_and_administration_expenses__director_s_remuneration_prev_yr, 0)) * 100 AS yoy_pct,
        l.general_and_administration_expenses__director_s_remuneration_3y_back AS value_3y_back,
        IF(
        l.general_and_administration_expenses__director_s_remuneration > 0
          AND l.general_and_administration_expenses__director_s_remuneration_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.general_and_administration_expenses__director_s_remuneration / l.general_and_administration_expenses__director_s_remuneration_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.general_and_administration_expenses__director_s_remuneration_5y_back AS value_5y_back,
        IF(
        l.general_and_administration_expenses__director_s_remuneration > 0
          AND l.general_and_administration_expenses__director_s_remuneration_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.general_and_administration_expenses__director_s_remuneration / l.general_and_administration_expenses__director_s_remuneration_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS director_s_remuneration,
      STRUCT(
        l.general_and_administration_expenses__other_administration AS value,
        l.general_and_administration_expenses__other_administration_prev_yr AS prev_yr,
        (l.general_and_administration_expenses__other_administration - l.general_and_administration_expenses__other_administration_prev_yr) / ABS(NULLIF(l.general_and_administration_expenses__other_administration_prev_yr, 0)) * 100 AS yoy_pct,
        l.general_and_administration_expenses__other_administration_3y_back AS value_3y_back,
        IF(
        l.general_and_administration_expenses__other_administration > 0
          AND l.general_and_administration_expenses__other_administration_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.general_and_administration_expenses__other_administration / l.general_and_administration_expenses__other_administration_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.general_and_administration_expenses__other_administration_5y_back AS value_5y_back,
        IF(
        l.general_and_administration_expenses__other_administration > 0
          AND l.general_and_administration_expenses__other_administration_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.general_and_administration_expenses__other_administration / l.general_and_administration_expenses__other_administration_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS other_administration,
      STRUCT(
        l.general_and_administration_expenses__administration_expenses_capitalised AS value,
        l.general_and_administration_expenses__administration_expenses_capitalised_prev_yr AS prev_yr,
        (l.general_and_administration_expenses__administration_expenses_capitalised - l.general_and_administration_expenses__administration_expenses_capitalised_prev_yr) / ABS(NULLIF(l.general_and_administration_expenses__administration_expenses_capitalised_prev_yr, 0)) * 100 AS yoy_pct,
        l.general_and_administration_expenses__administration_expenses_capitalised_3y_back AS value_3y_back,
        IF(
        l.general_and_administration_expenses__administration_expenses_capitalised > 0
          AND l.general_and_administration_expenses__administration_expenses_capitalised_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.general_and_administration_expenses__administration_expenses_capitalised / l.general_and_administration_expenses__administration_expenses_capitalised_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.general_and_administration_expenses__administration_expenses_capitalised_5y_back AS value_5y_back,
        IF(
        l.general_and_administration_expenses__administration_expenses_capitalised > 0
          AND l.general_and_administration_expenses__administration_expenses_capitalised_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.general_and_administration_expenses__administration_expenses_capitalised / l.general_and_administration_expenses__administration_expenses_capitalised_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS administration_expenses_capitalised
    ) AS general_and_administration_expenses,
    STRUCT(
      l.rent AS value,
      l.rent_prev_yr AS prev_yr,
      (l.rent - l.rent_prev_yr) / ABS(NULLIF(l.rent_prev_yr, 0)) * 100 AS yoy_pct,
      l.rent_3y_back AS value_3y_back,
      IF(
      l.rent > 0
        AND l.rent_3y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.rent / l.rent_3y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_3y_pct,
      l.rent_5y_back AS value_5y_back,
      IF(
      l.rent > 0
        AND l.rent_5y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.rent / l.rent_5y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_5y_pct
    ) AS rent,
    STRUCT(
      l.rates_taxes AS value,
      l.rates_taxes_prev_yr AS prev_yr,
      (l.rates_taxes - l.rates_taxes_prev_yr) / ABS(NULLIF(l.rates_taxes_prev_yr, 0)) * 100 AS yoy_pct,
      l.rates_taxes_3y_back AS value_3y_back,
      IF(
      l.rates_taxes > 0
        AND l.rates_taxes_3y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.rates_taxes / l.rates_taxes_3y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_3y_pct,
      l.rates_taxes_5y_back AS value_5y_back,
      IF(
      l.rates_taxes > 0
        AND l.rates_taxes_5y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.rates_taxes / l.rates_taxes_5y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_5y_pct
    ) AS rates_taxes,
    STRUCT(
      l.other_rent AS value,
      l.other_rent_prev_yr AS prev_yr,
      (l.other_rent - l.other_rent_prev_yr) / ABS(NULLIF(l.other_rent_prev_yr, 0)) * 100 AS yoy_pct,
      l.other_rent_3y_back AS value_3y_back,
      IF(
      l.other_rent > 0
        AND l.other_rent_3y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.other_rent / l.other_rent_3y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_3y_pct,
      l.other_rent_5y_back AS value_5y_back,
      IF(
      l.other_rent > 0
        AND l.other_rent_5y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.other_rent / l.other_rent_5y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_5y_pct
    ) AS other_rent,
    STRUCT(
      STRUCT(
        l.selling_and_distribution_expenses__value AS value,
        l.selling_and_distribution_expenses__value_prev_yr AS prev_yr,
        (l.selling_and_distribution_expenses__value - l.selling_and_distribution_expenses__value_prev_yr) / ABS(NULLIF(l.selling_and_distribution_expenses__value_prev_yr, 0)) * 100 AS yoy_pct,
        l.selling_and_distribution_expenses__value_3y_back AS value_3y_back,
        IF(
        l.selling_and_distribution_expenses__value > 0
          AND l.selling_and_distribution_expenses__value_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.selling_and_distribution_expenses__value / l.selling_and_distribution_expenses__value_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.selling_and_distribution_expenses__value_5y_back AS value_5y_back,
        IF(
        l.selling_and_distribution_expenses__value > 0
          AND l.selling_and_distribution_expenses__value_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.selling_and_distribution_expenses__value / l.selling_and_distribution_expenses__value_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS value,
      STRUCT(
        l.selling_and_distribution_expenses__distribution_expenses AS value,
        l.selling_and_distribution_expenses__distribution_expenses_prev_yr AS prev_yr,
        (l.selling_and_distribution_expenses__distribution_expenses - l.selling_and_distribution_expenses__distribution_expenses_prev_yr) / ABS(NULLIF(l.selling_and_distribution_expenses__distribution_expenses_prev_yr, 0)) * 100 AS yoy_pct,
        l.selling_and_distribution_expenses__distribution_expenses_3y_back AS value_3y_back,
        IF(
        l.selling_and_distribution_expenses__distribution_expenses > 0
          AND l.selling_and_distribution_expenses__distribution_expenses_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.selling_and_distribution_expenses__distribution_expenses / l.selling_and_distribution_expenses__distribution_expenses_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.selling_and_distribution_expenses__distribution_expenses_5y_back AS value_5y_back,
        IF(
        l.selling_and_distribution_expenses__distribution_expenses > 0
          AND l.selling_and_distribution_expenses__distribution_expenses_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.selling_and_distribution_expenses__distribution_expenses / l.selling_and_distribution_expenses__distribution_expenses_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS distribution_expenses,
      STRUCT(
        l.selling_and_distribution_expenses__advertisement_sales_promotion AS value,
        l.selling_and_distribution_expenses__advertisement_sales_promotion_prev_yr AS prev_yr,
        (l.selling_and_distribution_expenses__advertisement_sales_promotion - l.selling_and_distribution_expenses__advertisement_sales_promotion_prev_yr) / ABS(NULLIF(l.selling_and_distribution_expenses__advertisement_sales_promotion_prev_yr, 0)) * 100 AS yoy_pct,
        l.selling_and_distribution_expenses__advertisement_sales_promotion_3y_back AS value_3y_back,
        IF(
        l.selling_and_distribution_expenses__advertisement_sales_promotion > 0
          AND l.selling_and_distribution_expenses__advertisement_sales_promotion_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.selling_and_distribution_expenses__advertisement_sales_promotion / l.selling_and_distribution_expenses__advertisement_sales_promotion_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.selling_and_distribution_expenses__advertisement_sales_promotion_5y_back AS value_5y_back,
        IF(
        l.selling_and_distribution_expenses__advertisement_sales_promotion > 0
          AND l.selling_and_distribution_expenses__advertisement_sales_promotion_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.selling_and_distribution_expenses__advertisement_sales_promotion / l.selling_and_distribution_expenses__advertisement_sales_promotion_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS advertisement_sales_promotion,
      STRUCT(
        l.selling_and_distribution_expenses__sales_commissions_and_incentives AS value,
        l.selling_and_distribution_expenses__sales_commissions_and_incentives_prev_yr AS prev_yr,
        (l.selling_and_distribution_expenses__sales_commissions_and_incentives - l.selling_and_distribution_expenses__sales_commissions_and_incentives_prev_yr) / ABS(NULLIF(l.selling_and_distribution_expenses__sales_commissions_and_incentives_prev_yr, 0)) * 100 AS yoy_pct,
        l.selling_and_distribution_expenses__sales_commissions_and_incentives_3y_back AS value_3y_back,
        IF(
        l.selling_and_distribution_expenses__sales_commissions_and_incentives > 0
          AND l.selling_and_distribution_expenses__sales_commissions_and_incentives_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.selling_and_distribution_expenses__sales_commissions_and_incentives / l.selling_and_distribution_expenses__sales_commissions_and_incentives_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.selling_and_distribution_expenses__sales_commissions_and_incentives_5y_back AS value_5y_back,
        IF(
        l.selling_and_distribution_expenses__sales_commissions_and_incentives > 0
          AND l.selling_and_distribution_expenses__sales_commissions_and_incentives_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.selling_and_distribution_expenses__sales_commissions_and_incentives / l.selling_and_distribution_expenses__sales_commissions_and_incentives_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS sales_commissions_and_incentives,
      STRUCT(
        l.selling_and_distribution_expenses__brokerages AS value,
        l.selling_and_distribution_expenses__brokerages_prev_yr AS prev_yr,
        (l.selling_and_distribution_expenses__brokerages - l.selling_and_distribution_expenses__brokerages_prev_yr) / ABS(NULLIF(l.selling_and_distribution_expenses__brokerages_prev_yr, 0)) * 100 AS yoy_pct,
        l.selling_and_distribution_expenses__brokerages_3y_back AS value_3y_back,
        IF(
        l.selling_and_distribution_expenses__brokerages > 0
          AND l.selling_and_distribution_expenses__brokerages_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.selling_and_distribution_expenses__brokerages / l.selling_and_distribution_expenses__brokerages_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.selling_and_distribution_expenses__brokerages_5y_back AS value_5y_back,
        IF(
        l.selling_and_distribution_expenses__brokerages > 0
          AND l.selling_and_distribution_expenses__brokerages_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.selling_and_distribution_expenses__brokerages / l.selling_and_distribution_expenses__brokerages_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS brokerages,
      STRUCT(
        l.selling_and_distribution_expenses__discounts_rebates_s_d AS value,
        l.selling_and_distribution_expenses__discounts_rebates_s_d_prev_yr AS prev_yr,
        (l.selling_and_distribution_expenses__discounts_rebates_s_d - l.selling_and_distribution_expenses__discounts_rebates_s_d_prev_yr) / ABS(NULLIF(l.selling_and_distribution_expenses__discounts_rebates_s_d_prev_yr, 0)) * 100 AS yoy_pct,
        l.selling_and_distribution_expenses__discounts_rebates_s_d_3y_back AS value_3y_back,
        IF(
        l.selling_and_distribution_expenses__discounts_rebates_s_d > 0
          AND l.selling_and_distribution_expenses__discounts_rebates_s_d_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.selling_and_distribution_expenses__discounts_rebates_s_d / l.selling_and_distribution_expenses__discounts_rebates_s_d_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.selling_and_distribution_expenses__discounts_rebates_s_d_5y_back AS value_5y_back,
        IF(
        l.selling_and_distribution_expenses__discounts_rebates_s_d > 0
          AND l.selling_and_distribution_expenses__discounts_rebates_s_d_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.selling_and_distribution_expenses__discounts_rebates_s_d / l.selling_and_distribution_expenses__discounts_rebates_s_d_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS discounts_rebates_s_d,
      STRUCT(
        l.selling_and_distribution_expenses__freight_and_forwarding AS value,
        l.selling_and_distribution_expenses__freight_and_forwarding_prev_yr AS prev_yr,
        (l.selling_and_distribution_expenses__freight_and_forwarding - l.selling_and_distribution_expenses__freight_and_forwarding_prev_yr) / ABS(NULLIF(l.selling_and_distribution_expenses__freight_and_forwarding_prev_yr, 0)) * 100 AS yoy_pct,
        l.selling_and_distribution_expenses__freight_and_forwarding_3y_back AS value_3y_back,
        IF(
        l.selling_and_distribution_expenses__freight_and_forwarding > 0
          AND l.selling_and_distribution_expenses__freight_and_forwarding_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.selling_and_distribution_expenses__freight_and_forwarding / l.selling_and_distribution_expenses__freight_and_forwarding_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.selling_and_distribution_expenses__freight_and_forwarding_5y_back AS value_5y_back,
        IF(
        l.selling_and_distribution_expenses__freight_and_forwarding > 0
          AND l.selling_and_distribution_expenses__freight_and_forwarding_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.selling_and_distribution_expenses__freight_and_forwarding / l.selling_and_distribution_expenses__freight_and_forwarding_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS freight_and_forwarding,
      STRUCT(
        l.selling_and_distribution_expenses__handling_and_clearing_charges AS value,
        l.selling_and_distribution_expenses__handling_and_clearing_charges_prev_yr AS prev_yr,
        (l.selling_and_distribution_expenses__handling_and_clearing_charges - l.selling_and_distribution_expenses__handling_and_clearing_charges_prev_yr) / ABS(NULLIF(l.selling_and_distribution_expenses__handling_and_clearing_charges_prev_yr, 0)) * 100 AS yoy_pct,
        l.selling_and_distribution_expenses__handling_and_clearing_charges_3y_back AS value_3y_back,
        IF(
        l.selling_and_distribution_expenses__handling_and_clearing_charges > 0
          AND l.selling_and_distribution_expenses__handling_and_clearing_charges_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.selling_and_distribution_expenses__handling_and_clearing_charges / l.selling_and_distribution_expenses__handling_and_clearing_charges_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.selling_and_distribution_expenses__handling_and_clearing_charges_5y_back AS value_5y_back,
        IF(
        l.selling_and_distribution_expenses__handling_and_clearing_charges > 0
          AND l.selling_and_distribution_expenses__handling_and_clearing_charges_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.selling_and_distribution_expenses__handling_and_clearing_charges / l.selling_and_distribution_expenses__handling_and_clearing_charges_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS handling_and_clearing_charges,
      STRUCT(
        l.selling_and_distribution_expenses__sales_tax AS value,
        l.selling_and_distribution_expenses__sales_tax_prev_yr AS prev_yr,
        (l.selling_and_distribution_expenses__sales_tax - l.selling_and_distribution_expenses__sales_tax_prev_yr) / ABS(NULLIF(l.selling_and_distribution_expenses__sales_tax_prev_yr, 0)) * 100 AS yoy_pct,
        l.selling_and_distribution_expenses__sales_tax_3y_back AS value_3y_back,
        IF(
        l.selling_and_distribution_expenses__sales_tax > 0
          AND l.selling_and_distribution_expenses__sales_tax_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.selling_and_distribution_expenses__sales_tax / l.selling_and_distribution_expenses__sales_tax_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.selling_and_distribution_expenses__sales_tax_5y_back AS value_5y_back,
        IF(
        l.selling_and_distribution_expenses__sales_tax > 0
          AND l.selling_and_distribution_expenses__sales_tax_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.selling_and_distribution_expenses__sales_tax / l.selling_and_distribution_expenses__sales_tax_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS sales_tax,
      STRUCT(
        l.selling_and_distribution_expenses__other_selling_expenses AS value,
        l.selling_and_distribution_expenses__other_selling_expenses_prev_yr AS prev_yr,
        (l.selling_and_distribution_expenses__other_selling_expenses - l.selling_and_distribution_expenses__other_selling_expenses_prev_yr) / ABS(NULLIF(l.selling_and_distribution_expenses__other_selling_expenses_prev_yr, 0)) * 100 AS yoy_pct,
        l.selling_and_distribution_expenses__other_selling_expenses_3y_back AS value_3y_back,
        IF(
        l.selling_and_distribution_expenses__other_selling_expenses > 0
          AND l.selling_and_distribution_expenses__other_selling_expenses_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.selling_and_distribution_expenses__other_selling_expenses / l.selling_and_distribution_expenses__other_selling_expenses_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.selling_and_distribution_expenses__other_selling_expenses_5y_back AS value_5y_back,
        IF(
        l.selling_and_distribution_expenses__other_selling_expenses > 0
          AND l.selling_and_distribution_expenses__other_selling_expenses_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.selling_and_distribution_expenses__other_selling_expenses / l.selling_and_distribution_expenses__other_selling_expenses_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS other_selling_expenses,
      STRUCT(
        l.selling_and_distribution_expenses__selling_expenses_capitalised AS value,
        l.selling_and_distribution_expenses__selling_expenses_capitalised_prev_yr AS prev_yr,
        (l.selling_and_distribution_expenses__selling_expenses_capitalised - l.selling_and_distribution_expenses__selling_expenses_capitalised_prev_yr) / ABS(NULLIF(l.selling_and_distribution_expenses__selling_expenses_capitalised_prev_yr, 0)) * 100 AS yoy_pct,
        l.selling_and_distribution_expenses__selling_expenses_capitalised_3y_back AS value_3y_back,
        IF(
        l.selling_and_distribution_expenses__selling_expenses_capitalised > 0
          AND l.selling_and_distribution_expenses__selling_expenses_capitalised_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.selling_and_distribution_expenses__selling_expenses_capitalised / l.selling_and_distribution_expenses__selling_expenses_capitalised_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.selling_and_distribution_expenses__selling_expenses_capitalised_5y_back AS value_5y_back,
        IF(
        l.selling_and_distribution_expenses__selling_expenses_capitalised > 0
          AND l.selling_and_distribution_expenses__selling_expenses_capitalised_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.selling_and_distribution_expenses__selling_expenses_capitalised / l.selling_and_distribution_expenses__selling_expenses_capitalised_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS selling_expenses_capitalised
    ) AS selling_and_distribution_expenses,
    STRUCT(
      STRUCT(
        l.miscellaneous_expenses__value AS value,
        l.miscellaneous_expenses__value_prev_yr AS prev_yr,
        (l.miscellaneous_expenses__value - l.miscellaneous_expenses__value_prev_yr) / ABS(NULLIF(l.miscellaneous_expenses__value_prev_yr, 0)) * 100 AS yoy_pct,
        l.miscellaneous_expenses__value_3y_back AS value_3y_back,
        IF(
        l.miscellaneous_expenses__value > 0
          AND l.miscellaneous_expenses__value_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.miscellaneous_expenses__value / l.miscellaneous_expenses__value_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.miscellaneous_expenses__value_5y_back AS value_5y_back,
        IF(
        l.miscellaneous_expenses__value > 0
          AND l.miscellaneous_expenses__value_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.miscellaneous_expenses__value / l.miscellaneous_expenses__value_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS value,
      STRUCT(
        l.miscellaneous_expenses__deferred_revenue_expenditure_written_off AS value,
        l.miscellaneous_expenses__deferred_revenue_expenditure_written_off_prev_yr AS prev_yr,
        (l.miscellaneous_expenses__deferred_revenue_expenditure_written_off - l.miscellaneous_expenses__deferred_revenue_expenditure_written_off_prev_yr) / ABS(NULLIF(l.miscellaneous_expenses__deferred_revenue_expenditure_written_off_prev_yr, 0)) * 100 AS yoy_pct,
        l.miscellaneous_expenses__deferred_revenue_expenditure_written_off_3y_back AS value_3y_back,
        IF(
        l.miscellaneous_expenses__deferred_revenue_expenditure_written_off > 0
          AND l.miscellaneous_expenses__deferred_revenue_expenditure_written_off_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.miscellaneous_expenses__deferred_revenue_expenditure_written_off / l.miscellaneous_expenses__deferred_revenue_expenditure_written_off_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.miscellaneous_expenses__deferred_revenue_expenditure_written_off_5y_back AS value_5y_back,
        IF(
        l.miscellaneous_expenses__deferred_revenue_expenditure_written_off > 0
          AND l.miscellaneous_expenses__deferred_revenue_expenditure_written_off_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.miscellaneous_expenses__deferred_revenue_expenditure_written_off / l.miscellaneous_expenses__deferred_revenue_expenditure_written_off_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS deferred_revenue_expenditure_written_off,
      STRUCT(
        l.miscellaneous_expenses__bad_debts_advances_written_off AS value,
        l.miscellaneous_expenses__bad_debts_advances_written_off_prev_yr AS prev_yr,
        (l.miscellaneous_expenses__bad_debts_advances_written_off - l.miscellaneous_expenses__bad_debts_advances_written_off_prev_yr) / ABS(NULLIF(l.miscellaneous_expenses__bad_debts_advances_written_off_prev_yr, 0)) * 100 AS yoy_pct,
        l.miscellaneous_expenses__bad_debts_advances_written_off_3y_back AS value_3y_back,
        IF(
        l.miscellaneous_expenses__bad_debts_advances_written_off > 0
          AND l.miscellaneous_expenses__bad_debts_advances_written_off_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.miscellaneous_expenses__bad_debts_advances_written_off / l.miscellaneous_expenses__bad_debts_advances_written_off_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.miscellaneous_expenses__bad_debts_advances_written_off_5y_back AS value_5y_back,
        IF(
        l.miscellaneous_expenses__bad_debts_advances_written_off > 0
          AND l.miscellaneous_expenses__bad_debts_advances_written_off_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.miscellaneous_expenses__bad_debts_advances_written_off / l.miscellaneous_expenses__bad_debts_advances_written_off_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS bad_debts_advances_written_off,
      STRUCT(
        l.miscellaneous_expenses__provision_for_doubtful_debts AS value,
        l.miscellaneous_expenses__provision_for_doubtful_debts_prev_yr AS prev_yr,
        (l.miscellaneous_expenses__provision_for_doubtful_debts - l.miscellaneous_expenses__provision_for_doubtful_debts_prev_yr) / ABS(NULLIF(l.miscellaneous_expenses__provision_for_doubtful_debts_prev_yr, 0)) * 100 AS yoy_pct,
        l.miscellaneous_expenses__provision_for_doubtful_debts_3y_back AS value_3y_back,
        IF(
        l.miscellaneous_expenses__provision_for_doubtful_debts > 0
          AND l.miscellaneous_expenses__provision_for_doubtful_debts_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.miscellaneous_expenses__provision_for_doubtful_debts / l.miscellaneous_expenses__provision_for_doubtful_debts_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.miscellaneous_expenses__provision_for_doubtful_debts_5y_back AS value_5y_back,
        IF(
        l.miscellaneous_expenses__provision_for_doubtful_debts > 0
          AND l.miscellaneous_expenses__provision_for_doubtful_debts_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.miscellaneous_expenses__provision_for_doubtful_debts / l.miscellaneous_expenses__provision_for_doubtful_debts_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS provision_for_doubtful_debts,
      STRUCT(
        l.miscellaneous_expenses__loss_on_disposal_of_fixed_assets_net AS value,
        l.miscellaneous_expenses__loss_on_disposal_of_fixed_assets_net_prev_yr AS prev_yr,
        (l.miscellaneous_expenses__loss_on_disposal_of_fixed_assets_net - l.miscellaneous_expenses__loss_on_disposal_of_fixed_assets_net_prev_yr) / ABS(NULLIF(l.miscellaneous_expenses__loss_on_disposal_of_fixed_assets_net_prev_yr, 0)) * 100 AS yoy_pct,
        l.miscellaneous_expenses__loss_on_disposal_of_fixed_assets_net_3y_back AS value_3y_back,
        IF(
        l.miscellaneous_expenses__loss_on_disposal_of_fixed_assets_net > 0
          AND l.miscellaneous_expenses__loss_on_disposal_of_fixed_assets_net_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.miscellaneous_expenses__loss_on_disposal_of_fixed_assets_net / l.miscellaneous_expenses__loss_on_disposal_of_fixed_assets_net_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.miscellaneous_expenses__loss_on_disposal_of_fixed_assets_net_5y_back AS value_5y_back,
        IF(
        l.miscellaneous_expenses__loss_on_disposal_of_fixed_assets_net > 0
          AND l.miscellaneous_expenses__loss_on_disposal_of_fixed_assets_net_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.miscellaneous_expenses__loss_on_disposal_of_fixed_assets_net / l.miscellaneous_expenses__loss_on_disposal_of_fixed_assets_net_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS loss_on_disposal_of_fixed_assets_net,
      STRUCT(
        l.miscellaneous_expenses__loss_on_foreign_exchange_fluctuations AS value,
        l.miscellaneous_expenses__loss_on_foreign_exchange_fluctuations_prev_yr AS prev_yr,
        (l.miscellaneous_expenses__loss_on_foreign_exchange_fluctuations - l.miscellaneous_expenses__loss_on_foreign_exchange_fluctuations_prev_yr) / ABS(NULLIF(l.miscellaneous_expenses__loss_on_foreign_exchange_fluctuations_prev_yr, 0)) * 100 AS yoy_pct,
        l.miscellaneous_expenses__loss_on_foreign_exchange_fluctuations_3y_back AS value_3y_back,
        IF(
        l.miscellaneous_expenses__loss_on_foreign_exchange_fluctuations > 0
          AND l.miscellaneous_expenses__loss_on_foreign_exchange_fluctuations_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.miscellaneous_expenses__loss_on_foreign_exchange_fluctuations / l.miscellaneous_expenses__loss_on_foreign_exchange_fluctuations_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.miscellaneous_expenses__loss_on_foreign_exchange_fluctuations_5y_back AS value_5y_back,
        IF(
        l.miscellaneous_expenses__loss_on_foreign_exchange_fluctuations > 0
          AND l.miscellaneous_expenses__loss_on_foreign_exchange_fluctuations_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.miscellaneous_expenses__loss_on_foreign_exchange_fluctuations / l.miscellaneous_expenses__loss_on_foreign_exchange_fluctuations_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS loss_on_foreign_exchange_fluctuations,
      STRUCT(
        l.miscellaneous_expenses__loss_on_sale_of_non_trade_current_investments AS value,
        l.miscellaneous_expenses__loss_on_sale_of_non_trade_current_investments_prev_yr AS prev_yr,
        (l.miscellaneous_expenses__loss_on_sale_of_non_trade_current_investments - l.miscellaneous_expenses__loss_on_sale_of_non_trade_current_investments_prev_yr) / ABS(NULLIF(l.miscellaneous_expenses__loss_on_sale_of_non_trade_current_investments_prev_yr, 0)) * 100 AS yoy_pct,
        l.miscellaneous_expenses__loss_on_sale_of_non_trade_current_investments_3y_back AS value_3y_back,
        IF(
        l.miscellaneous_expenses__loss_on_sale_of_non_trade_current_investments > 0
          AND l.miscellaneous_expenses__loss_on_sale_of_non_trade_current_investments_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.miscellaneous_expenses__loss_on_sale_of_non_trade_current_investments / l.miscellaneous_expenses__loss_on_sale_of_non_trade_current_investments_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.miscellaneous_expenses__loss_on_sale_of_non_trade_current_investments_5y_back AS value_5y_back,
        IF(
        l.miscellaneous_expenses__loss_on_sale_of_non_trade_current_investments > 0
          AND l.miscellaneous_expenses__loss_on_sale_of_non_trade_current_investments_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.miscellaneous_expenses__loss_on_sale_of_non_trade_current_investments / l.miscellaneous_expenses__loss_on_sale_of_non_trade_current_investments_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS loss_on_sale_of_non_trade_current_investments,
      STRUCT(
        l.miscellaneous_expenses__diminution_in_the_value_of_long_term_investments AS value,
        l.miscellaneous_expenses__diminution_in_the_value_of_long_term_investments_prev_yr AS prev_yr,
        (l.miscellaneous_expenses__diminution_in_the_value_of_long_term_investments - l.miscellaneous_expenses__diminution_in_the_value_of_long_term_investments_prev_yr) / ABS(NULLIF(l.miscellaneous_expenses__diminution_in_the_value_of_long_term_investments_prev_yr, 0)) * 100 AS yoy_pct,
        l.miscellaneous_expenses__diminution_in_the_value_of_long_term_investments_3y_back AS value_3y_back,
        IF(
        l.miscellaneous_expenses__diminution_in_the_value_of_long_term_investments > 0
          AND l.miscellaneous_expenses__diminution_in_the_value_of_long_term_investments_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.miscellaneous_expenses__diminution_in_the_value_of_long_term_investments / l.miscellaneous_expenses__diminution_in_the_value_of_long_term_investments_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.miscellaneous_expenses__diminution_in_the_value_of_long_term_investments_5y_back AS value_5y_back,
        IF(
        l.miscellaneous_expenses__diminution_in_the_value_of_long_term_investments > 0
          AND l.miscellaneous_expenses__diminution_in_the_value_of_long_term_investments_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.miscellaneous_expenses__diminution_in_the_value_of_long_term_investments / l.miscellaneous_expenses__diminution_in_the_value_of_long_term_investments_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS diminution_in_the_value_of_long_term_investments,
      STRUCT(
        l.miscellaneous_expenses__provisions_write_off AS value,
        l.miscellaneous_expenses__provisions_write_off_prev_yr AS prev_yr,
        (l.miscellaneous_expenses__provisions_write_off - l.miscellaneous_expenses__provisions_write_off_prev_yr) / ABS(NULLIF(l.miscellaneous_expenses__provisions_write_off_prev_yr, 0)) * 100 AS yoy_pct,
        l.miscellaneous_expenses__provisions_write_off_3y_back AS value_3y_back,
        IF(
        l.miscellaneous_expenses__provisions_write_off > 0
          AND l.miscellaneous_expenses__provisions_write_off_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.miscellaneous_expenses__provisions_write_off / l.miscellaneous_expenses__provisions_write_off_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.miscellaneous_expenses__provisions_write_off_5y_back AS value_5y_back,
        IF(
        l.miscellaneous_expenses__provisions_write_off > 0
          AND l.miscellaneous_expenses__provisions_write_off_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.miscellaneous_expenses__provisions_write_off / l.miscellaneous_expenses__provisions_write_off_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS provisions_write_off,
      STRUCT(
        l.miscellaneous_expenses__loss_on_future_and_options AS value,
        l.miscellaneous_expenses__loss_on_future_and_options_prev_yr AS prev_yr,
        (l.miscellaneous_expenses__loss_on_future_and_options - l.miscellaneous_expenses__loss_on_future_and_options_prev_yr) / ABS(NULLIF(l.miscellaneous_expenses__loss_on_future_and_options_prev_yr, 0)) * 100 AS yoy_pct,
        l.miscellaneous_expenses__loss_on_future_and_options_3y_back AS value_3y_back,
        IF(
        l.miscellaneous_expenses__loss_on_future_and_options > 0
          AND l.miscellaneous_expenses__loss_on_future_and_options_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.miscellaneous_expenses__loss_on_future_and_options / l.miscellaneous_expenses__loss_on_future_and_options_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.miscellaneous_expenses__loss_on_future_and_options_5y_back AS value_5y_back,
        IF(
        l.miscellaneous_expenses__loss_on_future_and_options > 0
          AND l.miscellaneous_expenses__loss_on_future_and_options_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.miscellaneous_expenses__loss_on_future_and_options / l.miscellaneous_expenses__loss_on_future_and_options_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS loss_on_future_and_options,
      STRUCT(
        l.miscellaneous_expenses__donations AS value,
        l.miscellaneous_expenses__donations_prev_yr AS prev_yr,
        (l.miscellaneous_expenses__donations - l.miscellaneous_expenses__donations_prev_yr) / ABS(NULLIF(l.miscellaneous_expenses__donations_prev_yr, 0)) * 100 AS yoy_pct,
        l.miscellaneous_expenses__donations_3y_back AS value_3y_back,
        IF(
        l.miscellaneous_expenses__donations > 0
          AND l.miscellaneous_expenses__donations_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.miscellaneous_expenses__donations / l.miscellaneous_expenses__donations_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.miscellaneous_expenses__donations_5y_back AS value_5y_back,
        IF(
        l.miscellaneous_expenses__donations > 0
          AND l.miscellaneous_expenses__donations_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.miscellaneous_expenses__donations / l.miscellaneous_expenses__donations_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS donations,
      STRUCT(
        l.miscellaneous_expenses__loss_on_buy_back_of_shares_debentures AS value,
        l.miscellaneous_expenses__loss_on_buy_back_of_shares_debentures_prev_yr AS prev_yr,
        (l.miscellaneous_expenses__loss_on_buy_back_of_shares_debentures - l.miscellaneous_expenses__loss_on_buy_back_of_shares_debentures_prev_yr) / ABS(NULLIF(l.miscellaneous_expenses__loss_on_buy_back_of_shares_debentures_prev_yr, 0)) * 100 AS yoy_pct,
        l.miscellaneous_expenses__loss_on_buy_back_of_shares_debentures_3y_back AS value_3y_back,
        IF(
        l.miscellaneous_expenses__loss_on_buy_back_of_shares_debentures > 0
          AND l.miscellaneous_expenses__loss_on_buy_back_of_shares_debentures_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.miscellaneous_expenses__loss_on_buy_back_of_shares_debentures / l.miscellaneous_expenses__loss_on_buy_back_of_shares_debentures_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.miscellaneous_expenses__loss_on_buy_back_of_shares_debentures_5y_back AS value_5y_back,
        IF(
        l.miscellaneous_expenses__loss_on_buy_back_of_shares_debentures > 0
          AND l.miscellaneous_expenses__loss_on_buy_back_of_shares_debentures_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.miscellaneous_expenses__loss_on_buy_back_of_shares_debentures / l.miscellaneous_expenses__loss_on_buy_back_of_shares_debentures_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS loss_on_buy_back_of_shares_debentures,
      STRUCT(
        l.miscellaneous_expenses__other_miscellaneous_expenses AS value,
        l.miscellaneous_expenses__other_miscellaneous_expenses_prev_yr AS prev_yr,
        (l.miscellaneous_expenses__other_miscellaneous_expenses - l.miscellaneous_expenses__other_miscellaneous_expenses_prev_yr) / ABS(NULLIF(l.miscellaneous_expenses__other_miscellaneous_expenses_prev_yr, 0)) * 100 AS yoy_pct,
        l.miscellaneous_expenses__other_miscellaneous_expenses_3y_back AS value_3y_back,
        IF(
        l.miscellaneous_expenses__other_miscellaneous_expenses > 0
          AND l.miscellaneous_expenses__other_miscellaneous_expenses_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.miscellaneous_expenses__other_miscellaneous_expenses / l.miscellaneous_expenses__other_miscellaneous_expenses_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.miscellaneous_expenses__other_miscellaneous_expenses_5y_back AS value_5y_back,
        IF(
        l.miscellaneous_expenses__other_miscellaneous_expenses > 0
          AND l.miscellaneous_expenses__other_miscellaneous_expenses_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.miscellaneous_expenses__other_miscellaneous_expenses / l.miscellaneous_expenses__other_miscellaneous_expenses_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS other_miscellaneous_expenses,
      STRUCT(
        l.miscellaneous_expenses__miscellaneous_expenses_capitalised AS value,
        l.miscellaneous_expenses__miscellaneous_expenses_capitalised_prev_yr AS prev_yr,
        (l.miscellaneous_expenses__miscellaneous_expenses_capitalised - l.miscellaneous_expenses__miscellaneous_expenses_capitalised_prev_yr) / ABS(NULLIF(l.miscellaneous_expenses__miscellaneous_expenses_capitalised_prev_yr, 0)) * 100 AS yoy_pct,
        l.miscellaneous_expenses__miscellaneous_expenses_capitalised_3y_back AS value_3y_back,
        IF(
        l.miscellaneous_expenses__miscellaneous_expenses_capitalised > 0
          AND l.miscellaneous_expenses__miscellaneous_expenses_capitalised_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.miscellaneous_expenses__miscellaneous_expenses_capitalised / l.miscellaneous_expenses__miscellaneous_expenses_capitalised_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.miscellaneous_expenses__miscellaneous_expenses_capitalised_5y_back AS value_5y_back,
        IF(
        l.miscellaneous_expenses__miscellaneous_expenses_capitalised > 0
          AND l.miscellaneous_expenses__miscellaneous_expenses_capitalised_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.miscellaneous_expenses__miscellaneous_expenses_capitalised / l.miscellaneous_expenses__miscellaneous_expenses_capitalised_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS miscellaneous_expenses_capitalised
    ) AS miscellaneous_expenses,
    STRUCT(
      l.less_expenses_capitalised AS value,
      l.less_expenses_capitalised_prev_yr AS prev_yr,
      (l.less_expenses_capitalised - l.less_expenses_capitalised_prev_yr) / ABS(NULLIF(l.less_expenses_capitalised_prev_yr, 0)) * 100 AS yoy_pct,
      l.less_expenses_capitalised_3y_back AS value_3y_back,
      IF(
      l.less_expenses_capitalised > 0
        AND l.less_expenses_capitalised_3y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.less_expenses_capitalised / l.less_expenses_capitalised_3y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_3y_pct,
      l.less_expenses_capitalised_5y_back AS value_5y_back,
      IF(
      l.less_expenses_capitalised > 0
        AND l.less_expenses_capitalised_5y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.less_expenses_capitalised / l.less_expenses_capitalised_5y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_5y_pct
    ) AS less_expenses_capitalised,
    STRUCT(
      l.total_expenditure AS value,
      l.total_expenditure_prev_yr AS prev_yr,
      (l.total_expenditure - l.total_expenditure_prev_yr) / ABS(NULLIF(l.total_expenditure_prev_yr, 0)) * 100 AS yoy_pct,
      l.total_expenditure_3y_back AS value_3y_back,
      IF(
      l.total_expenditure > 0
        AND l.total_expenditure_3y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.total_expenditure / l.total_expenditure_3y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_3y_pct,
      l.total_expenditure_5y_back AS value_5y_back,
      IF(
      l.total_expenditure > 0
        AND l.total_expenditure_5y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.total_expenditure / l.total_expenditure_5y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_5y_pct
    ) AS total_expenditure,
    STRUCT(
      l.operating_profit_excl_oi AS value,
      l.operating_profit_excl_oi_prev_yr AS prev_yr,
      (l.operating_profit_excl_oi - l.operating_profit_excl_oi_prev_yr) / ABS(NULLIF(l.operating_profit_excl_oi_prev_yr, 0)) * 100 AS yoy_pct,
      l.operating_profit_excl_oi_3y_back AS value_3y_back,
      IF(
      l.operating_profit_excl_oi > 0
        AND l.operating_profit_excl_oi_3y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.operating_profit_excl_oi / l.operating_profit_excl_oi_3y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_3y_pct,
      l.operating_profit_excl_oi_5y_back AS value_5y_back,
      IF(
      l.operating_profit_excl_oi > 0
        AND l.operating_profit_excl_oi_5y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.operating_profit_excl_oi / l.operating_profit_excl_oi_5y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_5y_pct
    ) AS operating_profit_excl_oi,
    STRUCT(
      STRUCT(
        l.other_income__value AS value,
        l.other_income__value_prev_yr AS prev_yr,
        (l.other_income__value - l.other_income__value_prev_yr) / ABS(NULLIF(l.other_income__value_prev_yr, 0)) * 100 AS yoy_pct,
        l.other_income__value_3y_back AS value_3y_back,
        IF(
        l.other_income__value > 0
          AND l.other_income__value_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_income__value / l.other_income__value_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.other_income__value_5y_back AS value_5y_back,
        IF(
        l.other_income__value > 0
          AND l.other_income__value_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_income__value / l.other_income__value_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS value,
      STRUCT(
        STRUCT(
          l.other_income__interest_received__value AS value,
          l.other_income__interest_received__value_prev_yr AS prev_yr,
          (l.other_income__interest_received__value - l.other_income__interest_received__value_prev_yr) / ABS(NULLIF(l.other_income__interest_received__value_prev_yr, 0)) * 100 AS yoy_pct,
          l.other_income__interest_received__value_3y_back AS value_3y_back,
          IF(
          l.other_income__interest_received__value > 0
            AND l.other_income__interest_received__value_3y_back > 0
            AND DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH)
              > 0,
          (
            POW(
              l.other_income__interest_received__value / l.other_income__interest_received__value_3y_back,
              12.0 / DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                MONTH))
            - 1)
            * 100,
          NULL) AS cagr_3y_pct,
          l.other_income__interest_received__value_5y_back AS value_5y_back,
          IF(
          l.other_income__interest_received__value > 0
            AND l.other_income__interest_received__value_5y_back > 0
            AND DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH)
              > 0,
          (
            POW(
              l.other_income__interest_received__value / l.other_income__interest_received__value_5y_back,
              12.0 / DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                MONTH))
            - 1)
            * 100,
          NULL) AS cagr_5y_pct
        ) AS value,
        STRUCT(
          l.other_income__interest_received__interest_on_deposits AS value,
          l.other_income__interest_received__interest_on_deposits_prev_yr AS prev_yr,
          (l.other_income__interest_received__interest_on_deposits - l.other_income__interest_received__interest_on_deposits_prev_yr) / ABS(NULLIF(l.other_income__interest_received__interest_on_deposits_prev_yr, 0)) * 100 AS yoy_pct,
          l.other_income__interest_received__interest_on_deposits_3y_back AS value_3y_back,
          IF(
          l.other_income__interest_received__interest_on_deposits > 0
            AND l.other_income__interest_received__interest_on_deposits_3y_back > 0
            AND DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH)
              > 0,
          (
            POW(
              l.other_income__interest_received__interest_on_deposits / l.other_income__interest_received__interest_on_deposits_3y_back,
              12.0 / DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                MONTH))
            - 1)
            * 100,
          NULL) AS cagr_3y_pct,
          l.other_income__interest_received__interest_on_deposits_5y_back AS value_5y_back,
          IF(
          l.other_income__interest_received__interest_on_deposits > 0
            AND l.other_income__interest_received__interest_on_deposits_5y_back > 0
            AND DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH)
              > 0,
          (
            POW(
              l.other_income__interest_received__interest_on_deposits / l.other_income__interest_received__interest_on_deposits_5y_back,
              12.0 / DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                MONTH))
            - 1)
            * 100,
          NULL) AS cagr_5y_pct
        ) AS interest_on_deposits,
        STRUCT(
          l.other_income__interest_received__interest_on_debentures_bonds AS value,
          l.other_income__interest_received__interest_on_debentures_bonds_prev_yr AS prev_yr,
          (l.other_income__interest_received__interest_on_debentures_bonds - l.other_income__interest_received__interest_on_debentures_bonds_prev_yr) / ABS(NULLIF(l.other_income__interest_received__interest_on_debentures_bonds_prev_yr, 0)) * 100 AS yoy_pct,
          l.other_income__interest_received__interest_on_debentures_bonds_3y_back AS value_3y_back,
          IF(
          l.other_income__interest_received__interest_on_debentures_bonds > 0
            AND l.other_income__interest_received__interest_on_debentures_bonds_3y_back > 0
            AND DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH)
              > 0,
          (
            POW(
              l.other_income__interest_received__interest_on_debentures_bonds / l.other_income__interest_received__interest_on_debentures_bonds_3y_back,
              12.0 / DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                MONTH))
            - 1)
            * 100,
          NULL) AS cagr_3y_pct,
          l.other_income__interest_received__interest_on_debentures_bonds_5y_back AS value_5y_back,
          IF(
          l.other_income__interest_received__interest_on_debentures_bonds > 0
            AND l.other_income__interest_received__interest_on_debentures_bonds_5y_back > 0
            AND DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH)
              > 0,
          (
            POW(
              l.other_income__interest_received__interest_on_debentures_bonds / l.other_income__interest_received__interest_on_debentures_bonds_5y_back,
              12.0 / DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                MONTH))
            - 1)
            * 100,
          NULL) AS cagr_5y_pct
        ) AS interest_on_debentures_bonds,
        STRUCT(
          l.other_income__interest_received__interest_on_others AS value,
          l.other_income__interest_received__interest_on_others_prev_yr AS prev_yr,
          (l.other_income__interest_received__interest_on_others - l.other_income__interest_received__interest_on_others_prev_yr) / ABS(NULLIF(l.other_income__interest_received__interest_on_others_prev_yr, 0)) * 100 AS yoy_pct,
          l.other_income__interest_received__interest_on_others_3y_back AS value_3y_back,
          IF(
          l.other_income__interest_received__interest_on_others > 0
            AND l.other_income__interest_received__interest_on_others_3y_back > 0
            AND DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH)
              > 0,
          (
            POW(
              l.other_income__interest_received__interest_on_others / l.other_income__interest_received__interest_on_others_3y_back,
              12.0 / DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                MONTH))
            - 1)
            * 100,
          NULL) AS cagr_3y_pct,
          l.other_income__interest_received__interest_on_others_5y_back AS value_5y_back,
          IF(
          l.other_income__interest_received__interest_on_others > 0
            AND l.other_income__interest_received__interest_on_others_5y_back > 0
            AND DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH)
              > 0,
          (
            POW(
              l.other_income__interest_received__interest_on_others / l.other_income__interest_received__interest_on_others_5y_back,
              12.0 / DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                MONTH))
            - 1)
            * 100,
          NULL) AS cagr_5y_pct
        ) AS interest_on_others
      ) AS interest_received,
      STRUCT(
        l.other_income__dividend_received AS value,
        l.other_income__dividend_received_prev_yr AS prev_yr,
        (l.other_income__dividend_received - l.other_income__dividend_received_prev_yr) / ABS(NULLIF(l.other_income__dividend_received_prev_yr, 0)) * 100 AS yoy_pct,
        l.other_income__dividend_received_3y_back AS value_3y_back,
        IF(
        l.other_income__dividend_received > 0
          AND l.other_income__dividend_received_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_income__dividend_received / l.other_income__dividend_received_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.other_income__dividend_received_5y_back AS value_5y_back,
        IF(
        l.other_income__dividend_received > 0
          AND l.other_income__dividend_received_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_income__dividend_received / l.other_income__dividend_received_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS dividend_received,
      STRUCT(
        l.other_income__commission_received AS value,
        l.other_income__commission_received_prev_yr AS prev_yr,
        (l.other_income__commission_received - l.other_income__commission_received_prev_yr) / ABS(NULLIF(l.other_income__commission_received_prev_yr, 0)) * 100 AS yoy_pct,
        l.other_income__commission_received_3y_back AS value_3y_back,
        IF(
        l.other_income__commission_received > 0
          AND l.other_income__commission_received_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_income__commission_received / l.other_income__commission_received_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.other_income__commission_received_5y_back AS value_5y_back,
        IF(
        l.other_income__commission_received > 0
          AND l.other_income__commission_received_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_income__commission_received / l.other_income__commission_received_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS commission_received,
      STRUCT(
        l.other_income__export_incentives AS value,
        l.other_income__export_incentives_prev_yr AS prev_yr,
        (l.other_income__export_incentives - l.other_income__export_incentives_prev_yr) / ABS(NULLIF(l.other_income__export_incentives_prev_yr, 0)) * 100 AS yoy_pct,
        l.other_income__export_incentives_3y_back AS value_3y_back,
        IF(
        l.other_income__export_incentives > 0
          AND l.other_income__export_incentives_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_income__export_incentives / l.other_income__export_incentives_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.other_income__export_incentives_5y_back AS value_5y_back,
        IF(
        l.other_income__export_incentives > 0
          AND l.other_income__export_incentives_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_income__export_incentives / l.other_income__export_incentives_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS export_incentives,
      STRUCT(
        l.other_income__discounts AS value,
        l.other_income__discounts_prev_yr AS prev_yr,
        (l.other_income__discounts - l.other_income__discounts_prev_yr) / ABS(NULLIF(l.other_income__discounts_prev_yr, 0)) * 100 AS yoy_pct,
        l.other_income__discounts_3y_back AS value_3y_back,
        IF(
        l.other_income__discounts > 0
          AND l.other_income__discounts_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_income__discounts / l.other_income__discounts_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.other_income__discounts_5y_back AS value_5y_back,
        IF(
        l.other_income__discounts > 0
          AND l.other_income__discounts_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_income__discounts / l.other_income__discounts_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS discounts,
      STRUCT(
        l.other_income__profit_on_sale_of_fixed_assets AS value,
        l.other_income__profit_on_sale_of_fixed_assets_prev_yr AS prev_yr,
        (l.other_income__profit_on_sale_of_fixed_assets - l.other_income__profit_on_sale_of_fixed_assets_prev_yr) / ABS(NULLIF(l.other_income__profit_on_sale_of_fixed_assets_prev_yr, 0)) * 100 AS yoy_pct,
        l.other_income__profit_on_sale_of_fixed_assets_3y_back AS value_3y_back,
        IF(
        l.other_income__profit_on_sale_of_fixed_assets > 0
          AND l.other_income__profit_on_sale_of_fixed_assets_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_income__profit_on_sale_of_fixed_assets / l.other_income__profit_on_sale_of_fixed_assets_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.other_income__profit_on_sale_of_fixed_assets_5y_back AS value_5y_back,
        IF(
        l.other_income__profit_on_sale_of_fixed_assets > 0
          AND l.other_income__profit_on_sale_of_fixed_assets_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_income__profit_on_sale_of_fixed_assets / l.other_income__profit_on_sale_of_fixed_assets_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS profit_on_sale_of_fixed_assets,
      STRUCT(
        l.other_income__profits_on_sale_of_investments AS value,
        l.other_income__profits_on_sale_of_investments_prev_yr AS prev_yr,
        (l.other_income__profits_on_sale_of_investments - l.other_income__profits_on_sale_of_investments_prev_yr) / ABS(NULLIF(l.other_income__profits_on_sale_of_investments_prev_yr, 0)) * 100 AS yoy_pct,
        l.other_income__profits_on_sale_of_investments_3y_back AS value_3y_back,
        IF(
        l.other_income__profits_on_sale_of_investments > 0
          AND l.other_income__profits_on_sale_of_investments_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_income__profits_on_sale_of_investments / l.other_income__profits_on_sale_of_investments_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.other_income__profits_on_sale_of_investments_5y_back AS value_5y_back,
        IF(
        l.other_income__profits_on_sale_of_investments > 0
          AND l.other_income__profits_on_sale_of_investments_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_income__profits_on_sale_of_investments / l.other_income__profits_on_sale_of_investments_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS profits_on_sale_of_investments,
      STRUCT(
        l.other_income__income_from_mutual_funds AS value,
        l.other_income__income_from_mutual_funds_prev_yr AS prev_yr,
        (l.other_income__income_from_mutual_funds - l.other_income__income_from_mutual_funds_prev_yr) / ABS(NULLIF(l.other_income__income_from_mutual_funds_prev_yr, 0)) * 100 AS yoy_pct,
        l.other_income__income_from_mutual_funds_3y_back AS value_3y_back,
        IF(
        l.other_income__income_from_mutual_funds > 0
          AND l.other_income__income_from_mutual_funds_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_income__income_from_mutual_funds / l.other_income__income_from_mutual_funds_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.other_income__income_from_mutual_funds_5y_back AS value_5y_back,
        IF(
        l.other_income__income_from_mutual_funds > 0
          AND l.other_income__income_from_mutual_funds_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_income__income_from_mutual_funds / l.other_income__income_from_mutual_funds_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS income_from_mutual_funds,
      STRUCT(
        l.other_income__income_from_other_investments AS value,
        l.other_income__income_from_other_investments_prev_yr AS prev_yr,
        (l.other_income__income_from_other_investments - l.other_income__income_from_other_investments_prev_yr) / ABS(NULLIF(l.other_income__income_from_other_investments_prev_yr, 0)) * 100 AS yoy_pct,
        l.other_income__income_from_other_investments_3y_back AS value_3y_back,
        IF(
        l.other_income__income_from_other_investments > 0
          AND l.other_income__income_from_other_investments_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_income__income_from_other_investments / l.other_income__income_from_other_investments_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.other_income__income_from_other_investments_5y_back AS value_5y_back,
        IF(
        l.other_income__income_from_other_investments > 0
          AND l.other_income__income_from_other_investments_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_income__income_from_other_investments / l.other_income__income_from_other_investments_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS income_from_other_investments,
      STRUCT(
        l.other_income__diminution_in_carrying_cost_of_investments AS value,
        l.other_income__diminution_in_carrying_cost_of_investments_prev_yr AS prev_yr,
        (l.other_income__diminution_in_carrying_cost_of_investments - l.other_income__diminution_in_carrying_cost_of_investments_prev_yr) / ABS(NULLIF(l.other_income__diminution_in_carrying_cost_of_investments_prev_yr, 0)) * 100 AS yoy_pct,
        l.other_income__diminution_in_carrying_cost_of_investments_3y_back AS value_3y_back,
        IF(
        l.other_income__diminution_in_carrying_cost_of_investments > 0
          AND l.other_income__diminution_in_carrying_cost_of_investments_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_income__diminution_in_carrying_cost_of_investments / l.other_income__diminution_in_carrying_cost_of_investments_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.other_income__diminution_in_carrying_cost_of_investments_5y_back AS value_5y_back,
        IF(
        l.other_income__diminution_in_carrying_cost_of_investments > 0
          AND l.other_income__diminution_in_carrying_cost_of_investments_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_income__diminution_in_carrying_cost_of_investments / l.other_income__diminution_in_carrying_cost_of_investments_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS diminution_in_carrying_cost_of_investments,
      STRUCT(
        l.other_income__sale_of_scrap_other_income AS value,
        l.other_income__sale_of_scrap_other_income_prev_yr AS prev_yr,
        (l.other_income__sale_of_scrap_other_income - l.other_income__sale_of_scrap_other_income_prev_yr) / ABS(NULLIF(l.other_income__sale_of_scrap_other_income_prev_yr, 0)) * 100 AS yoy_pct,
        l.other_income__sale_of_scrap_other_income_3y_back AS value_3y_back,
        IF(
        l.other_income__sale_of_scrap_other_income > 0
          AND l.other_income__sale_of_scrap_other_income_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_income__sale_of_scrap_other_income / l.other_income__sale_of_scrap_other_income_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.other_income__sale_of_scrap_other_income_5y_back AS value_5y_back,
        IF(
        l.other_income__sale_of_scrap_other_income > 0
          AND l.other_income__sale_of_scrap_other_income_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_income__sale_of_scrap_other_income / l.other_income__sale_of_scrap_other_income_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS sale_of_scrap_other_income,
      STRUCT(
        l.other_income__service_fee AS value,
        l.other_income__service_fee_prev_yr AS prev_yr,
        (l.other_income__service_fee - l.other_income__service_fee_prev_yr) / ABS(NULLIF(l.other_income__service_fee_prev_yr, 0)) * 100 AS yoy_pct,
        l.other_income__service_fee_3y_back AS value_3y_back,
        IF(
        l.other_income__service_fee > 0
          AND l.other_income__service_fee_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_income__service_fee / l.other_income__service_fee_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.other_income__service_fee_5y_back AS value_5y_back,
        IF(
        l.other_income__service_fee > 0
          AND l.other_income__service_fee_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_income__service_fee / l.other_income__service_fee_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS service_fee,
      STRUCT(
        l.other_income__gain_on_forward_contracts_forex AS value,
        l.other_income__gain_on_forward_contracts_forex_prev_yr AS prev_yr,
        (l.other_income__gain_on_forward_contracts_forex - l.other_income__gain_on_forward_contracts_forex_prev_yr) / ABS(NULLIF(l.other_income__gain_on_forward_contracts_forex_prev_yr, 0)) * 100 AS yoy_pct,
        l.other_income__gain_on_forward_contracts_forex_3y_back AS value_3y_back,
        IF(
        l.other_income__gain_on_forward_contracts_forex > 0
          AND l.other_income__gain_on_forward_contracts_forex_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_income__gain_on_forward_contracts_forex / l.other_income__gain_on_forward_contracts_forex_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.other_income__gain_on_forward_contracts_forex_5y_back AS value_5y_back,
        IF(
        l.other_income__gain_on_forward_contracts_forex > 0
          AND l.other_income__gain_on_forward_contracts_forex_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_income__gain_on_forward_contracts_forex / l.other_income__gain_on_forward_contracts_forex_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS gain_on_forward_contracts_forex,
      STRUCT(
        l.other_income__foreign_exchange_gains AS value,
        l.other_income__foreign_exchange_gains_prev_yr AS prev_yr,
        (l.other_income__foreign_exchange_gains - l.other_income__foreign_exchange_gains_prev_yr) / ABS(NULLIF(l.other_income__foreign_exchange_gains_prev_yr, 0)) * 100 AS yoy_pct,
        l.other_income__foreign_exchange_gains_3y_back AS value_3y_back,
        IF(
        l.other_income__foreign_exchange_gains > 0
          AND l.other_income__foreign_exchange_gains_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_income__foreign_exchange_gains / l.other_income__foreign_exchange_gains_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.other_income__foreign_exchange_gains_5y_back AS value_5y_back,
        IF(
        l.other_income__foreign_exchange_gains > 0
          AND l.other_income__foreign_exchange_gains_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_income__foreign_exchange_gains / l.other_income__foreign_exchange_gains_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS foreign_exchange_gains,
      STRUCT(
        l.other_income__lease_rental_income AS value,
        l.other_income__lease_rental_income_prev_yr AS prev_yr,
        (l.other_income__lease_rental_income - l.other_income__lease_rental_income_prev_yr) / ABS(NULLIF(l.other_income__lease_rental_income_prev_yr, 0)) * 100 AS yoy_pct,
        l.other_income__lease_rental_income_3y_back AS value_3y_back,
        IF(
        l.other_income__lease_rental_income > 0
          AND l.other_income__lease_rental_income_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_income__lease_rental_income / l.other_income__lease_rental_income_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.other_income__lease_rental_income_5y_back AS value_5y_back,
        IF(
        l.other_income__lease_rental_income > 0
          AND l.other_income__lease_rental_income_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_income__lease_rental_income / l.other_income__lease_rental_income_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS lease_rental_income,
      STRUCT(
        l.other_income__grants_from_government AS value,
        l.other_income__grants_from_government_prev_yr AS prev_yr,
        (l.other_income__grants_from_government - l.other_income__grants_from_government_prev_yr) / ABS(NULLIF(l.other_income__grants_from_government_prev_yr, 0)) * 100 AS yoy_pct,
        l.other_income__grants_from_government_3y_back AS value_3y_back,
        IF(
        l.other_income__grants_from_government > 0
          AND l.other_income__grants_from_government_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_income__grants_from_government / l.other_income__grants_from_government_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.other_income__grants_from_government_5y_back AS value_5y_back,
        IF(
        l.other_income__grants_from_government > 0
          AND l.other_income__grants_from_government_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_income__grants_from_government / l.other_income__grants_from_government_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS grants_from_government,
      STRUCT(
        l.other_income__transfer_from_capital_reserve_capital_grants AS value,
        l.other_income__transfer_from_capital_reserve_capital_grants_prev_yr AS prev_yr,
        (l.other_income__transfer_from_capital_reserve_capital_grants - l.other_income__transfer_from_capital_reserve_capital_grants_prev_yr) / ABS(NULLIF(l.other_income__transfer_from_capital_reserve_capital_grants_prev_yr, 0)) * 100 AS yoy_pct,
        l.other_income__transfer_from_capital_reserve_capital_grants_3y_back AS value_3y_back,
        IF(
        l.other_income__transfer_from_capital_reserve_capital_grants > 0
          AND l.other_income__transfer_from_capital_reserve_capital_grants_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_income__transfer_from_capital_reserve_capital_grants / l.other_income__transfer_from_capital_reserve_capital_grants_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.other_income__transfer_from_capital_reserve_capital_grants_5y_back AS value_5y_back,
        IF(
        l.other_income__transfer_from_capital_reserve_capital_grants > 0
          AND l.other_income__transfer_from_capital_reserve_capital_grants_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_income__transfer_from_capital_reserve_capital_grants / l.other_income__transfer_from_capital_reserve_capital_grants_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS transfer_from_capital_reserve_capital_grants,
      STRUCT(
        l.other_income__bad_debts_recovered AS value,
        l.other_income__bad_debts_recovered_prev_yr AS prev_yr,
        (l.other_income__bad_debts_recovered - l.other_income__bad_debts_recovered_prev_yr) / ABS(NULLIF(l.other_income__bad_debts_recovered_prev_yr, 0)) * 100 AS yoy_pct,
        l.other_income__bad_debts_recovered_3y_back AS value_3y_back,
        IF(
        l.other_income__bad_debts_recovered > 0
          AND l.other_income__bad_debts_recovered_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_income__bad_debts_recovered / l.other_income__bad_debts_recovered_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.other_income__bad_debts_recovered_5y_back AS value_5y_back,
        IF(
        l.other_income__bad_debts_recovered > 0
          AND l.other_income__bad_debts_recovered_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_income__bad_debts_recovered / l.other_income__bad_debts_recovered_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS bad_debts_recovered,
      STRUCT(
        l.other_income__provision_written_back AS value,
        l.other_income__provision_written_back_prev_yr AS prev_yr,
        (l.other_income__provision_written_back - l.other_income__provision_written_back_prev_yr) / ABS(NULLIF(l.other_income__provision_written_back_prev_yr, 0)) * 100 AS yoy_pct,
        l.other_income__provision_written_back_3y_back AS value_3y_back,
        IF(
        l.other_income__provision_written_back > 0
          AND l.other_income__provision_written_back_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_income__provision_written_back / l.other_income__provision_written_back_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.other_income__provision_written_back_5y_back AS value_5y_back,
        IF(
        l.other_income__provision_written_back > 0
          AND l.other_income__provision_written_back_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_income__provision_written_back / l.other_income__provision_written_back_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS provision_written_back,
      STRUCT(
        l.other_income__claims_received AS value,
        l.other_income__claims_received_prev_yr AS prev_yr,
        (l.other_income__claims_received - l.other_income__claims_received_prev_yr) / ABS(NULLIF(l.other_income__claims_received_prev_yr, 0)) * 100 AS yoy_pct,
        l.other_income__claims_received_3y_back AS value_3y_back,
        IF(
        l.other_income__claims_received > 0
          AND l.other_income__claims_received_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_income__claims_received / l.other_income__claims_received_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.other_income__claims_received_5y_back AS value_5y_back,
        IF(
        l.other_income__claims_received > 0
          AND l.other_income__claims_received_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_income__claims_received / l.other_income__claims_received_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS claims_received,
      STRUCT(
        l.other_income__sale_of_power AS value,
        l.other_income__sale_of_power_prev_yr AS prev_yr,
        (l.other_income__sale_of_power - l.other_income__sale_of_power_prev_yr) / ABS(NULLIF(l.other_income__sale_of_power_prev_yr, 0)) * 100 AS yoy_pct,
        l.other_income__sale_of_power_3y_back AS value_3y_back,
        IF(
        l.other_income__sale_of_power > 0
          AND l.other_income__sale_of_power_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_income__sale_of_power / l.other_income__sale_of_power_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.other_income__sale_of_power_5y_back AS value_5y_back,
        IF(
        l.other_income__sale_of_power > 0
          AND l.other_income__sale_of_power_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_income__sale_of_power / l.other_income__sale_of_power_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS sale_of_power,
      STRUCT(
        l.other_income__others AS value,
        l.other_income__others_prev_yr AS prev_yr,
        (l.other_income__others - l.other_income__others_prev_yr) / ABS(NULLIF(l.other_income__others_prev_yr, 0)) * 100 AS yoy_pct,
        l.other_income__others_3y_back AS value_3y_back,
        IF(
        l.other_income__others > 0
          AND l.other_income__others_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_income__others / l.other_income__others_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.other_income__others_5y_back AS value_5y_back,
        IF(
        l.other_income__others > 0
          AND l.other_income__others_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.other_income__others / l.other_income__others_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS others
    ) AS other_income,
    STRUCT(
      l.operating_profit AS value,
      l.operating_profit_prev_yr AS prev_yr,
      (l.operating_profit - l.operating_profit_prev_yr) / ABS(NULLIF(l.operating_profit_prev_yr, 0)) * 100 AS yoy_pct,
      l.operating_profit_3y_back AS value_3y_back,
      IF(
      l.operating_profit > 0
        AND l.operating_profit_3y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.operating_profit / l.operating_profit_3y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_3y_pct,
      l.operating_profit_5y_back AS value_5y_back,
      IF(
      l.operating_profit > 0
        AND l.operating_profit_5y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.operating_profit / l.operating_profit_5y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_5y_pct
    ) AS operating_profit,
    STRUCT(
      STRUCT(
        l.interest__value AS value,
        l.interest__value_prev_yr AS prev_yr,
        (l.interest__value - l.interest__value_prev_yr) / ABS(NULLIF(l.interest__value_prev_yr, 0)) * 100 AS yoy_pct,
        l.interest__value_3y_back AS value_3y_back,
        IF(
        l.interest__value > 0
          AND l.interest__value_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.interest__value / l.interest__value_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.interest__value_5y_back AS value_5y_back,
        IF(
        l.interest__value > 0
          AND l.interest__value_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.interest__value / l.interest__value_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS value,
      STRUCT(
        l.interest__interest_on_debenture_bonds AS value,
        l.interest__interest_on_debenture_bonds_prev_yr AS prev_yr,
        (l.interest__interest_on_debenture_bonds - l.interest__interest_on_debenture_bonds_prev_yr) / ABS(NULLIF(l.interest__interest_on_debenture_bonds_prev_yr, 0)) * 100 AS yoy_pct,
        l.interest__interest_on_debenture_bonds_3y_back AS value_3y_back,
        IF(
        l.interest__interest_on_debenture_bonds > 0
          AND l.interest__interest_on_debenture_bonds_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.interest__interest_on_debenture_bonds / l.interest__interest_on_debenture_bonds_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.interest__interest_on_debenture_bonds_5y_back AS value_5y_back,
        IF(
        l.interest__interest_on_debenture_bonds > 0
          AND l.interest__interest_on_debenture_bonds_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.interest__interest_on_debenture_bonds / l.interest__interest_on_debenture_bonds_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS interest_on_debenture_bonds,
      STRUCT(
        l.interest__interest_on_term_loan AS value,
        l.interest__interest_on_term_loan_prev_yr AS prev_yr,
        (l.interest__interest_on_term_loan - l.interest__interest_on_term_loan_prev_yr) / ABS(NULLIF(l.interest__interest_on_term_loan_prev_yr, 0)) * 100 AS yoy_pct,
        l.interest__interest_on_term_loan_3y_back AS value_3y_back,
        IF(
        l.interest__interest_on_term_loan > 0
          AND l.interest__interest_on_term_loan_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.interest__interest_on_term_loan / l.interest__interest_on_term_loan_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.interest__interest_on_term_loan_5y_back AS value_5y_back,
        IF(
        l.interest__interest_on_term_loan > 0
          AND l.interest__interest_on_term_loan_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.interest__interest_on_term_loan / l.interest__interest_on_term_loan_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS interest_on_term_loan,
      STRUCT(
        l.interest__interest_on_fixed_deposits AS value,
        l.interest__interest_on_fixed_deposits_prev_yr AS prev_yr,
        (l.interest__interest_on_fixed_deposits - l.interest__interest_on_fixed_deposits_prev_yr) / ABS(NULLIF(l.interest__interest_on_fixed_deposits_prev_yr, 0)) * 100 AS yoy_pct,
        l.interest__interest_on_fixed_deposits_3y_back AS value_3y_back,
        IF(
        l.interest__interest_on_fixed_deposits > 0
          AND l.interest__interest_on_fixed_deposits_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.interest__interest_on_fixed_deposits / l.interest__interest_on_fixed_deposits_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.interest__interest_on_fixed_deposits_5y_back AS value_5y_back,
        IF(
        l.interest__interest_on_fixed_deposits > 0
          AND l.interest__interest_on_fixed_deposits_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.interest__interest_on_fixed_deposits / l.interest__interest_on_fixed_deposits_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS interest_on_fixed_deposits,
      STRUCT(
        l.interest__interest_on_vehicle_loan AS value,
        l.interest__interest_on_vehicle_loan_prev_yr AS prev_yr,
        (l.interest__interest_on_vehicle_loan - l.interest__interest_on_vehicle_loan_prev_yr) / ABS(NULLIF(l.interest__interest_on_vehicle_loan_prev_yr, 0)) * 100 AS yoy_pct,
        l.interest__interest_on_vehicle_loan_3y_back AS value_3y_back,
        IF(
        l.interest__interest_on_vehicle_loan > 0
          AND l.interest__interest_on_vehicle_loan_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.interest__interest_on_vehicle_loan / l.interest__interest_on_vehicle_loan_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.interest__interest_on_vehicle_loan_5y_back AS value_5y_back,
        IF(
        l.interest__interest_on_vehicle_loan > 0
          AND l.interest__interest_on_vehicle_loan_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.interest__interest_on_vehicle_loan / l.interest__interest_on_vehicle_loan_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS interest_on_vehicle_loan,
      STRUCT(
        l.interest__interest_on_cash_credits_packing_credits AS value,
        l.interest__interest_on_cash_credits_packing_credits_prev_yr AS prev_yr,
        (l.interest__interest_on_cash_credits_packing_credits - l.interest__interest_on_cash_credits_packing_credits_prev_yr) / ABS(NULLIF(l.interest__interest_on_cash_credits_packing_credits_prev_yr, 0)) * 100 AS yoy_pct,
        l.interest__interest_on_cash_credits_packing_credits_3y_back AS value_3y_back,
        IF(
        l.interest__interest_on_cash_credits_packing_credits > 0
          AND l.interest__interest_on_cash_credits_packing_credits_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.interest__interest_on_cash_credits_packing_credits / l.interest__interest_on_cash_credits_packing_credits_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.interest__interest_on_cash_credits_packing_credits_5y_back AS value_5y_back,
        IF(
        l.interest__interest_on_cash_credits_packing_credits > 0
          AND l.interest__interest_on_cash_credits_packing_credits_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.interest__interest_on_cash_credits_packing_credits / l.interest__interest_on_cash_credits_packing_credits_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS interest_on_cash_credits_packing_credits,
      STRUCT(
        l.interest__interest_on_working_capital_loans AS value,
        l.interest__interest_on_working_capital_loans_prev_yr AS prev_yr,
        (l.interest__interest_on_working_capital_loans - l.interest__interest_on_working_capital_loans_prev_yr) / ABS(NULLIF(l.interest__interest_on_working_capital_loans_prev_yr, 0)) * 100 AS yoy_pct,
        l.interest__interest_on_working_capital_loans_3y_back AS value_3y_back,
        IF(
        l.interest__interest_on_working_capital_loans > 0
          AND l.interest__interest_on_working_capital_loans_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.interest__interest_on_working_capital_loans / l.interest__interest_on_working_capital_loans_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.interest__interest_on_working_capital_loans_5y_back AS value_5y_back,
        IF(
        l.interest__interest_on_working_capital_loans > 0
          AND l.interest__interest_on_working_capital_loans_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.interest__interest_on_working_capital_loans / l.interest__interest_on_working_capital_loans_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS interest_on_working_capital_loans,
      STRUCT(
        l.interest__bank_charges_etc AS value,
        l.interest__bank_charges_etc_prev_yr AS prev_yr,
        (l.interest__bank_charges_etc - l.interest__bank_charges_etc_prev_yr) / ABS(NULLIF(l.interest__bank_charges_etc_prev_yr, 0)) * 100 AS yoy_pct,
        l.interest__bank_charges_etc_3y_back AS value_3y_back,
        IF(
        l.interest__bank_charges_etc > 0
          AND l.interest__bank_charges_etc_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.interest__bank_charges_etc / l.interest__bank_charges_etc_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.interest__bank_charges_etc_5y_back AS value_5y_back,
        IF(
        l.interest__bank_charges_etc > 0
          AND l.interest__bank_charges_etc_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.interest__bank_charges_etc / l.interest__bank_charges_etc_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS bank_charges_etc,
      STRUCT(
        l.interest__other_interest AS value,
        l.interest__other_interest_prev_yr AS prev_yr,
        (l.interest__other_interest - l.interest__other_interest_prev_yr) / ABS(NULLIF(l.interest__other_interest_prev_yr, 0)) * 100 AS yoy_pct,
        l.interest__other_interest_3y_back AS value_3y_back,
        IF(
        l.interest__other_interest > 0
          AND l.interest__other_interest_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.interest__other_interest / l.interest__other_interest_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.interest__other_interest_5y_back AS value_5y_back,
        IF(
        l.interest__other_interest > 0
          AND l.interest__other_interest_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.interest__other_interest / l.interest__other_interest_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS other_interest,
      STRUCT(
        l.interest__interest_capitalised AS value,
        l.interest__interest_capitalised_prev_yr AS prev_yr,
        (l.interest__interest_capitalised - l.interest__interest_capitalised_prev_yr) / ABS(NULLIF(l.interest__interest_capitalised_prev_yr, 0)) * 100 AS yoy_pct,
        l.interest__interest_capitalised_3y_back AS value_3y_back,
        IF(
        l.interest__interest_capitalised > 0
          AND l.interest__interest_capitalised_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.interest__interest_capitalised / l.interest__interest_capitalised_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.interest__interest_capitalised_5y_back AS value_5y_back,
        IF(
        l.interest__interest_capitalised > 0
          AND l.interest__interest_capitalised_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.interest__interest_capitalised / l.interest__interest_capitalised_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS interest_capitalised
    ) AS interest,
    STRUCT(
      l.pbdt AS value,
      l.pbdt_prev_yr AS prev_yr,
      (l.pbdt - l.pbdt_prev_yr) / ABS(NULLIF(l.pbdt_prev_yr, 0)) * 100 AS yoy_pct,
      l.pbdt_3y_back AS value_3y_back,
      IF(
      l.pbdt > 0
        AND l.pbdt_3y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.pbdt / l.pbdt_3y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_3y_pct,
      l.pbdt_5y_back AS value_5y_back,
      IF(
      l.pbdt > 0
        AND l.pbdt_5y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.pbdt / l.pbdt_5y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_5y_pct
    ) AS pbdt,
    STRUCT(
      l.depreciation AS value,
      l.depreciation_prev_yr AS prev_yr,
      (l.depreciation - l.depreciation_prev_yr) / ABS(NULLIF(l.depreciation_prev_yr, 0)) * 100 AS yoy_pct,
      l.depreciation_3y_back AS value_3y_back,
      IF(
      l.depreciation > 0
        AND l.depreciation_3y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.depreciation / l.depreciation_3y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_3y_pct,
      l.depreciation_5y_back AS value_5y_back,
      IF(
      l.depreciation > 0
        AND l.depreciation_5y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.depreciation / l.depreciation_5y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_5y_pct
    ) AS depreciation,
    STRUCT(
      l.profit_before_taxation_exceptional_items AS value,
      l.profit_before_taxation_exceptional_items_prev_yr AS prev_yr,
      (l.profit_before_taxation_exceptional_items - l.profit_before_taxation_exceptional_items_prev_yr) / ABS(NULLIF(l.profit_before_taxation_exceptional_items_prev_yr, 0)) * 100 AS yoy_pct,
      l.profit_before_taxation_exceptional_items_3y_back AS value_3y_back,
      IF(
      l.profit_before_taxation_exceptional_items > 0
        AND l.profit_before_taxation_exceptional_items_3y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.profit_before_taxation_exceptional_items / l.profit_before_taxation_exceptional_items_3y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_3y_pct,
      l.profit_before_taxation_exceptional_items_5y_back AS value_5y_back,
      IF(
      l.profit_before_taxation_exceptional_items > 0
        AND l.profit_before_taxation_exceptional_items_5y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.profit_before_taxation_exceptional_items / l.profit_before_taxation_exceptional_items_5y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_5y_pct
    ) AS profit_before_taxation_exceptional_items,
    STRUCT(
      l.share_of_profit_loss_of_jv_associates AS value,
      l.share_of_profit_loss_of_jv_associates_prev_yr AS prev_yr,
      (l.share_of_profit_loss_of_jv_associates - l.share_of_profit_loss_of_jv_associates_prev_yr) / ABS(NULLIF(l.share_of_profit_loss_of_jv_associates_prev_yr, 0)) * 100 AS yoy_pct,
      l.share_of_profit_loss_of_jv_associates_3y_back AS value_3y_back,
      IF(
      l.share_of_profit_loss_of_jv_associates > 0
        AND l.share_of_profit_loss_of_jv_associates_3y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.share_of_profit_loss_of_jv_associates / l.share_of_profit_loss_of_jv_associates_3y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_3y_pct,
      l.share_of_profit_loss_of_jv_associates_5y_back AS value_5y_back,
      IF(
      l.share_of_profit_loss_of_jv_associates > 0
        AND l.share_of_profit_loss_of_jv_associates_5y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.share_of_profit_loss_of_jv_associates / l.share_of_profit_loss_of_jv_associates_5y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_5y_pct
    ) AS share_of_profit_loss_of_jv_associates,
    STRUCT(
      STRUCT(
        l.exceptional_income_expenses__value AS value,
        l.exceptional_income_expenses__value_prev_yr AS prev_yr,
        (l.exceptional_income_expenses__value - l.exceptional_income_expenses__value_prev_yr) / ABS(NULLIF(l.exceptional_income_expenses__value_prev_yr, 0)) * 100 AS yoy_pct,
        l.exceptional_income_expenses__value_3y_back AS value_3y_back,
        IF(
        l.exceptional_income_expenses__value > 0
          AND l.exceptional_income_expenses__value_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.exceptional_income_expenses__value / l.exceptional_income_expenses__value_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.exceptional_income_expenses__value_5y_back AS value_5y_back,
        IF(
        l.exceptional_income_expenses__value > 0
          AND l.exceptional_income_expenses__value_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.exceptional_income_expenses__value / l.exceptional_income_expenses__value_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS value,
      STRUCT(
        l.exceptional_income_expenses__profit_loss_on_sale_of_fixed_assets AS value,
        l.exceptional_income_expenses__profit_loss_on_sale_of_fixed_assets_prev_yr AS prev_yr,
        (l.exceptional_income_expenses__profit_loss_on_sale_of_fixed_assets - l.exceptional_income_expenses__profit_loss_on_sale_of_fixed_assets_prev_yr) / ABS(NULLIF(l.exceptional_income_expenses__profit_loss_on_sale_of_fixed_assets_prev_yr, 0)) * 100 AS yoy_pct,
        l.exceptional_income_expenses__profit_loss_on_sale_of_fixed_assets_3y_back AS value_3y_back,
        IF(
        l.exceptional_income_expenses__profit_loss_on_sale_of_fixed_assets > 0
          AND l.exceptional_income_expenses__profit_loss_on_sale_of_fixed_assets_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.exceptional_income_expenses__profit_loss_on_sale_of_fixed_assets / l.exceptional_income_expenses__profit_loss_on_sale_of_fixed_assets_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.exceptional_income_expenses__profit_loss_on_sale_of_fixed_assets_5y_back AS value_5y_back,
        IF(
        l.exceptional_income_expenses__profit_loss_on_sale_of_fixed_assets > 0
          AND l.exceptional_income_expenses__profit_loss_on_sale_of_fixed_assets_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.exceptional_income_expenses__profit_loss_on_sale_of_fixed_assets / l.exceptional_income_expenses__profit_loss_on_sale_of_fixed_assets_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS profit_loss_on_sale_of_fixed_assets,
      STRUCT(
        l.exceptional_income_expenses__profit_loss_on_sale_of_investments AS value,
        l.exceptional_income_expenses__profit_loss_on_sale_of_investments_prev_yr AS prev_yr,
        (l.exceptional_income_expenses__profit_loss_on_sale_of_investments - l.exceptional_income_expenses__profit_loss_on_sale_of_investments_prev_yr) / ABS(NULLIF(l.exceptional_income_expenses__profit_loss_on_sale_of_investments_prev_yr, 0)) * 100 AS yoy_pct,
        l.exceptional_income_expenses__profit_loss_on_sale_of_investments_3y_back AS value_3y_back,
        IF(
        l.exceptional_income_expenses__profit_loss_on_sale_of_investments > 0
          AND l.exceptional_income_expenses__profit_loss_on_sale_of_investments_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.exceptional_income_expenses__profit_loss_on_sale_of_investments / l.exceptional_income_expenses__profit_loss_on_sale_of_investments_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.exceptional_income_expenses__profit_loss_on_sale_of_investments_5y_back AS value_5y_back,
        IF(
        l.exceptional_income_expenses__profit_loss_on_sale_of_investments > 0
          AND l.exceptional_income_expenses__profit_loss_on_sale_of_investments_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.exceptional_income_expenses__profit_loss_on_sale_of_investments / l.exceptional_income_expenses__profit_loss_on_sale_of_investments_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS profit_loss_on_sale_of_investments,
      STRUCT(
        l.exceptional_income_expenses__restructuring_cost_reversal_of_provisions AS value,
        l.exceptional_income_expenses__restructuring_cost_reversal_of_provisions_prev_yr AS prev_yr,
        (l.exceptional_income_expenses__restructuring_cost_reversal_of_provisions - l.exceptional_income_expenses__restructuring_cost_reversal_of_provisions_prev_yr) / ABS(NULLIF(l.exceptional_income_expenses__restructuring_cost_reversal_of_provisions_prev_yr, 0)) * 100 AS yoy_pct,
        l.exceptional_income_expenses__restructuring_cost_reversal_of_provisions_3y_back AS value_3y_back,
        IF(
        l.exceptional_income_expenses__restructuring_cost_reversal_of_provisions > 0
          AND l.exceptional_income_expenses__restructuring_cost_reversal_of_provisions_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.exceptional_income_expenses__restructuring_cost_reversal_of_provisions / l.exceptional_income_expenses__restructuring_cost_reversal_of_provisions_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.exceptional_income_expenses__restructuring_cost_reversal_of_provisions_5y_back AS value_5y_back,
        IF(
        l.exceptional_income_expenses__restructuring_cost_reversal_of_provisions > 0
          AND l.exceptional_income_expenses__restructuring_cost_reversal_of_provisions_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.exceptional_income_expenses__restructuring_cost_reversal_of_provisions / l.exceptional_income_expenses__restructuring_cost_reversal_of_provisions_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS restructuring_cost_reversal_of_provisions,
      STRUCT(
        l.exceptional_income_expenses__accidental_loss_damages AS value,
        l.exceptional_income_expenses__accidental_loss_damages_prev_yr AS prev_yr,
        (l.exceptional_income_expenses__accidental_loss_damages - l.exceptional_income_expenses__accidental_loss_damages_prev_yr) / ABS(NULLIF(l.exceptional_income_expenses__accidental_loss_damages_prev_yr, 0)) * 100 AS yoy_pct,
        l.exceptional_income_expenses__accidental_loss_damages_3y_back AS value_3y_back,
        IF(
        l.exceptional_income_expenses__accidental_loss_damages > 0
          AND l.exceptional_income_expenses__accidental_loss_damages_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.exceptional_income_expenses__accidental_loss_damages / l.exceptional_income_expenses__accidental_loss_damages_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.exceptional_income_expenses__accidental_loss_damages_5y_back AS value_5y_back,
        IF(
        l.exceptional_income_expenses__accidental_loss_damages > 0
          AND l.exceptional_income_expenses__accidental_loss_damages_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.exceptional_income_expenses__accidental_loss_damages / l.exceptional_income_expenses__accidental_loss_damages_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS accidental_loss_damages,
      STRUCT(
        l.exceptional_income_expenses__inventory_write_off AS value,
        l.exceptional_income_expenses__inventory_write_off_prev_yr AS prev_yr,
        (l.exceptional_income_expenses__inventory_write_off - l.exceptional_income_expenses__inventory_write_off_prev_yr) / ABS(NULLIF(l.exceptional_income_expenses__inventory_write_off_prev_yr, 0)) * 100 AS yoy_pct,
        l.exceptional_income_expenses__inventory_write_off_3y_back AS value_3y_back,
        IF(
        l.exceptional_income_expenses__inventory_write_off > 0
          AND l.exceptional_income_expenses__inventory_write_off_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.exceptional_income_expenses__inventory_write_off / l.exceptional_income_expenses__inventory_write_off_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.exceptional_income_expenses__inventory_write_off_5y_back AS value_5y_back,
        IF(
        l.exceptional_income_expenses__inventory_write_off > 0
          AND l.exceptional_income_expenses__inventory_write_off_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.exceptional_income_expenses__inventory_write_off / l.exceptional_income_expenses__inventory_write_off_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS inventory_write_off,
      STRUCT(
        l.exceptional_income_expenses__other_exceptional_expenses AS value,
        l.exceptional_income_expenses__other_exceptional_expenses_prev_yr AS prev_yr,
        (l.exceptional_income_expenses__other_exceptional_expenses - l.exceptional_income_expenses__other_exceptional_expenses_prev_yr) / ABS(NULLIF(l.exceptional_income_expenses__other_exceptional_expenses_prev_yr, 0)) * 100 AS yoy_pct,
        l.exceptional_income_expenses__other_exceptional_expenses_3y_back AS value_3y_back,
        IF(
        l.exceptional_income_expenses__other_exceptional_expenses > 0
          AND l.exceptional_income_expenses__other_exceptional_expenses_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.exceptional_income_expenses__other_exceptional_expenses / l.exceptional_income_expenses__other_exceptional_expenses_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.exceptional_income_expenses__other_exceptional_expenses_5y_back AS value_5y_back,
        IF(
        l.exceptional_income_expenses__other_exceptional_expenses > 0
          AND l.exceptional_income_expenses__other_exceptional_expenses_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.exceptional_income_expenses__other_exceptional_expenses / l.exceptional_income_expenses__other_exceptional_expenses_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS other_exceptional_expenses,
      STRUCT(
        l.exceptional_income_expenses__other_exceptional_income AS value,
        l.exceptional_income_expenses__other_exceptional_income_prev_yr AS prev_yr,
        (l.exceptional_income_expenses__other_exceptional_income - l.exceptional_income_expenses__other_exceptional_income_prev_yr) / ABS(NULLIF(l.exceptional_income_expenses__other_exceptional_income_prev_yr, 0)) * 100 AS yoy_pct,
        l.exceptional_income_expenses__other_exceptional_income_3y_back AS value_3y_back,
        IF(
        l.exceptional_income_expenses__other_exceptional_income > 0
          AND l.exceptional_income_expenses__other_exceptional_income_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.exceptional_income_expenses__other_exceptional_income / l.exceptional_income_expenses__other_exceptional_income_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.exceptional_income_expenses__other_exceptional_income_5y_back AS value_5y_back,
        IF(
        l.exceptional_income_expenses__other_exceptional_income > 0
          AND l.exceptional_income_expenses__other_exceptional_income_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.exceptional_income_expenses__other_exceptional_income / l.exceptional_income_expenses__other_exceptional_income_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS other_exceptional_income
    ) AS exceptional_income_expenses,
    STRUCT(
      l.profit_before_tax AS value,
      l.profit_before_tax_prev_yr AS prev_yr,
      (l.profit_before_tax - l.profit_before_tax_prev_yr) / ABS(NULLIF(l.profit_before_tax_prev_yr, 0)) * 100 AS yoy_pct,
      l.profit_before_tax_3y_back AS value_3y_back,
      IF(
      l.profit_before_tax > 0
        AND l.profit_before_tax_3y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.profit_before_tax / l.profit_before_tax_3y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_3y_pct,
      l.profit_before_tax_5y_back AS value_5y_back,
      IF(
      l.profit_before_tax > 0
        AND l.profit_before_tax_5y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.profit_before_tax / l.profit_before_tax_5y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_5y_pct
    ) AS profit_before_tax,
    STRUCT(
      STRUCT(
        l.provision_for_tax__value AS value,
        l.provision_for_tax__value_prev_yr AS prev_yr,
        (l.provision_for_tax__value - l.provision_for_tax__value_prev_yr) / ABS(NULLIF(l.provision_for_tax__value_prev_yr, 0)) * 100 AS yoy_pct,
        l.provision_for_tax__value_3y_back AS value_3y_back,
        IF(
        l.provision_for_tax__value > 0
          AND l.provision_for_tax__value_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.provision_for_tax__value / l.provision_for_tax__value_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.provision_for_tax__value_5y_back AS value_5y_back,
        IF(
        l.provision_for_tax__value > 0
          AND l.provision_for_tax__value_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.provision_for_tax__value / l.provision_for_tax__value_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS value,
      STRUCT(
        l.provision_for_tax__current_income_tax AS value,
        l.provision_for_tax__current_income_tax_prev_yr AS prev_yr,
        (l.provision_for_tax__current_income_tax - l.provision_for_tax__current_income_tax_prev_yr) / ABS(NULLIF(l.provision_for_tax__current_income_tax_prev_yr, 0)) * 100 AS yoy_pct,
        l.provision_for_tax__current_income_tax_3y_back AS value_3y_back,
        IF(
        l.provision_for_tax__current_income_tax > 0
          AND l.provision_for_tax__current_income_tax_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.provision_for_tax__current_income_tax / l.provision_for_tax__current_income_tax_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.provision_for_tax__current_income_tax_5y_back AS value_5y_back,
        IF(
        l.provision_for_tax__current_income_tax > 0
          AND l.provision_for_tax__current_income_tax_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.provision_for_tax__current_income_tax / l.provision_for_tax__current_income_tax_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS current_income_tax,
      STRUCT(
        l.provision_for_tax__deferred_tax AS value,
        l.provision_for_tax__deferred_tax_prev_yr AS prev_yr,
        (l.provision_for_tax__deferred_tax - l.provision_for_tax__deferred_tax_prev_yr) / ABS(NULLIF(l.provision_for_tax__deferred_tax_prev_yr, 0)) * 100 AS yoy_pct,
        l.provision_for_tax__deferred_tax_3y_back AS value_3y_back,
        IF(
        l.provision_for_tax__deferred_tax > 0
          AND l.provision_for_tax__deferred_tax_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.provision_for_tax__deferred_tax / l.provision_for_tax__deferred_tax_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.provision_for_tax__deferred_tax_5y_back AS value_5y_back,
        IF(
        l.provision_for_tax__deferred_tax > 0
          AND l.provision_for_tax__deferred_tax_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.provision_for_tax__deferred_tax / l.provision_for_tax__deferred_tax_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS deferred_tax,
      STRUCT(
        l.provision_for_tax__fringe_benefit_tax AS value,
        l.provision_for_tax__fringe_benefit_tax_prev_yr AS prev_yr,
        (l.provision_for_tax__fringe_benefit_tax - l.provision_for_tax__fringe_benefit_tax_prev_yr) / ABS(NULLIF(l.provision_for_tax__fringe_benefit_tax_prev_yr, 0)) * 100 AS yoy_pct,
        l.provision_for_tax__fringe_benefit_tax_3y_back AS value_3y_back,
        IF(
        l.provision_for_tax__fringe_benefit_tax > 0
          AND l.provision_for_tax__fringe_benefit_tax_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.provision_for_tax__fringe_benefit_tax / l.provision_for_tax__fringe_benefit_tax_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.provision_for_tax__fringe_benefit_tax_5y_back AS value_5y_back,
        IF(
        l.provision_for_tax__fringe_benefit_tax > 0
          AND l.provision_for_tax__fringe_benefit_tax_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.provision_for_tax__fringe_benefit_tax / l.provision_for_tax__fringe_benefit_tax_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS fringe_benefit_tax,
      STRUCT(
        l.provision_for_tax__mat_credit_entitlement AS value,
        l.provision_for_tax__mat_credit_entitlement_prev_yr AS prev_yr,
        (l.provision_for_tax__mat_credit_entitlement - l.provision_for_tax__mat_credit_entitlement_prev_yr) / ABS(NULLIF(l.provision_for_tax__mat_credit_entitlement_prev_yr, 0)) * 100 AS yoy_pct,
        l.provision_for_tax__mat_credit_entitlement_3y_back AS value_3y_back,
        IF(
        l.provision_for_tax__mat_credit_entitlement > 0
          AND l.provision_for_tax__mat_credit_entitlement_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.provision_for_tax__mat_credit_entitlement / l.provision_for_tax__mat_credit_entitlement_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.provision_for_tax__mat_credit_entitlement_5y_back AS value_5y_back,
        IF(
        l.provision_for_tax__mat_credit_entitlement > 0
          AND l.provision_for_tax__mat_credit_entitlement_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.provision_for_tax__mat_credit_entitlement / l.provision_for_tax__mat_credit_entitlement_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS mat_credit_entitlement,
      STRUCT(
        l.provision_for_tax__other_taxes AS value,
        l.provision_for_tax__other_taxes_prev_yr AS prev_yr,
        (l.provision_for_tax__other_taxes - l.provision_for_tax__other_taxes_prev_yr) / ABS(NULLIF(l.provision_for_tax__other_taxes_prev_yr, 0)) * 100 AS yoy_pct,
        l.provision_for_tax__other_taxes_3y_back AS value_3y_back,
        IF(
        l.provision_for_tax__other_taxes > 0
          AND l.provision_for_tax__other_taxes_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.provision_for_tax__other_taxes / l.provision_for_tax__other_taxes_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.provision_for_tax__other_taxes_5y_back AS value_5y_back,
        IF(
        l.provision_for_tax__other_taxes > 0
          AND l.provision_for_tax__other_taxes_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.provision_for_tax__other_taxes / l.provision_for_tax__other_taxes_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS other_taxes
    ) AS provision_for_tax,
    STRUCT(
      l.profit_after_tax AS value,
      l.profit_after_tax_prev_yr AS prev_yr,
      (l.profit_after_tax - l.profit_after_tax_prev_yr) / ABS(NULLIF(l.profit_after_tax_prev_yr, 0)) * 100 AS yoy_pct,
      l.profit_after_tax_3y_back AS value_3y_back,
      IF(
      l.profit_after_tax > 0
        AND l.profit_after_tax_3y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.profit_after_tax / l.profit_after_tax_3y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_3y_pct,
      l.profit_after_tax_5y_back AS value_5y_back,
      IF(
      l.profit_after_tax > 0
        AND l.profit_after_tax_5y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.profit_after_tax / l.profit_after_tax_5y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_5y_pct
    ) AS profit_after_tax,
    STRUCT(
      l.profit_before_tax_from_discontinued_operations AS value,
      l.profit_before_tax_from_discontinued_operations_prev_yr AS prev_yr,
      (l.profit_before_tax_from_discontinued_operations - l.profit_before_tax_from_discontinued_operations_prev_yr) / ABS(NULLIF(l.profit_before_tax_from_discontinued_operations_prev_yr, 0)) * 100 AS yoy_pct,
      l.profit_before_tax_from_discontinued_operations_3y_back AS value_3y_back,
      IF(
      l.profit_before_tax_from_discontinued_operations > 0
        AND l.profit_before_tax_from_discontinued_operations_3y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.profit_before_tax_from_discontinued_operations / l.profit_before_tax_from_discontinued_operations_3y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_3y_pct,
      l.profit_before_tax_from_discontinued_operations_5y_back AS value_5y_back,
      IF(
      l.profit_before_tax_from_discontinued_operations > 0
        AND l.profit_before_tax_from_discontinued_operations_5y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.profit_before_tax_from_discontinued_operations / l.profit_before_tax_from_discontinued_operations_5y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_5y_pct
    ) AS profit_before_tax_from_discontinued_operations,
    STRUCT(
      l.tax_from_discontinued_operations AS value,
      l.tax_from_discontinued_operations_prev_yr AS prev_yr,
      (l.tax_from_discontinued_operations - l.tax_from_discontinued_operations_prev_yr) / ABS(NULLIF(l.tax_from_discontinued_operations_prev_yr, 0)) * 100 AS yoy_pct,
      l.tax_from_discontinued_operations_3y_back AS value_3y_back,
      IF(
      l.tax_from_discontinued_operations > 0
        AND l.tax_from_discontinued_operations_3y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.tax_from_discontinued_operations / l.tax_from_discontinued_operations_3y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_3y_pct,
      l.tax_from_discontinued_operations_5y_back AS value_5y_back,
      IF(
      l.tax_from_discontinued_operations > 0
        AND l.tax_from_discontinued_operations_5y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.tax_from_discontinued_operations / l.tax_from_discontinued_operations_5y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_5y_pct
    ) AS tax_from_discontinued_operations,
    STRUCT(
      l.profit_after_tax_from_discontinued_operations AS value,
      l.profit_after_tax_from_discontinued_operations_prev_yr AS prev_yr,
      (l.profit_after_tax_from_discontinued_operations - l.profit_after_tax_from_discontinued_operations_prev_yr) / ABS(NULLIF(l.profit_after_tax_from_discontinued_operations_prev_yr, 0)) * 100 AS yoy_pct,
      l.profit_after_tax_from_discontinued_operations_3y_back AS value_3y_back,
      IF(
      l.profit_after_tax_from_discontinued_operations > 0
        AND l.profit_after_tax_from_discontinued_operations_3y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.profit_after_tax_from_discontinued_operations / l.profit_after_tax_from_discontinued_operations_3y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_3y_pct,
      l.profit_after_tax_from_discontinued_operations_5y_back AS value_5y_back,
      IF(
      l.profit_after_tax_from_discontinued_operations > 0
        AND l.profit_after_tax_from_discontinued_operations_5y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.profit_after_tax_from_discontinued_operations / l.profit_after_tax_from_discontinued_operations_5y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_5y_pct
    ) AS profit_after_tax_from_discontinued_operations,
    STRUCT(
      l.extra_items AS value,
      l.extra_items_prev_yr AS prev_yr,
      (l.extra_items - l.extra_items_prev_yr) / ABS(NULLIF(l.extra_items_prev_yr, 0)) * 100 AS yoy_pct,
      l.extra_items_3y_back AS value_3y_back,
      IF(
      l.extra_items > 0
        AND l.extra_items_3y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.extra_items / l.extra_items_3y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_3y_pct,
      l.extra_items_5y_back AS value_5y_back,
      IF(
      l.extra_items > 0
        AND l.extra_items_5y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.extra_items / l.extra_items_5y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_5y_pct
    ) AS extra_items,
    STRUCT(
      l.minority_interest AS value,
      l.minority_interest_prev_yr AS prev_yr,
      (l.minority_interest - l.minority_interest_prev_yr) / ABS(NULLIF(l.minority_interest_prev_yr, 0)) * 100 AS yoy_pct,
      l.minority_interest_3y_back AS value_3y_back,
      IF(
      l.minority_interest > 0
        AND l.minority_interest_3y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.minority_interest / l.minority_interest_3y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_3y_pct,
      l.minority_interest_5y_back AS value_5y_back,
      IF(
      l.minority_interest > 0
        AND l.minority_interest_5y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.minority_interest / l.minority_interest_5y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_5y_pct
    ) AS minority_interest,
    STRUCT(
      l.share_of_associate AS value,
      l.share_of_associate_prev_yr AS prev_yr,
      (l.share_of_associate - l.share_of_associate_prev_yr) / ABS(NULLIF(l.share_of_associate_prev_yr, 0)) * 100 AS yoy_pct,
      l.share_of_associate_3y_back AS value_3y_back,
      IF(
      l.share_of_associate > 0
        AND l.share_of_associate_3y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.share_of_associate / l.share_of_associate_3y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_3y_pct,
      l.share_of_associate_5y_back AS value_5y_back,
      IF(
      l.share_of_associate > 0
        AND l.share_of_associate_5y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.share_of_associate / l.share_of_associate_5y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_5y_pct
    ) AS share_of_associate,
    STRUCT(
      l.other_consolidated_items AS value,
      l.other_consolidated_items_prev_yr AS prev_yr,
      (l.other_consolidated_items - l.other_consolidated_items_prev_yr) / ABS(NULLIF(l.other_consolidated_items_prev_yr, 0)) * 100 AS yoy_pct,
      l.other_consolidated_items_3y_back AS value_3y_back,
      IF(
      l.other_consolidated_items > 0
        AND l.other_consolidated_items_3y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.other_consolidated_items / l.other_consolidated_items_3y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_3y_pct,
      l.other_consolidated_items_5y_back AS value_5y_back,
      IF(
      l.other_consolidated_items > 0
        AND l.other_consolidated_items_5y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.other_consolidated_items / l.other_consolidated_items_5y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_5y_pct
    ) AS other_consolidated_items,
    STRUCT(
      l.consolidated_net_profit AS value,
      l.consolidated_net_profit_prev_yr AS prev_yr,
      (l.consolidated_net_profit - l.consolidated_net_profit_prev_yr) / ABS(NULLIF(l.consolidated_net_profit_prev_yr, 0)) * 100 AS yoy_pct,
      l.consolidated_net_profit_3y_back AS value_3y_back,
      IF(
      l.consolidated_net_profit > 0
        AND l.consolidated_net_profit_3y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.consolidated_net_profit / l.consolidated_net_profit_3y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_3y_pct,
      l.consolidated_net_profit_5y_back AS value_5y_back,
      IF(
      l.consolidated_net_profit > 0
        AND l.consolidated_net_profit_5y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.consolidated_net_profit / l.consolidated_net_profit_5y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_5y_pct
    ) AS consolidated_net_profit,
    STRUCT(
      l.adjustments_to_pat AS value,
      l.adjustments_to_pat_prev_yr AS prev_yr,
      (l.adjustments_to_pat - l.adjustments_to_pat_prev_yr) / ABS(NULLIF(l.adjustments_to_pat_prev_yr, 0)) * 100 AS yoy_pct,
      l.adjustments_to_pat_3y_back AS value_3y_back,
      IF(
      l.adjustments_to_pat > 0
        AND l.adjustments_to_pat_3y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.adjustments_to_pat / l.adjustments_to_pat_3y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_3y_pct,
      l.adjustments_to_pat_5y_back AS value_5y_back,
      IF(
      l.adjustments_to_pat > 0
        AND l.adjustments_to_pat_5y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.adjustments_to_pat / l.adjustments_to_pat_5y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_5y_pct
    ) AS adjustments_to_pat,
    STRUCT(
      l.profit_balance_b_f AS value,
      l.profit_balance_b_f_prev_yr AS prev_yr,
      (l.profit_balance_b_f - l.profit_balance_b_f_prev_yr) / ABS(NULLIF(l.profit_balance_b_f_prev_yr, 0)) * 100 AS yoy_pct,
      l.profit_balance_b_f_3y_back AS value_3y_back,
      IF(
      l.profit_balance_b_f > 0
        AND l.profit_balance_b_f_3y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.profit_balance_b_f / l.profit_balance_b_f_3y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_3y_pct,
      l.profit_balance_b_f_5y_back AS value_5y_back,
      IF(
      l.profit_balance_b_f > 0
        AND l.profit_balance_b_f_5y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.profit_balance_b_f / l.profit_balance_b_f_5y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_5y_pct
    ) AS profit_balance_b_f,
    STRUCT(
      STRUCT(
        l.appropriations__value AS value,
        l.appropriations__value_prev_yr AS prev_yr,
        (l.appropriations__value - l.appropriations__value_prev_yr) / ABS(NULLIF(l.appropriations__value_prev_yr, 0)) * 100 AS yoy_pct,
        l.appropriations__value_3y_back AS value_3y_back,
        IF(
        l.appropriations__value > 0
          AND l.appropriations__value_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.appropriations__value / l.appropriations__value_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.appropriations__value_5y_back AS value_5y_back,
        IF(
        l.appropriations__value > 0
          AND l.appropriations__value_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.appropriations__value / l.appropriations__value_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS value,
      STRUCT(
        l.appropriations__general_reserve AS value,
        l.appropriations__general_reserve_prev_yr AS prev_yr,
        (l.appropriations__general_reserve - l.appropriations__general_reserve_prev_yr) / ABS(NULLIF(l.appropriations__general_reserve_prev_yr, 0)) * 100 AS yoy_pct,
        l.appropriations__general_reserve_3y_back AS value_3y_back,
        IF(
        l.appropriations__general_reserve > 0
          AND l.appropriations__general_reserve_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.appropriations__general_reserve / l.appropriations__general_reserve_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.appropriations__general_reserve_5y_back AS value_5y_back,
        IF(
        l.appropriations__general_reserve > 0
          AND l.appropriations__general_reserve_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.appropriations__general_reserve / l.appropriations__general_reserve_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS general_reserve,
      STRUCT(
        l.appropriations__interim_dividend_equity AS value,
        l.appropriations__interim_dividend_equity_prev_yr AS prev_yr,
        (l.appropriations__interim_dividend_equity - l.appropriations__interim_dividend_equity_prev_yr) / ABS(NULLIF(l.appropriations__interim_dividend_equity_prev_yr, 0)) * 100 AS yoy_pct,
        l.appropriations__interim_dividend_equity_3y_back AS value_3y_back,
        IF(
        l.appropriations__interim_dividend_equity > 0
          AND l.appropriations__interim_dividend_equity_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.appropriations__interim_dividend_equity / l.appropriations__interim_dividend_equity_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.appropriations__interim_dividend_equity_5y_back AS value_5y_back,
        IF(
        l.appropriations__interim_dividend_equity > 0
          AND l.appropriations__interim_dividend_equity_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.appropriations__interim_dividend_equity / l.appropriations__interim_dividend_equity_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS interim_dividend_equity,
      STRUCT(
        l.appropriations__proposed_equity_dividend AS value,
        l.appropriations__proposed_equity_dividend_prev_yr AS prev_yr,
        (l.appropriations__proposed_equity_dividend - l.appropriations__proposed_equity_dividend_prev_yr) / ABS(NULLIF(l.appropriations__proposed_equity_dividend_prev_yr, 0)) * 100 AS yoy_pct,
        l.appropriations__proposed_equity_dividend_3y_back AS value_3y_back,
        IF(
        l.appropriations__proposed_equity_dividend > 0
          AND l.appropriations__proposed_equity_dividend_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.appropriations__proposed_equity_dividend / l.appropriations__proposed_equity_dividend_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.appropriations__proposed_equity_dividend_5y_back AS value_5y_back,
        IF(
        l.appropriations__proposed_equity_dividend > 0
          AND l.appropriations__proposed_equity_dividend_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.appropriations__proposed_equity_dividend / l.appropriations__proposed_equity_dividend_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS proposed_equity_dividend,
      STRUCT(
        l.appropriations__preference_dividend AS value,
        l.appropriations__preference_dividend_prev_yr AS prev_yr,
        (l.appropriations__preference_dividend - l.appropriations__preference_dividend_prev_yr) / ABS(NULLIF(l.appropriations__preference_dividend_prev_yr, 0)) * 100 AS yoy_pct,
        l.appropriations__preference_dividend_3y_back AS value_3y_back,
        IF(
        l.appropriations__preference_dividend > 0
          AND l.appropriations__preference_dividend_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.appropriations__preference_dividend / l.appropriations__preference_dividend_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.appropriations__preference_dividend_5y_back AS value_5y_back,
        IF(
        l.appropriations__preference_dividend > 0
          AND l.appropriations__preference_dividend_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.appropriations__preference_dividend / l.appropriations__preference_dividend_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS preference_dividend,
      STRUCT(
        l.appropriations__corporate_dividend_tax AS value,
        l.appropriations__corporate_dividend_tax_prev_yr AS prev_yr,
        (l.appropriations__corporate_dividend_tax - l.appropriations__corporate_dividend_tax_prev_yr) / ABS(NULLIF(l.appropriations__corporate_dividend_tax_prev_yr, 0)) * 100 AS yoy_pct,
        l.appropriations__corporate_dividend_tax_3y_back AS value_3y_back,
        IF(
        l.appropriations__corporate_dividend_tax > 0
          AND l.appropriations__corporate_dividend_tax_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.appropriations__corporate_dividend_tax / l.appropriations__corporate_dividend_tax_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.appropriations__corporate_dividend_tax_5y_back AS value_5y_back,
        IF(
        l.appropriations__corporate_dividend_tax > 0
          AND l.appropriations__corporate_dividend_tax_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.appropriations__corporate_dividend_tax / l.appropriations__corporate_dividend_tax_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS corporate_dividend_tax,
      STRUCT(
        l.appropriations__statutory_reserve AS value,
        l.appropriations__statutory_reserve_prev_yr AS prev_yr,
        (l.appropriations__statutory_reserve - l.appropriations__statutory_reserve_prev_yr) / ABS(NULLIF(l.appropriations__statutory_reserve_prev_yr, 0)) * 100 AS yoy_pct,
        l.appropriations__statutory_reserve_3y_back AS value_3y_back,
        IF(
        l.appropriations__statutory_reserve > 0
          AND l.appropriations__statutory_reserve_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.appropriations__statutory_reserve / l.appropriations__statutory_reserve_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.appropriations__statutory_reserve_5y_back AS value_5y_back,
        IF(
        l.appropriations__statutory_reserve > 0
          AND l.appropriations__statutory_reserve_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.appropriations__statutory_reserve / l.appropriations__statutory_reserve_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS statutory_reserve,
      STRUCT(
        l.appropriations__other_appropriation AS value,
        l.appropriations__other_appropriation_prev_yr AS prev_yr,
        (l.appropriations__other_appropriation - l.appropriations__other_appropriation_prev_yr) / ABS(NULLIF(l.appropriations__other_appropriation_prev_yr, 0)) * 100 AS yoy_pct,
        l.appropriations__other_appropriation_3y_back AS value_3y_back,
        IF(
        l.appropriations__other_appropriation > 0
          AND l.appropriations__other_appropriation_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.appropriations__other_appropriation / l.appropriations__other_appropriation_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.appropriations__other_appropriation_5y_back AS value_5y_back,
        IF(
        l.appropriations__other_appropriation > 0
          AND l.appropriations__other_appropriation_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.appropriations__other_appropriation / l.appropriations__other_appropriation_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS other_appropriation,
      STRUCT(
        l.appropriations__capital_redemption_reserve AS value,
        l.appropriations__capital_redemption_reserve_prev_yr AS prev_yr,
        (l.appropriations__capital_redemption_reserve - l.appropriations__capital_redemption_reserve_prev_yr) / ABS(NULLIF(l.appropriations__capital_redemption_reserve_prev_yr, 0)) * 100 AS yoy_pct,
        l.appropriations__capital_redemption_reserve_3y_back AS value_3y_back,
        IF(
        l.appropriations__capital_redemption_reserve > 0
          AND l.appropriations__capital_redemption_reserve_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.appropriations__capital_redemption_reserve / l.appropriations__capital_redemption_reserve_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.appropriations__capital_redemption_reserve_5y_back AS value_5y_back,
        IF(
        l.appropriations__capital_redemption_reserve > 0
          AND l.appropriations__capital_redemption_reserve_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.appropriations__capital_redemption_reserve / l.appropriations__capital_redemption_reserve_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS capital_redemption_reserve,
      STRUCT(
        l.appropriations__profit_loss_balance_c_f AS value,
        l.appropriations__profit_loss_balance_c_f_prev_yr AS prev_yr,
        (l.appropriations__profit_loss_balance_c_f - l.appropriations__profit_loss_balance_c_f_prev_yr) / ABS(NULLIF(l.appropriations__profit_loss_balance_c_f_prev_yr, 0)) * 100 AS yoy_pct,
        l.appropriations__profit_loss_balance_c_f_3y_back AS value_3y_back,
        IF(
        l.appropriations__profit_loss_balance_c_f > 0
          AND l.appropriations__profit_loss_balance_c_f_3y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.appropriations__profit_loss_balance_c_f / l.appropriations__profit_loss_balance_c_f_3y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_3y_pct,
        l.appropriations__profit_loss_balance_c_f_5y_back AS value_5y_back,
        IF(
        l.appropriations__profit_loss_balance_c_f > 0
          AND l.appropriations__profit_loss_balance_c_f_5y_back > 0
          AND DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH)
            > 0,
        (
          POW(
            l.appropriations__profit_loss_balance_c_f / l.appropriations__profit_loss_balance_c_f_5y_back,
            12.0 / DATE_DIFF(
              PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
              PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
              MONTH))
          - 1)
          * 100,
        NULL) AS cagr_5y_pct
      ) AS profit_loss_balance_c_f
    ) AS appropriations,
    STRUCT(
      l.equity_dividend AS value,
      l.equity_dividend_prev_yr AS prev_yr,
      (l.equity_dividend - l.equity_dividend_prev_yr) / ABS(NULLIF(l.equity_dividend_prev_yr, 0)) * 100 AS yoy_pct,
      l.equity_dividend_3y_back AS value_3y_back,
      IF(
      l.equity_dividend > 0
        AND l.equity_dividend_3y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.equity_dividend / l.equity_dividend_3y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_3y_pct,
      l.equity_dividend_5y_back AS value_5y_back,
      IF(
      l.equity_dividend > 0
        AND l.equity_dividend_5y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.equity_dividend / l.equity_dividend_5y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_5y_pct
    ) AS equity_dividend,
    STRUCT(
      l.earnings_per_share_calculated AS value,
      l.earnings_per_share_calculated_prev_yr AS prev_yr,
      (l.earnings_per_share_calculated - l.earnings_per_share_calculated_prev_yr) / ABS(NULLIF(l.earnings_per_share_calculated_prev_yr, 0)) * 100 AS yoy_pct,
      l.earnings_per_share_calculated_3y_back AS value_3y_back,
      IF(
      l.earnings_per_share_calculated > 0
        AND l.earnings_per_share_calculated_3y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.earnings_per_share_calculated / l.earnings_per_share_calculated_3y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_3y_pct,
      l.earnings_per_share_calculated_5y_back AS value_5y_back,
      IF(
      l.earnings_per_share_calculated > 0
        AND l.earnings_per_share_calculated_5y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.earnings_per_share_calculated / l.earnings_per_share_calculated_5y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_5y_pct
    ) AS earnings_per_share_calculated,
    STRUCT(
      l.adjusted_eps AS value,
      l.adjusted_eps_prev_yr AS prev_yr,
      (l.adjusted_eps - l.adjusted_eps_prev_yr) / ABS(NULLIF(l.adjusted_eps_prev_yr, 0)) * 100 AS yoy_pct,
      l.adjusted_eps_3y_back AS value_3y_back,
      IF(
      l.adjusted_eps > 0
        AND l.adjusted_eps_3y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.adjusted_eps / l.adjusted_eps_3y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_3y_pct,
      l.adjusted_eps_5y_back AS value_5y_back,
      IF(
      l.adjusted_eps > 0
        AND l.adjusted_eps_5y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.adjusted_eps / l.adjusted_eps_5y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_5y_pct
    ) AS adjusted_eps,
    STRUCT(
      l.eps_basic_reported AS value,
      l.eps_basic_reported_prev_yr AS prev_yr,
      (l.eps_basic_reported - l.eps_basic_reported_prev_yr) / ABS(NULLIF(l.eps_basic_reported_prev_yr, 0)) * 100 AS yoy_pct,
      l.eps_basic_reported_3y_back AS value_3y_back,
      IF(
      l.eps_basic_reported > 0
        AND l.eps_basic_reported_3y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.eps_basic_reported / l.eps_basic_reported_3y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_3y_pct,
      l.eps_basic_reported_5y_back AS value_5y_back,
      IF(
      l.eps_basic_reported > 0
        AND l.eps_basic_reported_5y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.eps_basic_reported / l.eps_basic_reported_5y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_5y_pct
    ) AS eps_basic_reported,
    STRUCT(
      l.eps_diluted_reported AS value,
      l.eps_diluted_reported_prev_yr AS prev_yr,
      (l.eps_diluted_reported - l.eps_diluted_reported_prev_yr) / ABS(NULLIF(l.eps_diluted_reported_prev_yr, 0)) * 100 AS yoy_pct,
      l.eps_diluted_reported_3y_back AS value_3y_back,
      IF(
      l.eps_diluted_reported > 0
        AND l.eps_diluted_reported_3y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.eps_diluted_reported / l.eps_diluted_reported_3y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_3y_pct,
      l.eps_diluted_reported_5y_back AS value_5y_back,
      IF(
      l.eps_diluted_reported > 0
        AND l.eps_diluted_reported_5y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.eps_diluted_reported / l.eps_diluted_reported_5y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_5y_pct
    ) AS eps_diluted_reported,
    STRUCT(
      l.others_2 AS value,
      l.others_2_prev_yr AS prev_yr,
      (l.others_2 - l.others_2_prev_yr) / ABS(NULLIF(l.others_2_prev_yr, 0)) * 100 AS yoy_pct,
      l.others_2_3y_back AS value_3y_back,
      IF(
      l.others_2 > 0
        AND l.others_2_3y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.others_2 / l.others_2_3y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_3y_pct,
      l.others_2_5y_back AS value_5y_back,
      IF(
      l.others_2 > 0
        AND l.others_2_5y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.others_2 / l.others_2_5y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_5y_pct
    ) AS others_2,
    STRUCT(
      l.commission_brokerage_discounts AS value,
      l.commission_brokerage_discounts_prev_yr AS prev_yr,
      (l.commission_brokerage_discounts - l.commission_brokerage_discounts_prev_yr) / ABS(NULLIF(l.commission_brokerage_discounts_prev_yr, 0)) * 100 AS yoy_pct,
      l.commission_brokerage_discounts_3y_back AS value_3y_back,
      IF(
      l.commission_brokerage_discounts > 0
        AND l.commission_brokerage_discounts_3y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.commission_brokerage_discounts / l.commission_brokerage_discounts_3y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_3y_pct,
      l.commission_brokerage_discounts_5y_back AS value_5y_back,
      IF(
      l.commission_brokerage_discounts > 0
        AND l.commission_brokerage_discounts_5y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.commission_brokerage_discounts / l.commission_brokerage_discounts_5y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_5y_pct
    ) AS commission_brokerage_discounts,
    STRUCT(
      l.other_operating_expenses AS value,
      l.other_operating_expenses_prev_yr AS prev_yr,
      (l.other_operating_expenses - l.other_operating_expenses_prev_yr) / ABS(NULLIF(l.other_operating_expenses_prev_yr, 0)) * 100 AS yoy_pct,
      l.other_operating_expenses_3y_back AS value_3y_back,
      IF(
      l.other_operating_expenses > 0
        AND l.other_operating_expenses_3y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.other_operating_expenses / l.other_operating_expenses_3y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_3y_pct,
      l.other_operating_expenses_5y_back AS value_5y_back,
      IF(
      l.other_operating_expenses > 0
        AND l.other_operating_expenses_5y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.other_operating_expenses / l.other_operating_expenses_5y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_5y_pct
    ) AS other_operating_expenses,
    STRUCT(
      l.director_s_remunerations AS value,
      l.director_s_remunerations_prev_yr AS prev_yr,
      (l.director_s_remunerations - l.director_s_remunerations_prev_yr) / ABS(NULLIF(l.director_s_remunerations_prev_yr, 0)) * 100 AS yoy_pct,
      l.director_s_remunerations_3y_back AS value_3y_back,
      IF(
      l.director_s_remunerations > 0
        AND l.director_s_remunerations_3y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.director_s_remunerations / l.director_s_remunerations_3y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_3y_pct,
      l.director_s_remunerations_5y_back AS value_5y_back,
      IF(
      l.director_s_remunerations > 0
        AND l.director_s_remunerations_5y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.director_s_remunerations / l.director_s_remunerations_5y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_5y_pct
    ) AS director_s_remunerations,
    STRUCT(
      l.income_from_investments AS value,
      l.income_from_investments_prev_yr AS prev_yr,
      (l.income_from_investments - l.income_from_investments_prev_yr) / ABS(NULLIF(l.income_from_investments_prev_yr, 0)) * 100 AS yoy_pct,
      l.income_from_investments_3y_back AS value_3y_back,
      IF(
      l.income_from_investments > 0
        AND l.income_from_investments_3y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.income_from_investments / l.income_from_investments_3y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_3y_pct,
      l.income_from_investments_5y_back AS value_5y_back,
      IF(
      l.income_from_investments > 0
        AND l.income_from_investments_5y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.income_from_investments / l.income_from_investments_5y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_5y_pct
    ) AS income_from_investments,
    STRUCT(
      l.current_incometax AS value,
      l.current_incometax_prev_yr AS prev_yr,
      (l.current_incometax - l.current_incometax_prev_yr) / ABS(NULLIF(l.current_incometax_prev_yr, 0)) * 100 AS yoy_pct,
      l.current_incometax_3y_back AS value_3y_back,
      IF(
      l.current_incometax > 0
        AND l.current_incometax_3y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.current_incometax / l.current_incometax_3y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_3y_pct,
      l.current_incometax_5y_back AS value_5y_back,
      IF(
      l.current_incometax > 0
        AND l.current_incometax_5y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.current_incometax / l.current_incometax_5y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_5y_pct
    ) AS current_incometax,
    STRUCT(
      l.deferredtax AS value,
      l.deferredtax_prev_yr AS prev_yr,
      (l.deferredtax - l.deferredtax_prev_yr) / ABS(NULLIF(l.deferredtax_prev_yr, 0)) * 100 AS yoy_pct,
      l.deferredtax_3y_back AS value_3y_back,
      IF(
      l.deferredtax > 0
        AND l.deferredtax_3y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.deferredtax / l.deferredtax_3y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_3y_pct,
      l.deferredtax_5y_back AS value_5y_back,
      IF(
      l.deferredtax > 0
        AND l.deferredtax_5y_back > 0
        AND DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
          MONTH)
          > 0,
      (
        POW(
          l.deferredtax / l.deferredtax_5y_back,
          12.0 / DATE_DIFF(
            PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
            PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
            MONTH))
        - 1)
        * 100,
      NULL) AS cagr_5y_pct
    ) AS deferredtax
  ) AS expenditure_growth
FROM lagged l;
END
