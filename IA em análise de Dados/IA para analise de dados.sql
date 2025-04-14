Select
lead_gen_source as Fonte, call_done_date, count(call_status) Qtd_por_status
from leads_basic_details
left join leads_interaction_details on leads_basic_details.lead_id = leads_interaction_details.lead_id
where call_status is not null
group by Fonte,call_done_date

WITH ranked AS (
SELECT
keyword,
sv,
position,
post_name as name_post,
ROW_NUMBER() OVER (
PARTITION BY post_name
ORDER BY sv DESC, position ASC
) AS rank
FROM
cpv_semrush
WHERE
position < 10
),

semrush_treatment as (SELECTname_post,
array_agg((keyword, sv, position)) as keywords_semrush
FROM ranked WHERE
rank <= 10 GROUP BY name_post),


CTE AS (
SELECT
TO_DATE(SUBSTRING(datehourminute FROM 1 FOR 8), 'YYYYMMDD'),
*
FROM
sessions_cpv
JOIN
documents_cpv on documents_cpv.post_name = split_part(sessions_cpv.path, '/', 4)
JOIN
semrush_treatment on documents_cpv.post_name = semrush_treatment.name_post
WHERE
TO_DATE(SUBSTRING(datehourminute FROM 1 FOR 8), 'YYYYMMDD') >= '2023-05-01'
AND
lower(paragraph) like '%%'
AND
lower(title) like '%%'
),

final_cte as (
SELECT
sum(sessions) as sessions,
post_name,
title,
keywords_semrush,
ngrams
FROM
CTE
GROUP BY
post_name,
title,
keywords_semrush,
ngrams
ORDER BY
sum(sessions) DESC
),

temp_cte as  (
SELECT
source_medium,
split_part(path, '/', 4) as post_name_ga,
TO_DATE(SUBSTRING(datehourminute FROM 1 FOR 8), 'YYYYMMDD') as date_ga,
sessions
FROM
sessions_cpv
WHERE
split_part(path, '/', 4) in (
SELECT
post_name
FROM
final_cte
LIMIT 500
)),

model as (
SELECT
sum(sessions) as sessions,
date_ga,
post_name_ga
FROM
temp_cte
GROUP BY
date_ga,
post_name_ga
),

model_2 as (
SELECT
*,
get_week_number(date_ga) as week
FROM
model
WHERE
date_ga > '2023-02-25'
ORDER BY
get_week_number(date_ga) asc
),

model3 as (
SELECT
sum(sessions) as sessions,
week,
post_name_ga
FROM
model_2
GROUP BY
week,
post_name_ga
ORDER BY
week asc
),

model4 as (
SELECT
sessions as week11,
lead(sessions, 1) OVER (PARTITION BY post_name_ga ORDER BY week ASC) AS week12,
lead(sessions, 2) OVER (PARTITION BY post_name_ga ORDER BY week ASC) AS week13,
lead(sessions, 3) OVER (PARTITION BY post_name_ga ORDER BY week ASC) AS week14,
lead(sessions, 4) OVER (PARTITION BY post_name_ga ORDER BY week ASC) AS week15,
lead(sessions, 7) OVER (PARTITION BY post_name_ga ORDER BY week ASC) AS week18,
*

FROM model3 WHERE
week >= 11 AND week <=18 )

SELECT
round(week13/week12, 2) as comp_loses,
round(week18/week11, 2) as comp_stables,
*
FROM model4
WHERE round(week18/week11, 2) is not null
AND round(week18/week11, 2) > 1
ORDER BY week11 desc