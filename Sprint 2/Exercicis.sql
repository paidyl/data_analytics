############ NIVELL 1 ############
USE transactions;

### EXERCICI 2 ###
#Llistat dels països que estan generant vendes.
SELECT DISTINCT country
FROM company c
LEFT JOIN transaction t ON t.company_id = c.id
WHERE declined = 0;

#Des de quants països es generen les vendes.
SELECT COUNT(DISTINCT country) AS paisos_vendes
FROM company c
LEFT JOIN transaction t ON t.company_id = c.id
WHERE declined = 0;

#Identifica la companyia amb la mitjana més gran de vendes.
SELECT c.id, ROUND(AVG(amount), 2) AS mitjana_vendes
FROM company c
JOIN transaction t ON t.company_id = c.id
WHERE declined = 0
GROUP BY c.id	
ORDER BY mitjana_vendes DESC
LIMIT 1;

### EXERCICI 3 ###
#Mostra totes les transaccions realitzades per empreses d'Alemanya.
SELECT *
FROM transaction t
WHERE declined = 0
AND EXISTS (SELECT 1 
			FROM company c
			WHERE country = "Germany" 
            AND c.id = t.company_id);

#Llista les empreses que han realitzat transaccions per un amount superior a la mitjana de totes les transaccions.
SELECT t.company_id, ROUND(AVG(t.amount), 2) AS mitjana_empresa
FROM transaction t
WHERE t.declined = 0
GROUP BY t.company_id
HAVING AVG(t.amount) > (SELECT AVG(t2.amount)
						FROM transaction t2
						WHERE t2.declined = 0
)
ORDER BY mitjana_empresa DESC;

#Eliminaran del sistema les empreses que no tenen transaccions registrades, entrega el llistat d'aquestes empreses.
SELECT *
FROM company c
WHERE NOT EXISTS (SELECT *
				  FROM transaction t
                  WHERE t.company_id = c.id
                  AND declined = 0);

### EXERCICI 4 ###
CREATE TABLE IF NOT EXISTS credit_card (
	id VARCHAR(15) PRIMARY KEY,
    iban VARCHAR(34), 
    pan VARCHAR(20), 
    pin VARCHAR(4), 
    cvv VARCHAR(3),
    expiring_date VARCHAR(8)
);

ALTER TABLE transaction
ADD CONSTRAINT transaction_fk_2
FOREIGN KEY (credit_card_id) 
REFERENCES credit_card(id);

### EXERCICI 5 ###
UPDATE credit_card
SET iban = "TR323456312213576817699999"
WHERE id = "CcU-2938";

SELECT *
FROM credit_card
WHERE id = "CcU-2938";

### EXERCICI 6 ###
INSERT INTO credit_card(id)
VALUES ("CcU-9999");

INSERT INTO company(id)
VALUES ("b-9999");

INSERT INTO transaction(id, credit_card_id, company_id, user_id, lat, longitude, amount, declined)
VALUES ("108B1D1D-5B23-A76C-55EF-C568E49A99DD", "CcU-9999", "b-9999", "9999", "829.999", "-117.999", "111.11", "0");

SELECT *
FROM transaction
WHERE id = "108B1D1D-5B23-A76C-55EF-C568E49A99DD";

### EXERCICI 7 ###
ALTER TABLE credit_card
DROP COLUMN pan;

SELECT *
FROM credit_card;

### EXERCICI 8 ###
DROP DATABASE IF EXISTS transactions_s2;
CREATE DATABASE IF NOT EXISTS transactions_s2;
USE transactions_s2;

CREATE TABLE IF NOT EXISTS users (
	id INT PRIMARY KEY,
    name VARCHAR(20),
    surname VARCHAR(30),
    phone VARCHAR(20),
    email VARCHAR(60),
    birth_date VARCHAR(15),
    region VARCHAR(20),
    country VARCHAR(20),
    city VARCHAR(30),
    postal_code VARCHAR(15),
    address VARCHAR(50),
    signup_date DATE,
    user_segment VARCHAR(20),
    income_band VARCHAR(10)
);

CREATE TABLE IF NOT EXISTS credit_cards (
	id VARCHAR(20) PRIMARY KEY,
    user_id INT REFERENCES users(id),
    iban VARCHAR(34),
    pan VARCHAR(20),
    pin VARCHAR(4),
    cvv VARCHAR(3),
    track1 VARCHAR(100),
    track2 VARCHAR(100),
    expiring_date VARCHAR(8),
    card_type VARCHAR(15),
    card_renewal_flag BOOLEAN
);

CREATE TABLE IF NOT EXISTS companies (
	company_id VARCHAR(20) PRIMARY KEY,
    company_name VARCHAR(40),
    phone VARCHAR(20),
    email VARCHAR(40),
    country VARCHAR(20),
    website VARCHAR(100),
    merchant_category VARCHAR(20),
    merchant_price_position VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS transactions (
	id VARCHAR(40) PRIMARY KEY,
    card_id VARCHAR(20) REFERENCES credit_cards(id),
    business_id VARCHAR(20) REFERENCES companies(company_id),
    timestamp TIMESTAMP,
    amount DECIMAL(10, 2),
    declined BOOLEAN,
    product_ids VARCHAR(50),
    user_id INT REFERENCES users(id),
    lat FLOAT,
    longitude FLOAT,
    discount_amount DECIMAL(10, 2),
    tax_amount DECIMAL(10, 2),
    shipping_amount DECIMAL(10, 2),
    channel VARCHAR(20),
    campaign_id VARCHAR(20),
    device_type VARCHAR(20),
    is_international BOOLEAN,
    decline_reason VARCHAR(50),
    distance_km DECIMAL(10, 2)
);

LOAD DATA 
LOCAL INFILE 'C:/temp/N1-Ex.8__american_users.csv'
INTO TABLE users
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
IGNORE 1 ROWS
(id, name, surname, phone, email, birth_date, country, city, postal_code, address, signup_date, user_segment, income_band)
SET region = 'America';

LOAD DATA 
LOCAL INFILE 'C:/temp/N1-Ex.8__european_users.csv'
INTO TABLE users
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
IGNORE 1 ROWS
(id, name, surname, phone, email, birth_date, country, city, postal_code, address, signup_date, user_segment, income_band)
SET region = 'Europe';

LOAD DATA 
LOCAL INFILE 'C:/temp/N1-Ex.8__credit_cards.csv'
INTO TABLE credit_cards
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
IGNORE 1 ROWS;

LOAD DATA 
LOCAL INFILE 'C:/temp/N1-Ex.8__companies.csv'
INTO TABLE companies
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
IGNORE 1 ROWS;

LOAD DATA 
LOCAL INFILE 'C:/temp/N1-Ex.8__transactions.csv'
INTO TABLE transactions
FIELDS TERMINATED BY ';'
OPTIONALLY ENCLOSED BY '"'
IGNORE 1 ROWS;

SELECT * FROM users;
SELECT * FROM credit_cards;
SELECT * FROM companies;
SELECT * FROM transactions;

ALTER TABLE credit_cards
ADD CONSTRAINT fk_credit_cards_users
FOREIGN KEY (user_id)
REFERENCES users(id);

ALTER TABLE transactions
ADD CONSTRAINT fk_transactions_credit_cards
FOREIGN KEY (card_id)
REFERENCES credit_cards(id);

ALTER TABLE transactions
ADD CONSTRAINT fk_transactions_companies
FOREIGN KEY (business_id)
REFERENCES companies(company_id);

ALTER TABLE transactions
ADD CONSTRAINT fk_transactions_users
FOREIGN KEY (user_id)
REFERENCES users(id);

### EXERCICI 9 ###
SELECT id, name, surname
FROM users u
WHERE EXISTS (SELECT 1
			  FROM transactions t
              WHERE t.user_id = u.id
              AND t.declined = 0
			  GROUP BY t.user_id
			  HAVING COUNT(t.id) > 80);

### EXERCICI 10 ###
#Mostra la mitjana d'amount per IBAN de les targetes de crèdit a la companyia Donec Ltd, utilitza almenys 2 taules.
SELECT cc.iban, ROUND(AVG(t.amount), 2) AS mitjana_amount
FROM transactions t
JOIN credit_cards cc ON cc.id = t.card_id
WHERE t.business_id = (SELECT c.company_id
					   FROM companies c
					   WHERE c.company_name = 'Donec Ltd')
AND t.declined = 0
GROUP BY cc.iban;
                     

############ NIVELL 2 ############
### EXERCICI 1 ###
SELECT DATE(t.timestamp) AS data_transaccio, SUM(t.amount) AS total_vendes
FROM transactions t
WHERE t.declined = 0
GROUP BY DATE(t.timestamp)
ORDER BY total_vendes DESC
LIMIT 5;

### EXERCICI 2 ###
SELECT c.company_name, c.phone, c.country, DATE(t.timestamp) AS data, t.amount
FROM companies c
JOIN transactions t ON t.business_id = c.company_id
WHERE t.amount BETWEEN 350 AND 400
AND DATE(t.timestamp) IN ('2015-04-29', '2018-07-20', '2024-03-13')
AND t.declined = 0
ORDER BY t.amount DESC;

### EXERCICI 3 ###
SELECT c.company_id, COUNT(t.id) AS num_transaccions,
	CASE
        WHEN COUNT(t.id) >= 400 THEN '400 o més'
        ELSE 'Menys de 400'
    END AS categoria
FROM companies c
LEFT JOIN transactions t ON t.business_id = c.company_id AND t.declined = 0
GROUP BY c.company_id
ORDER BY num_transaccions DESC;

### EXERCICI 4 ###
DELETE FROM transactions
WHERE id = "000447FE-B650-4DCF-85DE-C7ED0EE1CAAD";

SELECT *
FROM transactions
WHERE id = "000447FE-B650-4DCF-85DE-C7ED0EE1CAAD";

### EXERCICI 5 ###
CREATE VIEW VistaMarketing AS 
SELECT c.company_name, c.phone, c.country, ROUND(AVG(t.amount), 2) AS mitjana_compra
FROM companies c
LEFT JOIN transactions t ON t.business_id = c.company_id AND t.declined = 0
GROUP BY c.company_id
ORDER BY mitjana_compra DESC;

SELECT * FROM VistaMarketing;


############ NIVELL 3 ############
### EXERCICI 1 ###
CREATE TABLE IF NOT EXISTS credit_card_estat AS
SELECT cc.id,
CASE
        WHEN COUNT(tn.id) = 3 AND SUM(tn.declined = 1) = 3 THEN 'Inactiva'
        ELSE 'Activa'
    END AS estat
FROM credit_cards cc
LEFT JOIN (SELECT t.id, t.card_id, t.declined, t.timestamp, 
			ROW_NUMBER() OVER (
				PARTITION BY t.card_id
				ORDER BY t.timestamp DESC, t.id DESC
			) AS num_transaccio
			FROM transactions t
) tn 
ON tn.card_id = cc.id AND tn.num_transaccio <= 3
GROUP BY cc.id;

SELECT COUNT(*) AS targetes_actives
FROM credit_card_estat cce
WHERE cce.estat = 'Activa';

### EXERCICI 2 ###
CREATE TABLE IF NOT EXISTS products (
	id INT PRIMARY KEY,
    product_name VARCHAR(80),
    price DECIMAL(10,2),
    currency VARCHAR(3) DEFAULT 'USD',
    colour VARCHAR(7),
    weight DECIMAL(10,1),
    warehouse_id VARCHAR(10),
    category VARCHAR(30),
    brand VARCHAR(30),
    cost DECIMAL(10,2),
    launch_date DATE
);

LOAD DATA 
LOCAL INFILE 'C:/temp/N1-Ex.8__products.csv'
INTO TABLE products
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
IGNORE 1 ROWS
(id, product_name, @price, colour, weight, warehouse_id, category, brand, @cost, launch_date)
SET price = CAST(REPLACE(@price, '$', '') AS DECIMAL(10,2)),
    cost = CAST(REPLACE(@cost, '$', '') AS DECIMAL(10,2)),
    currency = 'USD';

SELECT * FROM products;

CREATE TABLE IF NOT EXISTS products_transactions (
    id_transaction VARCHAR(40),
    id_producte INT,
    PRIMARY KEY (id_transaction, id_producte),
    FOREIGN KEY (id_transaction) REFERENCES transactions(id),
    FOREIGN KEY (id_producte) REFERENCES products(id)
);

INSERT INTO products_transactions (id_transaction, id_producte)
SELECT t.id AS id_transaction, jt.id_product
FROM transactions t
JOIN JSON_TABLE(
    CONCAT('[', t.product_ids, ']'),
    '$[*]' COLUMNS (
        id_product INT PATH '$'
    )
) AS jt;

SELECT * FROM products_transactions;

SELECT pt.id_producte, COUNT(pt.id_transaction) AS num_vendes_producte
FROM products_transactions pt
GROUP BY pt.id_producte
ORDER BY pt.id_producte;
