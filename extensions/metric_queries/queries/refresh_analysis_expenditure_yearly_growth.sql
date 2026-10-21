-- Routine: silverzone.refresh_analysis_expenditure_yearly_growth
-- Source: capable-code-486208-j8.silverzone

BEGIN
CREATE OR REPLACE TABLE silverzone.analysis_expenditure_yearly_growth
  CLUSTER BY company_id, yyyymm
AS
WITH
  lagged AS (
    SELECT
      *,
      LAG(yyyymm) OVER w AS prev_yyyymm,
      LAG(yyyymm, 3) OVER w AS yyyymm_3y_back,
      LAG(yyyymm, 5) OVER w AS yyyymm_5y_back,
      LAG(increase_decrease_in_stock)
        OVER w AS increase_decrease_in_stock_prev_yr,
      LAG(increase_decrease_in_stock, 3)
        OVER w AS increase_decrease_in_stock_3y_back,
      LAG(increase_decrease_in_stock, 5)
        OVER w AS increase_decrease_in_stock_5y_back,
      LAG(raw_material_consumed) OVER w AS raw_material_consumed_prev_yr,
      LAG(raw_material_consumed, 3) OVER w AS raw_material_consumed_3y_back,
      LAG(raw_material_consumed, 5) OVER w AS raw_material_consumed_5y_back,
      LAG(power_fuel_cost) OVER w AS power_fuel_cost_prev_yr,
      LAG(power_fuel_cost, 3) OVER w AS power_fuel_cost_3y_back,
      LAG(power_fuel_cost, 5) OVER w AS power_fuel_cost_5y_back,
      LAG(employee_cost) OVER w AS employee_cost_prev_yr,
      LAG(employee_cost, 3) OVER w AS employee_cost_3y_back,
      LAG(employee_cost, 5) OVER w AS employee_cost_5y_back,
      LAG(other_manufacturing_expenses)
        OVER w AS other_manufacturing_expenses_prev_yr,
      LAG(other_manufacturing_expenses, 3)
        OVER w AS other_manufacturing_expenses_3y_back,
      LAG(other_manufacturing_expenses, 5)
        OVER w AS other_manufacturing_expenses_5y_back,
      LAG(general_and_administration_expenses)
        OVER w AS general_and_administration_expenses_prev_yr,
      LAG(general_and_administration_expenses, 3)
        OVER w AS general_and_administration_expenses_3y_back,
      LAG(general_and_administration_expenses, 5)
        OVER w AS general_and_administration_expenses_5y_back,
      LAG(selling_and_distribution_expenses)
        OVER w AS selling_and_distribution_expenses_prev_yr,
      LAG(selling_and_distribution_expenses, 3)
        OVER w AS selling_and_distribution_expenses_3y_back,
      LAG(selling_and_distribution_expenses, 5)
        OVER w AS selling_and_distribution_expenses_5y_back,
      LAG(miscellaneous_expenses) OVER w AS miscellaneous_expenses_prev_yr,
      LAG(miscellaneous_expenses, 3) OVER w AS miscellaneous_expenses_3y_back,
      LAG(miscellaneous_expenses, 5) OVER w AS miscellaneous_expenses_5y_back,
      LAG(total_expenditure) OVER w AS total_expenditure_prev_yr,
      LAG(total_expenditure, 3) OVER w AS total_expenditure_3y_back,
      LAG(total_expenditure, 5) OVER w AS total_expenditure_5y_back,
      LAG(interest) OVER w AS interest_prev_yr,
      LAG(interest, 3) OVER w AS interest_3y_back,
      LAG(interest, 5) OVER w AS interest_5y_back,
      LAG(depreciation) OVER w AS depreciation_prev_yr,
      LAG(depreciation, 3) OVER w AS depreciation_3y_back,
      LAG(depreciation, 5) OVER w AS depreciation_5y_back
    FROM silverzone.combined_profit_and_loss_expenditure_quarterly_merged
    WINDOW w AS (PARTITION BY company_id, flag ORDER BY yyyymm)
  )
SELECT
  company_id,
  company_name,
  sector,
  subsector,
  flag,
  yyyymm,
  value_basis,
  prev_yyyymm,
  yyyymm_3y_back,
  yyyymm_5y_back,
  increase_decrease_in_stock,
  increase_decrease_in_stock_prev_yr,
  (increase_decrease_in_stock - increase_decrease_in_stock_prev_yr)
    / ABS(NULLIF(increase_decrease_in_stock_prev_yr, 0))
    * 100
    AS increase_decrease_in_stock_yoy_pct,
  increase_decrease_in_stock_3y_back,
  IF(
    increase_decrease_in_stock > 0
      AND increase_decrease_in_stock_3y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        increase_decrease_in_stock / increase_decrease_in_stock_3y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS increase_decrease_in_stock_cagr_3y_pct,
  increase_decrease_in_stock_5y_back,
  IF(
    increase_decrease_in_stock > 0
      AND increase_decrease_in_stock_5y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        increase_decrease_in_stock / increase_decrease_in_stock_5y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_5y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS increase_decrease_in_stock_cagr_5y_pct,
  raw_material_consumed,
  raw_material_consumed_prev_yr,
  (raw_material_consumed - raw_material_consumed_prev_yr)
    / ABS(NULLIF(raw_material_consumed_prev_yr, 0))
    * 100
    AS raw_material_consumed_yoy_pct,
  raw_material_consumed_3y_back,
  IF(
    raw_material_consumed > 0
      AND raw_material_consumed_3y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        raw_material_consumed / raw_material_consumed_3y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS raw_material_consumed_cagr_3y_pct,
  raw_material_consumed_5y_back,
  IF(
    raw_material_consumed > 0
      AND raw_material_consumed_5y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        raw_material_consumed / raw_material_consumed_5y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS raw_material_consumed_cagr_5y_pct,
  power_fuel_cost,
  power_fuel_cost_prev_yr,
  (power_fuel_cost - power_fuel_cost_prev_yr)
    / ABS(NULLIF(power_fuel_cost_prev_yr, 0))
    * 100
    AS power_fuel_cost_yoy_pct,
  power_fuel_cost_3y_back,
  IF(
    power_fuel_cost > 0
      AND power_fuel_cost_3y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        power_fuel_cost / power_fuel_cost_3y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS power_fuel_cost_cagr_3y_pct,
  power_fuel_cost_5y_back,
  IF(
    power_fuel_cost > 0
      AND power_fuel_cost_5y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_5y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        power_fuel_cost / power_fuel_cost_5y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_5y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS power_fuel_cost_cagr_5y_pct,
  employee_cost,
  employee_cost_prev_yr,
  (employee_cost - employee_cost_prev_yr)
    / ABS(NULLIF(employee_cost_prev_yr, 0))
    * 100
    AS employee_cost_yoy_pct,
  employee_cost_3y_back,
  IF(
    employee_cost > 0
      AND employee_cost_3y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        employee_cost / employee_cost_3y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS employee_cost_cagr_3y_pct,
  employee_cost_5y_back,
  IF(
    employee_cost > 0
      AND employee_cost_5y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_5y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        employee_cost / employee_cost_5y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_5y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS employee_cost_cagr_5y_pct,
  other_manufacturing_expenses,
  other_manufacturing_expenses_prev_yr,
  (other_manufacturing_expenses - other_manufacturing_expenses_prev_yr)
    / ABS(NULLIF(other_manufacturing_expenses_prev_yr, 0))
    * 100
    AS other_manufacturing_expenses_yoy_pct,
  other_manufacturing_expenses_3y_back,
  IF(
    other_manufacturing_expenses > 0
      AND other_manufacturing_expenses_3y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        other_manufacturing_expenses / other_manufacturing_expenses_3y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS other_manufacturing_expenses_cagr_3y_pct,
  other_manufacturing_expenses_5y_back,
  IF(
    other_manufacturing_expenses > 0
      AND other_manufacturing_expenses_5y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        other_manufacturing_expenses / other_manufacturing_expenses_5y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS other_manufacturing_expenses_cagr_5y_pct,
  general_and_administration_expenses,
  general_and_administration_expenses_prev_yr,
  (
    general_and_administration_expenses
    - general_and_administration_expenses_prev_yr)
    / ABS(NULLIF(general_and_administration_expenses_prev_yr, 0)) * 100
    AS general_and_administration_expenses_yoy_pct,
  general_and_administration_expenses_3y_back,
  IF(
    general_and_administration_expenses > 0
      AND general_and_administration_expenses_3y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        general_and_administration_expenses
          / general_and_administration_expenses_3y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS general_and_administration_expenses_cagr_3y_pct,
  general_and_administration_expenses_5y_back,
  IF(
    general_and_administration_expenses > 0
      AND general_and_administration_expenses_5y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_5y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        general_and_administration_expenses
          / general_and_administration_expenses_5y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_5y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS general_and_administration_expenses_cagr_5y_pct,
  selling_and_distribution_expenses,
  selling_and_distribution_expenses_prev_yr,
  (
    selling_and_distribution_expenses
    - selling_and_distribution_expenses_prev_yr)
    / ABS(NULLIF(selling_and_distribution_expenses_prev_yr, 0)) * 100
    AS selling_and_distribution_expenses_yoy_pct,
  selling_and_distribution_expenses_3y_back,
  IF(
    selling_and_distribution_expenses > 0
      AND selling_and_distribution_expenses_3y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        selling_and_distribution_expenses
          / selling_and_distribution_expenses_3y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS selling_and_distribution_expenses_cagr_3y_pct,
  selling_and_distribution_expenses_5y_back,
  IF(
    selling_and_distribution_expenses > 0
      AND selling_and_distribution_expenses_5y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_5y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        selling_and_distribution_expenses
          / selling_and_distribution_expenses_5y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_5y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS selling_and_distribution_expenses_cagr_5y_pct,
  miscellaneous_expenses,
  miscellaneous_expenses_prev_yr,
  (miscellaneous_expenses - miscellaneous_expenses_prev_yr)
    / ABS(NULLIF(miscellaneous_expenses_prev_yr, 0))
    * 100
    AS miscellaneous_expenses_yoy_pct,
  miscellaneous_expenses_3y_back,
  IF(
    miscellaneous_expenses > 0
      AND miscellaneous_expenses_3y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        miscellaneous_expenses / miscellaneous_expenses_3y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS miscellaneous_expenses_cagr_3y_pct,
  miscellaneous_expenses_5y_back,
  IF(
    miscellaneous_expenses > 0
      AND miscellaneous_expenses_5y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        miscellaneous_expenses / miscellaneous_expenses_5y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_5y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS miscellaneous_expenses_cagr_5y_pct,
  total_expenditure,
  total_expenditure_prev_yr,
  (total_expenditure - total_expenditure_prev_yr)
    / ABS(NULLIF(total_expenditure_prev_yr, 0))
    * 100
    AS total_expenditure_yoy_pct,
  total_expenditure_3y_back,
  IF(
    total_expenditure > 0
      AND total_expenditure_3y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        total_expenditure / total_expenditure_3y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS total_expenditure_cagr_3y_pct,
  total_expenditure_5y_back,
  IF(
    total_expenditure > 0
      AND total_expenditure_5y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_5y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        total_expenditure / total_expenditure_5y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_5y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS total_expenditure_cagr_5y_pct,
  interest,
  interest_prev_yr,
  (interest - interest_prev_yr) / ABS(NULLIF(interest_prev_yr, 0)) * 100
    AS interest_yoy_pct,
  interest_3y_back,
  IF(
    interest > 0
      AND interest_3y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        interest / interest_3y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS interest_cagr_3y_pct,
  interest_5y_back,
  IF(
    interest > 0
      AND interest_5y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_5y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        interest / interest_5y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_5y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS interest_cagr_5y_pct,
  depreciation,
  depreciation_prev_yr,
  (depreciation - depreciation_prev_yr)
    / ABS(NULLIF(depreciation_prev_yr, 0))
    * 100
    AS depreciation_yoy_pct,
  depreciation_3y_back,
  IF(
    depreciation > 0
      AND depreciation_3y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        depreciation / depreciation_3y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_3y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS depreciation_cagr_3y_pct,
  depreciation_5y_back,
  IF(
    depreciation > 0
      AND depreciation_5y_back > 0
      AND DATE_DIFF(
        PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
        PARSE_DATE('%Y%m', CAST(yyyymm_5y_back AS STRING)),
        MONTH)
        > 0,
    (
      POW(
        depreciation / depreciation_5y_back,
        12.0 / DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(yyyymm_5y_back AS STRING)),
          MONTH))
      - 1)
      * 100,
    NULL)
    AS depreciation_cagr_5y_pct
FROM lagged;

END
