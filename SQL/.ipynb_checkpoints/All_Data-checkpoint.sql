WITH UserSessions AS (
  SELECT user_id
  FROM sessions
  WHERE session_start >= '2023-01-04'
  GROUP BY user_id
  HAVING COUNT(session_id) > 7
)
SELECT
  u.user_id,
  u.birthdate,
  u.gender,
  u.married,
  u.has_children,
  u.home_country,
  u.home_city,
  u.sign_up_date,
  s.trip_id,
  s.flight_discount,
  s.hotel_discount,
  COALESCE(s.flight_discount_amount, 0) AS fd_amount,
  COALESCE(s.hotel_discount_amount, 0) AS hd_amount,
  s.flight_booked,
  s.hotel_booked,
  s.session_end,
  s.cancellation,
  COALESCE(s.page_clicks, 0) AS page_clicks,
  h.hotel_name,
  h.rooms,
  h.check_in_time,
  h.check_out_time,
  COALESCE(h.hotel_per_room_usd, 0) AS hotel_per_room_usd,
  COALESCE(f.base_fare_usd, 0) AS base_fare_usd,
  u.home_airport_lat,
  u.home_airport_lon,
  f.destination_airport_lat,
  f.destination_airport_lon,
  f.checked_bags
FROM UserSessions us
JOIN users u ON u.user_id = us.user_id
LEFT JOIN sessions s ON s.user_id = u.user_id
LEFT JOIN flights f ON f.trip_id = s.trip_id
LEFT JOIN hotels h ON h.trip_id = s.trip_id
ORDER BY u.user_id;