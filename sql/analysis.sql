
CREATE TABLE marketing_campaign_clean (
    id INTEGER PRIMARY KEY,
    year_birth SMALLINT,
    education VARCHAR(50),
    marital_status VARCHAR(30),
    income NUMERIC(12,2),
    kidhome SMALLINT,
    teenhome SMALLINT,
    dt_customer DATE,
    recency INTEGER,
    mntwines INTEGER,
    mntfruits INTEGER,
    mntmeatproducts INTEGER,
    mntfishproducts INTEGER,
    mntsweetproducts INTEGER,
    mntgoldprods INTEGER,
    numdealspurchases INTEGER,
    numwebpurchases INTEGER,
    numcatalogpurchases INTEGER,
    numstorepurchases INTEGER,
    numwebvisitsmonth INTEGER,
    acceptedcmp3 SMALLINT,
    acceptedcmp4 SMALLINT,
    acceptedcmp5 SMALLINT,
    acceptedcmp1 SMALLINT,
    acceptedcmp2 SMALLINT,
    complain SMALLINT,
    z_costcontact INTEGER,
    z_revenue INTEGER,
    response SMALLINT,
    income_was_missing BOOLEAN,
    income_iqr_outlier BOOLEAN,
    income_extreme_flag BOOLEAN,
    birth_year_flag BOOLEAN,
    marital_status_review BOOLEAN,
    marital_status_standardized VARCHAR(30)
);

-- 1. Check total rows
SELECT COUNT(*) AS total_customers
FROM marketing_campaign_clean;


-- 2. Preview the data
SELECT *
FROM marketing_campaign_clean
LIMIT 5;


-- 3. Check cleaning flags
SELECT
    COUNT(*) FILTER (
        WHERE income_was_missing
    ) AS imputed_income,

    COUNT(*) FILTER (
        WHERE income_iqr_outlier
    ) AS income_outliers,

    COUNT(*) FILTER (
        WHERE birth_year_flag
    ) AS birth_year_anomalies

FROM marketing_campaign_clean;



-- What does our current customer base look like, and how successful are our marketing campaigns?

-- 1, Finding total customer / mencari total customer: 

SELECT

	COUNT(*) AS total_customers -- count every row as total customers / menghitung total ROWS 

FROM marketing_campaign_clean;

-- 2. Average Income / mencari rata-rata pendapatan seluruh customer

SELECT

	AVG(income) AS average_income

FROM marketing_campaign_clean;

-- 3. Average customer spending / mencari rata-rata spending customer
-- products: wines, fruits, meat, fish, sweet, gold AS total spending.

SELECT

	ROUND(

		AVG(
			COALESCE(mntwines, 0)
            + COALESCE(mntfruits, 0)
            + COALESCE(mntmeatproducts, 0)
            + COALESCE(mntfishproducts, 0)
            + COALESCE(mntsweetproducts, 0)
            + COALESCE(mntgoldprods, 0)
        )::numeric,
        2
		
    ) AS avg_customer_spending
	
FROM marketing_campaign_clean;

-- 4. Average Recency (days) / rata-rata terakhir kali purchase (dalam hari)

SELECT

	ROUND(
	
		AVG(recency)::numeric,
		2
		
	) AS avg_recency

FROM marketing_campaign_clean;

-- 5. Responded Customers to campaign

SELECT

	COUNT(*) FILTER(
		WHERE response = 1
		
	) AS responded_customers
	
FROM marketing_campaign_clean;

-- 6. Response rate

SELECT

	ROUND(
		(
			COUNT(*) FILTER (WHERE response = 1) * 100.0 
			/ NULLIF(COUNT(*), 0)
			
		)::numeric,
		2
	) AS response_rate_pct

FROM marketing_campaign_clean;

-- 7. The marketing team wants to understand whether customers with different education backgrounds respond differently to marketing campaigns.
-- segment | total cust | avg spending | respondend | resp. rate

SELECT

	education,
	
	COUNT(*) AS total_customers,
	
	COUNT(*) FILTER (
		WHERE response = 1
		
	) AS total_response,

	
	ROUND(
		(
			COUNT(*) FILTER (WHERE response = 1) * 100.0
			/ NULLIF(COUNT(*), 0)
			
		)::numeric,
		2
	) AS response_rate

FROM marketing_campaign_clean

GROUP BY 1
ORDER BY response_rate DESC;

-- 8 Customer segment high/low spending and response rate

WITH customer_spending AS (
    -- 1. Calculate total spending for each customer
    SELECT
        id,
        response,

        COALESCE(mntwines, 0)
        + COALESCE(mntfruits, 0)
        + COALESCE(mntmeatproducts, 0)
        + COALESCE(mntfishproducts, 0)
        + COALESCE(mntsweetproducts, 0)
        + COALESCE(mntgoldprods, 0) AS total_spending

    FROM marketing_campaign_clean
),

spending_median AS (
    -- 2. Calculate median total spending
    SELECT
        PERCENTILE_CONT(0.5)
        WITHIN GROUP (
            ORDER BY total_spending
        ) AS median_spending

    FROM customer_spending
),

customer_segments AS (
    -- 3. Classify customers into spending segments
    SELECT
        cs.id,
        cs.response,
        cs.total_spending,

        CASE
            WHEN cs.total_spending >= sm.median_spending
                THEN 'High Spending'
            ELSE 'Low Spending'
        END AS customer_segment

    FROM customer_spending cs
    CROSS JOIN spending_median sm
)

-- 4. Analyze campaign response by segment
SELECT
    customer_segment,

    COUNT(*) AS total_customers,

    ROUND(
        AVG(total_spending)::numeric,
        2
    ) AS avg_spending,

    COUNT(*) FILTER (
        WHERE response = 1
    ) AS responded_customers,

    ROUND(
        (
            COUNT(*) FILTER (WHERE response = 1) * 100.0
            / NULLIF(COUNT(*), 0)
        )::numeric,
        2
    ) AS response_rate_pct

FROM customer_segments

GROUP BY customer_segment

ORDER BY response_rate_pct DESC;

--- 9 Response rate by education

SELECT

	education,
	
	COUNT(*) AS total_customers,
	
	COUNT(*) FILTER (
		WHERE response = 1
		
	) AS total_response,

	
	ROUND(
		(
			COUNT(*) FILTER (WHERE response = 1) * 100.0
			/ NULLIF(COUNT(*), 0)
			
		)::numeric,
		2
	) AS response_rate

FROM marketing_campaign_clean

GROUP BY 1
ORDER BY response_rate DESC;

	
-- 10 Which Marketing Campaign Performed Best?

WITH campaign_response AS(

	SELECT
		'Campaign 1' AS campaign,
		acceptedcmp1 AS accepted
	FROM marketing_campaign_clean

	UNION ALL

	SELECT
		'Campaign 2' AS campaign,
		acceptedcmp2 AS accepted
	FROM marketing_campaign_clean

	UNION ALL

	SELECT
		'Campaign 3' AS campaign,
		acceptedcmp3 AS accepted
	FROM marketing_campaign_clean

	UNION ALL

	SELECT
		'Campaign 4' AS campaign,
		acceptedcmp4 AS accepted
	FROM marketing_campaign_clean

	UNION ALL

	SELECT
		'Campaign 5' AS campaign,
		acceptedcmp5 AS accepted
	FROM marketing_campaign_clean


),

campaign_performance AS(

	SELECT

		campaign,
		COUNT(*) AS total_customers,

		SUM(accepted) AS accepted_customers,

		ROUND(
            SUM(accepted)::numeric
            * 100.0
            / NULLIF(COUNT(*), 0),
            2
        ) AS acceptance_rate_pct

    FROM campaign_response
    GROUP BY campaign

)


SELECT

	campaign,
	total_customers,
	accepted_customers,
	acceptance_rate_pct

FROM campaign_performance
ORDER BY acceptance_rate_pct,
			accepted_customers DESC;

--- 11 Do Loyal Customers Respond Better?

WITH previous_accepted_campaign AS (
    SELECT
        ID,

        COALESCE(acceptedcmp1, 0)
        + COALESCE(acceptedcmp2, 0)
        + COALESCE(acceptedcmp3, 0)
        + COALESCE(acceptedcmp4, 0)
        + COALESCE(acceptedcmp5, 0)
            AS previous_accepted_campaign,

        Response

    FROM marketing_campaign_clean
)

SELECT
    previous_accepted_campaign,

    COUNT(*) AS total_customers,

    COUNT(*) FILTER (
        WHERE Response = 1
    ) AS accepted_customers,

    ROUND(
        COUNT(*) FILTER (WHERE Response = 1) * 100.0
        / NULLIF(COUNT(*), 0),
        2
    ) AS response_rate_pct

FROM previous_accepted_campaign

GROUP BY previous_accepted_campaign
ORDER BY previous_accepted_campaign ASC;



------ 12 Do customers who respond to marketing campaigns demonstrate different purchasing behaviors compared to non-responders?


WITH customers_metric AS (
    SELECT
        ID,
        Response,

        COALESCE(mntwines, 0)
        + COALESCE(mntfruits, 0)
        + COALESCE(mntmeatproducts, 0)
        + COALESCE(mntfishproducts, 0)
        + COALESCE(mntsweetproducts, 0)
        + COALESCE(mntgoldprods, 0) AS total_spending,

        numwebpurchases AS web_purchases,
        numcatalogpurchases AS catalog_purchases,
        numstorepurchases AS store_purchases,
        numwebvisitsmonth AS web_visits

    FROM marketing_campaign_clean
)

SELECT
    CASE
        WHEN Response = 1 THEN 'Responded'
        ELSE 'Not Responded'
    END AS customer_group,

    COUNT(*) AS total_customers,

    ROUND(AVG(total_spending), 2) AS avg_spending,
    ROUND(AVG(web_purchases), 2) AS avg_web_purchases,
    ROUND(AVG(catalog_purchases), 2) AS avg_catalog_purchases,
    ROUND(AVG(store_purchases), 2) AS avg_store_purchases,
    ROUND(AVG(web_visits), 2) AS avg_web_visits

FROM customers_metric

GROUP BY Response
ORDER BY Response DESC;



-- 13 Are high-spending customers more likely to respond to marketing campaigns than medium- and low-spending customers?

WITH customers_spending AS(

	SELECT
		ID,
		Response,
		(
			COALESCE(mntwines, 0)
	        + COALESCE(mntfruits, 0)
	        + COALESCE(mntmeatproducts, 0)
	        + COALESCE(mntfishproducts, 0)
	        + COALESCE(mntsweetproducts, 0)
	        + COALESCE(mntgoldprods, 0) 
		)	AS total_spending

	FROM marketing_campaign_clean
),

customer_segment AS (

    SELECT
        ID,
        Response,
        total_spending,

        CASE NTILE(3) OVER (
            ORDER BY total_spending ASC
        )
            WHEN 1 THEN 'Low'
            WHEN 2 THEN 'Medium'
            WHEN 3 THEN 'High'
        END AS spending_segment

    FROM customers_spending

)

SELECT

	spending_segment,
	COUNT(*) total_customers,
	COUNT(*) FILTER (WHERE response = 1) AS responded_customers,
	avg(total_spending) AS avg_spending,
	ROUND(
    (
        COUNT(*) FILTER (WHERE response = 1) * 100.0
        / NULLIF(COUNT(*), 0)
    )::numeric,
    2
) AS response_rate_pct

FROM customer_segment
GROUP BY spending_segment
ORDER BY
    CASE spending_segment
        WHEN 'Low' THEN 1
        WHEN 'Medium' THEN 2
        WHEN 'High' THEN 3
    END;

-- 14 How does purchase channel behavior differ across low-, medium-, and high-spending customers?

WITH customer_metrics AS(

	SELECT

		ID,
		Response,
		(
			COALESCE(mntwines, 0)
	        + COALESCE(mntfruits, 0)
	        + COALESCE(mntmeatproducts, 0)
	        + COALESCE(mntfishproducts, 0)
	        + COALESCE(mntsweetproducts, 0)
	        + COALESCE(mntgoldprods, 0) 
		)	AS total_spending,

		numwebpurchases AS web_purchases,
		numcatalogpurchases AS catalog_purchases,
		numstorepurchases AS store_purchases,

		(numwebpurchases + numcatalogpurchases + numstorepurchases) AS all_channel_purchases

	FROM marketing_campaign_clean
		
),

customer_segment AS(

	SELECT
	
		*,
		CASE NTILE(3) OVER(
			ORDER BY total_spending ASC
		) 
			WHEN 1 THEN 'Low'
			WHEN 2 THEN 'Medium'
			WHEN 3 THEN 'High'
		END AS spending_segment

	FROM customer_metrics
)

SELECT

	spending_segment AS segment,
	COUNT(*) total_customers,
	
	ROUND(avg(web_purchases)::numeric, 2) AS avg_web,
	ROUND(avg(catalog_purchases)::numeric, 2) AS avg_catalog,
	ROUND(avg(store_purchases)::numeric, 2) AS avg_store,

	ROUND(
	(
	SUM(web_purchases) * 100.0 / 
	NULLIF(SUM(all_channel_purchases), 0)
	)::numeric, 2
	)AS web_share,

	ROUND(
	(
	SUM(catalog_purchases) * 100.0 / 
	NULLIF(SUM(all_channel_purchases), 0)
	)::numeric,2
	) AS catalog_share,

	ROUND(
	(
	SUM(store_purchases) * 100.0 / 
	NULLIF(SUM(all_channel_purchases), 0)
	)::numeric, 2
	) AS store_share



FROM customer_segment
GROUP BY spending_segment
ORDER BY
	CASE spending_segment
		WHEN 'Low' THEN 1
		WHEN 'Medium' THEN 2
		WHEN 'High' THEN 3
	END;

--15 What Makes Customers Respond to Campaigns?
-- What behavioral differences distinguish customers who responded to the campaign from those who did not?

WITH customer_metrics AS(

	SELECT

		ID,
		Response,
		(
			COALESCE(mntwines, 0)
	        + COALESCE(mntfruits, 0)
	        + COALESCE(mntmeatproducts, 0)
	        + COALESCE(mntfishproducts, 0)
	        + COALESCE(mntsweetproducts, 0)
	        + COALESCE(mntgoldprods, 0) 
		)	AS total_spending,

		(acceptedcmp1 + acceptedcmp2 + acceptedcmp3 + acceptedcmp4 + acceptedcmp5) AS previous_campaigns,

		numwebpurchases AS web_purchases,
		numcatalogpurchases AS catalog_purchases,
		numstorepurchases AS store_purchases

	FROM marketing_campaign_clean

)

SELECT
    CASE
        WHEN Response = 1 THEN 'Responded'
        ELSE 'Not Responded'
    END AS customer_group,

    COUNT(*) AS total_customers,

    ROUND(AVG(total_spending), 2) AS avg_spending,
    ROUND(AVG(web_purchases), 2) AS avg_web_purchases,
    ROUND(AVG(catalog_purchases), 2) AS avg_catalog_purchases,
    ROUND(AVG(store_purchases), 2) AS avg_store_purchases,
	ROUND(AVG(previous_campaigns), 2) AS avg_previous_campaigns
	
FROM customer_metrics

GROUP BY Response
ORDER BY Response DESC;
 
-- 16 Who should marketing prioritize?
-- Which customer segment offers the strongest opportunity for future marketing campaigns?


WITH customer_metrics AS(

	SELECT

		ID,
		Response,
		(
			COALESCE(mntwines, 0)
	        + COALESCE(mntfruits, 0)
	        + COALESCE(mntmeatproducts, 0)
	        + COALESCE(mntfishproducts, 0)
	        + COALESCE(mntsweetproducts, 0)
	        + COALESCE(mntgoldprods, 0) 
		)	AS total_spending,

		(acceptedcmp1 + acceptedcmp2 + acceptedcmp3 + acceptedcmp4 + acceptedcmp5) AS previous_campaigns_accepted

	FROM marketing_campaign_clean
		
)

SELECT

	previous_campaigns_accepted,
	COUNT(*) AS total_customers,
	ROUND(AVG(total_spending), 2) AS avg_spending,

	COUNT(*) FILTER (WHERE Response = 1) AS responded_customers,
	ROUND(
			(
				COUNT(*) FILTER (WHERE Response = 1) * 100.0
				/ NULLIF(COUNT(*), 0))::numeric,
				2
			) AS response_rate

FROM customer_metrics
GROUP BY previous_campaigns_accepted
ORDER BY previous_campaigns_accepted ASC;