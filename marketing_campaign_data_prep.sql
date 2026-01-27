-- 1. Staging table (raw import from SSIS)
CREATE TABLE dbo.stg_marketing_daily (
    Campaign nvarchar(100),
    [Date] date,
    [City/Location] nvarchar(100),
    Latitude decimal(9,6),
    Longitude decimal(9,6),
    Channel nvarchar(50),
    Device nvarchar(50),
    Ad nvarchar(100),
    Impressions bigint,
    Clicks int,
    [Daily Average CPC] decimal(18,6),
    [Spend, GBP] decimal(18,6),
    Conversions int,
    [Total conversion value, GBP] decimal(18,6),
    [Likes (Reactions)] int,
    Shares int,
    Comments int,
    [Net Profit, GBP] decimal(18,6),
    [Profit adjusted] decimal(18,6)
)

-- 2. Dimension tables
-- 2.1 campaign table
CREATE TABLE dbo.campaigns (
    campaign_id int IDENTITY(1,1) PRIMARY KEY,
    campaign_name nvarchar(100) NOT NULL UNIQUE,
    start_date date NULL,
    end_date date NULL
)

-- 2.2 channels table
CREATE TABLE dbo.channels (
    channel_id int IDENTITY(1,1) PRIMARY KEY,
    channel_name nvarchar(50) NOT NULL UNIQUE
)

-- 2.3 devices table
CREATE TABLE dbo.devices (
    device_id int IDENTITY(1,1) PRIMARY KEY,
    device_name nvarchar(50) NOT NULL UNIQUE
)

-- 2.4 locations table
CREATE TABLE dbo.locations (
    location_id int IDENTITY(1,1) PRIMARY KEY,
    city nvarchar(100) NOT NULL,
    latitude decimal(9,6) NULL,
    longitude decimal(9,6) NULL
)

CREATE INDEX IX_locations_city
ON dbo.locations (city)

-- 2.5 ads table
CREATE TABLE dbo.ads (
    ad_id int IDENTITY(1,1) PRIMARY KEY,
    ad_name nvarchar(100) NOT NULL,
    channel_id int NOT NULL,

    CONSTRAINT FK_ads_channels
        FOREIGN KEY (channel_id)
        REFERENCES dbo.channels (channel_id)
)

CREATE UNIQUE INDEX UX_ads_ad_channel
ON dbo.ads (ad_name, channel_id);


-- 3. Fact tables
-- 3.1 ad_performance_daily table
CREATE TABLE dbo.ad_performance_daily (
    performance_id int IDENTITY(1,1) PRIMARY KEY,

    [date] date NOT NULL,
    campaign_id int NOT NULL,
    ad_id int NOT NULL,
    channel_id int NOT NULL,
    device_id int NOT NULL,
    location_id int NOT NULL,
    impressions bigint NULL,
    clicks int NULL,
    avg_cpc decimal(18,6) NULL,
    spend_gbp decimal(18,6) NULL,
    conversions int NULL,
    conversion_value_gbp decimal(18,6) NULL,

    CONSTRAINT FK_perf_campaign
        FOREIGN KEY (campaign_id)
        REFERENCES dbo.campaigns (campaign_id),

    CONSTRAINT FK_perf_ad
        FOREIGN KEY (ad_id)
        REFERENCES dbo.ads (ad_id),

    CONSTRAINT FK_perf_channel
        FOREIGN KEY (channel_id)
        REFERENCES dbo.channels (channel_id),

    CONSTRAINT FK_perf_device
        FOREIGN KEY (device_id)
        REFERENCES dbo.devices (device_id),

    CONSTRAINT FK_perf_location
        FOREIGN KEY (location_id)
        REFERENCES dbo.locations (location_id),

    CONSTRAINT UX_perf_grain
        UNIQUE ([date], campaign_id, ad_id, channel_id, device_id, location_id)
)

-- 3.2 ad_engagement_daily table
CREATE TABLE dbo.ad_engagement_daily (
    performance_id int PRIMARY KEY,
    likes int NULL,
    shares int NULL,
    comments int NULL,

    CONSTRAINT FK_engagement_perf
        FOREIGN KEY (performance_id)
        REFERENCES dbo.ad_performance_daily (performance_id)
)

-- 3.3 ad_profit_daily table
CREATE TABLE dbo.ad_profit_daily (
    performance_id int PRIMARY KEY,
    net_profit_gbp decimal(18,6) NULL,
    profit_adjusted_gbp decimal(18,6) NULL,

    CONSTRAINT FK_profit_perf
        FOREIGN KEY (performance_id)
        REFERENCES dbo.ad_performance_daily (performance_id)
)
