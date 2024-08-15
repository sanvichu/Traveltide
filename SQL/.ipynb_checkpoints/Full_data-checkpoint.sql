WITH UserSessions AS (
  SELECT user_id
  FROM sessions
  WHERE session_start >= '2023-01-04'
  GROUP BY user_id
  HAVING COUNT(session_id) > 7
)

SELECT
  u.user_id,
  COALESCE(s.trip_id, '') AS trip_id,
  COALESCE(s.flight_discount_amount, 0) AS fd_amount,
  COALESCE(f.base_fare_usd, 0) AS base_fare_usd,
  u.home_airport_lat,
  u.home_airport_lon,
  f.destination_airport_lat,
  f.destination_airport_lon
FROM UserSessions us
JOIN users u ON u.user_id = us.user_id
LEFT JOIN sessions s ON s.user_id = u.user_id
LEFT JOIN flights f ON f.trip_id = s.trip_id
ORDER BY u.user_id;
