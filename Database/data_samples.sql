/* data_samples.sql
   - PL/SQL block that inserts sample data across tables.
   - Creates multiple sites, equipment, crews, extraction events, samples, and some holidays.
   - Generates ~300 extraction events and a subset of sample rows.
*/

SET SERVEROUTPUT ON;
BEGIN
  -- Seed small master data
  INSERT INTO mine_site(site_id, site_name, location) VALUES (1, 'North Ridge', 'Kigali Region');
  INSERT INTO mine_site(site_id, site_name, location) VALUES (2, 'East Quarry', 'Eastern Province');
  INSERT INTO mine_site(site_id, site_name, location) VALUES (3, 'South Pit', 'Southern Province');

  INSERT INTO equipment(equip_id, equip_name, equip_type, site_id, status, capacity_tonnes)
  VALUES (101, 'Excavator A', 'Excavator', 1, 'ACTIVE', 120.000);
  INSERT INTO equipment(equip_id, equip_name, equip_type, site_id, status, capacity_tonnes)
  VALUES (102, 'Loader B', 'Loader', 1, 'ACTIVE', 60.000);
  INSERT INTO equipment(equip_id, equip_name, equip_type, site_id, status, capacity_tonnes)
  VALUES (103, 'Dump Truck C', 'Truck', 2, 'ACTIVE', 80.000);
  INSERT INTO equipment(equip_id, equip_name, equip_type, site_id, status, capacity_tonnes)
  VALUES (104, 'Excavator D', 'Excavator', 3, 'MAINTENANCE', 110.000);

  INSERT INTO crew(crew_id, crew_name, shift) VALUES (201, 'Crew Alpha', 'Day');
  INSERT INTO crew(crew_id, crew_name, shift) VALUES (202, 'Crew Beta', 'Night');
  INSERT INTO crew(crew_id, crew_name, shift) VALUES (203, 'Crew Gamma', 'Day');

  -- Some public holidays (example)
  INSERT INTO public_holidays(holiday_date, description) VALUES (TRUNC(SYSDATE)-3, 'Local Holiday A');
  INSERT INTO public_holidays(holiday_date, description) VALUES (TRUNC(SYSDATE)+10, 'Local Holiday B');

  COMMIT;

  -- Generate many extraction events across last 60 days
  DECLARE
    v_start_date DATE := TRUNC(SYSDATE) - 60;
    v_days INTEGER := 61;
    v_event_id NUMBER;
    v_qty NUMBER;
    v_site NUMBER;
    v_equip NUMBER;
    v_crew NUMBER;
    v_mat VARCHAR2(30);
    v_by VARCHAR2(30);
    i INTEGER;
    j INTEGER;
  BEGIN
    FOR i IN 0..v_days-1 LOOP
      -- for each day create variable count of events
      FOR j IN 1..FLOOR(DBMS_RANDOM.VALUE(2,8)) LOOP
        -- pick site/equipment/crew randomly from seeded data
        v_site := TRUNC(DBMS_RANDOM.VALUE(1,4)); -- 1..3
        IF v_site = 1 THEN
          v_equip := CASE TRUNC(DBMS_RANDOM.VALUE(1,3)) WHEN 1 THEN 101 WHEN 2 THEN 102 ELSE 101 END;
        ELSIF v_site = 2 THEN
          v_equip := 103;
        ELSE
          v_equip := 104;
        END IF;
        v_crew := CASE TRUNC(DBMS_RANDOM.VALUE(1,4)) WHEN 1 THEN 201 WHEN 2 THEN 202 WHEN 3 THEN 203 ELSE 201 END;
        v_qty := ROUND(DBMS_RANDOM.VALUE(10, 140),3);
        v_mat := CASE TRUNC(DBMS_RANDOM.VALUE(1,4)) WHEN 1 THEN 'Gold Ore' WHEN 2 THEN 'Copper Ore' WHEN 3 THEN 'Iron Ore' ELSE 'Bauxite' END;
        v_by := 'operator_' || TO_CHAR(TRUNC(DBMS_RANDOM.VALUE(1,20)));
        v_event_id := event_seq.NEXTVAL;
        INSERT INTO extraction_event(event_id, site_id, equip_id, crew_id, event_time, quantity_tonnes, material_type, recorded_by)
        VALUES (v_event_id, v_site, v_equip, v_crew, v_start_date + i + (DBMS_RANDOM.VALUE(0,1)), v_qty, v_mat, v_by);

        -- random chance to create sample (30%)
        IF DBMS_RANDOM.VALUE(0,1) < 0.30 THEN
          INSERT INTO sample(sample_id, event_id, assay_grade, moisture_pct, received_time, lab_technician)
          VALUES (sample_seq.NEXTVAL, v_event_id, ROUND(DBMS_RANDOM.VALUE(0.5, 8.0),4), ROUND(DBMS_RANDOM.VALUE(0.5,5.0),2), v_start_date + i + (DBMS_RANDOM.VALUE(0,1)), 'lab_'||TO_CHAR(TRUNC(DBMS_RANDOM.VALUE(1,10))));
        END IF;
      END LOOP;
    END LOOP;
    COMMIT;
  END;
END;
/
-- After running the above, run the daily report generator for the past days:
BEGIN
  -- generate daily reports for last 30 days
  FOR d IN 0..30 LOOP
    pkg_forecast.generate_daily_report(TRUNC(SYSDATE)-d);
  END LOOP;
  -- generate forecasts for each site
  FOR s IN 1..3 LOOP
    pkg_forecast.generate_7day_forecast(s);
  END LOOP;
END;
/
