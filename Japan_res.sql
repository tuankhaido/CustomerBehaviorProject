CREATE DATABASE Restaurant;

USE Restaurant;
CREATE TABLE sales(
	sale_id int IDENTITY(1,1) PRIMARY KEY,
	customer_id VARCHAR(1),
	order_date DATE,
	product_id INTEGER
);

INSERT INTO sales
	(customer_id, order_date, product_id)
VALUES
	('A', '2021-01-01', 1),
	('A', '2021-01-01', 2),
	('A', '2021-01-07', 2),
	('A', '2021-01-10', 3),
	('A', '2021-01-11', 3),
	('A', '2021-01-11', 3),
	('B', '2021-01-01', 2),
	('B', '2021-01-02', 2),
	('B', '2021-01-04', 1),
	('B', '2021-01-11', 1),
	('B', '2021-01-16', 3),
	('B', '2021-02-01', 3),
	('C', '2021-01-01', 3),
	('C', '2021-01-01', 3),
	('C', '2021-01-07', 3);

CREATE TABLE menu(
	product_id INTEGER PRIMARY KEY,
	product_name VARCHAR(5),
	price INTEGER
);

INSERT INTO menu
	(product_id, product_name, price)
VALUES
	(1, 'sushi', 10),
    (2, 'curry', 15),
    (3, 'ramen', 12);

DROP TABLE members(
	customer_id VARCHAR(1) PRIMARY KEY,
	join_date DATE
);

-- Still works without specifying the column names explicitly
INSERT INTO members
	(customer_id, join_date)
VALUES
	('A', '2021-01-07'),
    ('B', '2021-01-09');

--1. What is the total amount each customer spent at the restaurant?

SELECT s.customer_id, SUM(m.price) as Total FROM sales S JOIN menu M ON S.product_id = m.product_id
GROUP BY s.customer_id

-- 2. How many days has each customer visited the restaurant?

SELECT customer_id, Count(Distinct(order_date)) as Total_Day FROM sales 
GROUP BY customer_id;
-- 3. What was the first item from the menu purchased by each customer?
WITH first_order AS (
SELECT s.customer_id, MIN(s.order_date) as firstdate FROM sales S 
GROUP BY s.customer_id)
SELECT s.customer_id, m.product_name FROM 
sales s JOIN first_order f on s.customer_id = f.customer_id 
join menu m on s.product_id = m.product_id
WHERE s.order_date = f.firstdate

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT TOP 1 s.product_id, m.product_name,  COUNT(s.product_id) as TIMES_BUY FROM sales s join menu m on s.product_id = m.product_id
GROUP BY s.product_id, m.product_name ORDER BY TIMES_BUY DESC
-- SỐ LẦN MUA SẢN PHẨM BESTSELLER THEO MỖI KHÁCH HÀNG
DECLARE @ID INT;
WITH bs AS (
SELECT TOP 1 s.product_id, m.product_name,  COUNT(s.product_id) as best FROM sales s join menu m on s.product_id = m.product_id
GROUP BY s.product_id, m.product_name ORDER BY best DESC
)

SELECT @ID = product_id FROM BS
SELECT S.customer_id, COUNT(*) AS TIMES FROM
sales S 
WHERE S.product_id = @ID
GROUP BY S.customer_id;


-- 5. Which item was the most popular for each customer?
WITH
bestseller AS (
SELECT s.customer_id, s.product_id, m.product_name, COUNT(m.product_id) as count_sell
FROM sales s JOIN menu M ON s.product_id = m.product_id
GROUP BY s.customer_id, S.product_id, m.product_name ),

rankproduct AS (
SELECT b.customer_id, b.product_name,  b.count_sell, DENSE_RANK() OVER(PARTITION BY b.customer_id ORDER BY b.count_sell DESC) as ranksell
FROM bestseller b
)

select r.customer_id, r.product_name, r.count_sell  from rankproduct r where r.ranksell = 1;

-- 6. Which item was purchased first by the customer after they became a member?
WITH
firstday AS (
SELECT s.customer_id, s.product_id, s.order_date, m.join_date, 
DENSE_RANK() OVER( PARTITION BY s.customer_id ORDER BY s.order_date) as dayrank
FROM SALES S JOIN members M ON S.customer_id = M.customer_id 
where order_date >= m.join_date )

SELECT f.customer_id, m.product_name 
FROM firstday F JOIN menu M on F.product_id = M.product_id 
WHERE  F.dayrank = 1;


-- 7. Which item was purchased just before the customer became a member?
WITH
beforeday AS (
SELECT s.customer_id, s.product_id, s.order_date, m.join_date, 
DENSE_RANK() OVER( PARTITION BY s.customer_id ORDER BY s.order_date DESC) as dayrank
FROM SALES S JOIN members M ON S.customer_id = M.customer_id 
where order_date < m.join_date )

SELECT f.customer_id, m.product_name 
FROM beforeday F JOIN menu M on F.product_id = M.product_id 
WHERE  F.dayrank = 1;


-- 8. What is the total items and amount spent for each member before they became a member?

SELECT s.customer_id, COUNT(s.product_id) AS total_items,
SUM(me.price) as total_spend
FROM sales s JOIN menu me on s.product_id =me.product_id
JOIN members M ON S.customer_id = M.customer_id 
WHERE s.order_date < m.join_date
GROUP BY S.customer_id;

-- 9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
SELECT s.customer_id, SUM(
	CASE 
		WHEN m.product_name = 'sushi' THEN m.price*20 
		ELSE m.price*10 END) AS total_points
FROM dbo.sales s
JOIN dbo.menu m ON s.product_id = m.product_id
GROUP BY s.customer_id;

/* 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - 
how many points do customer A and B have at the end of January?*/

SELECT s.customer_id, SUM(
    CASE 
        WHEN s.order_date BETWEEN mb.join_date AND DATEADD(day, 7, mb.join_date) THEN m.price*20
        WHEN m.product_name = 'sushi' THEN m.price*20 
        ELSE m.price*10 
    END) AS total_points
FROM sales s
JOIN menu m ON s.product_id = m.product_id
LEFT JOIN members mb ON s.customer_id = mb.customer_id
WHERE s.customer_id = mb.customer_id AND s.order_date <= '2021-01-31'
GROUP BY s.customer_id;

--11. Recreate the table output using the available data

SELECT s.customer_id, s.order_date, m.product_name, m.price,
CASE WHEN s.order_date >= mb.join_date THEN 'Y'
ELSE 'N' END AS member
FROM sales s
JOIN menu m ON s.product_id = m.product_id
LEFT JOIN members mb ON s.customer_id = mb.customer_id
ORDER BY s.customer_id, s.order_date;

