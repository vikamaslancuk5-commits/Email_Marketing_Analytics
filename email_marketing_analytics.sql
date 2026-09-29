WITH
base_account as (
-- виводимо всі дані по акаунтах
SELECT
s.date,
sp.country,
acc.send_interval,
acc.is_verified,
acc.is_unsubscribed,
acc.id AS account_id
FROM `data-analytics-mate.DA.session` AS s
JOIN `data-analytics-mate.DA.session_params` AS sp
ON s.ga_session_id = sp.ga_session_id
JOIN `data-analytics-mate.DA.account_session` AS ass
ON s.ga_session_id = ass.ga_session_id
JOIN `data-analytics-mate.DA.account` AS acc
ON ass.account_id = acc.id
),


metrics AS (
-- рахуємо кількості акаунтів, використовуємо UNION ALL, виводимо дату, рахуємо кількості листів
SELECT
ba.date,
ba.country,
ba.send_interval,
ba.is_verified,
ba.is_unsubscribed,
COUNT(DISTINCT account_id) AS account_cnt,
0 AS sent_msg,
0 AS open_msg,
0 AS visit_msg
FROM base_account AS ba
GROUP BY ba.date, ba.country, ba.send_interval, ba.is_verified, ba.is_unsubscribed
UNION ALL
SELECT
date_add(ba.date, INTERVAL sent_date DAY),
ba.country,
ba.send_interval,
ba.is_verified,
ba.is_unsubscribed,
    0 AS account_cnt,
    COUNT(DISTINCT es.id_message) AS sent_msg,
    COUNT(DISTINCT eo.id_message) AS open_msg,
    COUNT(DISTINCT ev.id_message) AS visit_msg
FROM base_account AS ba
JOIN `data-analytics-mate.DA.email_sent` AS es
ON ba.account_id = es.id_account
LEFT JOIN `data-analytics-mate.DA.email_open` as eo
ON es.id_message = eo.id_message
LEFT JOIN `data-analytics-mate.DA.email_visit` AS ev
ON es.id_message = ev.id_message
GROUP BY date_add(ba.date, INTERVAL sent_date DAY), ba.country, ba.send_interval, ba.is_verified, ba.is_unsubscribed
),


combined_data AS (
-- комбінуємо метрики
  SELECT
    date, country, send_interval, is_verified, is_unsubscribed,
    SUM(account_cnt) AS account_cnt,
    SUM(sent_msg) AS sent_msg,
    SUM(open_msg) AS open_msg,
    SUM(visit_msg) AS visit_msg
  FROM metrics
  GROUP BY date, country, send_interval, is_verified, is_unsubscribed
),


final_with_totals AS(
-- рахуємо тотали
SELECT *,
SUM (account_cnt) OVER (PARTITION BY country) AS total_country_account_cnt,
SUM (sent_msg) OVER (PARTITION BY country) AS total_country_sent_cnt
FROM combined_data
),


ranked_data AS (
-- додаємо ранги
SELECT *,
DENSE_RANK() OVER (ORDER BY total_country_account_cnt DESC) AS rank_total_country_account_cnt,
DENSE_RANK() OVER (ORDER BY total_country_sent_cnt DESC) AS rank_total_country_sent_cnt
FROM final_with_totals
)


-- фінальний SELECT, виводимо всі потрібні стовпці. Додаємо WHERE, щоб відсіяти лишні значення
SELECT
date, country, send_interval, is_verified, is_unsubscribed, account_cnt, sent_msg, open_msg, visit_msg, total_country_account_cnt , total_country_sent_cnt, rank_total_country_account_cnt, rank_total_country_sent_cnt
FROM ranked_data
WHERE rank_total_country_account_cnt <= 10 OR rank_total_country_sent_cnt <= 10
ORDER BY rank_total_country_account_cnt ASC, date DESC
