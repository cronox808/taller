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
-- 3. Compras por cliente con gasto total y ranking global
SELECT 
    c.id,
    c.nombre || ' ' || c.apellidos AS cliente,
    SUM(cp.total) AS gasto_total,
    COUNT(DISTINCT cp.id_compra) AS num_compras,
    RANK() OVER (ORDER BY SUM(cp.total) DESC) AS ranking
FROM miscompras.clientes c
JOIN miscompras.compras co USING (id)
JOIN miscompras.compras_productos cp USING (id_compra)
GROUP BY c.id, c.nombre, c.apellidos;

-- 4. Compras por día con ticket promedio y total
WITH compras_por_dia AS (
    SELECT 
        co.fecha::date AS dia,
        SUM(cp.total) AS total_dia,
        COUNT(DISTINCT co.id_compra) AS num_compras
    FROM miscompras.compras co
    JOIN miscompras.compras_productos cp USING (id_compra)
    GROUP BY dia
)
SELECT 
    dia,
    num_compras,
    ROUND(total_dia::numeric / num_compras, 2) AS ticket_promedio,
    total_dia
FROM compras_por_dia
ORDER BY dia;

-- 5. Búsqueda e-commerce: productos activos con stock cuyo nombre empieza por 'caf'
SELECT *
FROM miscompras.productos
WHERE estado = 1
  AND cantidad_stock > 0
  AND nombre ILIKE 'caf%';

-- 6. Productos con precio formateado como texto monetario
SELECT 
    nombre,
    '$' || TO_CHAR(precio_venta, 'FM999G999G999D00') AS precio_formateado
FROM miscompras.productos
ORDER BY precio_venta DESC;

-- 7. Resumen de canasta por compra (subtotal, IVA, total con IVA)
SELECT 
    id_compra,
    ROUND(SUM(total),2) AS subtotal,
    ROUND(SUM(total) * 0.19,2) AS iva,
    ROUND(SUM(total) * 1.19,2) AS total_con_iva
FROM miscompras.compras_productos
GROUP BY id_compra;

-- 8. Participación de cada categoría en ventas
SELECT 
    cat.descripcion AS categoria,
    ROUND(SUM(cp.total),2) AS ventas_categoria,
    ROUND(SUM(cp.total) * 100.0 / SUM(SUM(cp.total)) OVER (),2) AS participacion
FROM miscompras.compras_productos cp
JOIN miscompras.productos p USING (id_producto)
JOIN miscompras.categorias cat USING (id_categoria)
GROUP BY cat.descripcion;

-- 9. Clasificación del stock
SELECT 
    nombre,
    cantidad_stock,
    CASE 
        WHEN cantidad_stock < 50 THEN 'CRÍTICO'
        WHEN cantidad_stock < 200 THEN 'BAJO'
        ELSE 'OK'
    END AS nivel_stock
FROM miscompras.productos
WHERE estado = 1
ORDER BY cantidad_stock ASC;