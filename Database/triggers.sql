/* triggers.sql
   - Trigger: trg_after_insert_sample
   - Compound trigger: trg_audit_restrict_extraction
*/

-- Trigger: update production_daily.avg_grade after sample insert
CREATE OR REPLACE TRIGGER trg_after_insert_sample
AFTER INSERT ON sample
FOR EACH ROW
DECLARE
  v_event_time DATE;
  v_site_id NUMBER;
BEGIN
  SELECT event_time, site_id INTO v_event_time, v_site_id FROM extraction_event WHERE event_id = :NEW.event_id;

  UPDATE production_daily pd
  SET avg_grade = (
    SELECT NVL(AVG(s.assay_grade),0)
    FROM sample s JOIN extraction_event e ON s.event_id = e.event_id
    WHERE TRUNC(e.event_time) = pd.report_date AND e.site_id = pd.site_id
  )
  WHERE pd.report_date = TRUNC(v_event_time) AND pd.site_id = v_site_id;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    NULL;
END trg_after_insert_sample;
/

-- Restriction function (used by trigger)
CREATE OR REPLACE FUNCTION func_is_operation_allowed RETURN BOOLEAN IS
  v_today DATE := TRUNC(SYSDATE);
  v_dummy NUMBER;
BEGIN
  -- Block weekdays Mon-Fri
  IF TO_CHAR(v_today, 'DY', 'NLS_DATE_LANGUAGE=ENGLISH') IN ('MON','TUE','WED','THU','FRI') THEN
    RETURN FALSE;
  END IF;

  -- Block if today is a public holiday
  SELECT 1 INTO v_dummy FROM public_holidays WHERE holiday_date = v_today;
  RETURN FALSE;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN TRUE;
  WHEN OTHERS THEN
    RETURN FALSE;
END func_is_operation_allowed;
/

-- Audit logging procedure
CREATE OR REPLACE PROCEDURE proc_log_audit(
  p_operation IN VARCHAR2,
  p_table IN VARCHAR2,
  p_rowid IN VARCHAR2,
  p_status IN VARCHAR2,
  p_details IN VARCHAR2
) IS
BEGIN
  INSERT INTO audit_log(audit_id, audit_time, username, operation, table_name, row_id, status, details)
  VALUES (audit_seq.NEXTVAL, SYSDATE, SYS_CONTEXT('USERENV','SESSION_USER'), p_operation, p_table, p_rowid, p_status, p_details);
  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    NULL;
END proc_log_audit;
/

-- Compound trigger for extraction_event (enforce DML restriction & audit)
CREATE OR REPLACE TRIGGER trg_audit_restrict_extraction
FOR INSERT OR UPDATE OR DELETE ON extraction_event
COMPOUND TRIGGER
  TYPE t_rowids IS TABLE OF VARCHAR2(200) INDEX BY PLS_INTEGER;
  g_rowids t_rowids;
  g_cnt PLS_INTEGER := 0;

  BEFORE STATEMENT IS
  BEGIN
    IF NOT func_is_operation_allowed THEN
      proc_log_audit('BATCH_CHECK', 'EXTRACTION_EVENT', NULL, 'DENIED', 'DML operations are not allowed today (weekday/holiday)');
      RAISE_APPLICATION_ERROR(-20002, 'DML operations are not allowed today (weekday/holiday)');
    END IF;
  END BEFORE STATEMENT;

  BEFORE EACH ROW IS
  BEGIN
    g_cnt := g_cnt + 1;
    IF INSERTING THEN
      g_rowids(g_cnt) := 'INSERT';
    ELSIF UPDATING THEN
      g_rowids(g_cnt) := 'UPDATE';
    ELSIF DELETING THEN
      g_rowids(g_cnt) := 'DELETE';
    ELSE
      g_rowids(g_cnt) := 'UNKNOWN';
    END IF;
  END BEFORE EACH ROW;

  AFTER STATEMENT IS
  BEGIN
    proc_log_audit('DML', 'EXTRACTION_EVENT', 'rows='||TO_CHAR(g_cnt), 'ALLOWED', 'DML operation completed successfully');
  END AFTER STATEMENT;
END trg_audit_restrict_extraction;
/
