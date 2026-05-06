-- ============================================================
-- SCHEMA INICIAL - Sistema de Asignación Supply
-- ============================================================

-- Extensión para UUIDs
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- TABLA: fronteras
-- Puntos de frontera / ubicaciones que requieren equipos
-- ============================================================
CREATE TABLE IF NOT EXISTS fronteras (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    codigo      TEXT NOT NULL UNIQUE,           -- Ej: "FRO-001", "NOGALES-NOR"
    nombre      TEXT NOT NULL,                  -- Nombre descriptivo
    region      TEXT,                           -- Región geográfica
    prioridad   TEXT DEFAULT 'media'            -- 'alta', 'media', 'baja'
                CHECK (prioridad IN ('alta', 'media', 'baja')),
    activa      BOOLEAN DEFAULT true,
    notas       TEXT,
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABLA: tipos_equipo
-- Catálogo de tipos de equipos disponibles
-- ============================================================
CREATE TABLE IF NOT EXISTS tipos_equipo (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nombre      TEXT NOT NULL UNIQUE,           -- Ej: "Scanner", "Terminal POS", "Radio"
    descripcion TEXT,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABLA: equipos
-- Inventario de equipos físicos
-- ============================================================
CREATE TABLE IF NOT EXISTS equipos (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    codigo          TEXT NOT NULL UNIQUE,        -- Ej: "EQ-2024-001"
    tipo_id         UUID REFERENCES tipos_equipo(id),
    modelo          TEXT,
    serie           TEXT UNIQUE,
    estado          TEXT DEFAULT 'disponible'
                    CHECK (estado IN ('disponible', 'asignado', 'en_reparacion', 'pendiente_compra', 'dado_de_baja')),
    notas           TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABLA: asignaciones
-- Relación entre equipos y fronteras
-- ============================================================
CREATE TABLE IF NOT EXISTS asignaciones (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    frontera_id     UUID NOT NULL REFERENCES fronteras(id),
    equipo_id       UUID REFERENCES equipos(id),           -- NULL si pendiente
    estado          TEXT DEFAULT 'pendiente'
                    CHECK (estado IN ('activa', 'pendiente', 'pendiente_compra', 'completada', 'cancelada')),
    tipo_equipo_id  UUID REFERENCES tipos_equipo(id),      -- Qué tipo se necesita
    fecha_asignacion TIMESTAMPTZ,
    fecha_limite    TIMESTAMPTZ,
    asignado_por    TEXT,                                   -- Usuario que hizo la asignación
    notas           TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABLA: historial_eventos
-- Log de todos los cambios para auditoría
-- ============================================================
CREATE TABLE IF NOT EXISTS historial_eventos (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tabla           TEXT NOT NULL,
    registro_id     UUID NOT NULL,
    evento          TEXT NOT NULL,              -- 'creado', 'actualizado', 'asignado', etc.
    datos_antes     JSONB,
    datos_despues   JSONB,
    usuario         TEXT DEFAULT 'sistema',
    origen          TEXT DEFAULT 'manual',      -- 'manual', 'n8n', 'ia', 'api'
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- VISTAS ÚTILES
-- ============================================================

-- Vista: estado completo de fronteras con sus asignaciones
CREATE OR REPLACE VIEW v_estado_fronteras AS
SELECT
    f.id,
    f.codigo,
    f.nombre,
    f.region,
    f.prioridad,
    COUNT(a.id) FILTER (WHERE a.estado = 'activa')          AS equipos_asignados,
    COUNT(a.id) FILTER (WHERE a.estado = 'pendiente')       AS equipos_pendientes,
    COUNT(a.id) FILTER (WHERE a.estado = 'pendiente_compra') AS equipos_por_comprar,
    CASE
        WHEN COUNT(a.id) FILTER (WHERE a.estado IN ('pendiente', 'pendiente_compra')) > 0 THEN 'incompleta'
        WHEN COUNT(a.id) = 0 THEN 'sin_asignaciones'
        ELSE 'completa'
    END AS estado_general
FROM fronteras f
LEFT JOIN asignaciones a ON a.frontera_id = f.id
WHERE f.activa = true
GROUP BY f.id, f.codigo, f.nombre, f.region, f.prioridad;

-- Vista: equipos disponibles por tipo
CREATE OR REPLACE VIEW v_equipos_disponibles AS
SELECT
    e.id,
    e.codigo,
    t.nombre AS tipo,
    e.modelo,
    e.serie,
    e.estado
FROM equipos e
LEFT JOIN tipos_equipo t ON t.id = e.tipo_id
WHERE e.estado = 'disponible'
ORDER BY t.nombre, e.codigo;

-- Vista: resumen ejecutivo para dashboard
CREATE OR REPLACE VIEW v_resumen_dashboard AS
SELECT
    (SELECT COUNT(*) FROM fronteras WHERE activa = true)                    AS total_fronteras,
    (SELECT COUNT(*) FROM fronteras f
        JOIN asignaciones a ON a.frontera_id = f.id
        WHERE f.activa = true AND a.estado IN ('pendiente', 'pendiente_compra')
        GROUP BY f.id HAVING COUNT(*) > 0)                                  AS fronteras_incompletas,
    (SELECT COUNT(*) FROM equipos WHERE estado = 'disponible')              AS equipos_disponibles,
    (SELECT COUNT(*) FROM equipos WHERE estado = 'asignado')                AS equipos_asignados,
    (SELECT COUNT(*) FROM asignaciones WHERE estado = 'pendiente')          AS asignaciones_pendientes,
    (SELECT COUNT(*) FROM asignaciones WHERE estado = 'pendiente_compra')   AS pendientes_compra;

-- ============================================================
-- TRIGGERS: updated_at automático
-- ============================================================
CREATE OR REPLACE FUNCTION trigger_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_updated_at_fronteras
    BEFORE UPDATE ON fronteras
    FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

CREATE TRIGGER set_updated_at_equipos
    BEFORE UPDATE ON equipos
    FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

CREATE TRIGGER set_updated_at_asignaciones
    BEFORE UPDATE ON asignaciones
    FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- ============================================================
-- RLS (Row Level Security) - Supabase
-- ============================================================
ALTER TABLE fronteras         ENABLE ROW LEVEL SECURITY;
ALTER TABLE equipos           ENABLE ROW LEVEL SECURITY;
ALTER TABLE tipos_equipo      ENABLE ROW LEVEL SECURITY;
ALTER TABLE asignaciones      ENABLE ROW LEVEL SECURITY;
ALTER TABLE historial_eventos ENABLE ROW LEVEL SECURITY;

-- Política: service_role puede hacer todo (n8n usará service_role_key)
CREATE POLICY "service_role_all" ON fronteras         FOR ALL TO service_role USING (true);
CREATE POLICY "service_role_all" ON equipos           FOR ALL TO service_role USING (true);
CREATE POLICY "service_role_all" ON tipos_equipo      FOR ALL TO service_role USING (true);
CREATE POLICY "service_role_all" ON asignaciones      FOR ALL TO service_role USING (true);
CREATE POLICY "service_role_all" ON historial_eventos FOR ALL TO service_role USING (true);
