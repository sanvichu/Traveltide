WITH UserSessions AS (
  SELECT user_id
  FROM sessions
  WHERE session_start >= '2023-01-04'  
  GROUP BY user_id
  HAVING COUNT(session_id) > 7
),
UserTravelSpendSummary AS (
  SELECT
    u.user_id,
    AVG(s.hotel_discount_amount * (h.hotel_per_room_usd * h.rooms)) AS ADS_hotel,
    COALESCE(SUM(h.hotel_per_room_usd * h.rooms),0) AS total_hotel_usd_spent,
    COALESCE(SUM(f.base_fare_usd ),0) AS total_flight_usd_spent,
    COALESCE(SUM(h.hotel_per_room_usd * h.rooms) + SUM(f.base_fare_usd ),0) AS total_usd_spent
  FROM UserSessions us
  JOIN users u ON u.user_id = us.user_id
  LEFT JOIN sessions s ON s.user_id = u.user_id
  LEFT JOIN flights f ON f.trip_id = s.trip_id
  LEFT JOIN hotels h ON h.trip_id = s.trip_id
  GROUP BY u.user_id
  ORDER BY ADS_hotel DESC
),
MinMaxAdsHotel AS (
  SELECT
    MIN(ADS_hotel) AS min_hotel_ads,
    MAX(ADS_hotel) AS max_hotel_ads
  FROM UserTravelSpendSummary 
),
ScaledTravelMetrics AS (
  SELECT 
    utss.user_id,
    utss.ADS_hotel,
    CASE
      WHEN (utss.ADS_hotel - mma.min_hotel_ads) /
         (mma.max_hotel_ads - mma.min_hotel_ads) IS NULL THEN 0
      ELSE (utss.ADS_hotel - mma.min_hotel_ads) /
         (mma.max_hotel_ads - mma.min_hotel_ads)
    END AS scaled_hotel_ads
  FROM UserTravelSpendSummary utss 
  CROSS JOIN MinMaxAdsHotel mma
),
UserDiscountMetrics AS (
  SELECT
    u.user_id,
    COALESCE(AVG(s.flight_discount_amount),0) AS average_flight_discount,
    COALESCE(AVG(s.hotel_discount_amount),0) AS average_hotel_discount, 
    COALESCE(SUM(
      CASE
        WHEN s.flight_discount = 'true' AND s.flight_discount_amount > 0 AND s.hotel_discount = 'false' THEN 1 
        ELSE 0
      END
    ) :: FLOAT / COUNT(*)
    ,0) AS flight_discount_proportion,
    COALESCE(SUM(
      CASE 
       WHEN hotel_discount = 'true' AND s.hotel_discount_amount > 0 AND s.flight_discount ='false' THEN 1  
       ELSE 0 
      END) :: FLOAT / COUNT(*)
    ,0) AS hotel_discount_proportion,
     COALESCE(SUM(
      CASE
        WHEN s.flight_discount = 'true' AND s.flight_discount_amount > 0 AND s.hotel_discount = 'true' AND s.hotel_discount_amount > 0 THEN 1
        ELSE 0
      END) :: FLOAT / COUNT(*)
    ,0) AS both_discount_proportion, 
    COUNT(
      CASE
        WHEN s.flight_booked = 'true' AND s.hotel_booked = 'false' THEN s.trip_id
        ELSE NULL
      END
    ) AS total_only_flights,
    COUNT(
      CASE
         WHEN s.hotel_booked = 'true' AND s.flight_booked ='false' THEN s.trip_id
         ELSE NULL
      END
     ) AS total_only_hotels,
    COUNT(
      CASE
         WHEN s.hotel_booked = 'true' AND s.flight_booked ='true' THEN s.trip_id
         ELSE NULL
      END
     ) AS total_together,
    COUNT(s.trip_id) AS total_trips,  
    COUNT(s.trip_id IS NOT NULL) AS total_sessions,
    AVG(s.page_clicks) AS average_clicks,
    SUM(s.page_clicks) AS total_clicks,  
    COUNT(
     DISTINCT 
       CASE 
         WHEN s.cancellation = 'true' THEN s.trip_id 
         ELSE NULL 
       END
    ) AS total_cancellations,
    COALESCE(AVG(f.checked_bags),0) AS average_checked_bags
  FROM UserSessions us
  JOIN users u ON u.user_id = us.user_id
  LEFT JOIN sessions s ON s.user_id = u.user_id
  LEFT JOIN flights f ON f.trip_id = s.trip_id
  LEFT JOIN hotels h ON h.trip_id = s.trip_id
GROUP BY u.user_id
ORDER BY u.user_id ASC
),
UserBehaviorIndices AS (
  SELECT
    udm.user_id,
    udm.average_checked_bags,
    COALESCE(
      (udm.total_cancellations::FLOAT
       / NULLIF(udm.total_trips::FLOAT ,0))
    ,0) AS total_cancellation_rate,
    COALESCE(
      (udm.average_clicks * udm.total_trips)::FLOAT
             / udm.total_clicks
    ,0) AS engagement_index,
    COALESCE(
      udm.total_trips::FLOAT 
      / udm.total_sessions
    ,0) AS conversion_rate,
    COALESCE(
      udm.total_only_flights::FLOAT 
      / 
      NULLIF(udm.total_trips,0)
    ,0) AS prefers_flights,
    COALESCE(
      udm.total_only_hotels::FLOAT 
      / 
      NULLIF(udm.total_trips,0)
    ,0) AS prefers_hotels,
    COALESCE(
      udm.total_together::FLOAT
      / 
      NULLIF(udm.total_trips,0)
    ,0) AS prefers_both,  
   COALESCE(
      (udm.flight_discount_proportion * udm.total_only_flights +
      udm.hotel_discount_proportion * udm.total_only_hotels + 
      udm.both_discount_proportion * udm.total_together)
      / 
      NULLIF(udm.total_trips,0)
    ,0) AS discount_responsiveness,
    COALESCE(
      udm.total_clicks::FLOAT
      / NULLIF(udm.total_trips,0)
    ,0) AS click_efficiency
  FROM UserDiscountMetrics udm
),
FinalQuery AS (
  SELECT
    u.user_id,
    COALESCE(u.birthdate) AS birthdate,
    COALESCE(u.gender, '') AS gender,
    COALESCE(u.married) AS married,
    COALESCE(u.has_children) AS has_children,
    COALESCE(u.home_country, '') AS home_country,
    COALESCE(u.home_city, '') AS home_city,
    -- Calculating Age
    EXTRACT(YEAR FROM AGE(NOW(), u.birthdate)) AS age,
    -- Adding age group
    CASE
		  WHEN EXTRACT(YEAR FROM AGE(NOW(), u.birthdate)) BETWEEN 15 AND 17 THEN '<18'
      WHEN EXTRACT(YEAR FROM AGE(NOW(), u.birthdate)) BETWEEN 18 AND 24 THEN '18-24'
      WHEN EXTRACT(YEAR FROM AGE(NOW(), u.birthdate)) BETWEEN 25 AND 34 THEN '25-34'
      WHEN EXTRACT(YEAR FROM AGE(NOW(), u.birthdate)) BETWEEN 35 AND 44 THEN '35-44'
      WHEN EXTRACT(YEAR FROM AGE(NOW(), u.birthdate)) BETWEEN 45 AND 54 THEN '45-54'
      WHEN EXTRACT(YEAR FROM AGE(NOW(), u.birthdate)) BETWEEN 55 AND 64 THEN '55-64'
      ELSE '65+'
    END AS age_group,
    MAX(DATE(s.session_end)) AS latest_session,
    udm.total_trips,
    udm.total_cancellations,  
    udm.total_sessions,
    ubi.total_cancellation_rate,
    ubi.average_checked_bags,
    ubi.prefers_flights,
    ubi.prefers_hotels,
    ubi.prefers_both,  
    ubi.conversion_rate,
    udm.average_clicks,
    udm.total_clicks,
    ubi.click_efficiency,
    udm.average_hotel_discount,
    udm.average_flight_discount,
    udm.flight_discount_proportion,  
    udm.hotel_discount_proportion,
    udm.both_discount_proportion,
    ubi.discount_responsiveness,
    utss.total_hotel_usd_spent,
    utss.total_flight_usd_spent,
    utss.total_hotel_usd_spent + utss.total_flight_usd_spent AS total_usd_spent,
    (COALESCE(scaled_hotel_ads,0)
    * COALESCE(udm.hotel_discount_proportion,0)
    * COALESCE(udm.average_hotel_discount,0)
    ) AS hotel_hunter_index  
  FROM UserSessions us
  JOIN users u ON u.user_id = us.user_id
  LEFT JOIN sessions s ON u.user_id = s.user_id
  LEFT JOIN UserDiscountMetrics udm ON u.user_id = udm.user_id
  LEFT JOIN UserTravelSpendSummary utss ON u.user_id = utss.user_id
  LEFT JOIN UserBehaviorIndices ubi ON u.user_id = ubi.user_id
  LEFT JOIN ScaledTravelMetrics stm ON u.user_id = stm.user_id
  GROUP BY 
    u.user_id, 
    u.birthdate, 
    u.gender,
    u.married,
    u.has_children,
    u.home_country, 
    u.home_city, 
    utss.ADS_hotel,
    udm.total_trips,
    udm.total_cancellations,  
    udm.total_sessions,
    ubi.total_cancellation_rate,
    ubi.average_checked_bags,
    ubi.prefers_flights,
    ubi.prefers_hotels,
    ubi.prefers_both,  
    ubi.conversion_rate,
    udm.average_clicks,
    udm.total_clicks,
    ubi.click_efficiency,
    udm.average_hotel_discount,
    udm.average_flight_discount,
    udm.flight_discount_proportion,  
    udm.hotel_discount_proportion,
    udm.both_discount_proportion,
    ubi.discount_responsiveness,
    utss.total_hotel_usd_spent,
    utss.total_flight_usd_spent,
    scaled_hotel_ads
)
SELECT * FROM FinalQuery
ORDER BY user_id ASC;
