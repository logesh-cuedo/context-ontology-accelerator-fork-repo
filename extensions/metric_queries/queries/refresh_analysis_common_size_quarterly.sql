-- Routine: silverzone.refresh_analysis_common_size_quarterly
-- Source: capable-code-486208-j8.silverzone

BEGIN
CREATE OR REPLACE TABLE silverzone.analysis_common_size_quarterly
  CLUSTER BY company_id, yyyymm
AS
SELECT
  i.company_id,
  i.company_name,
  i.sector,
  i.subsector,
  i.flag,
  i.yyyymm,
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
FROM silverzone.combined_profit_and_loss_income_quarterly i
LEFT JOIN silverzone.combined_profit_and_loss_expenditure_quarterly e
  ON
    e.company_id = i.company_id
    AND COALESCE(e.flag, '') = COALESCE(i.flag, '')
    AND e.yyyymm = i.yyyymm
LEFT JOIN silverzone.combined_profit_and_loss_derived_quarterly d
  ON
    d.company_id = i.company_id
    AND COALESCE(d.flag, '') = COALESCE(i.flag, '')
    AND d.yyyymm = i.yyyymm;

END
