/*
GENERATE A REPORT THAT DISPLAYS THE TOTAL TRIPS,AVERAGE FARE PER KM,AVERAGE FARE PER TRIP
AND THE PERCENTAGE CONTRIBUTION OF EACH CITY'S TRIP.THIS REPORT WILL HELP IN ASSESSING TRIP,
VOLUME,PRICING EFFICIENCY,AND EACH CITY'S CONTRIBUTION TO OVERALL TRIP COUNT
FIELDS:
city_name
total_trips
avg_fare_per_km
avg_fare_per_trip
%_contribution_to_total_trips.
*/
WITH CTE AS 
(
SELECT c.city_name,
COUNT(trip_id) AS total_trips,SUM(distance_travelled_km) AS total_distance,
SUM(fare_amount) AS total_fare,
SUM(COUNT(trip_id))OVER() AS total
FROM fact_trips t INNER JOIN dim_city c ON c.city_id=t.city_id
GROUP BY city_name
)
SELECT city_name,total_trips,ROUND(total_fare/total_distance,2) AS avg_fare_per_km,
ROUND(total_fare/total_trips,2) AS avg_fare_per_trip,
ROUND(total_trips*100/total,2) AS "%_contribution_to_total_trips"
FROM CTE
ORDER BY 5 DESC;
/*
MONTHLY CITY LEVEL TRIPS TARGET PERFORMANCE REPORT
GENERATE A REPORT THAT EVALUATES THE TARGET PERFORMANCE FOR TRIPS AT THE MONTHLY AND CITY
LEVEL.FOR EACH CITY AND MONTH AND COMPARE THE ACTUAL TOTAL TRIPS WITH THE TARGET TRIPS AND CATEGORISE
 THE PERFROMANCE AS FOLLOWS
 * IF ACTUAL TRIPS ARE GREATER THAN TARGET TRIPS,MARK IT AS "ABOVE TARGET".
 * IF ACTUAL TRIPS ARE LESSER THAN TARGET TRIPS ,MARK IT AS "BELOW TARGET"
 FIELDS
 **********
 city_name
 month_name
 actual_trips
 target_trips
 performance_status
 %_difference
 */
 SELECT c.city_name,MONTHNAME(ft.month) AS month_name
 ,ft.actual_trips,tgt.total_target_trips AS target_trips,
CASE WHEN ft.actual_trips>tgt.total_target_trips THEN "ABOVE TARGET" 
ELSE "BELOW TARGET" 
END AS performance_status,
ROUND((1-ft.actual_trips/tgt.total_target_trips)*100,2) AS "%_difference"
FROM(
SELECT city_id,DATE_FORMAT(date,"%Y-%m-01") AS month,COUNT(trip_id) AS actual_trips
FROM fact_trips
GROUP BY city_id,DATE_FORMAT(date,"%Y-%m-01")
) ft INNER JOIN 
targets_db.monthly_target_trips tgt ON tgt.city_id=ft.city_id AND tgt.month=ft.month
INNER JOIN dim_city c ON c.city_id=ft.city_id
ORDER BY city_name,MONTH(ft.month);
/*
BUSSINESS REQUEST-3
CITY-LEVEL REPEAT PASSENGER TRIP FREQUENCY REPORT
GENERATE A REPORT THAT SHOWS THE PERCENTAGE DISTRIBUTON OF REPEAT PASSENGERS BY THE NO OF TRIPS THEY HAVE TAKEN IN EACH CITY
.CALCULATE THE PERCENTAGE OF REPEAT CUSTOMERS WHO TOOK 2-TRIPS,3-TRIPS,..... AND SO ON.
EACH COLUMN SHOULD  REPRESENT A TRIP COUNT CATEGORY,DISPLAING THE PERCENTAGE OF REPEAT PASSENGERS WHO FALL INTO THAT CATEGORY
OUT OF TOTAL REPEAT PASSENGERS FOR THAT CITY.
* FIELDS
**********
city_name
2-trips
3-trips
4-trips
6-trips
7-trips
8-trips
9-trips
10-trips
*/
WITH CTE AS
(
SELECT t.*,l.total_trips_by_city
FROM
(
SELECT  DISTINCT c.city_name,
SUM(repeat_passenger_count)OVER(PARTITION BY c.city_name) AS total_trips_by_city
FROM dim_repeat_trip_distribution rtrp INNER JOIN dim_city c ON c.city_id=rtrp.city_id
) l INNER JOIN
(
SELECT city_name,
SUM(CASE WHEN trip_count="2-Trips" THEN repeat_passenger_count ELSE 0 END)  AS "2_Trips",
SUM(CASE WHEN trip_count="3-Trips" THEN repeat_passenger_count ELSE 0 END) AS "3_Trips",
SUM(CASE WHEN trip_count="4-Trips" THEN repeat_passenger_count ELSE 0 END) AS "4_Trips",
SUM(CASE WHEN trip_count="5-Trips" THEN repeat_passenger_count ELSE 0 END) AS "5_Trips",
SUM(CASE WHEN trip_count="6-Trips" THEN repeat_passenger_count ELSE 0 END) AS "6_Trips",
SUM(CASE WHEN trip_count="7-Trips" THEN repeat_passenger_count ELSE 0 END) AS "7_Trips",
SUM(CASE WHEN trip_count="8-Trips" THEN repeat_passenger_count ELSE 0 END) AS "8_Trips",
SUM(CASE WHEN trip_count="9-Trips" THEN repeat_passenger_count ELSE 0 END) AS "9_Trips",
SUM(CASE WHEN trip_count="10-Trips" THEN repeat_passenger_count ELSE 0 END) AS "10_Trips" 
FROM dim_repeat_trip_distribution d INNER JOIN 
dim_city c ON c.city_id=d.city_id
GROUP BY city_name
) t ON t.city_name=l.city_name
)
SELECT city_name,
CONCAT(ROUND(2_Trips*100/total_trips_by_city,2)," ","%") AS "2_Trips",
CONCAT(ROUND(3_Trips*100/total_trips_by_city,2)," ","%") AS "3_Trips" ,
CONCAT(ROUND(4_Trips*100/total_trips_by_city,2)," ","%") AS "4_Trips" ,
CONCAT(ROUND(5_Trips*100/total_trips_by_city,2)," ","%") AS "5_Trips" ,
CONCAT(ROUND(6_Trips*100/total_trips_by_city,2)," ","%") AS "6_Trips" ,
CONCAT(ROUND(7_Trips*100/total_trips_by_city,2)," ","%") AS "7_Trips" ,
CONCAT(ROUND(8_Trips*100/total_trips_by_city,2)," ","%") AS "8_Trips" ,
CONCAT(ROUND(9_Trips*100/total_trips_by_city,2)," ","%") AS "9_Trips" ,
CONCAT(ROUND(10_Trips*100/total_trips_by_city,2)," ","%") AS "10_Trips" 
FROM CTE;
/*
BUSSINESS-REQUEST 4
IDENTIFY CITIES WITH HIGHEST AND LOWEST TOTAL NEW PASSENGERS.
GENERATE A REPORT THAT CALCULATES THE TOTAL NEW PASSENGERS FOR EACH CITY AND RANKS THEM BASED ON THIS VALUES
.IDENTIFY THE TOP 3 CITIES WITH HIGHEST NUMBER OF NEW PASSENGERS AS WELL THE BOTTOM 3 CITIES WITH THE LOWEST 
NUMBER OF NEW PASSENGERS,CATEGORISING THEM AS TOP-3 OR BOTTOM 3 ACCORDINGLY
FIELDS
*******
city_name
total_new_passengers
city_category("top-3,bottom-3")
*/
WITH CTE AS 
(
SELECT *,
CASE WHEN drnk<=3 THEN "TOP-3" ELSE "BOTTOM-3" END AS city_category FROM
(
SELECT  city_name,SUM(new_passengers) AS total_new_passengers,
DENSE_RANK()OVER(ORDER BY SUM(new_passengers) DESC) AS drnk
FROM fact_passenger_summary ps INNER JOIN 
dim_city c ON c.city_id=ps.city_id
GROUP BY city_name
)t
)
SELECT city_name,total_new_passengers,city_category
FROM CTE 
WHERE drnk <=3 OR drnk>=8
ORDER BY total_new_passengers DESC;
/*
BUSSINESS REQUEST -5
IDENTIFY MONTH WITH HIGHEST REVENUE FOR EACH CITY
GENERATES A REPORT THAT IDENTIFIES THE MONTH WITH HIGHEST REVENUE FOR EACH CITY.FOR EACH CITY,DISPLAY THE MONTH NAME,THE REVENUE AMOUNT
FOR THAT MONTH AND THE PERCENT CONTRIBUTION OF THAT REVENUE TO THE CITY'S TOTAL REVENUE.
FIELDS
********
city_name
highest_revenue_month
revenue
percent_contribution
*/
SELECT city_name,MONTHNAME(date) AS highest_revenue_month, revenue,
CONCAT(ROUND(revenue*100/total_revenue,2)," ","%") AS percent_contribution 
FROM
(
SELECT DATE_FORMAT(date,"%Y-%m-01") date,city_id,SUM(fare_amount) revenue,
DENSE_RANK()OVER(PARTITION BY city_id ORDER BY SUM(fare_amount) DESC) AS drnk,
SUM(SUM(fare_amount))OVER(PARTITION BY city_id) AS total_revenue
 FROM fact_trips 
GROUP BY city_id,DATE_FORMAT(date,"%Y-%m-01")
) t 
INNER JOIN dim_city c ON c.city_id=t.city_id
WHERE t.drnk=1;
/*
REPEAT PASSENGER RATE ANALYSIS 
GENRATE A REPORT THAT CALCULATE TWO METRICS:
THESE METRICS WILL PROVIDE INSIGHTS INTO MONTHLY REPEAT TRENDS AS WELL AS OVERALL REPEAT BEHAVIOUR OF EACH CITY
FIELDS:
*********
city_name
month
total_passengers
repeat_passengers
monthly_repeat_passengers_rate(%):REPEAT PASSENGER RATE AT THE  CITY AND MONTH LEVEL
city_repeat_passengers_rate(%):overall repeat passenger rate for each city,aggregated across months
*/
SELECT city_name,MONTHNAME(month) AS month_name,total_passengers,repeat_passengers,
CONCAT(ROUND(repeat_passengers*100/total_passengers,2)," ","%") AS monthly_repeat_passengers_rate
FROM fact_passenger_summary ps INNER JOIN 
dim_city c 	ON c.city_id=ps.city_id
ORDER BY city_name,MONTH(month);
-- OVERALL  CITY REPEAT PASSENGER RATE %
SELECT 	city_name,SUM(total_passengers) AS total_passengers,SUM(repeat_passengers) AS repeat_passengers,
CONCAT(ROUND(SUM(repeat_passengers)*100/SUM(total_passengers),2)," ","%") AS overall_repeat_passenger_rate
FROM fact_passenger_summary ps INNER JOIN
dim_city c ON c.city_id=ps.city_id
GROUP BY city_name
ORDER BY SUM(repeat_passengers)*100/SUM(total_passengers) DESC;
/*
EXTRA QUESTIONS
REVENUE GROWTH RATE MONTHLY
*/
WITH CTE AS
(
SELECT month,
LAG(revenue,1,0)OVER(ORDER BY month_no ASC) AS previous_month_revenue,
revenue
FROM
(
SELECT MONTHNAME(date) AS month,MONTH(date) AS month_no,SUM(fare_amount) AS revenue
FROM fact_trips
GROUP BY MONTHNAME(date),MONTH(date)
) t
)
SELECT month,CONCAT(ROUND(previous_month_revenue/10000000,2)," ","Cr") AS previous_month_revenue
,CONCAT(ROUND(revenue/10000000,2)," ","Cr") AS current_month_revenue,
CASE WHEN previous_month_revenue=0 THEN NULL
ELSE CONCAT(ROUND((revenue-previous_month_revenue)*100/previous_month_revenue,2)," ","%")
END monthly_growth_rate
FROM CTE;


















