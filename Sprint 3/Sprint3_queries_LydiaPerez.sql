-- =============================================
-- SPRINT 3 - INTRODUCCIÓ A BIGQUERY
-- =============================================

-- NIVELL 1 - EXERCICI 1
-- Creació del dataset Silver mitjançant SQL

CREATE SCHEMA `sprint3-analytics-lydia.sprint3_silver`
OPTIONS (
  location = 'EU'
);

-- NIVELL 1 - EXERCICI 2
-- Creació de les taules externes a Bronze

-- 1. Transaccions

CREATE EXTERNAL TABLE `sprint3-analytics-lydia.sprint3_bronze.transactions_raw`
OPTIONS (
  format = 'CSV',
  uris = ['gs://bootcamp-data-analytics-public/ERP/transactions.csv'],
  field_delimiter = ';'
);

-- 2. Companyies

CREATE EXTERNAL TABLE `sprint3-analytics-lydia.sprint3_bronze.companies_raw`
(
  company_id STRING,
  company_name STRING,
  phone STRING,
  email STRING,
  country STRING,
  website STRING
)
OPTIONS (
  format = 'CSV',
  uris = ['gs://bootcamp-data-analytics-public/ERP/companies.csv'],
  skip_leading_rows = 1
);

-- 3. Usuaris americans

CREATE EXTERNAL TABLE `sprint3-analytics-lydia.sprint3_bronze.american_users_raw`
OPTIONS (
  format = 'CSV',
  uris = ['gs://bootcamp-data-analytics-public/CRM/american_users.csv']
);

-- 4. Usuaris europeus

CREATE EXTERNAL TABLE `sprint3-analytics-lydia.sprint3_bronze.european_users_raw`
OPTIONS (
  format = 'CSV',
  uris = ['gs://bootcamp-data-analytics-public/CRM/european_users.csv']
);

-- 5. Targetes de crèdit

CREATE EXTERNAL TABLE `sprint3-analytics-lydia.sprint3_bronze.credit_cards_raw`
OPTIONS (
  format = 'CSV',
  uris = ['gs://bootcamp-data-analytics-public/CRM/credit_cards.csv']
);


-- NIVELL 1 - EXERCICI 4
-- Creació de la taula transactions_raw_native

CREATE OR REPLACE TABLE `sprint3-analytics-lydia.sprint3_bronze.transactions_raw_native` AS
SELECT * FROM `sprint3-analytics-lydia.sprint3_bronze.transactions_raw`;

-- NIVELL 1 - EXERICICI 4b
-- Comparació costos taula externa i taula nativa

-- Lectura de la taula externa
SELECT id
FROM `sprint3-analytics-lydia.sprint3_bronze.transactions_raw`;

-- Lectura de la taula nativa
SELECT id
FROM `sprint3-analytics-lydia.sprint3_bronze.transactions_raw_native`;


-- NIVELL 1 - EXERICICI 4c
-- Comparació costos LIMIT

SELECT *
FROM `sprint3-analytics-lydia.sprint3_bronze.transactions_raw_native`;

SELECT *
FROM `sprint3-analytics-lydia.sprint3_bronze.transactions_raw_native`
LIMIT 10;

SELECT id
FROM `sprint3-analytics-lydia.sprint3_bronze.transactions_raw_native`;

SELECT *
FROM `sprint3-analytics-lydia.sprint3_bronze.transactions_raw`
LIMIT 10;


-- NIVELL 1 - EXERCICI 5
-- Els cinc dies amb més ingressos durant l'any 2021

SELECT
  DATE(t.`timestamp`) AS data,
  ROUND(SUM(t.amount), 2) AS ingressos_totals
FROM `sprint3-analytics-lydia.sprint3_bronze.transactions_raw_native` AS t
WHERE t.`timestamp` >= TIMESTAMP('2021-01-01 00:00:00+00')
  AND t.`timestamp` < TIMESTAMP('2022-01-01 00:00:00+00')
  AND t.declined = 0
GROUP BY data
ORDER BY ingressos_totals DESC
LIMIT 5;


-- NIVELL 1 - EXERCICI 6
-- Transaccions d'empreses en dates seleccionades

SELECT
  c.company_name,
  c.country,
  DATE(t.`timestamp`) AS data_transaccio
FROM `sprint3-analytics-lydia.sprint3_bronze.transactions_raw_native` AS t
JOIN `sprint3-analytics-lydia.sprint3_bronze.companies_raw` AS c ON t.business_id = c.company_id
WHERE t.amount BETWEEN 100 AND 200
  AND t.declined = 0
  AND (DATE(t.`timestamp`) = DATE '2015-04-29'
       OR DATE(t.`timestamp`) = DATE '2018-07-20'
       OR DATE(t.`timestamp`) = DATE '2024-03-13')
ORDER BY data_transaccio;


-- NIVELL 2 - EXERCICI 1
-- Neteja de productes a la capa Silver

CREATE TABLE `sprint3-analytics-lydia.sprint3_silver.products_clean` AS
SELECT
  p.id AS product_id,
  p.product_name AS name,
  p.price,
  p.colour,
  p.weight,
  CAST(REPLACE(p.warehouse_id, 'WH-', '') AS INT64) AS warehouse_id,
  p.category,
  p.brand,
  p.cost,
  p.launch_date
FROM `sprint3-analytics-lydia.sprint3_bronze.products_raw` AS p;


-- NIVELL 2 - EXERCICI 2
-- Neteja de transaccions a la capa Silver

CREATE TABLE `sprint3-analytics-lydia.sprint3_silver.transactions_clean` AS
SELECT
  t.id AS transaction_id,
  t.card_id,
  t.business_id,
  t.timestamp,
  IFNULL(SAFE_CAST(t.amount AS FLOAT64), 0) AS amount,
  t.declined,
  ARRAY(
    SELECT CAST(TRIM(producte) AS INT64)
    FROM UNNEST(SPLIT(t.product_ids, ',')) AS producte
      WITH OFFSET AS posicio
    ORDER BY posicio
  ) AS product_ids,
  t.user_id,
  SAFE_CAST(t.lat AS FLOAT64) AS lat,
  SAFE_CAST(t.longitude AS FLOAT64) AS longitude
FROM `sprint3-analytics-lydia.sprint3_bronze.transactions_raw` AS t;


-- NIVELL 2 - EXERCICI 3
-- Unificació dels usuaris americans i europeus

CREATE TABLE `sprint3-analytics-lydia.sprint3_silver.users_combined` AS
SELECT
  u.id AS user_id,
  u.name, u.surname, u.phone, u.email, u.birth_date, u.country, u.city, u.postal_code, u.address,
  'USA' AS origin
FROM `sprint3-analytics-lydia.sprint3_bronze.american_users_raw` AS u
UNION ALL
SELECT
  u.id AS user_id,
  u.name, u.surname, u.phone, u.email, u.birth_date, u.country, u.city, u.postal_code, u.address,
  'Europe' AS origin
FROM `sprint3-analytics-lydia.sprint3_bronze.european_users_raw` AS u;


-- NIVELL 2 - EXERCICI 4
-- Materialització de companyies a Silver

CREATE TABLE `sprint3-analytics-lydia.sprint3_silver.companies_clean` AS
SELECT
  c.company_id,
  c.company_name,
  c.phone,
  c.email,
  c.country,
  c.website
FROM `sprint3-analytics-lydia.sprint3_bronze.companies_raw` AS c;

-- Materialització de targetes de crèdit a Silver

CREATE TABLE `sprint3-analytics-lydia.sprint3_silver.credit_cards_clean` AS
SELECT
  c.id AS card_id,
  c.user_id,
  c.iban,
  c.pan,
  c.pin,
  c.cvv,
  c.track1,
  c.track2,
  c.expiring_date
FROM `sprint3-analytics-lydia.sprint3_bronze.credit_cards_raw` AS c;

-- NIVELL 3 - EXERCICI 1
-- Vista d'indicadors de màrqueting per companyia

CREATE VIEW `sprint3-analytics-lydia.sprint3_gold.v_marketing_kpis` AS
SELECT c.company_name, c.phone, c.country, ROUND(AVG(t.amount), 2) AS mitjana_compra,
  CASE
    WHEN AVG(t.amount) > 260 THEN 'Premium'
    WHEN AVG(t.amount) <= 260 THEN 'Standard'
    ELSE NULL
  END AS client_tier
FROM `sprint3-analytics-lydia.sprint3_silver.companies_clean` AS c
LEFT JOIN `sprint3-analytics-lydia.sprint3_silver.transactions_clean` AS t ON c.company_id = t.business_id
  AND t.declined = 0
GROUP BY c.company_id, c.company_name, c.phone, c.country;

SELECT v.company_name, v.phone, v.country, v.mitjana_compra, v.client_tier
FROM `sprint3-analytics-lydia.sprint3_gold.v_marketing_kpis` AS v
ORDER BY v.client_tier ASC NULLS LAST, v.mitjana_compra DESC;


-- NIVELL 3 - EXERCICI 2
-- Rànquing de vendes per producte

CREATE TABLE `sprint3-analytics-lydia.sprint3_gold.product_sales_ranking` AS
SELECT p.product_id, p.name, p.price, p.colour, IFNULL(v.num_vendes, 0) AS total_vendes
FROM `sprint3-analytics-lydia.sprint3_silver.products_clean` AS p
LEFT JOIN (
  SELECT product_id, COUNT(*) AS num_vendes
  FROM `sprint3-analytics-lydia.sprint3_silver.transactions_clean` AS t
  CROSS JOIN UNNEST(t.product_ids) AS product_id
  WHERE t.declined = 0
  GROUP BY product_id
) AS v ON p.product_id = v.product_id;


-- NIVELL 3 - EXERCICI 3
-- Consulta del rànquing per a la seva exportació

SELECT
  p.product_id,
  p.name,
  ROUND(p.price, 2) AS price,
  p.colour,
  p.total_vendes
FROM `sprint3-analytics-lydia.sprint3_gold.product_sales_ranking` AS p
ORDER BY p.total_vendes DESC, p.product_id;
