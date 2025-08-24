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