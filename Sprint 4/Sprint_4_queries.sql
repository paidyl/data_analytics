-- =============================================
-- SPRINT 4 - BIGQUERY AVANÇAT
-- =============================================

-- NIVELL 1 - EXERCICI 1
-- Taula no optimitzada
SELECT *
FROM `sprint3-analytics-lydia.sprint3_silver.transactions_clean` AS t
JOIN `sprint3-analytics-lydia.sprint3_silver.companies_clean` AS c
    ON t.business_id = c.company_id
WHERE DATE(t.timestamp) = DATE '2022-03-12'
  AND c.country = 'Germany';

  -- NIVELL 1 - EXERCICI 2
-- Pas 1: Generació de dades recents

CREATE OR REPLACE TABLE `sprint3-analytics-lydia.sprint3_silver.transactions_recent` AS
SELECT * EXCEPT (timestamp),
  TIMESTAMP_SUB(
    CURRENT_TIMESTAMP(),
    INTERVAL CAST(FLOOR(RAND() * 50) AS INT64) DAY
  ) AS timestamp
FROM `sprint3-analytics-lydia.sprint3_silver.transactions_clean`;


-- Pas 2: Particionament i clustering
CREATE OR REPLACE TABLE `sprint3-analytics-lydia.sprint3_gold.fact_transactions_optimized`
PARTITION BY DATE(timestamp)
CLUSTER BY business_id AS
SELECT *
FROM `sprint3-analytics-lydia.sprint3_silver.transactions_recent`;


-- NIVELL 1 - EXERCICI 3
-- Pas 1: taula sense particionar

SELECT *
FROM `sprint3-analytics-lydia.sprint3_silver.transactions_recent`
WHERE DATE(timestamp) BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 29 DAY) AND CURRENT_DATE();

-- Pas 2: taula particionada
SELECT *
FROM `sprint3-analytics-lydia.sprint3_gold.fact_transactions_optimized`
WHERE DATE(timestamp) BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 29 DAY) AND CURRENT_DATE();

-- NIVELL 1 - EXERCICI 4
-- Creació de la vista materialitzada

CREATE OR REPLACE MATERIALIZED VIEW `sprint3-analytics-lydia.sprint3_gold.mv_daily_sales` AS
SELECT
  DATE(timestamp) AS data,
  SUM(amount) AS vendes_totals
FROM `sprint3-analytics-lydia.sprint3_gold.fact_transactions_optimized`
WHERE declined = 0
GROUP BY data;

-- Consulta de la vista materialitzada

SELECT data, ROUND(vendes_totals, 2) AS vendes_totals
FROM `sprint3-analytics-lydia.sprint3_gold.mv_daily_sales`
ORDER BY data;

-- NIVELL 2 - EXERCICI 1
-- Perfil de clients VIP

WITH VIP_Stats AS (
  SELECT
    user_id, COUNT(*) AS num_compres,
    ROUND(AVG(amount), 2) AS tiquet_mig,
    MAX(amount) AS max_compra,
    SUM(amount) AS total_gastat
  FROM `sprint3-analytics-lydia.sprint3_silver.transactions_clean`
  WHERE  declined = 0
  GROUP BY user_id
  HAVING SUM(amount) > 500
)
SELECT
  v.user_id,
  CONCAT(u.name, ' ', u.surname) AS nom_complet,
  u.email, v.num_compres, v.tiquet_mig, v.max_compra,
  ROUND(v.total_gastat, 2) AS total_gastat
FROM VIP_Stats v
JOIN `sprint3-analytics-lydia.sprint3_silver.users_combined` u 
  ON v.user_id = u.user_id
ORDER BY v.total_gastat DESC;

-- NIVELL 2 - EXERCICI 2
-- Evolució diària de les vendes

WITH vendes_anteriors AS (
  SELECT data, vendes_totals,
    LAG(data) OVER (ORDER BY data) AS data_anterior,
    LAG(vendes_totals) OVER (ORDER BY data) AS vendes_fila_anterior
  FROM `sprint3-analytics-lydia.sprint3_gold.mv_daily_sales`
)
SELECT data, ROUND(vendes_totals, 2) AS vendes_avui,
  CASE
    WHEN data_anterior = DATE_SUB(data, INTERVAL 1 DAY)
      THEN ROUND(vendes_fila_anterior, 2)
  END AS vendes_ahir,
  CASE
    WHEN data_anterior = DATE_SUB(data, INTERVAL 1 DAY)
      THEN ROUND(SAFE_DIVIDE(vendes_totals - vendes_fila_anterior, vendes_fila_anterior) * 100, 2)
  END AS diff_percentual
FROM vendes_anteriors
ORDER BY data;

-- NIVELL 2 - EXERCICI 3
-- Vendes acumulades anuals

SELECT data,
  ROUND(vendes_totals, 2) AS vendes_dia,
  ROUND(SUM(vendes_totals) OVER (
        PARTITION BY EXTRACT(YEAR FROM data)
        ORDER BY data
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ), 2) AS vendes_acumulades_ytd
FROM `sprint3-analytics-lydia.sprint3_gold.mv_daily_sales`
ORDER BY data;

-- NIVELL 2 - EXERCICI 4
-- Tercera compra i mitjana de les tres primeres
WITH tres_compres AS (
  SELECT t.user_id, t.transaction_id, t.timestamp, t.amount,
    ROW_NUMBER() OVER (
      PARTITION BY t.user_id
      ORDER BY t.timestamp, t.transaction_id
    ) AS num_compra
  FROM `sprint3-analytics-lydia.sprint3_gold.fact_transactions_optimized` AS t
  WHERE t.declined = 0
  QUALIFY num_compra <= 3
),
resum_compres AS (
  SELECT c.user_id,
    MAX(IF(c.num_compra = 3, c.timestamp, NULL)) AS data_tercera_compra,
    MAX(IF(c.num_compra = 3, c.amount, NULL)) AS import_tercera_compra,
    AVG(c.amount) AS mitjana_3_compres
  FROM tres_compres AS c
  GROUP BY c.user_id
  HAVING COUNT(*) = 3
)
SELECT u.user_id, CONCAT(u.name, ' ', u.surname) AS nom_complet, u.email,
  c.data_tercera_compra, c.import_tercera_compra,
  ROUND(c.mitjana_3_compres, 2) AS mitjana_3_compres
FROM resum_compres AS c
JOIN `sprint3-analytics-lydia.sprint3_silver.users_combined` AS u
  ON c.user_id = u.user_id
ORDER BY u.user_id;

-- Comprovació de les tres primeres compres de l'usuari 1
SELECT t.transaction_id, t.timestamp, t.amount
FROM `sprint3-analytics-lydia.sprint3_gold.fact_transactions_optimized` AS t
WHERE t.user_id = 1 AND t.declined = 0
ORDER BY t.timestamp, t.transaction_id
LIMIT 3;


-- NIVELL 3 - EXERCICI 1
-- Creació de la taula de transaccions aplanada

CREATE OR REPLACE TABLE `sprint3-analytics-lydia.sprint3_gold.dim_transactions_flat` AS
SELECT t.transaction_id, t.timestamp, t.amount AS total_ticket,
  p.product_id AS product_sku, p.name AS product_name, p.price AS product_price
FROM `sprint3-analytics-lydia.sprint3_silver.transactions_clean` AS t
CROSS JOIN UNNEST(t.product_ids) AS product_id
JOIN `sprint3-analytics-lydia.sprint3_silver.products_clean` AS p
  ON product_id = p.product_id
WHERE t.declined = 0;

-- Comprovació d'una transacció
SELECT *
FROM `sprint3-analytics-lydia.sprint3_gold.dim_transactions_flat`
WHERE transaction_id = (
  SELECT transaction_id
  FROM `sprint3-analytics-lydia.sprint3_gold.dim_transactions_flat`
  GROUP BY transaction_id
  HAVING COUNT(*) > 1
  LIMIT 1
)
ORDER BY product_sku;

-- NIVELL 3 - EXERCICI 2
-- Rànquing dels 5 productes més venuts

SELECT t.product_name, COUNT(*) AS unitats_venudes
FROM `sprint3-analytics-lydia.sprint3_gold.dim_transactions_flat` AS t
GROUP BY t.product_name
ORDER BY unitats_venudes DESC, t.product_name
LIMIT 5;

-- NIVELL 3 - EXERCICI 3

-- Creació de la funció per calcular el preu amb IVA
CREATE OR REPLACE FUNCTION`sprint3-analytics-lydia.sprint3_gold.calculate_tax`(amount FLOAT64)
RETURNS FLOAT64 AS (amount * 1.21);

-- Comprovació de la funció de càlcul de l'IVA
SELECT 100 AS preu_sense_iva, 
  `sprint3-analytics-lydia.sprint3_gold.calculate_tax`(100) AS preu_amb_iva;

-- Creació de la taula plana amb el preu amb IVA
CREATE OR REPLACE TABLE `sprint3-analytics-lydia.sprint3_gold.dim_transactions_flat` AS
SELECT
  t.transaction_id,
  t.timestamp,
  t.amount AS total_ticket,
  p.product_id AS product_sku,
  p.name AS product_name,
  p.price AS product_price,
  `sprint3-analytics-lydia.sprint3_gold.calculate_tax`(p.price) AS product_price_tax_inc
FROM `sprint3-analytics-lydia.sprint3_silver.transactions_clean` AS t
CROSS JOIN UNNEST(t.product_ids) AS product_id
JOIN `sprint3-analytics-lydia.sprint3_silver.products_clean` AS p
  ON product_id = p.product_id
WHERE t.declined = 0;

-- Comprovació d'una transacció
SELECT t.* REPLACE(ROUND(t.product_price_tax_inc, 2) AS product_price_tax_inc)
FROM `sprint3-analytics-lydia.sprint3_gold.dim_transactions_flat` t
WHERE t.transaction_id = (
  SELECT t2.transaction_id
  FROM `sprint3-analytics-lydia.sprint3_gold.dim_transactions_flat` t2
  GROUP BY t2.transaction_id
  HAVING COUNT(*) > 1
  LIMIT 1
)
ORDER BY t.product_sku;