-- IDENTIFY THE TOP 3 AND BOTTOM 3 CITIES BY TOTAL TRIPS OVER THE ENTIRE ANALYSIS PERIOD --
SELECT c.city_name AS City,CONCAT(ROUND(total_trips/total*100,2)," ","%") AS percent_of_trips
FROM
(
SELECT city_id,COUNT(trip_id) AS total_trips,
SUM(COUNT(trip_id))over() AS total,
DENSE_RANK()OVER(ORDER BY COUNT(trip_id) DESC) AS h_rnk
FROM fact_trips
GROUP BY city_id
)t INNER JOIN 
dim_city c ON c.city_id=t.city_id
WHERE h_rnk <=3 OR h_rnk>=8
ORDER BY ROUND(total_trips/total*100,2) DESC;
-- CALCULATE THE AVERAGE FARE PER TRIP FOR EACH CITY AND COMPARE IT WITH THE CITY'S AVERAGE TRIP DISTANCE.IDENTIFY THE CITIES WITH THE HIGHEST AND LOWEST AVERAGE FARE PER TRIP TO  ASSESS PRICING EFFICIENCY ACROSS LOCATIONS.
WITH CTE AS
(
SELECT c.city_id,c.city_name,
CONCAT(ROUND(AVG(distance_travelled_km),2)," ","KM") AS average_distance,
CONCAT("₹"," ",ROUND(SUM(fare_amount)/COUNT(trip_id),2)) AS average_fare
FROM fact_trips t INNER JOIN
dim_city c ON t.city_id=c.city_id
GROUP BY city_id
ORDER BY 2 ASC
)
SELECT city_name,average_distance,average_fare FROM CTE
ORDER BY  average_fare ASC;
-- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- CALCULATE THE AVERAGE PASSENGER AND DRIVER RATING FOR EACH CITY,SEGMENTED,BY PASSENGER TYPE (NEW VS REPEAT)IDENTIFY THE CITIES WITH HIGHEST AND LOWEST AVERAGE RATINGS.
-- Passenger Rating --
SELECT city_name AS City,passenger_type,ROUND(avg_passenger_rating,2) AS average_passenger_rating FROM
(
SELECT c.city_name,passenger_type,ROUND(AVG(passenger_rating),3) AS avg_passenger_rating
,ROUND(AVG(driver_rating),3) AS avg_driver_rating,
DENSE_RANK()OVER(ORDER BY ROUND(AVG(passenger_rating),3) DESC) AS p_rnk,
DENSE_RANK()OVER(ORDER BY ROUND(AVG(driver_rating),3) DESC) AS d_rnk
FROM fact_trips t INNER JOIN
dim_city c ON t.city_id=c.city_id
GROUP BY c.city_name,passenger_type
order by 3 asc
) T 
WHERE p_rnk=1 OR p_rnk=18;
-- ---------------------------------------------------------------------------------------------------------------------------------------------
-- Driver Rating --
SELECT city_name AS City,passenger_type,ROUND(avg_driver_rating,2) AS average_driver_rating FROM
(
SELECT c.city_name,passenger_type,ROUND(AVG(passenger_rating),3) AS avg_passenger_rating
,ROUND(AVG(driver_rating),3) AS avg_driver_rating,
DENSE_RANK()OVER(ORDER BY ROUND(AVG(passenger_rating),3) DESC) AS p_rnk,
DENSE_RANK()OVER(ORDER BY ROUND(AVG(driver_rating),3) DESC) AS d_rnk
FROM fact_trips t INNER JOIN
dim_city c ON t.city_id=c.city_id
GROUP BY c.city_name,passenger_type
order by 4 desc
) t 
WHERE d_rnk=1 OR d_rnk=19;
-- PEAK AND LOW DEMAND MONTHS BY CITY FOR EACH CITY IDENTIFY THE MONTH WITH THE HIGHEST TOTAL TRIPS(PEAK DEMAND) AND THE MONTH WITH LOWEST TRIPS(LOW DEMAND).
-- THIS ANALYSIS WILL HELP GOOD CABS TO UNDERSTAND SEASONAL PATTERNS AND ADJUST RESOURCES ACCORDINGLY.
WITH CTE1 AS
(
WITH CTE AS
(
SELECT city_id,MONTHNAME(date) AS month_name ,COUNT(trip_id) AS total_trips,
DENSE_RANK()OVER(PARTITION BY city_id ORDER BY COUNT(trip_id) DESC) AS h_rnk,
DENSE_RANK()OVER(PARTITION BY city_id ORDER BY COUNT(trip_id) ASC) AS l_rnk
FROM fact_trips
GROUP BY city_id,MONTHNAME(date)
)
SELECT c.city_name,month_name,total_trips,h_rnk
FROM CTE t INNER JOIN 
dim_city c ON c.city_id=t.city_id
WHERE h_rnk=1 OR l_rnk=1
ORDER BY city_name,total_trips DESC
)
SELECT city_name,
MAX(CASE WHEN 	h_rnk=1 THEN month_name ELSE NULL END) AS peak_monnth,
MAX(CASE WHEN  h_rnk=6 THEN month_name ELSE  NULL END) AS low_month
FROM CTE1
GROUP BY city_name
ORDER BY city_name;
-- ---------------------------------------------------------------------------------------------------------------------------------------------
-- WEEKEND VS WEEKDAY TRIP DEMAND BY CITY
WITH CTE1 AS
(
WITH CTE AS
(
SELECT trip_id,city_id,date,
CASE WHEN WEEKDAY(date) IN (5,6) THEN "Weekend"
	 ELSE "Weekday"
END AS day_type
FROM fact_trips
)
SELECT d.city_name,day_type,COUNT(trip_id) AS trips,
SUM(count(trip_id))OVER(PARTITION BY d.city_name) AS total_trips
FROM CTE c INNER JOIN
dim_city d ON c.city_id=d.city_id
GROUP BY d.city_name,c.day_type
ORDER BY d.city_name,trips DESC
)
SELECT city_name AS City,day_type AS Day_Type,CONCAT(ROUND(trips*100/total_trips,2),"%") AS percent_of_trips
FROM CTE1;
-- ------------------------------------------------------------------------------------------------------------------------------------------------
-- REPEAT PASSENGER FREQUENCY AND CITY CONTRIBUTIONS ANALYSIS ANALYSE THE FREQUECY OF TRIPS TAKEN BY REPEAT PASSENGERS IN EACH CITY.PERCENT OF REPEAT PASSENGERS TAKING 2 TRIPS,3 TRIPS ETC..........
WITH CTE AS
(
SELECT *,
DENSE_RANK()OVER(PARTITION BY city_id ORDER BY repeat_passengers DESC) AS d_rnk 
FROM
(
SELECT city_id,trip_count,SUM(repeat_passenger_count) AS repeat_passengers,
SUM(SUM(repeat_passenger_count))OVER(PARTITION BY city_id) AS all_passengers
FROM dim_repeat_trip_distribution
 GROUP BY city_id,trip_count
 ) t
 )
SELECT city_name,GROUP_CONCAT(trip_count SEPARATOR ",") AS top_2_trip_counts,
CONCAT(SUM(ROUND(repeat_passengers*100/all_passengers,2)),"%") AS pct_of_passengers
FROM CTE c INNER JOIN
dim_city d ON c.city_id=d.city_id
WHERE d_rnk<=2
GROUP BY city_name;
-- ------------------------------------------------------------------------------------------------------------------------------------------------
-- MONTHLY TARGET ACHIEVEMENTS ANALSIS OF KEY METRICS FOR EACH CITY,EVALUATE MONTHLY PERFORMANCE AGAINST TARGETS FOR TOTAL TRIPS NEW PASSENGERS,AND AVERAGE PASSENGER
-- CALCULATE THE  PERCENTAGE DIFFERENCE ANY CONSISTENT PATTERNS IN TARGET ACHEIVEMENT PARTICULARLY ACROSS TOURISM VERSUS BUSSINESS FOCUSED COUNTRIES.NEW PASSENGER TARGETS
-- TOURISM BASED CITIES --
SELECT c.city_name,MONTHNAME(fps.month) AS month,fps.new_passengers AS np,tnp.target_new_passengers AS tnp,
ROUND((1-tnp.target_new_passengers/fps.new_passengers)*100,2) AS pct_difference
FROM fact_passenger_summary fps 
INNER JOIN
targets_db.monthly_target_new_passengers tnp ON fps.month=tnp.month AND fps.city_id=tnp.city_id
INNER JOIN dim_city c ON c.city_id=fps.city_id
WHERE c.city_name IN ("Jaipur","Chandigarh","Mysore","Kochi")
ORDER BY city_name,month(fps.month);

-- BUSSINESS BASED CITIES------

SELECT c.city_name,MONTHNAME(fps.month) AS month,fps.new_passengers AS np,tnp.target_new_passengers AS tnp,
ROUND((1-tnp.target_new_passengers/fps.new_passengers)*100,2) AS pct_difference
FROM fact_passenger_summary fps 
INNER JOIN
targets_db.monthly_target_new_passengers tnp ON fps.month=tnp.month AND fps.city_id=tnp.city_id
INNER JOIN dim_city c ON c.city_id=fps.city_id
WHERE c.city_name NOT IN ("Jaipur","Chandigarh","Mysore","Kochi")
ORDER BY city_name,month(fps.month);

-- NEW TRIP TARGETS--


-- TOURISM BASED CITIES-- 
SELECT c.city_name, MONTHNAME(tp.month) AS month,tp.total_trips,tgt.total_target_trips,
ROUND((1-tgt.total_target_trips/tp.total_trips)*100,2) AS  pct_difference
FROM
(
SELECT DATE_FORMAT(date,"%Y-%m-01") AS month,city_id,COUNT(trip_id) AS total_trips
FROM fact_trips 
GROUP BY DATE_FORMAT(date,"%Y-%m-01"),city_id
)  tp INNER JOIN 
targets_db.monthly_target_trips tgt ON tgt.month=tp.month AND tgt.city_id=tp.city_id 
INNER JOIN dim_city c ON c.city_id=tp.city_id
WHERE c.city_name IN ("Jaipur","Kochi","Mysore","Chandigarh")
ORDER BY c.city_id,month(tp.month);

-- BUSSINESS BASED --
SELECT c.city_name, MONTHNAME(tp.month) AS month,tp.total_trips,tgt.total_target_trips,
ROUND((1-tgt.total_target_trips/tp.total_trips)*100,2) AS  pct_difference
FROM
(
SELECT DATE_FORMAT(date,"%Y-%m-01") AS month,city_id,COUNT(trip_id) AS total_trips
FROM fact_trips 
GROUP BY DATE_FORMAT(date,"%Y-%m-01"),city_id
)  tp INNER JOIN 
targets_db.monthly_target_trips tgt ON tgt.month=tp.month AND tgt.city_id=tp.city_id 
INNER JOIN dim_city c ON c.city_id=tp.city_id
WHERE c.city_name NOT IN ("Jaipur","Kochi","Mysore","Chandigarh")
ORDER BY c.city_id,month(tp.month);

-- RATING TARGET--



-- TOURISM BASEED-- 
SELECT c.city_name AS City ,MONTHNAME(t.month) AS month,t.avg_passenger_rating,tpr.target_avg_passenger_rating
FROM
(
SELECT DATE_FORMAT(date,"%Y-%m-01") AS month,city_id,ROUND(AVG(passenger_rating),2) avg_passenger_rating
FROM fact_trips
GROUP BY 1,2
) t INNER JOIN  targets_db.city_target_passenger_rating tpr ON tpr.city_id=t.city_id
INNER JOIN dim_city c ON tpr.city_id=c.city_id
WHERE c.city_name IN ("Jaipur","Kochi","Mysore","Chandigarh");
--  BUSSINESS BASED -- 
SELECT c.city_name AS City ,MONTHNAME(t.month) AS month,t.avg_passenger_rating,tpr.target_avg_passenger_rating
FROM
(
SELECT DATE_FORMAT(date,"%Y-%m-01") AS month,city_id,ROUND(AVG(passenger_rating),2) avg_passenger_rating
FROM fact_trips
GROUP BY 1,2
) t INNER JOIN  targets_db.city_target_passenger_rating tpr ON tpr.city_id=t.city_id
INNER JOIN dim_city c ON tpr.city_id=c.city_id
WHERE c.city_name NOT IN ("Jaipur","Kochi","Mysore","Chandigarh");

-- HIGHEST AND LOWEST REPEAT PASSENGER RATE FOR EACH CITY ACROSS THE SIX MONTH PERIOD.IDENTIFY  THE TOP 2 AND BOTTOM 2 CITIES BASED ON  THEIR RPR TO DETERMINE THE LOCATIONS HAVE THE STRONGEST AND WEAKEST RATES.*/
WITH CTE AS 
(
SELECT city_name,SUM(repeat_passengers) AS total_repeat_passengers,SUM(total_passengers) AS total_passengers,
CONCAT(ROUND(SUM(repeat_passengers)*100/SUM(total_passengers),2)," ","%")  AS  repeat_rate,
DENSE_RANK()OVER(ORDER BY (SUM(repeat_passengers)*100/SUM(total_passengers)) DESC) AS drnk
FROM fact_passenger_summary ps INNER JOIN 
dim_city c ON c.city_id=ps.city_id
GROUP BY city_name
)
SELECT city_name,repeat_rate FROM CTE
WHERE drnk <=2 OR drnk>=9;

-- SIMILARLY ANALYSE THE RPR% FOR MONTHS ACROSS ALL CITIES AND IDENTIFY THE MONTHS WITH HIGHEST AND LOWEST RPR ACROSS EACH CITY
WITH CTE AS
(
SELECT MONTHNAME(month) AS month_name,city_id,total_passengers,repeat_passengers,
repeat_passengers*100/total_passengers AS repeat_passenger_rate,
DENSE_RANK()OVER(PARTITION BY city_id  ORDER BY repeat_passengers*100/total_passengers DESC)AS drnk
FROM fact_passenger_summary
ORDER BY city_id,MONTH(month)
)
SELECT city_name,month_name,CONCAT(ROUND(repeat_passenger_rate,2)," ","%") AS repeat_passenger_rate
FROM CTE ct INNER JOIN dim_city c ON c.city_id=ct.city_id
WHERE drnk=1 OR drnk=6 
ORDER BY 1,ROUND(repeat_passenger_rate,2) DESC;










