-- Routine: silverzone.refresh_analysis_income_yearly_growth_nested
-- Source: capable-code-486208-j8.silverzone

BEGIN
-- silverzone.analysis_income_yearly_growth_nested
-- Full nested income yearly growth table.
-- Generated from silverzone.profit_and_loss_yearly_income_nested_merged schema.
-- Covers every numeric leaf under income, including children and grandchildren.
-- Each metric leaf is emitted as STRUCT(value, prev_yr, yoy_pct, value_3y_back,
-- cagr_3y_pct, value_5y_back, cagr_5y_pct).
-- Growth convention: (cur - prev) / ABS(NULLIF(prev, 0)) * 100.
-- CAGR is positive-base only and uses the actual month span between period ends.
CREATE OR REPLACE TABLE silverzone.analysis_income_yearly_growth_nested
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
    income.gross_sales.value AS gross_sales__value,
    income.gross_sales.sales AS gross_sales__sales,
    income.gross_sales.job_work_contract_receipts AS gross_sales__job_work_contract_receipts,
    income.gross_sales.processing_charges_service_income AS gross_sales__processing_charges_service_income,
    income.gross_sales.revenue_from_property_development AS gross_sales__revenue_from_property_development,
    income.gross_sales.revenue_from_wind_power_generation AS gross_sales__revenue_from_wind_power_generation,
    income.gross_sales.export_benefits AS gross_sales__export_benefits,
    income.gross_sales.sales_scrap AS gross_sales__sales_scrap,
    income.gross_sales.subsidy_grants_incentives AS gross_sales__subsidy_grants_incentives,
    income.gross_sales.profit_on_sale_of_assets_investments AS gross_sales__profit_on_sale_of_assets_investments,
    income.gross_sales.other_operational_income AS gross_sales__other_operational_income,
    income.less_inter_divisional_transfers AS less_inter_divisional_transfers,
    income.less_sales_returns AS less_sales_returns,
    income.less_excise_gst AS less_excise_gst,
    income.net_sales AS net_sales,
    income.operating_income AS operating_income,
    income.software_services_and_operating_revenues AS software_services_and_operating_revenues,
    income.sale_of_equipments_and_licenses AS sale_of_equipments_and_licenses,
    income.operating_income_net AS operating_income_net,
    income.income_from_medical_services AS income_from_medical_services,
    income.income_from_diagnostic_centre AS income_from_diagnostic_centre,
    income.pharmacy_optical_income AS pharmacy_optical_income,
    income.less_concession_free_treatment AS less_concession_free_treatment,
    income.income_from_shipbuilding_and_repairs AS income_from_shipbuilding_and_repairs,
    income.charter_income AS charter_income,
    income.freight_and_demurrage AS freight_and_demurrage,
    income.income_from_windmill_tower AS income_from_windmill_tower,
    income.subsidy_grants AS subsidy_grants,
    income.earning_from_sale_of_electrical_energy AS earning_from_sale_of_electrical_energy,
    income.less_cash_discount AS less_cash_discount,
    income.less_rebate_to_consumers AS less_rebate_to_consumers,
    income.less_consumer_benefit_account AS less_consumer_benefit_account,
    income.contracts_income AS contracts_income,
    income.transmission_epc_business AS transmission_epc_business,
    income.wheeling_and_transmission_charges_recoverable AS wheeling_and_transmission_charges_recoverable,
    income.electronic_products AS electronic_products,
    income.service_income AS service_income,
    income.sale_of_development_rights AS sale_of_development_rights,
    income.development_charges AS development_charges,
    income.income_from_investment_in_properties AS income_from_investment_in_properties,
    income.rooms_restaurant_banquets AS rooms_restaurant_banquets,
    income.communication_services AS communication_services,
    income.food_and_beverages AS food_and_beverages,
    income.telecommunication_services AS telecommunication_services,
    income.broadcasting_revenue AS broadcasting_revenue,
    income.advertising_revenue AS advertising_revenue,
    income.license_income AS license_income,
    income.subscription_income AS subscription_income,
    income.income_from_content_event_shows_films AS income_from_content_event_shows_films
  FROM silverzone.profit_and_loss_yearly_income_nested_merged
),
lagged AS (
  SELECT
    *,
    LAG(yyyymm) OVER w AS prev_yyyymm,
    LAG(yyyymm, 3) OVER w AS yyyymm_3y_back,
    LAG(yyyymm, 5) OVER w AS yyyymm_5y_back,
    LAG(gross_sales__value) OVER w AS gross_sales__value_prev_yr,
    LAG(gross_sales__value, 3) OVER w AS gross_sales__value_3y_back,
    LAG(gross_sales__value, 5) OVER w AS gross_sales__value_5y_back,
    LAG(gross_sales__sales) OVER w AS gross_sales__sales_prev_yr,
    LAG(gross_sales__sales, 3) OVER w AS gross_sales__sales_3y_back,
    LAG(gross_sales__sales, 5) OVER w AS gross_sales__sales_5y_back,
    LAG(gross_sales__job_work_contract_receipts) OVER w AS gross_sales__job_work_contract_receipts_prev_yr,
    LAG(gross_sales__job_work_contract_receipts, 3) OVER w AS gross_sales__job_work_contract_receipts_3y_back,
    LAG(gross_sales__job_work_contract_receipts, 5) OVER w AS gross_sales__job_work_contract_receipts_5y_back,
    LAG(gross_sales__processing_charges_service_income) OVER w AS gross_sales__processing_charges_service_income_prev_yr,
    LAG(gross_sales__processing_charges_service_income, 3) OVER w AS gross_sales__processing_charges_service_income_3y_back,
    LAG(gross_sales__processing_charges_service_income, 5) OVER w AS gross_sales__processing_charges_service_income_5y_back,
    LAG(gross_sales__revenue_from_property_development) OVER w AS gross_sales__revenue_from_property_development_prev_yr,
    LAG(gross_sales__revenue_from_property_development, 3) OVER w AS gross_sales__revenue_from_property_development_3y_back,
    LAG(gross_sales__revenue_from_property_development, 5) OVER w AS gross_sales__revenue_from_property_development_5y_back,
    LAG(gross_sales__revenue_from_wind_power_generation) OVER w AS gross_sales__revenue_from_wind_power_generation_prev_yr,
    LAG(gross_sales__revenue_from_wind_power_generation, 3) OVER w AS gross_sales__revenue_from_wind_power_generation_3y_back,
    LAG(gross_sales__revenue_from_wind_power_generation, 5) OVER w AS gross_sales__revenue_from_wind_power_generation_5y_back,
    LAG(gross_sales__export_benefits) OVER w AS gross_sales__export_benefits_prev_yr,
    LAG(gross_sales__export_benefits, 3) OVER w AS gross_sales__export_benefits_3y_back,
    LAG(gross_sales__export_benefits, 5) OVER w AS gross_sales__export_benefits_5y_back,
    LAG(gross_sales__sales_scrap) OVER w AS gross_sales__sales_scrap_prev_yr,
    LAG(gross_sales__sales_scrap, 3) OVER w AS gross_sales__sales_scrap_3y_back,
    LAG(gross_sales__sales_scrap, 5) OVER w AS gross_sales__sales_scrap_5y_back,
    LAG(gross_sales__subsidy_grants_incentives) OVER w AS gross_sales__subsidy_grants_incentives_prev_yr,
    LAG(gross_sales__subsidy_grants_incentives, 3) OVER w AS gross_sales__subsidy_grants_incentives_3y_back,
    LAG(gross_sales__subsidy_grants_incentives, 5) OVER w AS gross_sales__subsidy_grants_incentives_5y_back,
    LAG(gross_sales__profit_on_sale_of_assets_investments) OVER w AS gross_sales__profit_on_sale_of_assets_investments_prev_yr,
    LAG(gross_sales__profit_on_sale_of_assets_investments, 3) OVER w AS gross_sales__profit_on_sale_of_assets_investments_3y_back,
    LAG(gross_sales__profit_on_sale_of_assets_investments, 5) OVER w AS gross_sales__profit_on_sale_of_assets_investments_5y_back,
    LAG(gross_sales__other_operational_income) OVER w AS gross_sales__other_operational_income_prev_yr,
    LAG(gross_sales__other_operational_income, 3) OVER w AS gross_sales__other_operational_income_3y_back,
    LAG(gross_sales__other_operational_income, 5) OVER w AS gross_sales__other_operational_income_5y_back,
    LAG(less_inter_divisional_transfers) OVER w AS less_inter_divisional_transfers_prev_yr,
    LAG(less_inter_divisional_transfers, 3) OVER w AS less_inter_divisional_transfers_3y_back,
    LAG(less_inter_divisional_transfers, 5) OVER w AS less_inter_divisional_transfers_5y_back,
    LAG(less_sales_returns) OVER w AS less_sales_returns_prev_yr,
    LAG(less_sales_returns, 3) OVER w AS less_sales_returns_3y_back,
    LAG(less_sales_returns, 5) OVER w AS less_sales_returns_5y_back,
    LAG(less_excise_gst) OVER w AS less_excise_gst_prev_yr,
    LAG(less_excise_gst, 3) OVER w AS less_excise_gst_3y_back,
    LAG(less_excise_gst, 5) OVER w AS less_excise_gst_5y_back,
    LAG(net_sales) OVER w AS net_sales_prev_yr,
    LAG(net_sales, 3) OVER w AS net_sales_3y_back,
    LAG(net_sales, 5) OVER w AS net_sales_5y_back,
    LAG(operating_income) OVER w AS operating_income_prev_yr,
    LAG(operating_income, 3) OVER w AS operating_income_3y_back,
    LAG(operating_income, 5) OVER w AS operating_income_5y_back,
    LAG(software_services_and_operating_revenues) OVER w AS software_services_and_operating_revenues_prev_yr,
    LAG(software_services_and_operating_revenues, 3) OVER w AS software_services_and_operating_revenues_3y_back,
    LAG(software_services_and_operating_revenues, 5) OVER w AS software_services_and_operating_revenues_5y_back,
    LAG(sale_of_equipments_and_licenses) OVER w AS sale_of_equipments_and_licenses_prev_yr,
    LAG(sale_of_equipments_and_licenses, 3) OVER w AS sale_of_equipments_and_licenses_3y_back,
    LAG(sale_of_equipments_and_licenses, 5) OVER w AS sale_of_equipments_and_licenses_5y_back,
    LAG(operating_income_net) OVER w AS operating_income_net_prev_yr,
    LAG(operating_income_net, 3) OVER w AS operating_income_net_3y_back,
    LAG(operating_income_net, 5) OVER w AS operating_income_net_5y_back,
    LAG(income_from_medical_services) OVER w AS income_from_medical_services_prev_yr,
    LAG(income_from_medical_services, 3) OVER w AS income_from_medical_services_3y_back,
    LAG(income_from_medical_services, 5) OVER w AS income_from_medical_services_5y_back,
    LAG(income_from_diagnostic_centre) OVER w AS income_from_diagnostic_centre_prev_yr,
    LAG(income_from_diagnostic_centre, 3) OVER w AS income_from_diagnostic_centre_3y_back,
    LAG(income_from_diagnostic_centre, 5) OVER w AS income_from_diagnostic_centre_5y_back,
    LAG(pharmacy_optical_income) OVER w AS pharmacy_optical_income_prev_yr,
    LAG(pharmacy_optical_income, 3) OVER w AS pharmacy_optical_income_3y_back,
    LAG(pharmacy_optical_income, 5) OVER w AS pharmacy_optical_income_5y_back,
    LAG(less_concession_free_treatment) OVER w AS less_concession_free_treatment_prev_yr,
    LAG(less_concession_free_treatment, 3) OVER w AS less_concession_free_treatment_3y_back,
    LAG(less_concession_free_treatment, 5) OVER w AS less_concession_free_treatment_5y_back,
    LAG(income_from_shipbuilding_and_repairs) OVER w AS income_from_shipbuilding_and_repairs_prev_yr,
    LAG(income_from_shipbuilding_and_repairs, 3) OVER w AS income_from_shipbuilding_and_repairs_3y_back,
    LAG(income_from_shipbuilding_and_repairs, 5) OVER w AS income_from_shipbuilding_and_repairs_5y_back,
    LAG(charter_income) OVER w AS charter_income_prev_yr,
    LAG(charter_income, 3) OVER w AS charter_income_3y_back,
    LAG(charter_income, 5) OVER w AS charter_income_5y_back,
    LAG(freight_and_demurrage) OVER w AS freight_and_demurrage_prev_yr,
    LAG(freight_and_demurrage, 3) OVER w AS freight_and_demurrage_3y_back,
    LAG(freight_and_demurrage, 5) OVER w AS freight_and_demurrage_5y_back,
    LAG(income_from_windmill_tower) OVER w AS income_from_windmill_tower_prev_yr,
    LAG(income_from_windmill_tower, 3) OVER w AS income_from_windmill_tower_3y_back,
    LAG(income_from_windmill_tower, 5) OVER w AS income_from_windmill_tower_5y_back,
    LAG(subsidy_grants) OVER w AS subsidy_grants_prev_yr,
    LAG(subsidy_grants, 3) OVER w AS subsidy_grants_3y_back,
    LAG(subsidy_grants, 5) OVER w AS subsidy_grants_5y_back,
    LAG(earning_from_sale_of_electrical_energy) OVER w AS earning_from_sale_of_electrical_energy_prev_yr,
    LAG(earning_from_sale_of_electrical_energy, 3) OVER w AS earning_from_sale_of_electrical_energy_3y_back,
    LAG(earning_from_sale_of_electrical_energy, 5) OVER w AS earning_from_sale_of_electrical_energy_5y_back,
    LAG(less_cash_discount) OVER w AS less_cash_discount_prev_yr,
    LAG(less_cash_discount, 3) OVER w AS less_cash_discount_3y_back,
    LAG(less_cash_discount, 5) OVER w AS less_cash_discount_5y_back,
    LAG(less_rebate_to_consumers) OVER w AS less_rebate_to_consumers_prev_yr,
    LAG(less_rebate_to_consumers, 3) OVER w AS less_rebate_to_consumers_3y_back,
    LAG(less_rebate_to_consumers, 5) OVER w AS less_rebate_to_consumers_5y_back,
    LAG(less_consumer_benefit_account) OVER w AS less_consumer_benefit_account_prev_yr,
    LAG(less_consumer_benefit_account, 3) OVER w AS less_consumer_benefit_account_3y_back,
    LAG(less_consumer_benefit_account, 5) OVER w AS less_consumer_benefit_account_5y_back,
    LAG(contracts_income) OVER w AS contracts_income_prev_yr,
    LAG(contracts_income, 3) OVER w AS contracts_income_3y_back,
    LAG(contracts_income, 5) OVER w AS contracts_income_5y_back,
    LAG(transmission_epc_business) OVER w AS transmission_epc_business_prev_yr,
    LAG(transmission_epc_business, 3) OVER w AS transmission_epc_business_3y_back,
    LAG(transmission_epc_business, 5) OVER w AS transmission_epc_business_5y_back,
    LAG(wheeling_and_transmission_charges_recoverable) OVER w AS wheeling_and_transmission_charges_recoverable_prev_yr,
    LAG(wheeling_and_transmission_charges_recoverable, 3) OVER w AS wheeling_and_transmission_charges_recoverable_3y_back,
    LAG(wheeling_and_transmission_charges_recoverable, 5) OVER w AS wheeling_and_transmission_charges_recoverable_5y_back,
    LAG(electronic_products) OVER w AS electronic_products_prev_yr,
    LAG(electronic_products, 3) OVER w AS electronic_products_3y_back,
    LAG(electronic_products, 5) OVER w AS electronic_products_5y_back,
    LAG(service_income) OVER w AS service_income_prev_yr,
    LAG(service_income, 3) OVER w AS service_income_3y_back,
    LAG(service_income, 5) OVER w AS service_income_5y_back,
    LAG(sale_of_development_rights) OVER w AS sale_of_development_rights_prev_yr,
    LAG(sale_of_development_rights, 3) OVER w AS sale_of_development_rights_3y_back,
    LAG(sale_of_development_rights, 5) OVER w AS sale_of_development_rights_5y_back,
    LAG(development_charges) OVER w AS development_charges_prev_yr,
    LAG(development_charges, 3) OVER w AS development_charges_3y_back,
    LAG(development_charges, 5) OVER w AS development_charges_5y_back,
    LAG(income_from_investment_in_properties) OVER w AS income_from_investment_in_properties_prev_yr,
    LAG(income_from_investment_in_properties, 3) OVER w AS income_from_investment_in_properties_3y_back,
    LAG(income_from_investment_in_properties, 5) OVER w AS income_from_investment_in_properties_5y_back,
    LAG(rooms_restaurant_banquets) OVER w AS rooms_restaurant_banquets_prev_yr,
    LAG(rooms_restaurant_banquets, 3) OVER w AS rooms_restaurant_banquets_3y_back,
    LAG(rooms_restaurant_banquets, 5) OVER w AS rooms_restaurant_banquets_5y_back,
    LAG(communication_services) OVER w AS communication_services_prev_yr,
    LAG(communication_services, 3) OVER w AS communication_services_3y_back,
    LAG(communication_services, 5) OVER w AS communication_services_5y_back,
    LAG(food_and_beverages) OVER w AS food_and_beverages_prev_yr,
    LAG(food_and_beverages, 3) OVER w AS food_and_beverages_3y_back,
    LAG(food_and_beverages, 5) OVER w AS food_and_beverages_5y_back,
    LAG(telecommunication_services) OVER w AS telecommunication_services_prev_yr,
    LAG(telecommunication_services, 3) OVER w AS telecommunication_services_3y_back,
    LAG(telecommunication_services, 5) OVER w AS telecommunication_services_5y_back,
    LAG(broadcasting_revenue) OVER w AS broadcasting_revenue_prev_yr,
    LAG(broadcasting_revenue, 3) OVER w AS broadcasting_revenue_3y_back,
    LAG(broadcasting_revenue, 5) OVER w AS broadcasting_revenue_5y_back,
    LAG(advertising_revenue) OVER w AS advertising_revenue_prev_yr,
    LAG(advertising_revenue, 3) OVER w AS advertising_revenue_3y_back,
    LAG(advertising_revenue, 5) OVER w AS advertising_revenue_5y_back,
    LAG(license_income) OVER w AS license_income_prev_yr,
    LAG(license_income, 3) OVER w AS license_income_3y_back,
    LAG(license_income, 5) OVER w AS license_income_5y_back,
    LAG(subscription_income) OVER w AS subscription_income_prev_yr,
    LAG(subscription_income, 3) OVER w AS subscription_income_3y_back,
    LAG(subscription_income, 5) OVER w AS subscription_income_5y_back,
    LAG(income_from_content_event_shows_films) OVER w AS income_from_content_event_shows_films_prev_yr,
    LAG(income_from_content_event_shows_films, 3) OVER w AS income_from_content_event_shows_films_3y_back,
    LAG(income_from_content_event_shows_films, 5) OVER w AS income_from_content_event_shows_films_5y_back
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
                l.gross_sales__value AS value,
                l.gross_sales__value_prev_yr AS prev_yr,
                (l.gross_sales__value - l.gross_sales__value_prev_yr) / ABS(NULLIF(l.gross_sales__value_prev_yr, 0)) * 100 AS yoy_pct,
                l.gross_sales__value_3y_back AS value_3y_back,
                IF(
                  l.gross_sales__value > 0
                    AND l.gross_sales__value_3y_back > 0
                    AND DATE_DIFF(
                      PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                      PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                      MONTH)
                      > 0,
                  (
                    POW(
                      l.gross_sales__value / l.gross_sales__value_3y_back,
                      12.0 / DATE_DIFF(
                        PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                        PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                        MONTH))
                    - 1)
                    * 100,
                  NULL) AS cagr_3y_pct,
                l.gross_sales__value_5y_back AS value_5y_back,
                IF(
                  l.gross_sales__value > 0
                    AND l.gross_sales__value_5y_back > 0
                    AND DATE_DIFF(
                      PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                      PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                      MONTH)
                      > 0,
                  (
                    POW(
                      l.gross_sales__value / l.gross_sales__value_5y_back,
                      12.0 / DATE_DIFF(
                        PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                        PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                        MONTH))
                    - 1)
                    * 100,
                  NULL) AS cagr_5y_pct
              ) AS value,
              STRUCT(
                l.gross_sales__sales AS value,
                l.gross_sales__sales_prev_yr AS prev_yr,
                (l.gross_sales__sales - l.gross_sales__sales_prev_yr) / ABS(NULLIF(l.gross_sales__sales_prev_yr, 0)) * 100 AS yoy_pct,
                l.gross_sales__sales_3y_back AS value_3y_back,
                IF(
                  l.gross_sales__sales > 0
                    AND l.gross_sales__sales_3y_back > 0
                    AND DATE_DIFF(
                      PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                      PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                      MONTH)
                      > 0,
                  (
                    POW(
                      l.gross_sales__sales / l.gross_sales__sales_3y_back,
                      12.0 / DATE_DIFF(
                        PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                        PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                        MONTH))
                    - 1)
                    * 100,
                  NULL) AS cagr_3y_pct,
                l.gross_sales__sales_5y_back AS value_5y_back,
                IF(
                  l.gross_sales__sales > 0
                    AND l.gross_sales__sales_5y_back > 0
                    AND DATE_DIFF(
                      PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                      PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                      MONTH)
                      > 0,
                  (
                    POW(
                      l.gross_sales__sales / l.gross_sales__sales_5y_back,
                      12.0 / DATE_DIFF(
                        PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                        PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                        MONTH))
                    - 1)
                    * 100,
                  NULL) AS cagr_5y_pct
              ) AS sales,
              STRUCT(
                l.gross_sales__job_work_contract_receipts AS value,
                l.gross_sales__job_work_contract_receipts_prev_yr AS prev_yr,
                (l.gross_sales__job_work_contract_receipts - l.gross_sales__job_work_contract_receipts_prev_yr) / ABS(NULLIF(l.gross_sales__job_work_contract_receipts_prev_yr, 0)) * 100 AS yoy_pct,
                l.gross_sales__job_work_contract_receipts_3y_back AS value_3y_back,
                IF(
                  l.gross_sales__job_work_contract_receipts > 0
                    AND l.gross_sales__job_work_contract_receipts_3y_back > 0
                    AND DATE_DIFF(
                      PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                      PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                      MONTH)
                      > 0,
                  (
                    POW(
                      l.gross_sales__job_work_contract_receipts / l.gross_sales__job_work_contract_receipts_3y_back,
                      12.0 / DATE_DIFF(
                        PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                        PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                        MONTH))
                    - 1)
                    * 100,
                  NULL) AS cagr_3y_pct,
                l.gross_sales__job_work_contract_receipts_5y_back AS value_5y_back,
                IF(
                  l.gross_sales__job_work_contract_receipts > 0
                    AND l.gross_sales__job_work_contract_receipts_5y_back > 0
                    AND DATE_DIFF(
                      PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                      PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                      MONTH)
                      > 0,
                  (
                    POW(
                      l.gross_sales__job_work_contract_receipts / l.gross_sales__job_work_contract_receipts_5y_back,
                      12.0 / DATE_DIFF(
                        PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                        PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                        MONTH))
                    - 1)
                    * 100,
                  NULL) AS cagr_5y_pct
              ) AS job_work_contract_receipts,
              STRUCT(
                l.gross_sales__processing_charges_service_income AS value,
                l.gross_sales__processing_charges_service_income_prev_yr AS prev_yr,
                (l.gross_sales__processing_charges_service_income - l.gross_sales__processing_charges_service_income_prev_yr) / ABS(NULLIF(l.gross_sales__processing_charges_service_income_prev_yr, 0)) * 100 AS yoy_pct,
                l.gross_sales__processing_charges_service_income_3y_back AS value_3y_back,
                IF(
                  l.gross_sales__processing_charges_service_income > 0
                    AND l.gross_sales__processing_charges_service_income_3y_back > 0
                    AND DATE_DIFF(
                      PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                      PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                      MONTH)
                      > 0,
                  (
                    POW(
                      l.gross_sales__processing_charges_service_income / l.gross_sales__processing_charges_service_income_3y_back,
                      12.0 / DATE_DIFF(
                        PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                        PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                        MONTH))
                    - 1)
                    * 100,
                  NULL) AS cagr_3y_pct,
                l.gross_sales__processing_charges_service_income_5y_back AS value_5y_back,
                IF(
                  l.gross_sales__processing_charges_service_income > 0
                    AND l.gross_sales__processing_charges_service_income_5y_back > 0
                    AND DATE_DIFF(
                      PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                      PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                      MONTH)
                      > 0,
                  (
                    POW(
                      l.gross_sales__processing_charges_service_income / l.gross_sales__processing_charges_service_income_5y_back,
                      12.0 / DATE_DIFF(
                        PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                        PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                        MONTH))
                    - 1)
                    * 100,
                  NULL) AS cagr_5y_pct
              ) AS processing_charges_service_income,
              STRUCT(
                l.gross_sales__revenue_from_property_development AS value,
                l.gross_sales__revenue_from_property_development_prev_yr AS prev_yr,
                (l.gross_sales__revenue_from_property_development - l.gross_sales__revenue_from_property_development_prev_yr) / ABS(NULLIF(l.gross_sales__revenue_from_property_development_prev_yr, 0)) * 100 AS yoy_pct,
                l.gross_sales__revenue_from_property_development_3y_back AS value_3y_back,
                IF(
                  l.gross_sales__revenue_from_property_development > 0
                    AND l.gross_sales__revenue_from_property_development_3y_back > 0
                    AND DATE_DIFF(
                      PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                      PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                      MONTH)
                      > 0,
                  (
                    POW(
                      l.gross_sales__revenue_from_property_development / l.gross_sales__revenue_from_property_development_3y_back,
                      12.0 / DATE_DIFF(
                        PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                        PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                        MONTH))
                    - 1)
                    * 100,
                  NULL) AS cagr_3y_pct,
                l.gross_sales__revenue_from_property_development_5y_back AS value_5y_back,
                IF(
                  l.gross_sales__revenue_from_property_development > 0
                    AND l.gross_sales__revenue_from_property_development_5y_back > 0
                    AND DATE_DIFF(
                      PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                      PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                      MONTH)
                      > 0,
                  (
                    POW(
                      l.gross_sales__revenue_from_property_development / l.gross_sales__revenue_from_property_development_5y_back,
                      12.0 / DATE_DIFF(
                        PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                        PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                        MONTH))
                    - 1)
                    * 100,
                  NULL) AS cagr_5y_pct
              ) AS revenue_from_property_development,
              STRUCT(
                l.gross_sales__revenue_from_wind_power_generation AS value,
                l.gross_sales__revenue_from_wind_power_generation_prev_yr AS prev_yr,
                (l.gross_sales__revenue_from_wind_power_generation - l.gross_sales__revenue_from_wind_power_generation_prev_yr) / ABS(NULLIF(l.gross_sales__revenue_from_wind_power_generation_prev_yr, 0)) * 100 AS yoy_pct,
                l.gross_sales__revenue_from_wind_power_generation_3y_back AS value_3y_back,
                IF(
                  l.gross_sales__revenue_from_wind_power_generation > 0
                    AND l.gross_sales__revenue_from_wind_power_generation_3y_back > 0
                    AND DATE_DIFF(
                      PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                      PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                      MONTH)
                      > 0,
                  (
                    POW(
                      l.gross_sales__revenue_from_wind_power_generation / l.gross_sales__revenue_from_wind_power_generation_3y_back,
                      12.0 / DATE_DIFF(
                        PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                        PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                        MONTH))
                    - 1)
                    * 100,
                  NULL) AS cagr_3y_pct,
                l.gross_sales__revenue_from_wind_power_generation_5y_back AS value_5y_back,
                IF(
                  l.gross_sales__revenue_from_wind_power_generation > 0
                    AND l.gross_sales__revenue_from_wind_power_generation_5y_back > 0
                    AND DATE_DIFF(
                      PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                      PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                      MONTH)
                      > 0,
                  (
                    POW(
                      l.gross_sales__revenue_from_wind_power_generation / l.gross_sales__revenue_from_wind_power_generation_5y_back,
                      12.0 / DATE_DIFF(
                        PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                        PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                        MONTH))
                    - 1)
                    * 100,
                  NULL) AS cagr_5y_pct
              ) AS revenue_from_wind_power_generation,
              STRUCT(
                l.gross_sales__export_benefits AS value,
                l.gross_sales__export_benefits_prev_yr AS prev_yr,
                (l.gross_sales__export_benefits - l.gross_sales__export_benefits_prev_yr) / ABS(NULLIF(l.gross_sales__export_benefits_prev_yr, 0)) * 100 AS yoy_pct,
                l.gross_sales__export_benefits_3y_back AS value_3y_back,
                IF(
                  l.gross_sales__export_benefits > 0
                    AND l.gross_sales__export_benefits_3y_back > 0
                    AND DATE_DIFF(
                      PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                      PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                      MONTH)
                      > 0,
                  (
                    POW(
                      l.gross_sales__export_benefits / l.gross_sales__export_benefits_3y_back,
                      12.0 / DATE_DIFF(
                        PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                        PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                        MONTH))
                    - 1)
                    * 100,
                  NULL) AS cagr_3y_pct,
                l.gross_sales__export_benefits_5y_back AS value_5y_back,
                IF(
                  l.gross_sales__export_benefits > 0
                    AND l.gross_sales__export_benefits_5y_back > 0
                    AND DATE_DIFF(
                      PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                      PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                      MONTH)
                      > 0,
                  (
                    POW(
                      l.gross_sales__export_benefits / l.gross_sales__export_benefits_5y_back,
                      12.0 / DATE_DIFF(
                        PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                        PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                        MONTH))
                    - 1)
                    * 100,
                  NULL) AS cagr_5y_pct
              ) AS export_benefits,
              STRUCT(
                l.gross_sales__sales_scrap AS value,
                l.gross_sales__sales_scrap_prev_yr AS prev_yr,
                (l.gross_sales__sales_scrap - l.gross_sales__sales_scrap_prev_yr) / ABS(NULLIF(l.gross_sales__sales_scrap_prev_yr, 0)) * 100 AS yoy_pct,
                l.gross_sales__sales_scrap_3y_back AS value_3y_back,
                IF(
                  l.gross_sales__sales_scrap > 0
                    AND l.gross_sales__sales_scrap_3y_back > 0
                    AND DATE_DIFF(
                      PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                      PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                      MONTH)
                      > 0,
                  (
                    POW(
                      l.gross_sales__sales_scrap / l.gross_sales__sales_scrap_3y_back,
                      12.0 / DATE_DIFF(
                        PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                        PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                        MONTH))
                    - 1)
                    * 100,
                  NULL) AS cagr_3y_pct,
                l.gross_sales__sales_scrap_5y_back AS value_5y_back,
                IF(
                  l.gross_sales__sales_scrap > 0
                    AND l.gross_sales__sales_scrap_5y_back > 0
                    AND DATE_DIFF(
                      PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                      PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                      MONTH)
                      > 0,
                  (
                    POW(
                      l.gross_sales__sales_scrap / l.gross_sales__sales_scrap_5y_back,
                      12.0 / DATE_DIFF(
                        PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                        PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                        MONTH))
                    - 1)
                    * 100,
                  NULL) AS cagr_5y_pct
              ) AS sales_scrap,
              STRUCT(
                l.gross_sales__subsidy_grants_incentives AS value,
                l.gross_sales__subsidy_grants_incentives_prev_yr AS prev_yr,
                (l.gross_sales__subsidy_grants_incentives - l.gross_sales__subsidy_grants_incentives_prev_yr) / ABS(NULLIF(l.gross_sales__subsidy_grants_incentives_prev_yr, 0)) * 100 AS yoy_pct,
                l.gross_sales__subsidy_grants_incentives_3y_back AS value_3y_back,
                IF(
                  l.gross_sales__subsidy_grants_incentives > 0
                    AND l.gross_sales__subsidy_grants_incentives_3y_back > 0
                    AND DATE_DIFF(
                      PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                      PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                      MONTH)
                      > 0,
                  (
                    POW(
                      l.gross_sales__subsidy_grants_incentives / l.gross_sales__subsidy_grants_incentives_3y_back,
                      12.0 / DATE_DIFF(
                        PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                        PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                        MONTH))
                    - 1)
                    * 100,
                  NULL) AS cagr_3y_pct,
                l.gross_sales__subsidy_grants_incentives_5y_back AS value_5y_back,
                IF(
                  l.gross_sales__subsidy_grants_incentives > 0
                    AND l.gross_sales__subsidy_grants_incentives_5y_back > 0
                    AND DATE_DIFF(
                      PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                      PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                      MONTH)
                      > 0,
                  (
                    POW(
                      l.gross_sales__subsidy_grants_incentives / l.gross_sales__subsidy_grants_incentives_5y_back,
                      12.0 / DATE_DIFF(
                        PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                        PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                        MONTH))
                    - 1)
                    * 100,
                  NULL) AS cagr_5y_pct
              ) AS subsidy_grants_incentives,
              STRUCT(
                l.gross_sales__profit_on_sale_of_assets_investments AS value,
                l.gross_sales__profit_on_sale_of_assets_investments_prev_yr AS prev_yr,
                (l.gross_sales__profit_on_sale_of_assets_investments - l.gross_sales__profit_on_sale_of_assets_investments_prev_yr) / ABS(NULLIF(l.gross_sales__profit_on_sale_of_assets_investments_prev_yr, 0)) * 100 AS yoy_pct,
                l.gross_sales__profit_on_sale_of_assets_investments_3y_back AS value_3y_back,
                IF(
                  l.gross_sales__profit_on_sale_of_assets_investments > 0
                    AND l.gross_sales__profit_on_sale_of_assets_investments_3y_back > 0
                    AND DATE_DIFF(
                      PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                      PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                      MONTH)
                      > 0,
                  (
                    POW(
                      l.gross_sales__profit_on_sale_of_assets_investments / l.gross_sales__profit_on_sale_of_assets_investments_3y_back,
                      12.0 / DATE_DIFF(
                        PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                        PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                        MONTH))
                    - 1)
                    * 100,
                  NULL) AS cagr_3y_pct,
                l.gross_sales__profit_on_sale_of_assets_investments_5y_back AS value_5y_back,
                IF(
                  l.gross_sales__profit_on_sale_of_assets_investments > 0
                    AND l.gross_sales__profit_on_sale_of_assets_investments_5y_back > 0
                    AND DATE_DIFF(
                      PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                      PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                      MONTH)
                      > 0,
                  (
                    POW(
                      l.gross_sales__profit_on_sale_of_assets_investments / l.gross_sales__profit_on_sale_of_assets_investments_5y_back,
                      12.0 / DATE_DIFF(
                        PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                        PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                        MONTH))
                    - 1)
                    * 100,
                  NULL) AS cagr_5y_pct
              ) AS profit_on_sale_of_assets_investments,
              STRUCT(
                l.gross_sales__other_operational_income AS value,
                l.gross_sales__other_operational_income_prev_yr AS prev_yr,
                (l.gross_sales__other_operational_income - l.gross_sales__other_operational_income_prev_yr) / ABS(NULLIF(l.gross_sales__other_operational_income_prev_yr, 0)) * 100 AS yoy_pct,
                l.gross_sales__other_operational_income_3y_back AS value_3y_back,
                IF(
                  l.gross_sales__other_operational_income > 0
                    AND l.gross_sales__other_operational_income_3y_back > 0
                    AND DATE_DIFF(
                      PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                      PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                      MONTH)
                      > 0,
                  (
                    POW(
                      l.gross_sales__other_operational_income / l.gross_sales__other_operational_income_3y_back,
                      12.0 / DATE_DIFF(
                        PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                        PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                        MONTH))
                    - 1)
                    * 100,
                  NULL) AS cagr_3y_pct,
                l.gross_sales__other_operational_income_5y_back AS value_5y_back,
                IF(
                  l.gross_sales__other_operational_income > 0
                    AND l.gross_sales__other_operational_income_5y_back > 0
                    AND DATE_DIFF(
                      PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                      PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                      MONTH)
                      > 0,
                  (
                    POW(
                      l.gross_sales__other_operational_income / l.gross_sales__other_operational_income_5y_back,
                      12.0 / DATE_DIFF(
                        PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                        PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                        MONTH))
                    - 1)
                    * 100,
                  NULL) AS cagr_5y_pct
              ) AS other_operational_income
        ) AS gross_sales,
        STRUCT(
          l.less_inter_divisional_transfers AS value,
          l.less_inter_divisional_transfers_prev_yr AS prev_yr,
          (l.less_inter_divisional_transfers - l.less_inter_divisional_transfers_prev_yr) / ABS(NULLIF(l.less_inter_divisional_transfers_prev_yr, 0)) * 100 AS yoy_pct,
          l.less_inter_divisional_transfers_3y_back AS value_3y_back,
          IF(
            l.less_inter_divisional_transfers > 0
              AND l.less_inter_divisional_transfers_3y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.less_inter_divisional_transfers / l.less_inter_divisional_transfers_3y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_3y_pct,
          l.less_inter_divisional_transfers_5y_back AS value_5y_back,
          IF(
            l.less_inter_divisional_transfers > 0
              AND l.less_inter_divisional_transfers_5y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.less_inter_divisional_transfers / l.less_inter_divisional_transfers_5y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_5y_pct
        ) AS less_inter_divisional_transfers,
        STRUCT(
          l.less_sales_returns AS value,
          l.less_sales_returns_prev_yr AS prev_yr,
          (l.less_sales_returns - l.less_sales_returns_prev_yr) / ABS(NULLIF(l.less_sales_returns_prev_yr, 0)) * 100 AS yoy_pct,
          l.less_sales_returns_3y_back AS value_3y_back,
          IF(
            l.less_sales_returns > 0
              AND l.less_sales_returns_3y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.less_sales_returns / l.less_sales_returns_3y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_3y_pct,
          l.less_sales_returns_5y_back AS value_5y_back,
          IF(
            l.less_sales_returns > 0
              AND l.less_sales_returns_5y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.less_sales_returns / l.less_sales_returns_5y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_5y_pct
        ) AS less_sales_returns,
        STRUCT(
          l.less_excise_gst AS value,
          l.less_excise_gst_prev_yr AS prev_yr,
          (l.less_excise_gst - l.less_excise_gst_prev_yr) / ABS(NULLIF(l.less_excise_gst_prev_yr, 0)) * 100 AS yoy_pct,
          l.less_excise_gst_3y_back AS value_3y_back,
          IF(
            l.less_excise_gst > 0
              AND l.less_excise_gst_3y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.less_excise_gst / l.less_excise_gst_3y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_3y_pct,
          l.less_excise_gst_5y_back AS value_5y_back,
          IF(
            l.less_excise_gst > 0
              AND l.less_excise_gst_5y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.less_excise_gst / l.less_excise_gst_5y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_5y_pct
        ) AS less_excise_gst,
        STRUCT(
          l.net_sales AS value,
          l.net_sales_prev_yr AS prev_yr,
          (l.net_sales - l.net_sales_prev_yr) / ABS(NULLIF(l.net_sales_prev_yr, 0)) * 100 AS yoy_pct,
          l.net_sales_3y_back AS value_3y_back,
          IF(
            l.net_sales > 0
              AND l.net_sales_3y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.net_sales / l.net_sales_3y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_3y_pct,
          l.net_sales_5y_back AS value_5y_back,
          IF(
            l.net_sales > 0
              AND l.net_sales_5y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.net_sales / l.net_sales_5y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_5y_pct
        ) AS net_sales,
        STRUCT(
          l.operating_income AS value,
          l.operating_income_prev_yr AS prev_yr,
          (l.operating_income - l.operating_income_prev_yr) / ABS(NULLIF(l.operating_income_prev_yr, 0)) * 100 AS yoy_pct,
          l.operating_income_3y_back AS value_3y_back,
          IF(
            l.operating_income > 0
              AND l.operating_income_3y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.operating_income / l.operating_income_3y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_3y_pct,
          l.operating_income_5y_back AS value_5y_back,
          IF(
            l.operating_income > 0
              AND l.operating_income_5y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.operating_income / l.operating_income_5y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_5y_pct
        ) AS operating_income,
        STRUCT(
          l.software_services_and_operating_revenues AS value,
          l.software_services_and_operating_revenues_prev_yr AS prev_yr,
          (l.software_services_and_operating_revenues - l.software_services_and_operating_revenues_prev_yr) / ABS(NULLIF(l.software_services_and_operating_revenues_prev_yr, 0)) * 100 AS yoy_pct,
          l.software_services_and_operating_revenues_3y_back AS value_3y_back,
          IF(
            l.software_services_and_operating_revenues > 0
              AND l.software_services_and_operating_revenues_3y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.software_services_and_operating_revenues / l.software_services_and_operating_revenues_3y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_3y_pct,
          l.software_services_and_operating_revenues_5y_back AS value_5y_back,
          IF(
            l.software_services_and_operating_revenues > 0
              AND l.software_services_and_operating_revenues_5y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.software_services_and_operating_revenues / l.software_services_and_operating_revenues_5y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_5y_pct
        ) AS software_services_and_operating_revenues,
        STRUCT(
          l.sale_of_equipments_and_licenses AS value,
          l.sale_of_equipments_and_licenses_prev_yr AS prev_yr,
          (l.sale_of_equipments_and_licenses - l.sale_of_equipments_and_licenses_prev_yr) / ABS(NULLIF(l.sale_of_equipments_and_licenses_prev_yr, 0)) * 100 AS yoy_pct,
          l.sale_of_equipments_and_licenses_3y_back AS value_3y_back,
          IF(
            l.sale_of_equipments_and_licenses > 0
              AND l.sale_of_equipments_and_licenses_3y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.sale_of_equipments_and_licenses / l.sale_of_equipments_and_licenses_3y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_3y_pct,
          l.sale_of_equipments_and_licenses_5y_back AS value_5y_back,
          IF(
            l.sale_of_equipments_and_licenses > 0
              AND l.sale_of_equipments_and_licenses_5y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.sale_of_equipments_and_licenses / l.sale_of_equipments_and_licenses_5y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_5y_pct
        ) AS sale_of_equipments_and_licenses,
        STRUCT(
          l.operating_income_net AS value,
          l.operating_income_net_prev_yr AS prev_yr,
          (l.operating_income_net - l.operating_income_net_prev_yr) / ABS(NULLIF(l.operating_income_net_prev_yr, 0)) * 100 AS yoy_pct,
          l.operating_income_net_3y_back AS value_3y_back,
          IF(
            l.operating_income_net > 0
              AND l.operating_income_net_3y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.operating_income_net / l.operating_income_net_3y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_3y_pct,
          l.operating_income_net_5y_back AS value_5y_back,
          IF(
            l.operating_income_net > 0
              AND l.operating_income_net_5y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.operating_income_net / l.operating_income_net_5y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_5y_pct
        ) AS operating_income_net,
        STRUCT(
          l.income_from_medical_services AS value,
          l.income_from_medical_services_prev_yr AS prev_yr,
          (l.income_from_medical_services - l.income_from_medical_services_prev_yr) / ABS(NULLIF(l.income_from_medical_services_prev_yr, 0)) * 100 AS yoy_pct,
          l.income_from_medical_services_3y_back AS value_3y_back,
          IF(
            l.income_from_medical_services > 0
              AND l.income_from_medical_services_3y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.income_from_medical_services / l.income_from_medical_services_3y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_3y_pct,
          l.income_from_medical_services_5y_back AS value_5y_back,
          IF(
            l.income_from_medical_services > 0
              AND l.income_from_medical_services_5y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.income_from_medical_services / l.income_from_medical_services_5y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_5y_pct
        ) AS income_from_medical_services,
        STRUCT(
          l.income_from_diagnostic_centre AS value,
          l.income_from_diagnostic_centre_prev_yr AS prev_yr,
          (l.income_from_diagnostic_centre - l.income_from_diagnostic_centre_prev_yr) / ABS(NULLIF(l.income_from_diagnostic_centre_prev_yr, 0)) * 100 AS yoy_pct,
          l.income_from_diagnostic_centre_3y_back AS value_3y_back,
          IF(
            l.income_from_diagnostic_centre > 0
              AND l.income_from_diagnostic_centre_3y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.income_from_diagnostic_centre / l.income_from_diagnostic_centre_3y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_3y_pct,
          l.income_from_diagnostic_centre_5y_back AS value_5y_back,
          IF(
            l.income_from_diagnostic_centre > 0
              AND l.income_from_diagnostic_centre_5y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.income_from_diagnostic_centre / l.income_from_diagnostic_centre_5y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_5y_pct
        ) AS income_from_diagnostic_centre,
        STRUCT(
          l.pharmacy_optical_income AS value,
          l.pharmacy_optical_income_prev_yr AS prev_yr,
          (l.pharmacy_optical_income - l.pharmacy_optical_income_prev_yr) / ABS(NULLIF(l.pharmacy_optical_income_prev_yr, 0)) * 100 AS yoy_pct,
          l.pharmacy_optical_income_3y_back AS value_3y_back,
          IF(
            l.pharmacy_optical_income > 0
              AND l.pharmacy_optical_income_3y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.pharmacy_optical_income / l.pharmacy_optical_income_3y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_3y_pct,
          l.pharmacy_optical_income_5y_back AS value_5y_back,
          IF(
            l.pharmacy_optical_income > 0
              AND l.pharmacy_optical_income_5y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.pharmacy_optical_income / l.pharmacy_optical_income_5y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_5y_pct
        ) AS pharmacy_optical_income,
        STRUCT(
          l.less_concession_free_treatment AS value,
          l.less_concession_free_treatment_prev_yr AS prev_yr,
          (l.less_concession_free_treatment - l.less_concession_free_treatment_prev_yr) / ABS(NULLIF(l.less_concession_free_treatment_prev_yr, 0)) * 100 AS yoy_pct,
          l.less_concession_free_treatment_3y_back AS value_3y_back,
          IF(
            l.less_concession_free_treatment > 0
              AND l.less_concession_free_treatment_3y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.less_concession_free_treatment / l.less_concession_free_treatment_3y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_3y_pct,
          l.less_concession_free_treatment_5y_back AS value_5y_back,
          IF(
            l.less_concession_free_treatment > 0
              AND l.less_concession_free_treatment_5y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.less_concession_free_treatment / l.less_concession_free_treatment_5y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_5y_pct
        ) AS less_concession_free_treatment,
        STRUCT(
          l.income_from_shipbuilding_and_repairs AS value,
          l.income_from_shipbuilding_and_repairs_prev_yr AS prev_yr,
          (l.income_from_shipbuilding_and_repairs - l.income_from_shipbuilding_and_repairs_prev_yr) / ABS(NULLIF(l.income_from_shipbuilding_and_repairs_prev_yr, 0)) * 100 AS yoy_pct,
          l.income_from_shipbuilding_and_repairs_3y_back AS value_3y_back,
          IF(
            l.income_from_shipbuilding_and_repairs > 0
              AND l.income_from_shipbuilding_and_repairs_3y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.income_from_shipbuilding_and_repairs / l.income_from_shipbuilding_and_repairs_3y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_3y_pct,
          l.income_from_shipbuilding_and_repairs_5y_back AS value_5y_back,
          IF(
            l.income_from_shipbuilding_and_repairs > 0
              AND l.income_from_shipbuilding_and_repairs_5y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.income_from_shipbuilding_and_repairs / l.income_from_shipbuilding_and_repairs_5y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_5y_pct
        ) AS income_from_shipbuilding_and_repairs,
        STRUCT(
          l.charter_income AS value,
          l.charter_income_prev_yr AS prev_yr,
          (l.charter_income - l.charter_income_prev_yr) / ABS(NULLIF(l.charter_income_prev_yr, 0)) * 100 AS yoy_pct,
          l.charter_income_3y_back AS value_3y_back,
          IF(
            l.charter_income > 0
              AND l.charter_income_3y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.charter_income / l.charter_income_3y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_3y_pct,
          l.charter_income_5y_back AS value_5y_back,
          IF(
            l.charter_income > 0
              AND l.charter_income_5y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.charter_income / l.charter_income_5y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_5y_pct
        ) AS charter_income,
        STRUCT(
          l.freight_and_demurrage AS value,
          l.freight_and_demurrage_prev_yr AS prev_yr,
          (l.freight_and_demurrage - l.freight_and_demurrage_prev_yr) / ABS(NULLIF(l.freight_and_demurrage_prev_yr, 0)) * 100 AS yoy_pct,
          l.freight_and_demurrage_3y_back AS value_3y_back,
          IF(
            l.freight_and_demurrage > 0
              AND l.freight_and_demurrage_3y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.freight_and_demurrage / l.freight_and_demurrage_3y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_3y_pct,
          l.freight_and_demurrage_5y_back AS value_5y_back,
          IF(
            l.freight_and_demurrage > 0
              AND l.freight_and_demurrage_5y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.freight_and_demurrage / l.freight_and_demurrage_5y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_5y_pct
        ) AS freight_and_demurrage,
        STRUCT(
          l.income_from_windmill_tower AS value,
          l.income_from_windmill_tower_prev_yr AS prev_yr,
          (l.income_from_windmill_tower - l.income_from_windmill_tower_prev_yr) / ABS(NULLIF(l.income_from_windmill_tower_prev_yr, 0)) * 100 AS yoy_pct,
          l.income_from_windmill_tower_3y_back AS value_3y_back,
          IF(
            l.income_from_windmill_tower > 0
              AND l.income_from_windmill_tower_3y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.income_from_windmill_tower / l.income_from_windmill_tower_3y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_3y_pct,
          l.income_from_windmill_tower_5y_back AS value_5y_back,
          IF(
            l.income_from_windmill_tower > 0
              AND l.income_from_windmill_tower_5y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.income_from_windmill_tower / l.income_from_windmill_tower_5y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_5y_pct
        ) AS income_from_windmill_tower,
        STRUCT(
          l.subsidy_grants AS value,
          l.subsidy_grants_prev_yr AS prev_yr,
          (l.subsidy_grants - l.subsidy_grants_prev_yr) / ABS(NULLIF(l.subsidy_grants_prev_yr, 0)) * 100 AS yoy_pct,
          l.subsidy_grants_3y_back AS value_3y_back,
          IF(
            l.subsidy_grants > 0
              AND l.subsidy_grants_3y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.subsidy_grants / l.subsidy_grants_3y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_3y_pct,
          l.subsidy_grants_5y_back AS value_5y_back,
          IF(
            l.subsidy_grants > 0
              AND l.subsidy_grants_5y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.subsidy_grants / l.subsidy_grants_5y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_5y_pct
        ) AS subsidy_grants,
        STRUCT(
          l.earning_from_sale_of_electrical_energy AS value,
          l.earning_from_sale_of_electrical_energy_prev_yr AS prev_yr,
          (l.earning_from_sale_of_electrical_energy - l.earning_from_sale_of_electrical_energy_prev_yr) / ABS(NULLIF(l.earning_from_sale_of_electrical_energy_prev_yr, 0)) * 100 AS yoy_pct,
          l.earning_from_sale_of_electrical_energy_3y_back AS value_3y_back,
          IF(
            l.earning_from_sale_of_electrical_energy > 0
              AND l.earning_from_sale_of_electrical_energy_3y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.earning_from_sale_of_electrical_energy / l.earning_from_sale_of_electrical_energy_3y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_3y_pct,
          l.earning_from_sale_of_electrical_energy_5y_back AS value_5y_back,
          IF(
            l.earning_from_sale_of_electrical_energy > 0
              AND l.earning_from_sale_of_electrical_energy_5y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.earning_from_sale_of_electrical_energy / l.earning_from_sale_of_electrical_energy_5y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_5y_pct
        ) AS earning_from_sale_of_electrical_energy,
        STRUCT(
          l.less_cash_discount AS value,
          l.less_cash_discount_prev_yr AS prev_yr,
          (l.less_cash_discount - l.less_cash_discount_prev_yr) / ABS(NULLIF(l.less_cash_discount_prev_yr, 0)) * 100 AS yoy_pct,
          l.less_cash_discount_3y_back AS value_3y_back,
          IF(
            l.less_cash_discount > 0
              AND l.less_cash_discount_3y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.less_cash_discount / l.less_cash_discount_3y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_3y_pct,
          l.less_cash_discount_5y_back AS value_5y_back,
          IF(
            l.less_cash_discount > 0
              AND l.less_cash_discount_5y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.less_cash_discount / l.less_cash_discount_5y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_5y_pct
        ) AS less_cash_discount,
        STRUCT(
          l.less_rebate_to_consumers AS value,
          l.less_rebate_to_consumers_prev_yr AS prev_yr,
          (l.less_rebate_to_consumers - l.less_rebate_to_consumers_prev_yr) / ABS(NULLIF(l.less_rebate_to_consumers_prev_yr, 0)) * 100 AS yoy_pct,
          l.less_rebate_to_consumers_3y_back AS value_3y_back,
          IF(
            l.less_rebate_to_consumers > 0
              AND l.less_rebate_to_consumers_3y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.less_rebate_to_consumers / l.less_rebate_to_consumers_3y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_3y_pct,
          l.less_rebate_to_consumers_5y_back AS value_5y_back,
          IF(
            l.less_rebate_to_consumers > 0
              AND l.less_rebate_to_consumers_5y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.less_rebate_to_consumers / l.less_rebate_to_consumers_5y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_5y_pct
        ) AS less_rebate_to_consumers,
        STRUCT(
          l.less_consumer_benefit_account AS value,
          l.less_consumer_benefit_account_prev_yr AS prev_yr,
          (l.less_consumer_benefit_account - l.less_consumer_benefit_account_prev_yr) / ABS(NULLIF(l.less_consumer_benefit_account_prev_yr, 0)) * 100 AS yoy_pct,
          l.less_consumer_benefit_account_3y_back AS value_3y_back,
          IF(
            l.less_consumer_benefit_account > 0
              AND l.less_consumer_benefit_account_3y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.less_consumer_benefit_account / l.less_consumer_benefit_account_3y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_3y_pct,
          l.less_consumer_benefit_account_5y_back AS value_5y_back,
          IF(
            l.less_consumer_benefit_account > 0
              AND l.less_consumer_benefit_account_5y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.less_consumer_benefit_account / l.less_consumer_benefit_account_5y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_5y_pct
        ) AS less_consumer_benefit_account,
        STRUCT(
          l.contracts_income AS value,
          l.contracts_income_prev_yr AS prev_yr,
          (l.contracts_income - l.contracts_income_prev_yr) / ABS(NULLIF(l.contracts_income_prev_yr, 0)) * 100 AS yoy_pct,
          l.contracts_income_3y_back AS value_3y_back,
          IF(
            l.contracts_income > 0
              AND l.contracts_income_3y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.contracts_income / l.contracts_income_3y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_3y_pct,
          l.contracts_income_5y_back AS value_5y_back,
          IF(
            l.contracts_income > 0
              AND l.contracts_income_5y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.contracts_income / l.contracts_income_5y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_5y_pct
        ) AS contracts_income,
        STRUCT(
          l.transmission_epc_business AS value,
          l.transmission_epc_business_prev_yr AS prev_yr,
          (l.transmission_epc_business - l.transmission_epc_business_prev_yr) / ABS(NULLIF(l.transmission_epc_business_prev_yr, 0)) * 100 AS yoy_pct,
          l.transmission_epc_business_3y_back AS value_3y_back,
          IF(
            l.transmission_epc_business > 0
              AND l.transmission_epc_business_3y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.transmission_epc_business / l.transmission_epc_business_3y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_3y_pct,
          l.transmission_epc_business_5y_back AS value_5y_back,
          IF(
            l.transmission_epc_business > 0
              AND l.transmission_epc_business_5y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.transmission_epc_business / l.transmission_epc_business_5y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_5y_pct
        ) AS transmission_epc_business,
        STRUCT(
          l.wheeling_and_transmission_charges_recoverable AS value,
          l.wheeling_and_transmission_charges_recoverable_prev_yr AS prev_yr,
          (l.wheeling_and_transmission_charges_recoverable - l.wheeling_and_transmission_charges_recoverable_prev_yr) / ABS(NULLIF(l.wheeling_and_transmission_charges_recoverable_prev_yr, 0)) * 100 AS yoy_pct,
          l.wheeling_and_transmission_charges_recoverable_3y_back AS value_3y_back,
          IF(
            l.wheeling_and_transmission_charges_recoverable > 0
              AND l.wheeling_and_transmission_charges_recoverable_3y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.wheeling_and_transmission_charges_recoverable / l.wheeling_and_transmission_charges_recoverable_3y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_3y_pct,
          l.wheeling_and_transmission_charges_recoverable_5y_back AS value_5y_back,
          IF(
            l.wheeling_and_transmission_charges_recoverable > 0
              AND l.wheeling_and_transmission_charges_recoverable_5y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.wheeling_and_transmission_charges_recoverable / l.wheeling_and_transmission_charges_recoverable_5y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_5y_pct
        ) AS wheeling_and_transmission_charges_recoverable,
        STRUCT(
          l.electronic_products AS value,
          l.electronic_products_prev_yr AS prev_yr,
          (l.electronic_products - l.electronic_products_prev_yr) / ABS(NULLIF(l.electronic_products_prev_yr, 0)) * 100 AS yoy_pct,
          l.electronic_products_3y_back AS value_3y_back,
          IF(
            l.electronic_products > 0
              AND l.electronic_products_3y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.electronic_products / l.electronic_products_3y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_3y_pct,
          l.electronic_products_5y_back AS value_5y_back,
          IF(
            l.electronic_products > 0
              AND l.electronic_products_5y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.electronic_products / l.electronic_products_5y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_5y_pct
        ) AS electronic_products,
        STRUCT(
          l.service_income AS value,
          l.service_income_prev_yr AS prev_yr,
          (l.service_income - l.service_income_prev_yr) / ABS(NULLIF(l.service_income_prev_yr, 0)) * 100 AS yoy_pct,
          l.service_income_3y_back AS value_3y_back,
          IF(
            l.service_income > 0
              AND l.service_income_3y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.service_income / l.service_income_3y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_3y_pct,
          l.service_income_5y_back AS value_5y_back,
          IF(
            l.service_income > 0
              AND l.service_income_5y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.service_income / l.service_income_5y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_5y_pct
        ) AS service_income,
        STRUCT(
          l.sale_of_development_rights AS value,
          l.sale_of_development_rights_prev_yr AS prev_yr,
          (l.sale_of_development_rights - l.sale_of_development_rights_prev_yr) / ABS(NULLIF(l.sale_of_development_rights_prev_yr, 0)) * 100 AS yoy_pct,
          l.sale_of_development_rights_3y_back AS value_3y_back,
          IF(
            l.sale_of_development_rights > 0
              AND l.sale_of_development_rights_3y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.sale_of_development_rights / l.sale_of_development_rights_3y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_3y_pct,
          l.sale_of_development_rights_5y_back AS value_5y_back,
          IF(
            l.sale_of_development_rights > 0
              AND l.sale_of_development_rights_5y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.sale_of_development_rights / l.sale_of_development_rights_5y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_5y_pct
        ) AS sale_of_development_rights,
        STRUCT(
          l.development_charges AS value,
          l.development_charges_prev_yr AS prev_yr,
          (l.development_charges - l.development_charges_prev_yr) / ABS(NULLIF(l.development_charges_prev_yr, 0)) * 100 AS yoy_pct,
          l.development_charges_3y_back AS value_3y_back,
          IF(
            l.development_charges > 0
              AND l.development_charges_3y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.development_charges / l.development_charges_3y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_3y_pct,
          l.development_charges_5y_back AS value_5y_back,
          IF(
            l.development_charges > 0
              AND l.development_charges_5y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.development_charges / l.development_charges_5y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_5y_pct
        ) AS development_charges,
        STRUCT(
          l.income_from_investment_in_properties AS value,
          l.income_from_investment_in_properties_prev_yr AS prev_yr,
          (l.income_from_investment_in_properties - l.income_from_investment_in_properties_prev_yr) / ABS(NULLIF(l.income_from_investment_in_properties_prev_yr, 0)) * 100 AS yoy_pct,
          l.income_from_investment_in_properties_3y_back AS value_3y_back,
          IF(
            l.income_from_investment_in_properties > 0
              AND l.income_from_investment_in_properties_3y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.income_from_investment_in_properties / l.income_from_investment_in_properties_3y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_3y_pct,
          l.income_from_investment_in_properties_5y_back AS value_5y_back,
          IF(
            l.income_from_investment_in_properties > 0
              AND l.income_from_investment_in_properties_5y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.income_from_investment_in_properties / l.income_from_investment_in_properties_5y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_5y_pct
        ) AS income_from_investment_in_properties,
        STRUCT(
          l.rooms_restaurant_banquets AS value,
          l.rooms_restaurant_banquets_prev_yr AS prev_yr,
          (l.rooms_restaurant_banquets - l.rooms_restaurant_banquets_prev_yr) / ABS(NULLIF(l.rooms_restaurant_banquets_prev_yr, 0)) * 100 AS yoy_pct,
          l.rooms_restaurant_banquets_3y_back AS value_3y_back,
          IF(
            l.rooms_restaurant_banquets > 0
              AND l.rooms_restaurant_banquets_3y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.rooms_restaurant_banquets / l.rooms_restaurant_banquets_3y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_3y_pct,
          l.rooms_restaurant_banquets_5y_back AS value_5y_back,
          IF(
            l.rooms_restaurant_banquets > 0
              AND l.rooms_restaurant_banquets_5y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.rooms_restaurant_banquets / l.rooms_restaurant_banquets_5y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_5y_pct
        ) AS rooms_restaurant_banquets,
        STRUCT(
          l.communication_services AS value,
          l.communication_services_prev_yr AS prev_yr,
          (l.communication_services - l.communication_services_prev_yr) / ABS(NULLIF(l.communication_services_prev_yr, 0)) * 100 AS yoy_pct,
          l.communication_services_3y_back AS value_3y_back,
          IF(
            l.communication_services > 0
              AND l.communication_services_3y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.communication_services / l.communication_services_3y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_3y_pct,
          l.communication_services_5y_back AS value_5y_back,
          IF(
            l.communication_services > 0
              AND l.communication_services_5y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.communication_services / l.communication_services_5y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_5y_pct
        ) AS communication_services,
        STRUCT(
          l.food_and_beverages AS value,
          l.food_and_beverages_prev_yr AS prev_yr,
          (l.food_and_beverages - l.food_and_beverages_prev_yr) / ABS(NULLIF(l.food_and_beverages_prev_yr, 0)) * 100 AS yoy_pct,
          l.food_and_beverages_3y_back AS value_3y_back,
          IF(
            l.food_and_beverages > 0
              AND l.food_and_beverages_3y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.food_and_beverages / l.food_and_beverages_3y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_3y_pct,
          l.food_and_beverages_5y_back AS value_5y_back,
          IF(
            l.food_and_beverages > 0
              AND l.food_and_beverages_5y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.food_and_beverages / l.food_and_beverages_5y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_5y_pct
        ) AS food_and_beverages,
        STRUCT(
          l.telecommunication_services AS value,
          l.telecommunication_services_prev_yr AS prev_yr,
          (l.telecommunication_services - l.telecommunication_services_prev_yr) / ABS(NULLIF(l.telecommunication_services_prev_yr, 0)) * 100 AS yoy_pct,
          l.telecommunication_services_3y_back AS value_3y_back,
          IF(
            l.telecommunication_services > 0
              AND l.telecommunication_services_3y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.telecommunication_services / l.telecommunication_services_3y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_3y_pct,
          l.telecommunication_services_5y_back AS value_5y_back,
          IF(
            l.telecommunication_services > 0
              AND l.telecommunication_services_5y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.telecommunication_services / l.telecommunication_services_5y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_5y_pct
        ) AS telecommunication_services,
        STRUCT(
          l.broadcasting_revenue AS value,
          l.broadcasting_revenue_prev_yr AS prev_yr,
          (l.broadcasting_revenue - l.broadcasting_revenue_prev_yr) / ABS(NULLIF(l.broadcasting_revenue_prev_yr, 0)) * 100 AS yoy_pct,
          l.broadcasting_revenue_3y_back AS value_3y_back,
          IF(
            l.broadcasting_revenue > 0
              AND l.broadcasting_revenue_3y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.broadcasting_revenue / l.broadcasting_revenue_3y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_3y_pct,
          l.broadcasting_revenue_5y_back AS value_5y_back,
          IF(
            l.broadcasting_revenue > 0
              AND l.broadcasting_revenue_5y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.broadcasting_revenue / l.broadcasting_revenue_5y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_5y_pct
        ) AS broadcasting_revenue,
        STRUCT(
          l.advertising_revenue AS value,
          l.advertising_revenue_prev_yr AS prev_yr,
          (l.advertising_revenue - l.advertising_revenue_prev_yr) / ABS(NULLIF(l.advertising_revenue_prev_yr, 0)) * 100 AS yoy_pct,
          l.advertising_revenue_3y_back AS value_3y_back,
          IF(
            l.advertising_revenue > 0
              AND l.advertising_revenue_3y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.advertising_revenue / l.advertising_revenue_3y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_3y_pct,
          l.advertising_revenue_5y_back AS value_5y_back,
          IF(
            l.advertising_revenue > 0
              AND l.advertising_revenue_5y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.advertising_revenue / l.advertising_revenue_5y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_5y_pct
        ) AS advertising_revenue,
        STRUCT(
          l.license_income AS value,
          l.license_income_prev_yr AS prev_yr,
          (l.license_income - l.license_income_prev_yr) / ABS(NULLIF(l.license_income_prev_yr, 0)) * 100 AS yoy_pct,
          l.license_income_3y_back AS value_3y_back,
          IF(
            l.license_income > 0
              AND l.license_income_3y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.license_income / l.license_income_3y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_3y_pct,
          l.license_income_5y_back AS value_5y_back,
          IF(
            l.license_income > 0
              AND l.license_income_5y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.license_income / l.license_income_5y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_5y_pct
        ) AS license_income,
        STRUCT(
          l.subscription_income AS value,
          l.subscription_income_prev_yr AS prev_yr,
          (l.subscription_income - l.subscription_income_prev_yr) / ABS(NULLIF(l.subscription_income_prev_yr, 0)) * 100 AS yoy_pct,
          l.subscription_income_3y_back AS value_3y_back,
          IF(
            l.subscription_income > 0
              AND l.subscription_income_3y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.subscription_income / l.subscription_income_3y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_3y_pct,
          l.subscription_income_5y_back AS value_5y_back,
          IF(
            l.subscription_income > 0
              AND l.subscription_income_5y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.subscription_income / l.subscription_income_5y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_5y_pct
        ) AS subscription_income,
        STRUCT(
          l.income_from_content_event_shows_films AS value,
          l.income_from_content_event_shows_films_prev_yr AS prev_yr,
          (l.income_from_content_event_shows_films - l.income_from_content_event_shows_films_prev_yr) / ABS(NULLIF(l.income_from_content_event_shows_films_prev_yr, 0)) * 100 AS yoy_pct,
          l.income_from_content_event_shows_films_3y_back AS value_3y_back,
          IF(
            l.income_from_content_event_shows_films > 0
              AND l.income_from_content_event_shows_films_3y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.income_from_content_event_shows_films / l.income_from_content_event_shows_films_3y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_3y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_3y_pct,
          l.income_from_content_event_shows_films_5y_back AS value_5y_back,
          IF(
            l.income_from_content_event_shows_films > 0
              AND l.income_from_content_event_shows_films_5y_back > 0
              AND DATE_DIFF(
                PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                MONTH)
                > 0,
            (
              POW(
                l.income_from_content_event_shows_films / l.income_from_content_event_shows_films_5y_back,
                12.0 / DATE_DIFF(
                  PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
                  PARSE_DATE('%Y%m', CAST(l.yyyymm_5y_back AS STRING)),
                  MONTH))
              - 1)
              * 100,
            NULL) AS cagr_5y_pct
        ) AS income_from_content_event_shows_films
  ) AS income_growth
FROM lagged l;
END
