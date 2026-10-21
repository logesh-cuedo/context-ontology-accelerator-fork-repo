-- Routine: silverzone.refresh_analysis_income_ttm_nested
-- Source: capable-code-486208-j8.silverzone

BEGIN
-- silverzone.analysis_income_ttm_nested
-- Full nested income TTM table.
-- Generated from silverzone.profit_and_loss_quarterly_income_nested schema.
-- Covers every numeric leaf under income, including children and grandchildren.
-- Each metric leaf is emitted as STRUCT(value, ttm), where ttm is the rolling
-- trailing-four-quarter sum over complete consecutive quarter windows.
CREATE OR REPLACE TABLE silverzone.analysis_income_ttm_nested
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
  MIN(yyyymm) OVER w AS ttm_start_yyyymm,
  STRUCT(
    STRUCT(
      STRUCT(
        operating_income__value AS value,
        SUM(operating_income__value) OVER w AS ttm
      ) AS value,
      STRUCT(
        operating_income__gross_sales AS value,
        SUM(operating_income__gross_sales) OVER w AS ttm
      ) AS gross_sales,
      STRUCT(
        operating_income__net_sales_other_operating_income AS value,
        SUM(operating_income__net_sales_other_operating_income) OVER w AS ttm
      ) AS net_sales_other_operating_income,
      STRUCT(
        operating_income__less_excise_duty AS value,
        SUM(operating_income__less_excise_duty) OVER w AS ttm
      ) AS less_excise_duty,
      STRUCT(
        operating_income__excise_duty AS value,
        SUM(operating_income__excise_duty) OVER w AS ttm
      ) AS excise_duty,
      STRUCT(
        operating_income__other_operating_income AS value,
        SUM(operating_income__other_operating_income) OVER w AS ttm
      ) AS other_operating_income
    ) AS operating_income,
    STRUCT(
      STRUCT(
        other_income__value AS value,
        SUM(other_income__value) OVER w AS ttm
      ) AS value,
      STRUCT(
        other_income__other_income_2_0 AS value,
        SUM(other_income__other_income_2_0) OVER w AS ttm
      ) AS other_income_2_0,
      STRUCT(
        other_income__total_income AS value,
        SUM(other_income__total_income) OVER w AS ttm
      ) AS total_income,
      STRUCT(
        other_income__dividend AS value,
        SUM(other_income__dividend) OVER w AS ttm
      ) AS dividend,
      STRUCT(
        other_income__dividend_income AS value,
        SUM(other_income__dividend_income) OVER w AS ttm
      ) AS dividend_income,
      STRUCT(
        other_income__interest_income AS value,
        SUM(other_income__interest_income) OVER w AS ttm
      ) AS interest_income,
      STRUCT(
        other_income__export_incentives AS value,
        SUM(other_income__export_incentives) OVER w AS ttm
      ) AS export_incentives,
      STRUCT(
        other_income__lease_rental_income AS value,
        SUM(other_income__lease_rental_income) OVER w AS ttm
      ) AS lease_rental_income,
      STRUCT(
        other_income__fees_income AS value,
        SUM(other_income__fees_income) OVER w AS ttm
      ) AS fees_income,
      STRUCT(
        other_income__income_on_investments AS value,
        SUM(other_income__income_on_investments) OVER w AS ttm
      ) AS income_on_investments,
      STRUCT(
        other_income__foreign_exchange_gain AS value,
        SUM(other_income__foreign_exchange_gain) OVER w AS ttm
      ) AS foreign_exchange_gain,
      STRUCT(
        other_income__foreign_exchange_gain_loss AS value,
        SUM(other_income__foreign_exchange_gain_loss) OVER w AS ttm
      ) AS foreign_exchange_gain_loss,
      STRUCT(
        other_income__profit_on_sale_of_investments AS value,
        SUM(other_income__profit_on_sale_of_investments) OVER w AS ttm
      ) AS profit_on_sale_of_investments,
      STRUCT(
        other_income__profit_on_sale_of_shares AS value,
        SUM(other_income__profit_on_sale_of_shares) OVER w AS ttm
      ) AS profit_on_sale_of_shares,
      STRUCT(
        other_income__profit_on_sale_of_assets AS value,
        SUM(other_income__profit_on_sale_of_assets) OVER w AS ttm
      ) AS profit_on_sale_of_assets,
      STRUCT(
        other_income__profit_loss_on_sale_of_investments AS value,
        SUM(other_income__profit_loss_on_sale_of_investments) OVER w AS ttm
      ) AS profit_loss_on_sale_of_investments,
      STRUCT(
        other_income__profit_loss_on_sale_of_assets AS value,
        SUM(other_income__profit_loss_on_sale_of_assets) OVER w AS ttm
      ) AS profit_loss_on_sale_of_assets,
      STRUCT(
        other_income__provision_written_back AS value,
        SUM(other_income__provision_written_back) OVER w AS ttm
      ) AS provision_written_back,
      STRUCT(
        other_income__others AS value,
        SUM(other_income__others) OVER w AS ttm
      ) AS others
    ) AS other_income,
    STRUCT(
      STRUCT(
        shareholding__value AS value,
        SUM(shareholding__value) OVER w AS ttm
      ) AS value,
      STRUCT(
        shareholding__of_public_share_holding AS value,
        SUM(shareholding__of_public_share_holding) OVER w AS ttm
      ) AS of_public_share_holding,
      STRUCT(
        shareholding__number_of_public_share_holding AS value,
        SUM(shareholding__number_of_public_share_holding) OVER w AS ttm
      ) AS number_of_public_share_holding,
      STRUCT(
        shareholding__encumbered_of_promoter_holdings AS value,
        SUM(shareholding__encumbered_of_promoter_holdings) OVER w AS ttm
      ) AS encumbered_of_promoter_holdings,
      STRUCT(
        shareholding__encumbered_of_share_capital AS value,
        SUM(shareholding__encumbered_of_share_capital) OVER w AS ttm
      ) AS encumbered_of_share_capital,
      STRUCT(
        shareholding__encumbered_no_of_shares AS value,
        SUM(shareholding__encumbered_no_of_shares) OVER w AS ttm
      ) AS encumbered_no_of_shares,
      STRUCT(
        shareholding__non_encumbered AS value,
        SUM(shareholding__non_encumbered) OVER w AS ttm
      ) AS non_encumbered,
      STRUCT(
        shareholding__non_encumbered_of_promoter_holdings AS value,
        SUM(shareholding__non_encumbered_of_promoter_holdings) OVER w AS ttm
      ) AS non_encumbered_of_promoter_holdings,
      STRUCT(
        shareholding__non_encumbered_of_share_capital AS value,
        SUM(shareholding__non_encumbered_of_share_capital) OVER w AS ttm
      ) AS non_encumbered_of_share_capital,
      STRUCT(
        shareholding__non_encumbered_no_of_shares AS value,
        SUM(shareholding__non_encumbered_no_of_shares) OVER w AS ttm
      ) AS non_encumbered_no_of_shares,
      STRUCT(
        shareholding__promoters_no_of_shares AS value,
        SUM(shareholding__promoters_no_of_shares) OVER w AS ttm
      ) AS promoters_no_of_shares,
      STRUCT(
        shareholding__of_shares_held_by_govt AS value,
        SUM(shareholding__of_shares_held_by_govt) OVER w AS ttm
      ) AS of_shares_held_by_govt
    ) AS shareholding
  ) AS income_ttm
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
