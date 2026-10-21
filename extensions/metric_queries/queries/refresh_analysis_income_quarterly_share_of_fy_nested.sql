-- Routine: silverzone.refresh_analysis_income_quarterly_share_of_fy_nested
-- Source: capable-code-486208-j8.silverzone

BEGIN
-- silverzone.analysis_income_quarterly_share_of_fy_nested
-- Full nested income quarterly share-of-FY table.
-- Generated from silverzone.profit_and_loss_quarterly_income_nested schema.
-- Covers every numeric leaf under income, including children and grandchildren.
-- Each metric leaf is emitted as STRUCT(value, fy_total, pct_of_fy).
CREATE OR REPLACE TABLE silverzone.analysis_income_quarterly_share_of_fy_nested
CLUSTER BY company_id, yyyymm AS
WITH q AS (
  SELECT
    company_id,
    company_name,
    sector,
    subsector,
    flag,
    yyyymm,
    value_basis,
    unit,
    DIV(yyyymm, 100) + IF(MOD(yyyymm, 100) >= 4, 1, 0) AS fiscal_year,
    income.operating_income.value AS operating_income__value,
    income.operating_income.gross_sales AS operating_income__gross_sales,
    income.operating_income.net_sales_other_operating_income AS operating_income__net_sales_other_operating_income,
    income.operating_income.less_excise_duty AS operating_income__less_excise_duty,
    income.operating_income.excise_duty AS operating_income__excise_duty,
    income.operating_income.other_operating_income AS operating_income__other_operating_income,
    income.other_income.value AS other_income__value,
    income.other_income.other_income_2_0 AS other_income__other_income_2_0,
    income.other_income.total_income AS other_income__total_income,
    income.other_income.dividend AS other_income__dividend,
    income.other_income.dividend_income AS other_income__dividend_income,
    income.other_income.interest_income AS other_income__interest_income,
    income.other_income.export_incentives AS other_income__export_incentives,
    income.other_income.lease_rental_income AS other_income__lease_rental_income,
    income.other_income.fees_income AS other_income__fees_income,
    income.other_income.income_on_investments AS other_income__income_on_investments,
    income.other_income.foreign_exchange_gain AS other_income__foreign_exchange_gain,
    income.other_income.foreign_exchange_gain_loss AS other_income__foreign_exchange_gain_loss,
    income.other_income.profit_on_sale_of_investments AS other_income__profit_on_sale_of_investments,
    income.other_income.profit_on_sale_of_shares AS other_income__profit_on_sale_of_shares,
    income.other_income.profit_on_sale_of_assets AS other_income__profit_on_sale_of_assets,
    income.other_income.profit_loss_on_sale_of_investments AS other_income__profit_loss_on_sale_of_investments,
    income.other_income.profit_loss_on_sale_of_assets AS other_income__profit_loss_on_sale_of_assets,
    income.other_income.provision_written_back AS other_income__provision_written_back,
    income.other_income.others AS other_income__others,
    income.shareholding.value AS shareholding__value,
    income.shareholding.of_public_share_holding AS shareholding__of_public_share_holding,
    income.shareholding.number_of_public_share_holding AS shareholding__number_of_public_share_holding,
    income.shareholding.encumbered_of_promoter_holdings AS shareholding__encumbered_of_promoter_holdings,
    income.shareholding.encumbered_of_share_capital AS shareholding__encumbered_of_share_capital,
    income.shareholding.encumbered_no_of_shares AS shareholding__encumbered_no_of_shares,
    income.shareholding.non_encumbered AS shareholding__non_encumbered,
    income.shareholding.non_encumbered_of_promoter_holdings AS shareholding__non_encumbered_of_promoter_holdings,
    income.shareholding.non_encumbered_of_share_capital AS shareholding__non_encumbered_of_share_capital,
    income.shareholding.non_encumbered_no_of_shares AS shareholding__non_encumbered_no_of_shares,
    income.shareholding.promoters_no_of_shares AS shareholding__promoters_no_of_shares,
    income.shareholding.of_shares_held_by_govt AS shareholding__of_shares_held_by_govt
  FROM silverzone.profit_and_loss_quarterly_income_nested
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
  fiscal_year,
  CASE MOD(yyyymm, 100)
    WHEN 6 THEN 'Q1'
    WHEN 9 THEN 'Q2'
    WHEN 12 THEN 'Q3'
    WHEN 3 THEN 'Q4'
  END AS fiscal_quarter,
  STRUCT(
    STRUCT(
      STRUCT(
        operating_income__value AS value,
        SUM(operating_income__value) OVER fy AS fy_total,
        IF(ABS(SUM(operating_income__value) OVER fy) < 1e-6, NULL, operating_income__value / SUM(operating_income__value) OVER fy * 100) AS pct_of_fy
      ) AS value,
      STRUCT(
        operating_income__gross_sales AS value,
        SUM(operating_income__gross_sales) OVER fy AS fy_total,
        IF(ABS(SUM(operating_income__gross_sales) OVER fy) < 1e-6, NULL, operating_income__gross_sales / SUM(operating_income__gross_sales) OVER fy * 100) AS pct_of_fy
      ) AS gross_sales,
      STRUCT(
        operating_income__net_sales_other_operating_income AS value,
        SUM(operating_income__net_sales_other_operating_income) OVER fy AS fy_total,
        IF(ABS(SUM(operating_income__net_sales_other_operating_income) OVER fy) < 1e-6, NULL, operating_income__net_sales_other_operating_income / SUM(operating_income__net_sales_other_operating_income) OVER fy * 100) AS pct_of_fy
      ) AS net_sales_other_operating_income,
      STRUCT(
        operating_income__less_excise_duty AS value,
        SUM(operating_income__less_excise_duty) OVER fy AS fy_total,
        IF(ABS(SUM(operating_income__less_excise_duty) OVER fy) < 1e-6, NULL, operating_income__less_excise_duty / SUM(operating_income__less_excise_duty) OVER fy * 100) AS pct_of_fy
      ) AS less_excise_duty,
      STRUCT(
        operating_income__excise_duty AS value,
        SUM(operating_income__excise_duty) OVER fy AS fy_total,
        IF(ABS(SUM(operating_income__excise_duty) OVER fy) < 1e-6, NULL, operating_income__excise_duty / SUM(operating_income__excise_duty) OVER fy * 100) AS pct_of_fy
      ) AS excise_duty,
      STRUCT(
        operating_income__other_operating_income AS value,
        SUM(operating_income__other_operating_income) OVER fy AS fy_total,
        IF(ABS(SUM(operating_income__other_operating_income) OVER fy) < 1e-6, NULL, operating_income__other_operating_income / SUM(operating_income__other_operating_income) OVER fy * 100) AS pct_of_fy
      ) AS other_operating_income
    ) AS operating_income,
    STRUCT(
      STRUCT(
        other_income__value AS value,
        SUM(other_income__value) OVER fy AS fy_total,
        IF(ABS(SUM(other_income__value) OVER fy) < 1e-6, NULL, other_income__value / SUM(other_income__value) OVER fy * 100) AS pct_of_fy
      ) AS value,
      STRUCT(
        other_income__other_income_2_0 AS value,
        SUM(other_income__other_income_2_0) OVER fy AS fy_total,
        IF(ABS(SUM(other_income__other_income_2_0) OVER fy) < 1e-6, NULL, other_income__other_income_2_0 / SUM(other_income__other_income_2_0) OVER fy * 100) AS pct_of_fy
      ) AS other_income_2_0,
      STRUCT(
        other_income__total_income AS value,
        SUM(other_income__total_income) OVER fy AS fy_total,
        IF(ABS(SUM(other_income__total_income) OVER fy) < 1e-6, NULL, other_income__total_income / SUM(other_income__total_income) OVER fy * 100) AS pct_of_fy
      ) AS total_income,
      STRUCT(
        other_income__dividend AS value,
        SUM(other_income__dividend) OVER fy AS fy_total,
        IF(ABS(SUM(other_income__dividend) OVER fy) < 1e-6, NULL, other_income__dividend / SUM(other_income__dividend) OVER fy * 100) AS pct_of_fy
      ) AS dividend,
      STRUCT(
        other_income__dividend_income AS value,
        SUM(other_income__dividend_income) OVER fy AS fy_total,
        IF(ABS(SUM(other_income__dividend_income) OVER fy) < 1e-6, NULL, other_income__dividend_income / SUM(other_income__dividend_income) OVER fy * 100) AS pct_of_fy
      ) AS dividend_income,
      STRUCT(
        other_income__interest_income AS value,
        SUM(other_income__interest_income) OVER fy AS fy_total,
        IF(ABS(SUM(other_income__interest_income) OVER fy) < 1e-6, NULL, other_income__interest_income / SUM(other_income__interest_income) OVER fy * 100) AS pct_of_fy
      ) AS interest_income,
      STRUCT(
        other_income__export_incentives AS value,
        SUM(other_income__export_incentives) OVER fy AS fy_total,
        IF(ABS(SUM(other_income__export_incentives) OVER fy) < 1e-6, NULL, other_income__export_incentives / SUM(other_income__export_incentives) OVER fy * 100) AS pct_of_fy
      ) AS export_incentives,
      STRUCT(
        other_income__lease_rental_income AS value,
        SUM(other_income__lease_rental_income) OVER fy AS fy_total,
        IF(ABS(SUM(other_income__lease_rental_income) OVER fy) < 1e-6, NULL, other_income__lease_rental_income / SUM(other_income__lease_rental_income) OVER fy * 100) AS pct_of_fy
      ) AS lease_rental_income,
      STRUCT(
        other_income__fees_income AS value,
        SUM(other_income__fees_income) OVER fy AS fy_total,
        IF(ABS(SUM(other_income__fees_income) OVER fy) < 1e-6, NULL, other_income__fees_income / SUM(other_income__fees_income) OVER fy * 100) AS pct_of_fy
      ) AS fees_income,
      STRUCT(
        other_income__income_on_investments AS value,
        SUM(other_income__income_on_investments) OVER fy AS fy_total,
        IF(ABS(SUM(other_income__income_on_investments) OVER fy) < 1e-6, NULL, other_income__income_on_investments / SUM(other_income__income_on_investments) OVER fy * 100) AS pct_of_fy
      ) AS income_on_investments,
      STRUCT(
        other_income__foreign_exchange_gain AS value,
        SUM(other_income__foreign_exchange_gain) OVER fy AS fy_total,
        IF(ABS(SUM(other_income__foreign_exchange_gain) OVER fy) < 1e-6, NULL, other_income__foreign_exchange_gain / SUM(other_income__foreign_exchange_gain) OVER fy * 100) AS pct_of_fy
      ) AS foreign_exchange_gain,
      STRUCT(
        other_income__foreign_exchange_gain_loss AS value,
        SUM(other_income__foreign_exchange_gain_loss) OVER fy AS fy_total,
        IF(ABS(SUM(other_income__foreign_exchange_gain_loss) OVER fy) < 1e-6, NULL, other_income__foreign_exchange_gain_loss / SUM(other_income__foreign_exchange_gain_loss) OVER fy * 100) AS pct_of_fy
      ) AS foreign_exchange_gain_loss,
      STRUCT(
        other_income__profit_on_sale_of_investments AS value,
        SUM(other_income__profit_on_sale_of_investments) OVER fy AS fy_total,
        IF(ABS(SUM(other_income__profit_on_sale_of_investments) OVER fy) < 1e-6, NULL, other_income__profit_on_sale_of_investments / SUM(other_income__profit_on_sale_of_investments) OVER fy * 100) AS pct_of_fy
      ) AS profit_on_sale_of_investments,
      STRUCT(
        other_income__profit_on_sale_of_shares AS value,
        SUM(other_income__profit_on_sale_of_shares) OVER fy AS fy_total,
        IF(ABS(SUM(other_income__profit_on_sale_of_shares) OVER fy) < 1e-6, NULL, other_income__profit_on_sale_of_shares / SUM(other_income__profit_on_sale_of_shares) OVER fy * 100) AS pct_of_fy
      ) AS profit_on_sale_of_shares,
      STRUCT(
        other_income__profit_on_sale_of_assets AS value,
        SUM(other_income__profit_on_sale_of_assets) OVER fy AS fy_total,
        IF(ABS(SUM(other_income__profit_on_sale_of_assets) OVER fy) < 1e-6, NULL, other_income__profit_on_sale_of_assets / SUM(other_income__profit_on_sale_of_assets) OVER fy * 100) AS pct_of_fy
      ) AS profit_on_sale_of_assets,
      STRUCT(
        other_income__profit_loss_on_sale_of_investments AS value,
        SUM(other_income__profit_loss_on_sale_of_investments) OVER fy AS fy_total,
        IF(ABS(SUM(other_income__profit_loss_on_sale_of_investments) OVER fy) < 1e-6, NULL, other_income__profit_loss_on_sale_of_investments / SUM(other_income__profit_loss_on_sale_of_investments) OVER fy * 100) AS pct_of_fy
      ) AS profit_loss_on_sale_of_investments,
      STRUCT(
        other_income__profit_loss_on_sale_of_assets AS value,
        SUM(other_income__profit_loss_on_sale_of_assets) OVER fy AS fy_total,
        IF(ABS(SUM(other_income__profit_loss_on_sale_of_assets) OVER fy) < 1e-6, NULL, other_income__profit_loss_on_sale_of_assets / SUM(other_income__profit_loss_on_sale_of_assets) OVER fy * 100) AS pct_of_fy
      ) AS profit_loss_on_sale_of_assets,
      STRUCT(
        other_income__provision_written_back AS value,
        SUM(other_income__provision_written_back) OVER fy AS fy_total,
        IF(ABS(SUM(other_income__provision_written_back) OVER fy) < 1e-6, NULL, other_income__provision_written_back / SUM(other_income__provision_written_back) OVER fy * 100) AS pct_of_fy
      ) AS provision_written_back,
      STRUCT(
        other_income__others AS value,
        SUM(other_income__others) OVER fy AS fy_total,
        IF(ABS(SUM(other_income__others) OVER fy) < 1e-6, NULL, other_income__others / SUM(other_income__others) OVER fy * 100) AS pct_of_fy
      ) AS others
    ) AS other_income,
    STRUCT(
      STRUCT(
        shareholding__value AS value,
        SUM(shareholding__value) OVER fy AS fy_total,
        IF(ABS(SUM(shareholding__value) OVER fy) < 1e-6, NULL, shareholding__value / SUM(shareholding__value) OVER fy * 100) AS pct_of_fy
      ) AS value,
      STRUCT(
        shareholding__of_public_share_holding AS value,
        SUM(shareholding__of_public_share_holding) OVER fy AS fy_total,
        IF(ABS(SUM(shareholding__of_public_share_holding) OVER fy) < 1e-6, NULL, shareholding__of_public_share_holding / SUM(shareholding__of_public_share_holding) OVER fy * 100) AS pct_of_fy
      ) AS of_public_share_holding,
      STRUCT(
        shareholding__number_of_public_share_holding AS value,
        SUM(shareholding__number_of_public_share_holding) OVER fy AS fy_total,
        IF(ABS(SUM(shareholding__number_of_public_share_holding) OVER fy) < 1e-6, NULL, shareholding__number_of_public_share_holding / SUM(shareholding__number_of_public_share_holding) OVER fy * 100) AS pct_of_fy
      ) AS number_of_public_share_holding,
      STRUCT(
        shareholding__encumbered_of_promoter_holdings AS value,
        SUM(shareholding__encumbered_of_promoter_holdings) OVER fy AS fy_total,
        IF(ABS(SUM(shareholding__encumbered_of_promoter_holdings) OVER fy) < 1e-6, NULL, shareholding__encumbered_of_promoter_holdings / SUM(shareholding__encumbered_of_promoter_holdings) OVER fy * 100) AS pct_of_fy
      ) AS encumbered_of_promoter_holdings,
      STRUCT(
        shareholding__encumbered_of_share_capital AS value,
        SUM(shareholding__encumbered_of_share_capital) OVER fy AS fy_total,
        IF(ABS(SUM(shareholding__encumbered_of_share_capital) OVER fy) < 1e-6, NULL, shareholding__encumbered_of_share_capital / SUM(shareholding__encumbered_of_share_capital) OVER fy * 100) AS pct_of_fy
      ) AS encumbered_of_share_capital,
      STRUCT(
        shareholding__encumbered_no_of_shares AS value,
        SUM(shareholding__encumbered_no_of_shares) OVER fy AS fy_total,
        IF(ABS(SUM(shareholding__encumbered_no_of_shares) OVER fy) < 1e-6, NULL, shareholding__encumbered_no_of_shares / SUM(shareholding__encumbered_no_of_shares) OVER fy * 100) AS pct_of_fy
      ) AS encumbered_no_of_shares,
      STRUCT(
        shareholding__non_encumbered AS value,
        SUM(shareholding__non_encumbered) OVER fy AS fy_total,
        IF(ABS(SUM(shareholding__non_encumbered) OVER fy) < 1e-6, NULL, shareholding__non_encumbered / SUM(shareholding__non_encumbered) OVER fy * 100) AS pct_of_fy
      ) AS non_encumbered,
      STRUCT(
        shareholding__non_encumbered_of_promoter_holdings AS value,
        SUM(shareholding__non_encumbered_of_promoter_holdings) OVER fy AS fy_total,
        IF(ABS(SUM(shareholding__non_encumbered_of_promoter_holdings) OVER fy) < 1e-6, NULL, shareholding__non_encumbered_of_promoter_holdings / SUM(shareholding__non_encumbered_of_promoter_holdings) OVER fy * 100) AS pct_of_fy
      ) AS non_encumbered_of_promoter_holdings,
      STRUCT(
        shareholding__non_encumbered_of_share_capital AS value,
        SUM(shareholding__non_encumbered_of_share_capital) OVER fy AS fy_total,
        IF(ABS(SUM(shareholding__non_encumbered_of_share_capital) OVER fy) < 1e-6, NULL, shareholding__non_encumbered_of_share_capital / SUM(shareholding__non_encumbered_of_share_capital) OVER fy * 100) AS pct_of_fy
      ) AS non_encumbered_of_share_capital,
      STRUCT(
        shareholding__non_encumbered_no_of_shares AS value,
        SUM(shareholding__non_encumbered_no_of_shares) OVER fy AS fy_total,
        IF(ABS(SUM(shareholding__non_encumbered_no_of_shares) OVER fy) < 1e-6, NULL, shareholding__non_encumbered_no_of_shares / SUM(shareholding__non_encumbered_no_of_shares) OVER fy * 100) AS pct_of_fy
      ) AS non_encumbered_no_of_shares,
      STRUCT(
        shareholding__promoters_no_of_shares AS value,
        SUM(shareholding__promoters_no_of_shares) OVER fy AS fy_total,
        IF(ABS(SUM(shareholding__promoters_no_of_shares) OVER fy) < 1e-6, NULL, shareholding__promoters_no_of_shares / SUM(shareholding__promoters_no_of_shares) OVER fy * 100) AS pct_of_fy
      ) AS promoters_no_of_shares,
      STRUCT(
        shareholding__of_shares_held_by_govt AS value,
        SUM(shareholding__of_shares_held_by_govt) OVER fy AS fy_total,
        IF(ABS(SUM(shareholding__of_shares_held_by_govt) OVER fy) < 1e-6, NULL, shareholding__of_shares_held_by_govt / SUM(shareholding__of_shares_held_by_govt) OVER fy * 100) AS pct_of_fy
      ) AS of_shares_held_by_govt
    ) AS shareholding
  ) AS income_share_of_fy
FROM q
QUALIFY COUNT(*) OVER fy = 4
WINDOW fy AS (PARTITION BY company_id, flag, fiscal_year);
END
