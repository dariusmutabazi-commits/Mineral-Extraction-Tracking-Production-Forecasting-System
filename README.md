# Mineral Extraction Tracking & Production Forecasting System

**Author:** Darius MUTABAZI  
**Student ID:** 28239  
**Course:** PL/SQL Capstone (INSY 8311)  
**Lecturer:** Eric Maniraguha — eric.maniraguha@auca.ac.rw

## Project Overview
A PL/SQL-driven system that records mineral extraction events, validates inputs, summarizes daily production per site, detects anomalies, and generates 7-day production forecasts. The system supports auditing and enforces a DML restriction rule for weekdays and public holidays.

## Features
- Extraction event recording (site, equipment, crew, quantity, material)
- Sample assay recording and grade tracking
- Automatic daily summary generation
- 7-day production forecasting using weighted moving average
- Anomaly detection and logging
- Audit logging and DML restriction on weekdays/holidays

## Quick Start
1. Create tablespaces and the `c##dariusMining28239` 
2. Connect as `c##dariusMining28239`.
3. Run `schema.sql`.
4. Run `packages.sql`.
5. Run `triggers.sql`.
6. Run `data_samples.sql` to populate synthetic data.
7. Run sample queries from `analytics_queries.sql`.

## Repository Structure 
