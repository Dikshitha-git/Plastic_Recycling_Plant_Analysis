SELECT * FROM bag_production
SELECT * FROM weighbridge_intake
SELECT * FROM wash_batches
SELECT * FROM qa_lab_tests
SELECT * FROM extrusion_compounding
SELECT * FROM outbound_dispatch

ALTER TABLE extrusion_compounding
RENAME COLUMN extruder_id TO extruder_machine_code;

--Challenge 1: Supplier Contamination Audit & Invoicing
"""
Business Context:
The commercial contract allows suppliers up to 5.00% contamination. If a load arrives with more 
than 5.00% contamination, the factory deducts the excess percentage directly from the payable tonnage
"""
SELECT supplier_id,
       hauler_id,
	   net_weight_kg,
	   sample_contamination_pct
FROM weighbridge_intake FILTER WHERE sample_contamination_pct > 5.00

SELECT supplier_id,
COUNT(ticket_id) AS total_deliveries,
ROUND(SUM(net_weight_kg)/1000, 2) AS total_net_tonnes,
AVG(sample_contamination_pct) AS Avg_Contamination_Percentage
FROM weighbridge_intake
GROUP BY supplier_id

SELECT supplier_id,
       COUNT(ticket_id) AS total_deliveries,
       ROUND(SUM(net_weight_kg)/1000, 2) AS total_net_tonnes,
	   AVG(sample_contamination_pct) AS Avg_Contamination_Percentage,
	   ROUND(
	   SUM(net_weight_kg/1000.0
	   *
	   CASE
	       WHEN sample_contamination_pct > 5.00 
		   THEN (1.0 - (sample_contamination_pct - 5.00) / 100.0)
		   ELSE 1.00
	   END 
	   *
	   price_per_tonne), 2) AS total_payable_eur
FROM weighbridge_intake
GROUP BY supplier_id
ORDER BY total_payable_eur DESC

--Challenge 2: Wash Line Yield & Mass Balance Reconciliation (Joins & Metrics)
"""
Business Context:
The wash plant takes dirty flakes (feed_mass_kg), washes them, and splits them into clean usable 
flakes (clean_flake_output_kg) and solid waste (reject_waste_kg). Plant management needs to know:
Which wash line (LINE_1 vs. LINE_2) has better recovery yield.
How much unaccounted mass disappears during the wash cycle (loss to wash water, 
centrifuge evaporation, or floor spills).
"""

SELECT wb.line_id, 
       w.polymer_type,
	   COUNT(wb.batch_id) AS total_batches_processed,
	   ROUND(SUM(wb.feed_mass_kg) / 1000.0, 2) AS total_feed_tonnes,
	   ROUND(SUM(wb.clean_flake_output_kg) / 1000.0, 2) AS total_clean_tonnes,
	   ROUND(SUM(wb.clean_flake_output_kg) / SUM(wb.feed_mass_kg) * 100, 2) AS recovery_yield_pct,
	   ROUND(AVG(wb.feed_mass_kg - (wb.clean_flake_output_kg + wb.reject_waste_kg)), 2) AS avg_unaccounted_loss_kg
FROM weighbridge_intake w
JOIN wash_batches wb
ON wb.ticket_id = w.ticket_id
GROUP BY wb.line_id, w.polymer_type

--Challenge 3: Wash Line Energy Anomaly Detection
"""
The Business Context
Washing dirty plastic consumes large amounts of power. High-speed friction washers spin at 1,500 RPM, 
centrifugal dryers fling water off flakes, and thermal blowers heat air to dry the polymer 
before extrusion.
When mechanical operations run smoothly, energy consumption remains stable.
If flexible film wraps around an agitator axle, water screens become clogged with paper pulp, 
or motor bearings begin to fail, motor drag increases significantly. The machine draws heavy 
electrical current without producing extra clean flake.
Plant maintenance needs to identify the top 3 worst energy-spike batches for each wash line 
(LINE_1 and LINE_2) so engineering can inspect the equipment during scheduled downtime.
"""
WITH batch_energy_metrics AS (
SELECT wb.line_id,
       wb.batch_id,
	   wb.start_time,
	   wb.clean_flake_output_kg,
	   wb.energy_kwh,
	   ROUND(wb.energy_kwh / wb.clean_flake_output_kg, 3) AS batch_energy_intensity,
	   ROUND(AVG(wb.energy_kwh / wb.clean_flake_output_kg) OVER (PARTITION BY wb.line_id), 3) AS line_avg_energy_intensity,
	   ROUND((wb.energy_kwh / wb.clean_flake_output_kg) - AVG(wb.energy_kwh / wb.clean_flake_output_kg) 
	   OVER (PARTITION BY wb.line_id), 3) AS variance_from_line_avg,
	   DENSE_RANK() 
	   OVER(PARTITION BY wb.line_id 
       ORDER BY (wb.energy_kwh / wb.clean_flake_output_kg) DESC ) AS energy_rank
FROM wash_batches wb)
SELECT 
    line_id,
    energy_rank,
    batch_id,
    start_time,
    clean_flake_output_kg,
    energy_kwh,
    batch_energy_intensity,
    line_avg_energy_intensity,
    variance_from_line_avg
FROM batch_energy_metrics
WHERE energy_rank <= 3
ORDER BY line_id, energy_rank;

--Challenge 4: Extruder Performance & QA Lab Release Certification
"""
Before any melted pellet lot can be released to the factory floor to be blown into bags, 
a QA technician draws a physical sample and tests it in the laboratory. If the pellets 
fail QA standards, they are rejected and cannot proceed to bag_production.
"""
SELECT COUNT(test_id) AS total_lots_tested FROM qa_lab_tests
----------------------------------------------------------------------------------------------------------------
SELECT ex.extruder_machine_code,
       COUNT(qa.test_id) AS total_lots_tested,
       COUNT(CASE WHEN qa.qa_status = 'PASSED' THEN 1 END) AS passed_lots,
	   COUNT(CASE WHEN qa.qa_status = 'REJECTED' THEN 1 END) AS rejected_lots,
	   ROUND((COUNT(CASE WHEN qa.qa_status = 'PASSED' THEN 1 END) * 100.0) / COUNT(*),2) AS qa_pass_rate_pct,
	   ROUND(AVG(qa.melt_flow_index), 2) AS avg_mfi,
	   ROUND(AVG(qa.moisture_pct), 3) AS Avg_moisture_pct,
	   ROUND(AVG(qa.tensile_break_strength_mpa), 2) AS avg_tensile_strength_mpa
FROM qa_lab_tests qa
JOIN extrusion_compounding ex
ON qa.extrusion_id = ex.extrusion_id
GROUP BY ex.extruder_machine_code

--Challenge 5: Bag Conversion Scrap & Production Efficiency
"""
The Business Context
In the bag conversion department, certified plastic pellets are pneumatically fed into high-speed blown 
film extrusion lines (BAG_M01, BAG_M02, etc.).
The machine melts the pellets, blows a continuous vertical air bubble of thin plastic film, 
flattens it through nip rollers, heat-welds the bottom seams (star-seal or flat-weld), punches perforations, 
and winds finished refuse sacks onto coreless rolls.
During this process, scrap is generated in three ways:
Startup / Gauge Calibration Scrap: Pellets melted while technicians adjust bubble diameter and 
film thickness (gauge) to meet specifications.
Edge Trim: Slitting circular bubbles into flat continuous sheets produces thin edge ribbons
that must be cut off.
Heat-Seal Burns & Web Snaps: High-speed perforation blades or hot sealing wires that overheat or tear the web.
Every kilogram of scrap must be thrown into a regrind bin and re-extruded, consuming extra energy, labor,
and machine capacity. Plant managers target a conversion scrap rate under 4.00%.
"""
SELECT * FROM bag_production LIMIT 1;

SELECT machine_id,
       sku_id,
	   COUNT(work_order_id) AS total_work_orders,
	   ROUND(SUM(pellet_input_kg) / 1000, 2) AS total_pellet_input_tonnes,
	   SUM(units_produced) AS total_units_produced,
	   ROUND(SUM(scrap_kg) / 1000, 2) AS total_scrap_tonnes,
	   ROUND(SUM(scrap_kg) / SUM(pellet_input_kg) * 100, 2) AS scrap_rate_pct,
	   CASE
	       WHEN ROUND(SUM(scrap_kg) / SUM(pellet_input_kg) * 100, 2) >= 4.00 THEN 'HIGH_SCRAP'
		   ELSE 'EFFICIENT'
	   END AS performance_flag
FROM bag_production
GROUP BY machine_id, sku_id
ORDER BY machine_id ASC, scrap_rate_pct DESC

--Challenge 6: Outbound Sales, Margins & ESG Carbon Savings
"""
Finished products are sold to two main customer types:
Irish & UK Retailers / Councils: Buy finished palletized sacks (BAG-REFUSE-85L, etc.).
Industrial Packaging Manufacturers: Buy pure washed rPET flakes or recycled compound pellets directly 
in 1-tonne bulk bags (bypassing bag conversion).
To win corporate retail contracts (like Tesco or Musgrave), Shabra provides an ESG Environmental Impact 
Certificate on every delivery manifest showing how much virgin oil and carbon emissions were avoided by 
using post-consumer recycled plastic instead of virgin plastic.
"""

SELECT od.customer_id,
       bp.sku_id,
	   COUNT(od.dispatch_id) AS total_truckload_dispatch,
	   ROUND(SUM(od.net_mass_shipped_kg)/1000, 2) AS total_dispatched_tonnes,
	   ROUND(SUM(od.invoice_value_eur), 2) AS gross_revenue_eur,
	   ROUND(SUM(od.invoice_value_eur) / (SUM(od.net_mass_shipped_kg) / 1000.0), 2) AS avg_price_per_tonne_eur,
	   ROUND(SUM(od.avoided_co2e_kg)/1000, 2) AS total_co2_saved_tonnes
FROM outbound_dispatch od
JOIN bag_production bp	   
ON od.work_order_id = bp.work_order_id
GROUP BY od.customer_id, bp.sku_id
ORDER BY gross_revenue_eur 


-- 1. Create the physical Dim_Customer table
CREATE TABLE dim_customer (
    customer_id VARCHAR(40) PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    customer_segment VARCHAR(50) NOT NULL,
    account_region VARCHAR(50) DEFAULT 'Republic of Ireland'
);

-- 2. Populate it cleanly from your existing dispatch data
INSERT INTO dim_customer (customer_id, customer_name, customer_segment)
VALUES
    ('CUST-TESCO-IE', 'Tesco Ireland', 'Retail Supermarket'),
    ('CUST-BWG-FOODS', 'BWG Foods (Spar / Mace)', 'Wholesale Distribution'),
    ('CUST-BUNZL-CLEAN', 'Bunzl Cleaning & Hygiene', 'Commercial Distribution'),
    ('CUST-DUBLIN-COUNCIL', 'Dublin City Council', 'Local Authority'),
    ('CUST-MONAGHAN-COUNCIL', 'Monaghan County Council', 'Local Authority')
ON CONFLICT (customer_id) DO NOTHING;





