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

-- 10. Última compra por cliente
SELECT DISTINCT ON (co.id_cliente)
    co.id_cliente,
    co.id_compra,
    co.fecha,
    SUM(cp.total) AS total_compra
FROM miscompras.compras co
JOIN miscompras.compras_productos cp USING (id_compra)
GROUP BY co.id_cliente, co.id_compra, co.fecha
ORDER BY co.id_cliente, co.fecha DESC;

-- 11. Dos productos más vendidos por categoría
SELECT *
FROM (
    SELECT 
        cat.descripcion AS categoria,
        p.nombre,
        SUM(cp.cantidad) AS unidades,
        ROW_NUMBER() OVER (PARTITION BY cat.descripcion ORDER BY SUM(cp.cantidad) DESC) AS rn
    FROM miscompras.compras_productos cp
    JOIN miscompras.productos p USING (id_producto)
    JOIN miscompras.categorias cat USING (id_categoria)
    GROUP BY cat.descripcion, p.nombre
) sub
WHERE rn <= 2;

-- 12. Ventas mensuales
SELECT 
    DATE_TRUNC('month', co.fecha) AS mes,
    COUNT(DISTINCT co.id_compra) AS num_compras,
    SUM(cp.total) AS ventas_totales
FROM miscompras.compras co
JOIN miscompras.compras_productos cp USING (id_compra)
GROUP BY mes
ORDER BY mes;

-- 13. Productos que nunca se han vendido
SELECT *
FROM miscompras.productos p
WHERE NOT EXISTS (
    SELECT 1
    FROM miscompras.compras_productos cp
    WHERE cp.id_producto = p.id_producto
);

-- 14. Clientes que al comprar 'café' también compran 'pan'
SELECT DISTINCT co.id_cliente
FROM miscompras.compras co
JOIN miscompras.compras_productos cp1 USING (id_compra)
JOIN miscompras.productos p1 ON cp1.id_producto = p1.id_producto
WHERE p1.nombre ILIKE '%café%'
  AND EXISTS (
    SELECT 1
    FROM miscompras.compras_productos cp2
    JOIN miscompras.productos p2 ON cp2.id_producto = p2.id_producto
    WHERE cp2.id_compra = co.id_compra
      AND p2.nombre ILIKE '%pan%'
);

-- 15. Margen porcentual simulado de productos
SELECT 
    nombre,
    ROUND((precio_venta - (precio_venta * 0.7)) / precio_venta * 100, 1) AS margen_simulado
FROM miscompras.productos;

-- 16. Clientes de un dominio específico
SELECT *
FROM miscompras.clientes
WHERE TRIM(correo_electronico) ~* '@example\.com$';

-- 17. Normalizar nombres y apellidos
SELECT 
    id,
    INITCAP(TRIM(nombre)) AS nombre_normalizado,
    INITCAP(TRIM(apellidos)) AS apellidos_normalizados
FROM miscompras.clientes;

-- 18. Productos con id par
SELECT *
FROM miscompras.productos
WHERE id_producto % 2 = 0;

-- 19. Vista ventas por compra
CREATE OR REPLACE VIEW miscompras.ventas_por_compra AS
SELECT 
    co.id_compra,
    co.id_cliente,
    co.fecha,
    SUM(cp.total) AS total
FROM miscompras.compras co
JOIN miscompras.compras_productos cp USING (id_compra)
GROUP BY co.id_compra, co.id_cliente, co.fecha;

-- 20. Vista materializada de ventas mensuales
CREATE MATERIALIZED VIEW IF NOT EXISTS miscompras.mv_ventas_mensuales AS
SELECT 
    DATE_TRUNC('month', co.fecha) AS mes,
    SUM(cp.total) AS ventas_totales
FROM miscompras.compras co
JOIN miscompras.compras_productos cp USING (id_compra)
GROUP BY DATE_TRUNC('month', co.fecha);

-- Para refrescar:
-- REFRESH MATERIALIZED VIEW miscompras.mv_ventas_mensuales;

-- 21. UPSERT de un producto por código de barras
INSERT INTO miscompras.productos (nombre, id_categoria, codigo_barras, precio_venta, cantidad_stock, estado)
VALUES ('Nuevo Producto', 1, '1234567890000', 5000.00, 100, 1)
ON CONFLICT (codigo_barras) DO UPDATE
SET nombre = EXCLUDED.nombre,
    precio_venta = EXCLUDED.precio_venta;

-- 22. Recalcular stock descontando lo vendido
UPDATE miscompras.productos p
SET cantidad_stock = GREATEST(p.cantidad_stock - COALESCE(v.vendido, 0), 0)
FROM (
    SELECT id_producto, SUM(cantidad) AS vendido
    FROM miscompras.compras_productos
    GROUP BY id_producto
) v
WHERE p.id_producto = v.id_producto;

-- 23. Función total de una compra
CREATE OR REPLACE FUNCTION miscompras.fn_total_compra(p_id_compra INT)
RETURNS NUMERIC(16,2) AS $$
BEGIN
    RETURN COALESCE(
        (SELECT SUM(total) FROM miscompras.compras_productos WHERE id_compra = p_id_compra),
        0
    );
END;
$$ LANGUAGE plpgsql;

-- 24. Trigger para descontar stock al insertar en compras_productos
CREATE OR REPLACE FUNCTION miscompras.trg_descuento_stock()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE miscompras.productos
    SET cantidad_stock = GREATEST(cantidad_stock - NEW.cantidad, 0)
    WHERE id_producto = NEW.id_producto;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER after_insert_cp
AFTER INSERT ON miscompras.compras_productos
FOR EACH ROW
EXECUTE FUNCTION miscompras.trg_descuento_stock();

-- 25. Posición por precio dentro de su categoría
SELECT 
    cat.descripcion AS categoria,
    p.nombre,
    p.precio_venta,
    DENSE_RANK() OVER (PARTITION BY cat.descripcion ORDER BY p.precio_venta DESC) AS posicion
FROM miscompras.productos p
JOIN miscompras.categorias cat USING (id_categoria);

-- 26. Gasto por cliente, compra anterior y delta
WITH gastos_por_dia AS (
    SELECT 
        co.id_cliente,
        co.fecha::date AS dia,
        SUM(cp.total) AS gasto
    FROM miscompras.compras co
    JOIN miscompras.compras_productos cp USING (id_compra)
    GROUP BY co.id_cliente, dia
)
SELECT 
    id_cliente,
    dia,
    gasto,
    LAG(gasto) OVER (PARTITION BY id_cliente ORDER BY dia) AS gasto_anterior,
    gasto - LAG(gasto) OVER (PARTITION BY id_cliente ORDER BY dia) AS delta
FROM gastos_por_dia;