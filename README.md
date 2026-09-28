# Plastic Recycling | Manufacturing & ESG Operations Analysis

An enterprise-grade business intelligence and data engineering solution built on **PostgreSQL**, **Power BI**, and **DAX**. This system models end-to-end operational telemetry, mass balance recovery, and decarbonization accounting for a closed-loop post-consumer plastic recycling and blown-film manufacturing facility.

---

## 1. Project Overview & Business Context

Post-consumer polymer recycling requires strict synchronization across multi-stage chemical, mechanical, and thermal processes. Inefficiencies at the wash line or compounding stage cascade downstream into mechanical line downtime and conversion scrap.

This platform bridges plant floor execution with executive decision-making:
* **Feedstock Sourcing & Intake:** Quantifying supplier contamination penalties and net payable mass.
* **Wash Line Mass Balance:** Measuring hydrocyclone separation efficiency and clean flake yields.
* **Compounding & Energy Intensity:** Monitoring extruder Specific Energy Consumption (kWh/tonne) and verifying Post-Consumer Recycled (PCR) polymer content.
* **Quality Assurance (QA) Certification:** Enforcing rheological and tensile compliance across production batches.
* **Downstream Conversion Line Reliability:** Diagnosing machine downtime root causes on blown-film extrusion and bag conversion lines.
* **Commercial Realization & Scope 3 ESG Accounting:** Calculating revenue realization per metric tonne across market segments and certifying customer Scope 3 greenhouse gas avoidance.

---

## 2. Data Architecture: Fact Constellation (Galaxy Schema)

The analytical data engine implements a **Kimball Fact Constellation Schema** with shared, conformed dimensions. Because individual plant stages operate at varying operational granularities, the model utilizes multiple fact tables unified by conformed Date and Customer dimensions.

### Table Dictionary & Granularity

| Table | Entity Type | Grain / Key Metric | Description |
| :--- | :--- | :--- | :--- |
| **Dim_Date** | Conformed Dimension | Daily (Date) | Master fiscal and operational calendar. |
| **dim_customer** | Conformed Dimension | Customer Account (customer_id) | Commercial client segments (Wholesale, Local Authority, Commercial, Retail). |
| **weighbridge_intake** | Fact | Weighment Ticket (ticket_id) | Inbound bale weighments, tare weights, and sample contamination tests. |
| **wash_batches** | Fact | Wash Run (batch_id) | Wet friction washing, sink-float separation, and reject mass tracking. |
| **extrusion_compounding** | Fact | Pellet Run (extrusion_id) | Polymer compounding, virgin/additive mix, power telemetry (kWh), and pellet yield. |
| **qa_lab_tests** | Fact | Lab Certificate (test_id) | Melt Flow Index (MFI), tensile yield, density, and release status. |
| **bag_production** | Fact | Shift Job (job_id) | Blown-film extrusion, bag conversion scrap, and stoppage root causes. |
| **outbound_dispatch** | Fact | Sales Invoice (dispatch_id) | Finished goods logistics, invoiced revenue, and certified mass deliveries. |

---

## 3. Plant Diagnostics & Root Cause Findings (Sep 01–05, 2026)

* **Wash Line Balance:** The wash facility achieved an **85.75% recovery yield** on 810.26 tonnes of gross intake. Line 2 carried 62% of total throughput (442.56K kg flake output vs. Line 1's 270.32K kg), identifying an upstream conveyor feed bottleneck.
* **Quality-Driven Conversion Scrap:** While pellet compounding maintained an **86.10% PCR purity level**, only **57.61% of lots achieved Prime Pass status**. Over **32.6% of batches were Downgraded** due to melt-flow index (MFI) and tensile variance.
* **Downstream Reliability Failure:** Blown-film line telemetry recorded **5,345 minutes of downtime** and a **6.45% conversion scrap rate**. Two failure modes represented **75.8% of all stoppages**:
  * **Seal Failure:** 2,435 minutes
  * **Bubble Burst:** 1,616 minutes
  * *Root Cause Finding:* Processing downgraded polymer lots directly correlated with bubble stability loss and poor heat sealing in bag making machines.
* **Commercial Realization:** Revenue realization remained uniform across channels:
  * **Wholesale Distribution:** €1,940.86 / tonne
  * **Local Authority:** €1,921.64 / tonne
  * **Commercial Distribution:** €1,910.55 / tonne
  * **Retail Supermarket:** €1,887.91 / tonne
