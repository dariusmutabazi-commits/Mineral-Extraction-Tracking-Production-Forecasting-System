/* analytics_queries.sql
   - Useful queries for BI dashboard and analysis
*/

/* 1. Daily production trend (last 30 days for all sites) */
SELECT report_date, site_id, SUM(total_tonnes) total
FROM production_daily
WHERE report_date >= TRUNC(SYSDATE)-30
GROUP BY report_date, site_id
ORDER BY report_date;

/* 2. Total production by site (last 30 days) */
SELECT site_id, SUM(total_tonnes) total_30d
FROM production_daily
WHERE report_date >= TRUNC(SYSDATE)-30
GROUP BY site_id
ORDER BY total_30d DESC;

/* 3. Forecast vs Actual (site 1) */
SELECT f.forecast_date, f.predicted_tonnes, pd.total_tonnes actual
FROM forecast_7day f LEFT JOIN production_daily pd
  ON f.forecast_date = pd.report_date AND f.site_id = pd.site_id
WHERE f.site_id = 1
ORDER BY f.forecast_date;

/* 4. Top 5 crews by total extraction (last 14 days) */
SELECT e.crew_id, c.crew_name, SUM(e.quantity_tonnes) total
FROM extraction_event e JOIN crew c ON e.crew_id = c.crew_id
WHERE e.event_time >= TRUNC(SYSDATE)-14
GROUP BY e.crew_id, c.crew_name
ORDER BY total DESC FETCH FIRST 5 ROWS ONLY;

/* 5. Equipment utilization estimate: total tonnes / capacity (last 30 days) */
SELECT e.equip_id, e.equip_name,
       SUM(ev.quantity_tonnes) total_30d,
       e.capacity_tonnes,
       ROUND(SUM(ev.quantity_tonnes) / (NVL(e.capacity_tonnes,1) * 30) * 100,2) est_util_pct
FROM equipment e
JOIN extraction_event ev ON e.equip_id = ev.equip_id
WHERE ev.event_time >= TRUNC(SYSDATE)-30
GROUP BY e.equip_id, e.equip_name, e.capacity_tonnes
ORDER BY est_util_pct DESC;

/* 6. Anomaly summary (last 30 days) */
SELECT anomaly_type, COUNT(*) cnt
FROM anomaly_log
WHERE log_time >= SYSDATE - 30
GROUP BY anomaly_type;

/* 7. Recent audit log */
SELECT * FROM audit_log ORDER BY audit_time DESC FETCH FIRST 50 ROWS ONLY;
