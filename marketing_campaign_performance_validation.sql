-- Check duplicates
SELECT performance_id, COUNT(*) cnt
FROM dbo.ad_engagement_daily
GROUP BY performance_id
HAVING COUNT(*) > 1

SELECT performance_id, COUNT(*) cnt
FROM dbo.ad_profit_daily
GROUP BY performance_id
HAVING COUNT(*) > 1

-- Row count comparison between staging vs fact tables
SELECT
  (SELECT COUNT(*) FROM dbo.stg_marketing_raw) AS stg_rows,
  (SELECT COUNT(*) FROM dbo.ad_performance_daily) AS perf_rows,
  (SELECT COUNT(*) FROM dbo.ad_engagement_daily) AS eng_rows,
  (SELECT COUNT(*) FROM dbo.ad_profit_daily) AS profit_rows

-- Validate result in Tableau
-- KPIs
SELECT
  SUM(impressions) AS impressions,
  SUM(clicks) AS clicks,
  SUM(spend_gbp) AS spend_gbp,
  SUM(conversions) AS conversions,
  SUM(conversion_value_gbp) AS conversion_value_gbp
FROM dbo.ad_performance_daily
WHERE [date] BETWEEN '2024-03-01' AND '2024-03-31'

-- vs after join
SELECT
  SUM(f.impressions) AS impressions,
  SUM(f.clicks) AS clicks,
  SUM(f.spend_gbp) AS spend_gbp
FROM dbo.ad_performance_daily f
LEFT JOIN dbo.ad_engagement_daily e ON e.performance_id = f.performance_id
LEFT JOIN dbo.ad_profit_daily p ON p.performance_id = f.performance_id;

-- Validate values in Tableau (top channels/cities,funnel rates, seasonality, outliers, negative profit)
DECLARE @date_from date = '2024-01-01'
DECLARE @date_to   date = '2024-06-30'

WITH base AS (
    SELECT
        f.performance_id,
        f.[date],
        f.channel_id,
        f.location_id,
        f.impressions,
        f.clicks,
        f.spend_gbp,
        f.conversions,
        f.conversion_value_gbp,
        e.likes,
        e.shares,
        e.comments,
        p.net_profit_gbp
    FROM dbo.ad_performance_daily f
    LEFT JOIN dbo.ad_engagement_daily e ON e.performance_id = f.performance_id
    LEFT JOIN dbo.ad_profit_daily p     ON p.performance_id = f.performance_id
    WHERE f.[date] BETWEEN @date_from AND @date_to
),
kpi AS (
    SELECT
        SUM(COALESCE(impressions,0)) AS impressions,
        SUM(COALESCE(clicks,0)) AS clicks,
        SUM(COALESCE(spend_gbp,0)) AS spend_gbp,
        SUM(COALESCE(conversions,0)) AS conversions,
        SUM(COALESCE(conversion_value_gbp,0)) AS conv_value_gbp,
        SUM(COALESCE(net_profit_gbp,0)) AS net_profit_gbp,
        CAST(SUM(COALESCE(clicks,0)) AS decimal(18,6)) / NULLIF(SUM(COALESCE(impressions,0)),0) AS ctr,
        CAST(SUM(COALESCE(conversions,0)) AS decimal(18,6)) / NULLIF(SUM(COALESCE(clicks,0)),0) AS cvr,
        SUM(COALESCE(conversion_value_gbp,0)) / NULLIF(SUM(COALESCE(spend_gbp,0)),0) AS roas
    FROM base
),
by_channel AS (
    SELECT
        channel_id,
        SUM(COALESCE(spend_gbp,0)) AS spend_gbp,
        SUM(COALESCE(conversion_value_gbp,0)) AS conv_value_gbp,
        SUM(COALESCE(conversion_value_gbp,0)) / NULLIF(SUM(COALESCE(spend_gbp,0)),0) AS roas
    FROM base
    GROUP BY channel_id
),
issues AS (
    SELECT TOP (50)
        performance_id, [date], channel_id, location_id,
        impressions, clicks, conversions, spend_gbp, conversion_value_gbp
    FROM base
    WHERE clicks > impressions
       OR spend_gbp < 0
       OR conversions < 0
       OR conversion_value_gbp < 0
       OR (impressions > 0 AND CAST(clicks AS decimal(18,6))/impressions > 0.30)
       OR (clicks > 0 AND CAST(conversions AS decimal(18,6))/clicks > 0.80)
    ORDER BY [date] DESC
)

-- 1) Overall totals (compare to Tableau grand totals)
SELECT * FROM kpi

-- 2) ROAS by channel (compare to Tableau bar chart)
-- SELECT TOP (10) ch.channel_name, bc.*
-- FROM by_channel bc
-- JOIN dbo.dim_channel ch ON ch.channel_id = bc.channel_id
-- ORDER BY bc.roas DESC

-- 3) Data issues/outliers to investigate when Tableau looks “wrong”
-- SELECT * FROM issues

