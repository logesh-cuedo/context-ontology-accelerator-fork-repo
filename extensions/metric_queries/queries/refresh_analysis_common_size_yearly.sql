-- Routine: silverzone.refresh_analysis_common_size_yearly
-- Source: capable-code-486208-j8.silverzone

BEGIN
CREATE OR REPLACE TABLE silverzone.analysis_common_size_yearly
  CLUSTER BY company_id, yyyymm
AS
SELECT
  i.company_id,
  i.company_name,
  i.sector,
  i.subsector,
  i.flag,
  i.yyyymm,
  i.value_basis,
  i.net_sales,
  e.increase_decrease_in_stock,
  IF(
    ABS(e.total_expenditure) < 1e-6,
    NULL,
    e.increase_decrease_in_stock / e.total_expenditure * 100)
    AS increase_decrease_in_stock_pct_of_total_expenditure,
  IF(
    ABS(i.net_sales) < 1e-6,
    NULL,
    e.increase_decrease_in_stock / i.net_sales * 100)
    AS increase_decrease_in_stock_pct_of_net_sales,
  e.raw_material_consumed,
  IF(
    ABS(e.total_expenditure) < 1e-6,
    NULL,
    e.raw_material_consumed / e.total_expenditure * 100)
    AS raw_material_consumed_pct_of_total_expenditure,
  IF(ABS(i.net_sales) < 1e-6, NULL, e.raw_material_consumed / i.net_sales * 100)
    AS raw_material_consumed_pct_of_net_sales,
  e.power_fuel_cost,
  IF(
    ABS(e.total_expenditure) < 1e-6,
    NULL,
    e.power_fuel_cost / e.total_expenditure * 100)
    AS power_fuel_cost_pct_of_total_expenditure,
  IF(ABS(i.net_sales) < 1e-6, NULL, e.power_fuel_cost / i.net_sales * 100)
    AS power_fuel_cost_pct_of_net_sales,
  e.employee_cost,
  IF(
    ABS(e.total_expenditure) < 1e-6,
    NULL,
    e.employee_cost / e.total_expenditure * 100)
    AS employee_cost_pct_of_total_expenditure,
  IF(ABS(i.net_sales) < 1e-6, NULL, e.employee_cost / i.net_sales * 100)
    AS employee_cost_pct_of_net_sales,
  e.other_manufacturing_expenses,
  IF(
    ABS(e.total_expenditure) < 1e-6,
    NULL,
    e.other_manufacturing_expenses / e.total_expenditure * 100)
    AS other_manufacturing_expenses_pct_of_total_expenditure,
  IF(
    ABS(i.net_sales) < 1e-6,
    NULL,
    e.other_manufacturing_expenses / i.net_sales * 100)
    AS other_manufacturing_expenses_pct_of_net_sales,
  e.general_and_administration_expenses,
  IF(
    ABS(e.total_expenditure) < 1e-6,
    NULL,
    e.general_and_administration_expenses / e.total_expenditure * 100)
    AS general_and_administration_expenses_pct_of_total_expenditure,
  IF(
    ABS(i.net_sales) < 1e-6,
    NULL,
    e.general_and_administration_expenses / i.net_sales * 100)
    AS general_and_administration_expenses_pct_of_net_sales,
  e.selling_and_distribution_expenses,
  IF(
    ABS(e.total_expenditure) < 1e-6,
    NULL,
    e.selling_and_distribution_expenses / e.total_expenditure * 100)
    AS selling_and_distribution_expenses_pct_of_total_expenditure,
  IF(
    ABS(i.net_sales) < 1e-6,
    NULL,
    e.selling_and_distribution_expenses / i.net_sales * 100)
    AS selling_and_distribution_expenses_pct_of_net_sales,
  e.miscellaneous_expenses,
  IF(
    ABS(e.total_expenditure) < 1e-6,
    NULL,
    e.miscellaneous_expenses / e.total_expenditure * 100)
    AS miscellaneous_expenses_pct_of_total_expenditure,
  IF(
    ABS(i.net_sales) < 1e-6, NULL, e.miscellaneous_expenses / i.net_sales * 100)
    AS miscellaneous_expenses_pct_of_net_sales,
  e.total_expenditure,
  IF(
    ABS(e.total_expenditure) < 1e-6,
    NULL,
    e.total_expenditure / e.total_expenditure * 100)
    AS total_expenditure_pct_of_total_expenditure,
  IF(ABS(i.net_sales) < 1e-6, NULL, e.total_expenditure / i.net_sales * 100)
    AS total_expenditure_pct_of_net_sales,
  e.interest,
  IF(
    ABS(e.total_expenditure) < 1e-6,
    NULL,
    e.interest / e.total_expenditure * 100)
    AS interest_pct_of_total_expenditure,
  IF(ABS(i.net_sales) < 1e-6, NULL, e.interest / i.net_sales * 100)
    AS interest_pct_of_net_sales,
  e.depreciation,
  IF(
    ABS(e.total_expenditure) < 1e-6,
    NULL,
    e.depreciation / e.total_expenditure * 100)
    AS depreciation_pct_of_total_expenditure,
  IF(ABS(i.net_sales) < 1e-6, NULL, e.depreciation / i.net_sales * 100)
    AS depreciation_pct_of_net_sales,
  d.operating_profit_excl_oi,
  IF(
    ABS(i.net_sales) < 1e-6,
    NULL,
    d.operating_profit_excl_oi / i.net_sales * 100)
    AS operating_profit_excl_oi_pct_of_net_sales,
  d.operating_profit,
  IF(ABS(i.net_sales) < 1e-6, NULL, d.operating_profit / i.net_sales * 100)
    AS operating_profit_pct_of_net_sales,
  d.pbdt,
  IF(ABS(i.net_sales) < 1e-6, NULL, d.pbdt / i.net_sales * 100)
    AS pbdt_pct_of_net_sales,
  d.profit_before_tax,
  IF(ABS(i.net_sales) < 1e-6, NULL, d.profit_before_tax / i.net_sales * 100)
    AS profit_before_tax_pct_of_net_sales,
  d.profit_after_tax,
  IF(ABS(i.net_sales) < 1e-6, NULL, d.profit_after_tax / i.net_sales * 100)
    AS profit_after_tax_pct_of_net_sales
FROM silverzone.combined_profit_and_loss_income_quarterly_merged i
LEFT JOIN silverzone.combined_profit_and_loss_expenditure_quarterly_merged e
  ON
    e.company_id = i.company_id
    AND COALESCE(e.flag, '') = COALESCE(i.flag, '')
    AND e.yyyymm = i.yyyymm
LEFT JOIN silverzone.combined_profit_and_loss_derived_quarterly_merged d
  ON
    d.company_id = i.company_id
    AND COALESCE(d.flag, '') = COALESCE(i.flag, '')
    AND d.yyyymm = i.yyyymm;

END
