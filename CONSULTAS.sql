-- Active: 1755129857417@@127.0.0.1@5432@miscompras
SELECT
    p.nombre AS productos,
    SUM(cp.cantidad) AS unidades_vendidas,
    SUM(cp.total) AS ingreso_total
FROM miscompras.compras_productos cp 
JOIN miscompras.productos p USING (id_producto)
GROUP BY p.nombre
ORDER BY unidades_vendidas DESC
LIMIT 10;

-- 2. Promedio y mediana de total pagado por compra
SELECT
    ROUND(AVG(total_compra), 2) AS promedio,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_compra) AS mediana
FROM (
    SELECT id_compra, SUM(total) AS total_compra
    FROM miscompras.compras_productos
    GROUP BY id_compra
) compras_totales;