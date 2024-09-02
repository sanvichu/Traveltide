WITH UserSessions AS (
  SELECT s.user_id
  FROM sessions s
  WHERE s.session_start >= '2023-01-04'
  GROUP BY s.user_id
  HAVING COUNT(s.session_id) > 7
),
FilteredSessions AS (
  SELECT s.*
  FROM sessions s
  JOIN UserSessions us ON s.user_id = us.user_id
),
UserNightsSummary AS (
  SELECT 
    u.user_id,
    -- Calculate average and total nights per user
    COALESCE(
      AVG(
        CASE
          WHEN h.nights < 0 THEN 0
          ELSE h.nights
        END
      ), 0
    ) AS avg_nights,
    SUM(
      CASE
        WHEN h.nights < 0 THEN 1
        ELSE h.nights
      END
    ) AS total_nights
  FROM 
    FilteredSessions fs  
    JOIN users u ON fs.user_id = u.user_id
  LEFT JOIN hotels h ON h.trip_id = fs.trip_id
  GROUP BY u.user_id
),    
UserTravelSpendSummary AS (
  SELECT
    u.user_id,

    -- Calculate ADS for hotels considering discounts and total nights
    AVG(
      CASE 
        WHEN fs.hotel_discount = TRUE THEN (h.hotel_per_room_usd * (1 - fs.hotel_discount_amount) * h.rooms * uns.total_nights)
        ELSE (h.hotel_per_room_usd * h.rooms * uns.total_nights)
      END
    ) AS ADS_hotel,

    -- Calculate total hotel spend considering discounts and total nights
    COALESCE(
      SUM(
        CASE 
          WHEN fs.hotel_discount = TRUE THEN (h.hotel_per_room_usd * (1 - fs.hotel_discount_amount) * h.rooms * uns.total_nights)
          ELSE (h.hotel_per_room_usd * h.rooms * uns.total_nights)
        END
      ), 0
    ) AS total_hotel_usd_spent,

    -- Calculate total flight spend considering discounts
    COALESCE(
      SUM(
        CASE 
          WHEN fs.flight_discount = TRUE THEN f.base_fare_usd * (1 - fs.flight_discount_amount)
          ELSE f.base_fare_usd
        END
      ), 0
    ) AS total_flight_usd_spent,

    -- Calculate total spend considering discounts and total nights
    COALESCE(
      SUM(
        CASE 
          WHEN fs.hotel_discount = TRUE THEN (h.hotel_per_room_usd * (1 - fs.hotel_discount_amount) * h.rooms * uns.total_nights)
          ELSE (h.hotel_per_room_usd * h.rooms * uns.total_nights)
        END
      ) + 
      SUM(
        CASE 
          WHEN fs.flight_discount = TRUE THEN f.base_fare_usd * (1 - fs.flight_discount_amount)
          ELSE f.base_fare_usd
        END
      ), 0
    ) AS total_usd_spent
  FROM 
    FilteredSessions fs  
    JOIN users u ON fs.user_id = u.user_id
  LEFT JOIN flights f ON f.trip_id = fs.trip_id
  LEFT JOIN hotels h ON h.trip_id = fs.trip_id
  LEFT JOIN UserNightsSummary uns ON u.user_id = uns.user_id -- Join with UserNightsSummary to get total nights
  GROUP BY u.user_id
),
distance AS (
  SELECT 
    fs.user_id, 
    f.origin_airport, 
    f.destination_airport,
    6371 * acos(
      cos(radians(u.home_airport_lat)) * cos(radians(f.destination_airport_lat)) * 
      cos(radians(f.destination_airport_lon) - radians(u.home_airport_lon)) + 
      sin(radians(u.home_airport_lat)) * sin(radians(f.destination_airport_lat))
    ) AS distance_km
  FROM 
    FilteredSessions fs
  JOIN flights f ON fs.trip_id = f.trip_id
  JOIN users u ON fs.user_id = u.user_id
  GROUP BY 
    fs.user_id, f.origin_airport, f.destination_airport, 
    f.destination_airport_lat, u.home_airport_lat, 
    f.destination_airport_lon, u.home_airport_lon
),
distance_metrics AS (
  SELECT 
    d.user_id,
    COALESCE(SUM(fs.flight_discount_amount), 0) AS total_discount_amount,
    COALESCE(SUM(d.distance_km), 0) AS total_distance,
    COALESCE(SUM(fs.flight_discount_amount) / NULLIF(SUM(d.distance_km), 0), 0) AS ads_per_km
  FROM 
    distance d
  LEFT JOIN FilteredSessions fs ON d.user_id = fs.user_id
  GROUP BY 
    d.user_id
),
scaled_metrics AS (
  SELECT
    sm.user_id,
    sm.ads_per_km,
    COALESCE(
      (sm.ads_per_km - MIN(sm.ads_per_km) OVER ()) / 
      NULLIF((MAX(sm.ads_per_km) OVER () - MIN(sm.ads_per_km) OVER ()), 0), 
      0
    ) AS scaled_ads_per_km
  FROM 
    distance_metrics sm
),
MinMaxAdsHotel AS (
  SELECT
    MIN(utss.ADS_hotel) AS min_hotel_ads,
    MAX(utss.ADS_hotel) AS max_hotel_ads
  FROM UserTravelSpendSummary utss
),
ScaledTravelMetrics AS (
  SELECT 
    utss.user_id,
    utss.ADS_hotel,
    COALESCE(
      (utss.ADS_hotel - mma.min_hotel_ads) /
      NULLIF((mma.max_hotel_ads - mma.min_hotel_ads), 0), 
      0
    ) AS scaled_hotel_ads
  FROM UserTravelSpendSummary utss 
  CROSS JOIN MinMaxAdsHotel mma
),
UserDiscountMetrics AS (
  SELECT
    u.user_id,
    COALESCE(AVG(fs.flight_discount_amount), 0) AS average_flight_discount,
    COALESCE(AVG(fs.hotel_discount_amount), 0) AS average_hotel_discount, 
    COALESCE(SUM(
      CASE
        WHEN fs.flight_discount = 'true' AND fs.flight_discount_amount > 0 AND fs.hotel_discount = 'false' THEN 1 
        ELSE 0
      END
    ) :: FLOAT / COUNT(*), 0) AS flight_discount_proportion,
    COALESCE(SUM(
      CASE 
        WHEN fs.hotel_discount = 'true' AND fs.hotel_discount_amount > 0 AND fs.flight_discount ='false' THEN 1  
        ELSE 0 
      END) :: FLOAT / COUNT(*), 0) AS hotel_discount_proportion,
    COALESCE(SUM(
      CASE
        WHEN fs.flight_discount = 'true' AND fs.flight_discount_amount > 0 AND fs.hotel_discount = 'true' AND fs.hotel_discount_amount > 0 THEN 1
        ELSE 0
      END) :: FLOAT / COUNT(*), 0) AS both_discount_proportion, 
    COUNT(
      CASE
        WHEN fs.flight_booked = 'true' AND fs.hotel_booked = 'false' THEN fs.trip_id
        ELSE NULL
      END
    ) AS total_only_flights,
    COUNT(
      CASE
        WHEN fs.hotel_booked = 'true' AND fs.flight_booked ='false' THEN fs.trip_id
        ELSE NULL
      END
    ) AS total_only_hotels,
    COUNT(
      CASE
        WHEN fs.hotel_booked = 'true' AND fs.flight_booked ='true' THEN fs.trip_id
        ELSE NULL
      END
    ) AS total_together,
    COUNT( fs.trip_id) AS total_trips,  
    COUNT(fs.trip_id IS NOT NULL) AS total_sessions,
    AVG(fs.page_clicks) AS average_clicks,
    SUM(fs.page_clicks) AS total_clicks,  
    COUNT(
      DISTINCT 
        CASE 
          WHEN fs.cancellation = 'true' THEN fs.trip_id 
          ELSE NULL 
        END
    ) AS total_cancellations,
 
    COALESCE(AVG(f.checked_bags), 0) AS average_checked_bags
  FROM 
    users u
   JOIN FilteredSessions fs ON u.user_id = fs.user_id
  LEFT JOIN flights f ON f.trip_id = fs.trip_id
  LEFT JOIN hotels h ON h.trip_id = fs.trip_id
  GROUP BY u.user_id
  ORDER BY u.user_id ASC
),
UserBehaviorIndices AS (
  SELECT
    udm.user_id,
    udm.average_checked_bags,
    COALESCE(
      (udm.total_cancellations::FLOAT / NULLIF(udm.total_trips::FLOAT, 0)), 
      0
    ) AS total_cancellation_rate,
    COALESCE(
      (udm.average_clicks * udm.total_trips)::FLOAT / udm.total_clicks, 
      0
    ) AS engagement_index,
    COALESCE(
      udm.total_trips::FLOAT / udm.total_sessions, 
      0
    ) AS conversion_rate,
    COALESCE(
      udm.total_only_flights::FLOAT / NULLIF(udm.total_trips, 0), 
      0
    ) AS prefers_flights,
    COALESCE(
      udm.total_only_hotels::FLOAT / NULLIF(udm.total_trips, 0), 
      0
    ) AS prefers_hotels,
    COALESCE(
      udm.total_together::FLOAT / NULLIF(udm.total_trips, 0), 
      0
    ) AS prefers_both,  
    COALESCE(
      (udm.flight_discount_proportion * udm.total_only_flights +
       udm.hotel_discount_proportion * udm.total_only_hotels + 
       udm.both_discount_proportion * udm.total_together) / 
       NULLIF(udm.total_trips, 0), 
      0
    ) AS discount_responsiveness,
    COALESCE(
      udm.total_clicks::FLOAT / NULLIF(udm.total_trips, 0), 
      0
    ) AS click_efficiency
  FROM 
    UserDiscountMetrics udm
),
FinalQuery AS (
  SELECT
    u.user_id,
    u.birthdate,
    u.gender,
    u.married,
    u.has_children,
    u.home_country,
    u.home_city,
    EXTRACT(YEAR FROM AGE(NOW(), u.birthdate)) AS age,
    CASE
      WHEN EXTRACT(YEAR FROM AGE(NOW(), u.birthdate)) BETWEEN 15 AND 17 THEN '15-17'
      WHEN EXTRACT(YEAR FROM AGE(NOW(), u.birthdate)) BETWEEN 18 AND 24 THEN '18-24'
      WHEN EXTRACT(YEAR FROM AGE(NOW(), u.birthdate)) BETWEEN 25 AND 34 THEN '25-34'
      WHEN EXTRACT(YEAR FROM AGE(NOW(), u.birthdate)) BETWEEN 35 AND 44 THEN '35-44'
      WHEN EXTRACT(YEAR FROM AGE(NOW(), u.birthdate)) BETWEEN 45 AND 54 THEN '45-54'
      WHEN EXTRACT(YEAR FROM AGE(NOW(), u.birthdate)) BETWEEN 55 AND 64 THEN '55-64'
      ELSE '65+'
    END AS age_group,
    MAX(DATE(fs.session_end)) AS latest_session,
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
  	uns.total_nights,
    uns.avg_nights,
    COALESCE(stm.scaled_hotel_ads, 0) AS scaled_hotel_ads,
    COALESCE(sm.ads_per_km, 0) AS ads_per_km,
    COALESCE(sm.scaled_ads_per_km, 0) AS scaled_ads_per_km,
      (COALESCE(scaled_hotel_ads,0)
  * COALESCE(udm.hotel_discount_proportion,0)
  * COALESCE(udm.average_hotel_discount,0)
  ) AS hotel_hunter_index  
  FROM 
  	FilteredSessions fs
    
   JOIN users u ON u.user_id = fs.user_id
  LEFT JOIN UserDiscountMetrics udm ON fs.user_id = udm.user_id
  LEFT JOIN UserTravelSpendSummary utss ON fs.user_id = utss.user_id
  LEFT JOIN UserBehaviorIndices ubi ON fs.user_id = ubi.user_id
  LEFT JOIN ScaledTravelMetrics stm ON fs.user_id = stm.user_id
  LEFT JOIN scaled_metrics sm ON fs.user_id = sm.user_id
  LEFT JOIN UserNightsSummary uns ON fs.user_id = uns.user_id
  GROUP BY 
    u.user_id, u.birthdate, u.gender, u.married, u.has_children, u.home_country, u.home_city, 
    udm.total_trips, udm.total_cancellations, udm.total_sessions, ubi.total_cancellation_rate,
    ubi.average_checked_bags, ubi.prefers_flights, ubi.prefers_hotels, ubi.prefers_both,  
    ubi.conversion_rate, udm.average_clicks, udm.total_clicks, ubi.click_efficiency, 
    udm.average_hotel_discount, udm.average_flight_discount, udm.flight_discount_proportion,  
    udm.hotel_discount_proportion, udm.both_discount_proportion, ubi.discount_responsiveness,
    utss.total_hotel_usd_spent, utss.total_flight_usd_spent,uns.total_nights, stm.scaled_hotel_ads,  
    sm.ads_per_km, sm.scaled_ads_per_km, uns.avg_nights
)
SELECT * FROM FinalQuery
ORDER BY user_id ASC;