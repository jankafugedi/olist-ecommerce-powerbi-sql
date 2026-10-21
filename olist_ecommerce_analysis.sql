-- ====================================================================
-- PROJEKT: E-Commerce Értékesítési és Vásárlói Teljesítmény Elemzés
-- Adathalmaz: Brazilian E-Commerce Public Dataset by Olist
-- Szerző: [A Neved]
-- ====================================================================


-- --------------------------------------------------------------------
-- 1. FŐ ÉRTÉKESÍTÉSI KPI-OK (BEVÉTEL, MEGRENDELÉSEK, ÁTLAGOS KOSÁRÉRTÉK)
-- Cél: Az üzlet általános teljesítményének felmérése
-- --------------------------------------------------------------------
SELECT 
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price)::numeric, 2) AS total_revenue,
    ROUND(AVG(oi.price)::numeric, 2) AS average_item_price,
    ROUND((SUM(oi.price) / COUNT(DISTINCT o.order_id))::numeric, 2) AS average_order_value
FROM olist_orders_dataset o
JOIN olist_order_items_dataset oi 
    ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered';



-- --------------------------------------------------------------------
-- 2. HAVI BEVÉTELI TREND ÉS NÖVEKEDÉSI DINAMIKA
-- Cél: Időbeli szezonalitás és a Black Friday kiugrás azonosítása
-- --------------------------------------------------------------------
SELECT 
    DATE_TRUNC('month', o.order_purchase_timestamp)::date AS order_month,
    COUNT(DISTINCT o.order_id) AS monthly_orders,
    ROUND(SUM(oi.price)::numeric, 2) AS monthly_revenue
FROM olist_orders_dataset o
JOIN olist_order_items_dataset oi 
    ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
ORDER BY order_month ASC;



-- --------------------------------------------------------------------
-- 3. TOP 10 TERMÉKKATEGÓRIA FORGALOM ÉS RANGSOR ALAPJÁN (WINDOW FUNCTION)
-- Cél: A legmagasabb bevételt generáló termékcsoportok szűrése angol névvel
-- --------------------------------------------------------------------
WITH CategoryRevenue AS (
    SELECT 
        COALESCE(t.product_category_name_english, 'Other / Uncategorized') AS category_name,
        COUNT(DISTINCT oi.order_id) AS total_orders,
        ROUND(SUM(oi.price)::numeric, 2) AS total_sales,
        DENSE_RANK() OVER (ORDER BY SUM(oi.price) DESC) as sales_rank
    FROM olist_order_items_dataset oi
    JOIN olist_products_dataset p 
        ON oi.product_id = p.product_id
    LEFT JOIN product_category_name_translation t 
        ON p.product_category_name = t.product_category_name
    GROUP BY t.product_category_name_english
)
SELECT 
    sales_rank,
    category_name,
    total_orders,
    total_sales
FROM CategoryRevenue
WHERE sales_rank <= 10
ORDER BY sales_rank ASC;

                                                                         

-- --------------------------------------------------------------------
-- 4. SZÁLLÍTÁSI PONTOSSÁG ÉS KÉSELEMEK VIZSGÁLATA (LOGISZTIKAI KPI)
-- Cél: Megvizsgálni, hogy a kiszállítások hány százaléka érkezik meg időben
-- --------------------------------------------------------------------
SELECT 
    CASE 
        WHEN order_delivered_customer_date <= order_estimated_delivery_date THEN 'Időben kézbesítve'
        WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 'Késett kézbesítés'
        ELSE 'Nem elérhető adat'
    END AS delivery_status,
    COUNT(order_id) AS total_shipments,
    ROUND((COUNT(order_id) * 100.0 / SUM(COUNT(order_id)) OVER ())::numeric, 2) AS percentage_share
FROM olist_orders_dataset
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
GROUP BY delivery_status
ORDER BY total_shipments DESC;