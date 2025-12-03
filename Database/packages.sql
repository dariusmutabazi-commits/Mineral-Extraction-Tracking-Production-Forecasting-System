/* packages.sql
   - pkg_extraction: record_extraction, get_7day_avg, check_and_log_anomaly
   - pkg_forecast: generate_daily_report, generate_7day_forecast
   - pkg_alerts: create_alert
*/

/* pkg_extraction */
CREATE OR REPLACE PACKAGE pkg_extraction AS
  PROCEDURE record_extraction(
    p_site_id IN NUMBER,
    p_equip_id IN NUMBER,
    p_crew_id IN NUMBER,
    p_event_time IN DATE,
    p_quantity IN NUMBER,
    p_material IN VARCHAR2,
    p_recorded_by IN VARCHAR2
  );
  FUNCTION get_7day_avg(p_site_id IN NUMBER) RETURN NUMBER;
  PROCEDURE check_and_log_anomaly(p_event_id IN NUMBER);
END pkg_extraction;
/

CREATE OR REPLACE PACKAGE BODY pkg_extraction AS
  PROCEDURE record_extraction(
    p_site_id IN NUMBER,
    p_equip_id IN NUMBER,
    p_crew_id IN NUMBER,
    p_event_time IN DATE,
    p_quantity IN NUMBER,
    p_material IN VARCHAR2,
    p_recorded_by IN VARCHAR2
  ) IS
    v_event_id NUMBER;
  BEGIN
    IF p_quantity < 0 THEN
      RAISE_APPLICATION_ERROR(-20001, 'Quantity must be >= 0');
    END IF;

    v_event_id := event_seq.NEXTVAL;
    INSERT INTO extraction_event(event_id, site_id, equip_id, crew_id, event_time, quantity_tonnes, material_type, recorded_by)
    VALUES (v_event_id, p_site_id, p_equip_id, p_crew_id, p_event_time, p_quantity, p_material, p_recorded_by);

    check_and_log_anomaly(v_event_id);

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      RAISE;
  END record_extraction;

  FUNCTION get_7day_avg(p_site_id IN NUMBER) RETURN NUMBER IS
    v_avg NUMBER := 0;
  BEGIN
    SELECT NVL(AVG(quantity_tonnes),0) INTO v_avg
    FROM extraction_event
    WHERE site_id = p_site_id
      AND event_time >= TRUNC(SYSDATE) - 7;
    RETURN v_avg;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN 0;
  END get_7day_avg;

  PROCEDURE check_and_log_anomaly(p_event_id IN NUMBER) IS
    v_qty NUMBER;
    v_site NUMBER;
    v_avg NUMBER;
    v_dev_pct NUMBER;
  BEGIN
    SELECT quantity_tonnes, site_id INTO v_qty, v_site FROM extraction_event WHERE event_id = p_event_id;
    v_avg := get_7day_avg(v_site);
    IF v_avg > 0 THEN
      v_dev_pct := ABS(v_qty - v_avg) / v_avg * 100;
      IF v_dev_pct > 30 THEN
        INSERT INTO anomaly_log(log_id, event_id, anomaly_type, details)
        VALUES (log_seq.NEXTVAL, p_event_id, 'VOLUME_DEVIATION', 'Deviation '||TO_CHAR(v_dev_pct,'90.00')||'% from 7-day avg');
      END IF;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END check_and_log_anomaly;
END pkg_extraction;
/

-- pkg_forecast
CREATE OR REPLACE PACKAGE pkg_forecast AS
  PROCEDURE generate_daily_report(p_report_date IN DATE := TRUNC(SYSDATE)-1);
  PROCEDURE generate_7day_forecast(p_site_id IN NUMBER);
END pkg_forecast;
/

CREATE OR REPLACE PACKAGE BODY pkg_forecast AS
  PROCEDURE generate_daily_report(p_report_date IN DATE) IS
  BEGIN
    DELETE FROM production_daily WHERE report_date = p_report_date;

    INSERT INTO production_daily(report_date, site_id, total_tonnes, avg_grade)
    SELECT TRUNC(event_time), site_id, NVL(SUM(quantity_tonnes),0), NVL(AVG(s.assay_grade),0)
    FROM extraction_event e LEFT JOIN sample s ON e.event_id = s.event_id
    WHERE TRUNC(event_time) = p_report_date
    GROUP BY TRUNC(event_time), site_id;

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      RAISE;
  END generate_daily_report;

  PROCEDURE generate_7day_forecast(p_site_id IN NUMBER) IS
    v_vals SYS.ODCINUMBERLIST := SYS.ODCINUMBERLIST();
    v_count INTEGER := 0;
    v_weighted_avg NUMBER := 0;
    v_weight_sum NUMBER := 0;
    CURSOR c_hist IS
      SELECT total_tonnes FROM production_daily WHERE site_id = p_site_id ORDER BY report_date DESC FETCH FIRST 14 ROWS ONLY;
  BEGIN
    FOR r IN c_hist LOOP
      v_count := v_count + 1;
      v_vals.EXTEND;
      v_vals(v_count) := r.total_tonnes;
    END LOOP;

    IF v_count = 0 THEN
      NULL;
    ELSE
      FOR i IN 1..v_count LOOP
        v_weighted_avg := v_weighted_avg + v_vals(i) * (v_count - i + 1);
        v_weight_sum := v_weight_sum + (v_count - i + 1);
      END LOOP;
      v_weighted_avg := v_weighted_avg / v_weight_sum;

      DELETE FROM forecast_7day WHERE site_id = p_site_id AND forecast_date > TRUNC(SYSDATE);

      FOR d IN 1..7 LOOP
        INSERT INTO forecast_7day(forecast_date, site_id, predicted_tonnes)
        VALUES (TRUNC(SYSDATE)+d, p_site_id, ROUND(v_weighted_avg,3));
      END LOOP;

      COMMIT;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      RAISE;
  END generate_7day_forecast;
END pkg_forecast;
/

-- pkg_alerts
CREATE OR REPLACE PACKAGE pkg_alerts AS
  PROCEDURE create_alert(p_site_id IN NUMBER, p_type IN VARCHAR2, p_message IN VARCHAR2);
END pkg_alerts;
/

CREATE OR REPLACE PACKAGE BODY pkg_alerts AS
  PROCEDURE create_alert(p_site_id IN NUMBER, p_type IN VARCHAR2, p_message IN VARCHAR2) IS
  BEGIN
    INSERT INTO anomaly_log(log_id, event_id, log_time, anomaly_type, details)
    VALUES (log_seq.NEXTVAL, NULL, SYSDATE, p_type, 'Site '||p_site_id||': '||p_message);
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END create_alert;
END pkg_alerts;
/
