
ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD HH24:MI:SS';

-- Sequences
CREATE SEQUENCE event_seq START WITH 1000 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE sample_seq START WITH 5000 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE log_seq START WITH 9000 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE prod_seq START WITH 2000 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE forecast_seq START WITH 3000 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE audit_seq START WITH 4000 INCREMENT BY 1 NOCACHE NOCYCLE;

-- Main tables
CREATE TABLE mine_site (
  site_id NUMBER PRIMARY KEY,
  site_name VARCHAR2(100) NOT NULL,
  location VARCHAR2(100)
);

CREATE TABLE equipment (
  equip_id NUMBER PRIMARY KEY,
  equip_name VARCHAR2(100) NOT NULL,
  equip_type VARCHAR2(50),
  site_id NUMBER NOT NULL,
  status VARCHAR2(20),
  capacity_tonnes NUMBER(12,3),
  CONSTRAINT fk_equipment_site FOREIGN KEY (site_id) REFERENCES mine_site(site_id)
);

CREATE TABLE crew (
  crew_id NUMBER PRIMARY KEY,
  crew_name VARCHAR2(100) NOT NULL,
  shift VARCHAR2(20)
);

CREATE TABLE extraction_event (
  event_id NUMBER PRIMARY KEY,
  site_id NUMBER NOT NULL,
  equip_id NUMBER NOT NULL,
  crew_id NUMBER NOT NULL,
  event_time DATE DEFAULT SYSDATE,
  quantity_tonnes NUMBER(12,3) CHECK (quantity_tonnes >= 0),
  material_type VARCHAR2(50),
  sample_id NUMBER,
  recorded_by VARCHAR2(100),
  CONSTRAINT fk_event_site FOREIGN KEY (site_id) REFERENCES mine_site(site_id),
  CONSTRAINT fk_event_equip FOREIGN KEY (equip_id) REFERENCES equipment(equip_id),
  CONSTRAINT fk_event_crew FOREIGN KEY (crew_id) REFERENCES crew(crew_id)
);

CREATE TABLE sample (
  sample_id NUMBER PRIMARY KEY,
  event_id NUMBER NOT NULL,
  assay_grade NUMBER(6,4) CHECK (assay_grade BETWEEN 0 AND 100),
  moisture_pct NUMBER(5,2),
  received_time DATE,
  lab_technician VARCHAR2(100),
  CONSTRAINT fk_sample_event FOREIGN KEY (event_id) REFERENCES extraction_event(event_id)
);

CREATE TABLE anomaly_log (
  log_id NUMBER PRIMARY KEY,
  event_id NUMBER,
  log_time DATE DEFAULT SYSDATE,
  anomaly_type VARCHAR2(50),
  details VARCHAR2(4000)
);

CREATE TABLE production_daily (
  report_date DATE,
  site_id NUMBER,
  total_tonnes NUMBER(14,3),
  avg_grade NUMBER(6,4),
  created_at DATE DEFAULT SYSDATE,
  CONSTRAINT pk_prod_daily PRIMARY KEY (report_date, site_id),
  CONSTRAINT fk_prod_site FOREIGN KEY (site_id) REFERENCES mine_site(site_id)
);

CREATE TABLE forecast_7day (
  forecast_date DATE,
  site_id NUMBER,
  predicted_tonnes NUMBER(14,3),
  prediction_generated_at DATE DEFAULT SYSDATE,
  CONSTRAINT pk_forecast PRIMARY KEY (forecast_date, site_id),
  CONSTRAINT fk_forecast_site FOREIGN KEY (site_id) REFERENCES mine_site(site_id)
);

-- Audit and Holiday tables
CREATE TABLE audit_log (
  audit_id NUMBER PRIMARY KEY,
  audit_time DATE DEFAULT SYSDATE,
  username VARCHAR2(100),
  operation VARCHAR2(10),
  table_name VARCHAR2(100),
  row_id VARCHAR2(200),
  status VARCHAR2(20),
  details VARCHAR2(4000)
);

CREATE TABLE public_holidays (
  holiday_date DATE PRIMARY KEY,
  description VARCHAR2(200)
);

-- Indexes
CREATE INDEX idx_event_time ON extraction_event(event_time);
CREATE INDEX idx_prod_date ON production_daily(report_date);

COMMIT;
