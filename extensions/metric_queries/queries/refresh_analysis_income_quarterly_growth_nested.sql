-- Routine: silverzone.refresh_analysis_income_quarterly_growth_nested
-- Source: capable-code-486208-j8.silverzone

BEGIN
-- silverzone.analysis_income_quarterly_growth_nested
-- Full nested income quarterly growth table.
-- Generated from silverzone.profit_and_loss_quarterly_income_nested schema.
-- Covers every numeric leaf under income, including children and grandchildren.
-- Each metric leaf is emitted as STRUCT(value, prev_q, qoq_pct, prior_yr_q, yoy_pct).
-- Growth convention: (cur - prev) / ABS(NULLIF(prev, 0)) * 100.
CREATE OR REPLACE TABLE silverzone.analysis_income_quarterly_growth_nested
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
),
lagged AS (
  SELECT
    *,
    LAG(yyyymm) OVER w AS prev_yyyymm,
    LAG(operating_income__value) OVER w AS operating_income__value_prev_q,
    LAG(operating_income__gross_sales) OVER w AS operating_income__gross_sales_prev_q,
    LAG(operating_income__net_sales_other_operating_income) OVER w AS operating_income__net_sales_other_operating_income_prev_q,
    LAG(operating_income__less_excise_duty) OVER w AS operating_income__less_excise_duty_prev_q,
    LAG(operating_income__excise_duty) OVER w AS operating_income__excise_duty_prev_q,
    LAG(operating_income__other_operating_income) OVER w AS operating_income__other_operating_income_prev_q,
    LAG(other_income__value) OVER w AS other_income__value_prev_q,
    LAG(other_income__other_income_2_0) OVER w AS other_income__other_income_2_0_prev_q,
    LAG(other_income__total_income) OVER w AS other_income__total_income_prev_q,
    LAG(other_income__dividend) OVER w AS other_income__dividend_prev_q,
    LAG(other_income__dividend_income) OVER w AS other_income__dividend_income_prev_q,
    LAG(other_income__interest_income) OVER w AS other_income__interest_income_prev_q,
    LAG(other_income__export_incentives) OVER w AS other_income__export_incentives_prev_q,
    LAG(other_income__lease_rental_income) OVER w AS other_income__lease_rental_income_prev_q,
    LAG(other_income__fees_income) OVER w AS other_income__fees_income_prev_q,
    LAG(other_income__income_on_investments) OVER w AS other_income__income_on_investments_prev_q,
    LAG(other_income__foreign_exchange_gain) OVER w AS other_income__foreign_exchange_gain_prev_q,
    LAG(other_income__foreign_exchange_gain_loss) OVER w AS other_income__foreign_exchange_gain_loss_prev_q,
    LAG(other_income__profit_on_sale_of_investments) OVER w AS other_income__profit_on_sale_of_investments_prev_q,
    LAG(other_income__profit_on_sale_of_shares) OVER w AS other_income__profit_on_sale_of_shares_prev_q,
    LAG(other_income__profit_on_sale_of_assets) OVER w AS other_income__profit_on_sale_of_assets_prev_q,
    LAG(other_income__profit_loss_on_sale_of_investments) OVER w AS other_income__profit_loss_on_sale_of_investments_prev_q,
    LAG(other_income__profit_loss_on_sale_of_assets) OVER w AS other_income__profit_loss_on_sale_of_assets_prev_q,
    LAG(other_income__provision_written_back) OVER w AS other_income__provision_written_back_prev_q,
    LAG(other_income__others) OVER w AS other_income__others_prev_q,
    LAG(shareholding__value) OVER w AS shareholding__value_prev_q,
    LAG(shareholding__of_public_share_holding) OVER w AS shareholding__of_public_share_holding_prev_q,
    LAG(shareholding__number_of_public_share_holding) OVER w AS shareholding__number_of_public_share_holding_prev_q,
    LAG(shareholding__encumbered_of_promoter_holdings) OVER w AS shareholding__encumbered_of_promoter_holdings_prev_q,
    LAG(shareholding__encumbered_of_share_capital) OVER w AS shareholding__encumbered_of_share_capital_prev_q,
    LAG(shareholding__encumbered_no_of_shares) OVER w AS shareholding__encumbered_no_of_shares_prev_q,
    LAG(shareholding__non_encumbered) OVER w AS shareholding__non_encumbered_prev_q,
    LAG(shareholding__non_encumbered_of_promoter_holdings) OVER w AS shareholding__non_encumbered_of_promoter_holdings_prev_q,
    LAG(shareholding__non_encumbered_of_share_capital) OVER w AS shareholding__non_encumbered_of_share_capital_prev_q,
    LAG(shareholding__non_encumbered_no_of_shares) OVER w AS shareholding__non_encumbered_no_of_shares_prev_q,
    LAG(shareholding__promoters_no_of_shares) OVER w AS shareholding__promoters_no_of_shares_prev_q,
    LAG(shareholding__of_shares_held_by_govt) OVER w AS shareholding__of_shares_held_by_govt_prev_q
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
        l.operating_income__value AS value,
        l.operating_income__value_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.operating_income__value - l.operating_income__value_prev_q) / ABS(NULLIF(l.operating_income__value_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.operating_income__value AS prior_yr_q,
        (l.operating_income__value - p.operating_income__value) / ABS(NULLIF(p.operating_income__value, 0)) * 100 AS yoy_pct
      ) AS value,
      STRUCT(
        l.operating_income__gross_sales AS value,
        l.operating_income__gross_sales_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.operating_income__gross_sales - l.operating_income__gross_sales_prev_q) / ABS(NULLIF(l.operating_income__gross_sales_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.operating_income__gross_sales AS prior_yr_q,
        (l.operating_income__gross_sales - p.operating_income__gross_sales) / ABS(NULLIF(p.operating_income__gross_sales, 0)) * 100 AS yoy_pct
      ) AS gross_sales,
      STRUCT(
        l.operating_income__net_sales_other_operating_income AS value,
        l.operating_income__net_sales_other_operating_income_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.operating_income__net_sales_other_operating_income - l.operating_income__net_sales_other_operating_income_prev_q) / ABS(NULLIF(l.operating_income__net_sales_other_operating_income_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.operating_income__net_sales_other_operating_income AS prior_yr_q,
        (l.operating_income__net_sales_other_operating_income - p.operating_income__net_sales_other_operating_income) / ABS(NULLIF(p.operating_income__net_sales_other_operating_income, 0)) * 100 AS yoy_pct
      ) AS net_sales_other_operating_income,
      STRUCT(
        l.operating_income__less_excise_duty AS value,
        l.operating_income__less_excise_duty_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.operating_income__less_excise_duty - l.operating_income__less_excise_duty_prev_q) / ABS(NULLIF(l.operating_income__less_excise_duty_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.operating_income__less_excise_duty AS prior_yr_q,
        (l.operating_income__less_excise_duty - p.operating_income__less_excise_duty) / ABS(NULLIF(p.operating_income__less_excise_duty, 0)) * 100 AS yoy_pct
      ) AS less_excise_duty,
      STRUCT(
        l.operating_income__excise_duty AS value,
        l.operating_income__excise_duty_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.operating_income__excise_duty - l.operating_income__excise_duty_prev_q) / ABS(NULLIF(l.operating_income__excise_duty_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.operating_income__excise_duty AS prior_yr_q,
        (l.operating_income__excise_duty - p.operating_income__excise_duty) / ABS(NULLIF(p.operating_income__excise_duty, 0)) * 100 AS yoy_pct
      ) AS excise_duty,
      STRUCT(
        l.operating_income__other_operating_income AS value,
        l.operating_income__other_operating_income_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.operating_income__other_operating_income - l.operating_income__other_operating_income_prev_q) / ABS(NULLIF(l.operating_income__other_operating_income_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.operating_income__other_operating_income AS prior_yr_q,
        (l.operating_income__other_operating_income - p.operating_income__other_operating_income) / ABS(NULLIF(p.operating_income__other_operating_income, 0)) * 100 AS yoy_pct
      ) AS other_operating_income
    ) AS operating_income,
    STRUCT(
      STRUCT(
        l.other_income__value AS value,
        l.other_income__value_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.other_income__value - l.other_income__value_prev_q) / ABS(NULLIF(l.other_income__value_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.other_income__value AS prior_yr_q,
        (l.other_income__value - p.other_income__value) / ABS(NULLIF(p.other_income__value, 0)) * 100 AS yoy_pct
      ) AS value,
      STRUCT(
        l.other_income__other_income_2_0 AS value,
        l.other_income__other_income_2_0_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.other_income__other_income_2_0 - l.other_income__other_income_2_0_prev_q) / ABS(NULLIF(l.other_income__other_income_2_0_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.other_income__other_income_2_0 AS prior_yr_q,
        (l.other_income__other_income_2_0 - p.other_income__other_income_2_0) / ABS(NULLIF(p.other_income__other_income_2_0, 0)) * 100 AS yoy_pct
      ) AS other_income_2_0,
      STRUCT(
        l.other_income__total_income AS value,
        l.other_income__total_income_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.other_income__total_income - l.other_income__total_income_prev_q) / ABS(NULLIF(l.other_income__total_income_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.other_income__total_income AS prior_yr_q,
        (l.other_income__total_income - p.other_income__total_income) / ABS(NULLIF(p.other_income__total_income, 0)) * 100 AS yoy_pct
      ) AS total_income,
      STRUCT(
        l.other_income__dividend AS value,
        l.other_income__dividend_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.other_income__dividend - l.other_income__dividend_prev_q) / ABS(NULLIF(l.other_income__dividend_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.other_income__dividend AS prior_yr_q,
        (l.other_income__dividend - p.other_income__dividend) / ABS(NULLIF(p.other_income__dividend, 0)) * 100 AS yoy_pct
      ) AS dividend,
      STRUCT(
        l.other_income__dividend_income AS value,
        l.other_income__dividend_income_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.other_income__dividend_income - l.other_income__dividend_income_prev_q) / ABS(NULLIF(l.other_income__dividend_income_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.other_income__dividend_income AS prior_yr_q,
        (l.other_income__dividend_income - p.other_income__dividend_income) / ABS(NULLIF(p.other_income__dividend_income, 0)) * 100 AS yoy_pct
      ) AS dividend_income,
      STRUCT(
        l.other_income__interest_income AS value,
        l.other_income__interest_income_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.other_income__interest_income - l.other_income__interest_income_prev_q) / ABS(NULLIF(l.other_income__interest_income_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.other_income__interest_income AS prior_yr_q,
        (l.other_income__interest_income - p.other_income__interest_income) / ABS(NULLIF(p.other_income__interest_income, 0)) * 100 AS yoy_pct
      ) AS interest_income,
      STRUCT(
        l.other_income__export_incentives AS value,
        l.other_income__export_incentives_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.other_income__export_incentives - l.other_income__export_incentives_prev_q) / ABS(NULLIF(l.other_income__export_incentives_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.other_income__export_incentives AS prior_yr_q,
        (l.other_income__export_incentives - p.other_income__export_incentives) / ABS(NULLIF(p.other_income__export_incentives, 0)) * 100 AS yoy_pct
      ) AS export_incentives,
      STRUCT(
        l.other_income__lease_rental_income AS value,
        l.other_income__lease_rental_income_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.other_income__lease_rental_income - l.other_income__lease_rental_income_prev_q) / ABS(NULLIF(l.other_income__lease_rental_income_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.other_income__lease_rental_income AS prior_yr_q,
        (l.other_income__lease_rental_income - p.other_income__lease_rental_income) / ABS(NULLIF(p.other_income__lease_rental_income, 0)) * 100 AS yoy_pct
      ) AS lease_rental_income,
      STRUCT(
        l.other_income__fees_income AS value,
        l.other_income__fees_income_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.other_income__fees_income - l.other_income__fees_income_prev_q) / ABS(NULLIF(l.other_income__fees_income_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.other_income__fees_income AS prior_yr_q,
        (l.other_income__fees_income - p.other_income__fees_income) / ABS(NULLIF(p.other_income__fees_income, 0)) * 100 AS yoy_pct
      ) AS fees_income,
      STRUCT(
        l.other_income__income_on_investments AS value,
        l.other_income__income_on_investments_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.other_income__income_on_investments - l.other_income__income_on_investments_prev_q) / ABS(NULLIF(l.other_income__income_on_investments_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.other_income__income_on_investments AS prior_yr_q,
        (l.other_income__income_on_investments - p.other_income__income_on_investments) / ABS(NULLIF(p.other_income__income_on_investments, 0)) * 100 AS yoy_pct
      ) AS income_on_investments,
      STRUCT(
        l.other_income__foreign_exchange_gain AS value,
        l.other_income__foreign_exchange_gain_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.other_income__foreign_exchange_gain - l.other_income__foreign_exchange_gain_prev_q) / ABS(NULLIF(l.other_income__foreign_exchange_gain_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.other_income__foreign_exchange_gain AS prior_yr_q,
        (l.other_income__foreign_exchange_gain - p.other_income__foreign_exchange_gain) / ABS(NULLIF(p.other_income__foreign_exchange_gain, 0)) * 100 AS yoy_pct
      ) AS foreign_exchange_gain,
      STRUCT(
        l.other_income__foreign_exchange_gain_loss AS value,
        l.other_income__foreign_exchange_gain_loss_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.other_income__foreign_exchange_gain_loss - l.other_income__foreign_exchange_gain_loss_prev_q) / ABS(NULLIF(l.other_income__foreign_exchange_gain_loss_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.other_income__foreign_exchange_gain_loss AS prior_yr_q,
        (l.other_income__foreign_exchange_gain_loss - p.other_income__foreign_exchange_gain_loss) / ABS(NULLIF(p.other_income__foreign_exchange_gain_loss, 0)) * 100 AS yoy_pct
      ) AS foreign_exchange_gain_loss,
      STRUCT(
        l.other_income__profit_on_sale_of_investments AS value,
        l.other_income__profit_on_sale_of_investments_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.other_income__profit_on_sale_of_investments - l.other_income__profit_on_sale_of_investments_prev_q) / ABS(NULLIF(l.other_income__profit_on_sale_of_investments_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.other_income__profit_on_sale_of_investments AS prior_yr_q,
        (l.other_income__profit_on_sale_of_investments - p.other_income__profit_on_sale_of_investments) / ABS(NULLIF(p.other_income__profit_on_sale_of_investments, 0)) * 100 AS yoy_pct
      ) AS profit_on_sale_of_investments,
      STRUCT(
        l.other_income__profit_on_sale_of_shares AS value,
        l.other_income__profit_on_sale_of_shares_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.other_income__profit_on_sale_of_shares - l.other_income__profit_on_sale_of_shares_prev_q) / ABS(NULLIF(l.other_income__profit_on_sale_of_shares_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.other_income__profit_on_sale_of_shares AS prior_yr_q,
        (l.other_income__profit_on_sale_of_shares - p.other_income__profit_on_sale_of_shares) / ABS(NULLIF(p.other_income__profit_on_sale_of_shares, 0)) * 100 AS yoy_pct
      ) AS profit_on_sale_of_shares,
      STRUCT(
        l.other_income__profit_on_sale_of_assets AS value,
        l.other_income__profit_on_sale_of_assets_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.other_income__profit_on_sale_of_assets - l.other_income__profit_on_sale_of_assets_prev_q) / ABS(NULLIF(l.other_income__profit_on_sale_of_assets_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.other_income__profit_on_sale_of_assets AS prior_yr_q,
        (l.other_income__profit_on_sale_of_assets - p.other_income__profit_on_sale_of_assets) / ABS(NULLIF(p.other_income__profit_on_sale_of_assets, 0)) * 100 AS yoy_pct
      ) AS profit_on_sale_of_assets,
      STRUCT(
        l.other_income__profit_loss_on_sale_of_investments AS value,
        l.other_income__profit_loss_on_sale_of_investments_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.other_income__profit_loss_on_sale_of_investments - l.other_income__profit_loss_on_sale_of_investments_prev_q) / ABS(NULLIF(l.other_income__profit_loss_on_sale_of_investments_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.other_income__profit_loss_on_sale_of_investments AS prior_yr_q,
        (l.other_income__profit_loss_on_sale_of_investments - p.other_income__profit_loss_on_sale_of_investments) / ABS(NULLIF(p.other_income__profit_loss_on_sale_of_investments, 0)) * 100 AS yoy_pct
      ) AS profit_loss_on_sale_of_investments,
      STRUCT(
        l.other_income__profit_loss_on_sale_of_assets AS value,
        l.other_income__profit_loss_on_sale_of_assets_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.other_income__profit_loss_on_sale_of_assets - l.other_income__profit_loss_on_sale_of_assets_prev_q) / ABS(NULLIF(l.other_income__profit_loss_on_sale_of_assets_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.other_income__profit_loss_on_sale_of_assets AS prior_yr_q,
        (l.other_income__profit_loss_on_sale_of_assets - p.other_income__profit_loss_on_sale_of_assets) / ABS(NULLIF(p.other_income__profit_loss_on_sale_of_assets, 0)) * 100 AS yoy_pct
      ) AS profit_loss_on_sale_of_assets,
      STRUCT(
        l.other_income__provision_written_back AS value,
        l.other_income__provision_written_back_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.other_income__provision_written_back - l.other_income__provision_written_back_prev_q) / ABS(NULLIF(l.other_income__provision_written_back_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.other_income__provision_written_back AS prior_yr_q,
        (l.other_income__provision_written_back - p.other_income__provision_written_back) / ABS(NULLIF(p.other_income__provision_written_back, 0)) * 100 AS yoy_pct
      ) AS provision_written_back,
      STRUCT(
        l.other_income__others AS value,
        l.other_income__others_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.other_income__others - l.other_income__others_prev_q) / ABS(NULLIF(l.other_income__others_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.other_income__others AS prior_yr_q,
        (l.other_income__others - p.other_income__others) / ABS(NULLIF(p.other_income__others, 0)) * 100 AS yoy_pct
      ) AS others
    ) AS other_income,
    STRUCT(
      STRUCT(
        l.shareholding__value AS value,
        l.shareholding__value_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.shareholding__value - l.shareholding__value_prev_q) / ABS(NULLIF(l.shareholding__value_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.shareholding__value AS prior_yr_q,
        (l.shareholding__value - p.shareholding__value) / ABS(NULLIF(p.shareholding__value, 0)) * 100 AS yoy_pct
      ) AS value,
      STRUCT(
        l.shareholding__of_public_share_holding AS value,
        l.shareholding__of_public_share_holding_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.shareholding__of_public_share_holding - l.shareholding__of_public_share_holding_prev_q) / ABS(NULLIF(l.shareholding__of_public_share_holding_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.shareholding__of_public_share_holding AS prior_yr_q,
        (l.shareholding__of_public_share_holding - p.shareholding__of_public_share_holding) / ABS(NULLIF(p.shareholding__of_public_share_holding, 0)) * 100 AS yoy_pct
      ) AS of_public_share_holding,
      STRUCT(
        l.shareholding__number_of_public_share_holding AS value,
        l.shareholding__number_of_public_share_holding_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.shareholding__number_of_public_share_holding - l.shareholding__number_of_public_share_holding_prev_q) / ABS(NULLIF(l.shareholding__number_of_public_share_holding_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.shareholding__number_of_public_share_holding AS prior_yr_q,
        (l.shareholding__number_of_public_share_holding - p.shareholding__number_of_public_share_holding) / ABS(NULLIF(p.shareholding__number_of_public_share_holding, 0)) * 100 AS yoy_pct
      ) AS number_of_public_share_holding,
      STRUCT(
        l.shareholding__encumbered_of_promoter_holdings AS value,
        l.shareholding__encumbered_of_promoter_holdings_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.shareholding__encumbered_of_promoter_holdings - l.shareholding__encumbered_of_promoter_holdings_prev_q) / ABS(NULLIF(l.shareholding__encumbered_of_promoter_holdings_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.shareholding__encumbered_of_promoter_holdings AS prior_yr_q,
        (l.shareholding__encumbered_of_promoter_holdings - p.shareholding__encumbered_of_promoter_holdings) / ABS(NULLIF(p.shareholding__encumbered_of_promoter_holdings, 0)) * 100 AS yoy_pct
      ) AS encumbered_of_promoter_holdings,
      STRUCT(
        l.shareholding__encumbered_of_share_capital AS value,
        l.shareholding__encumbered_of_share_capital_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.shareholding__encumbered_of_share_capital - l.shareholding__encumbered_of_share_capital_prev_q) / ABS(NULLIF(l.shareholding__encumbered_of_share_capital_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.shareholding__encumbered_of_share_capital AS prior_yr_q,
        (l.shareholding__encumbered_of_share_capital - p.shareholding__encumbered_of_share_capital) / ABS(NULLIF(p.shareholding__encumbered_of_share_capital, 0)) * 100 AS yoy_pct
      ) AS encumbered_of_share_capital,
      STRUCT(
        l.shareholding__encumbered_no_of_shares AS value,
        l.shareholding__encumbered_no_of_shares_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.shareholding__encumbered_no_of_shares - l.shareholding__encumbered_no_of_shares_prev_q) / ABS(NULLIF(l.shareholding__encumbered_no_of_shares_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.shareholding__encumbered_no_of_shares AS prior_yr_q,
        (l.shareholding__encumbered_no_of_shares - p.shareholding__encumbered_no_of_shares) / ABS(NULLIF(p.shareholding__encumbered_no_of_shares, 0)) * 100 AS yoy_pct
      ) AS encumbered_no_of_shares,
      STRUCT(
        l.shareholding__non_encumbered AS value,
        l.shareholding__non_encumbered_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.shareholding__non_encumbered - l.shareholding__non_encumbered_prev_q) / ABS(NULLIF(l.shareholding__non_encumbered_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.shareholding__non_encumbered AS prior_yr_q,
        (l.shareholding__non_encumbered - p.shareholding__non_encumbered) / ABS(NULLIF(p.shareholding__non_encumbered, 0)) * 100 AS yoy_pct
      ) AS non_encumbered,
      STRUCT(
        l.shareholding__non_encumbered_of_promoter_holdings AS value,
        l.shareholding__non_encumbered_of_promoter_holdings_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.shareholding__non_encumbered_of_promoter_holdings - l.shareholding__non_encumbered_of_promoter_holdings_prev_q) / ABS(NULLIF(l.shareholding__non_encumbered_of_promoter_holdings_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.shareholding__non_encumbered_of_promoter_holdings AS prior_yr_q,
        (l.shareholding__non_encumbered_of_promoter_holdings - p.shareholding__non_encumbered_of_promoter_holdings) / ABS(NULLIF(p.shareholding__non_encumbered_of_promoter_holdings, 0)) * 100 AS yoy_pct
      ) AS non_encumbered_of_promoter_holdings,
      STRUCT(
        l.shareholding__non_encumbered_of_share_capital AS value,
        l.shareholding__non_encumbered_of_share_capital_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.shareholding__non_encumbered_of_share_capital - l.shareholding__non_encumbered_of_share_capital_prev_q) / ABS(NULLIF(l.shareholding__non_encumbered_of_share_capital_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.shareholding__non_encumbered_of_share_capital AS prior_yr_q,
        (l.shareholding__non_encumbered_of_share_capital - p.shareholding__non_encumbered_of_share_capital) / ABS(NULLIF(p.shareholding__non_encumbered_of_share_capital, 0)) * 100 AS yoy_pct
      ) AS non_encumbered_of_share_capital,
      STRUCT(
        l.shareholding__non_encumbered_no_of_shares AS value,
        l.shareholding__non_encumbered_no_of_shares_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.shareholding__non_encumbered_no_of_shares - l.shareholding__non_encumbered_no_of_shares_prev_q) / ABS(NULLIF(l.shareholding__non_encumbered_no_of_shares_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.shareholding__non_encumbered_no_of_shares AS prior_yr_q,
        (l.shareholding__non_encumbered_no_of_shares - p.shareholding__non_encumbered_no_of_shares) / ABS(NULLIF(p.shareholding__non_encumbered_no_of_shares, 0)) * 100 AS yoy_pct
      ) AS non_encumbered_no_of_shares,
      STRUCT(
        l.shareholding__promoters_no_of_shares AS value,
        l.shareholding__promoters_no_of_shares_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.shareholding__promoters_no_of_shares - l.shareholding__promoters_no_of_shares_prev_q) / ABS(NULLIF(l.shareholding__promoters_no_of_shares_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.shareholding__promoters_no_of_shares AS prior_yr_q,
        (l.shareholding__promoters_no_of_shares - p.shareholding__promoters_no_of_shares) / ABS(NULLIF(p.shareholding__promoters_no_of_shares, 0)) * 100 AS yoy_pct
      ) AS promoters_no_of_shares,
      STRUCT(
        l.shareholding__of_shares_held_by_govt AS value,
        l.shareholding__of_shares_held_by_govt_prev_q AS prev_q,
        IF(
        DATE_DIFF(
          PARSE_DATE('%Y%m', CAST(l.yyyymm AS STRING)),
          PARSE_DATE('%Y%m', CAST(l.prev_yyyymm AS STRING)),
          MONTH)
          = 3,
        (l.shareholding__of_shares_held_by_govt - l.shareholding__of_shares_held_by_govt_prev_q) / ABS(NULLIF(l.shareholding__of_shares_held_by_govt_prev_q, 0)) * 100,
        NULL) AS qoq_pct,
        p.shareholding__of_shares_held_by_govt AS prior_yr_q,
        (l.shareholding__of_shares_held_by_govt - p.shareholding__of_shares_held_by_govt) / ABS(NULLIF(p.shareholding__of_shares_held_by_govt, 0)) * 100 AS yoy_pct
      ) AS of_shares_held_by_govt
    ) AS shareholding
  ) AS income_growth
FROM lagged l
LEFT JOIN base p
  ON p.company_id = l.company_id
 AND COALESCE(p.flag, '') = COALESCE(l.flag, '')
 AND p.yyyymm = l.yyyymm - 100;
END
