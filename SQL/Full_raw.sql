
-- The query gathers various attributes related to the user, sessions, flights, and hotels, which are then used for further calculations.
WITH UserSessions AS (
  SELECT user_id
  FROM sessions
  WHERE session_start >= '2023-01-04'  
  GROUP BY user_id
  HAVING COUNT(session_id) > 7
)

SELECT
  u.user_id,
  -- If trip_id is NULL, replace with an empty string
  COALESCE(s.trip_id, '') AS trip_id,
  -- Handling NULLs for basic user information fields
  COALESCE(u.birthdate) AS birthdate,
  COALESCE(u.gender, '') AS gender,
  COALESCE(u.married) AS married,
  COALESCE(u.has_children) AS has_children,
  COALESCE(u.home_country, '') AS home_country,
  COALESCE(u.home_city, '') AS home_city,
  -- Capture sign-up date for each user
  COALESCE(u.sign_up_date) AS sign_up_date,
  -- Capture discount information for flights and hotels
  COALESCE(s.flight_discount) AS f_discount,
  COALESCE(s.hotel_discount) AS h_discount,
  -- Actual amounts of discounts
  COALESCE(s.flight_discount_amount, 0) AS fd_amount,
  COALESCE(s.hotel_discount_amount, 0) AS hd_amount,
  -- Whether the flight or hotel was booked
  COALESCE(s.flight_booked) AS f_booked,
  COALESCE(s.hotel_booked) AS h_booked,
  -- Session end timestamp
  COALESCE(s.session_end) AS s_timestamp,
  -- Information on whether the trip was cancelled
  COALESCE(s.cancellation) AS cancelled,
  -- Number of page clicks during the session
  COALESCE(s.page_clicks, 0) AS page_clicks,
  -- Hotel details, if available
  COALESCE(h.hotel_name, '') AS h_hotel,
  COALESCE(h.rooms) AS h_rooms,
  -- Time spent at the hotel
  COALESCE(h.check_out_time - h.check_in_time) AS h_timespent,
  -- Hotel room price in USD
  COALESCE(h.hotel_per_room_usd) AS hotel_per_room_usd,
  -- Flight details, if available
  COALESCE(f.destination, '') AS f_destination,
  -- Whether a return flight was booked
  COALESCE(f.return_flight_booked) AS f_return_booked,
  -- Time spent on the flight
  COALESCE(f.return_time - f.departure_time) AS f_timespent,
  -- Number of checked bags
  COALESCE(f.checked_bags) AS f_checked_bags,
  -- Latitude and Longitude information for home and destination airports
  u.home_airport_lat,
  u.home_airport_lon,
  f.destination_airport_lat,
  f.destination_airport_lon,
  -- Base fare for the flight in USD
  COALESCE(f.base_fare_usd,0) AS base_fare_usd
FROM UserSessions us
JOIN users u ON u.user_id = us.user_id
-- LEFT JOINs are used to fetch optional data that may or may not exist for each user
LEFT JOIN sessions s ON s.user_id = u.user_id
LEFT JOIN flights f ON f.trip_id = s.trip_id
LEFT JOIN hotels h ON h.trip_id = s.trip_id
-- Sorting the results by user_id
ORDER BY user_id;









