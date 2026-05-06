-- ============================================================
-- DATOS DE SEMILLA - Ejemplos para arrancar
-- Personaliza estos datos con tus fronteras y equipos reales
-- ============================================================

-- Tipos de equipo
INSERT INTO tipos_equipo (nombre, descripcion) VALUES
    ('Scanner',           'Escáner de documentos y códigos'),
    ('Terminal POS',      'Terminal punto de servicio'),
    ('Radio Comunicación','Radio de comunicación'),
    ('Cámara IP',         'Cámara de vigilancia IP'),
    ('UPS',               'Sistema de alimentación ininterrumpida')
ON CONFLICT (nombre) DO NOTHING;

-- Fronteras de ejemplo (reemplaza con las tuyas)
INSERT INTO fronteras (codigo, nombre, region, prioridad) VALUES
    ('FRO-001', 'Frontera Norte A',   'Norte',  'alta'),
    ('FRO-002', 'Frontera Norte B',   'Norte',  'alta'),
    ('FRO-003', 'Frontera Sur A',     'Sur',    'media'),
    ('FRO-004', 'Frontera Sur B',     'Sur',    'media'),
    ('FRO-005', 'Frontera Este',      'Este',   'baja'),
    ('FRO-006', 'Frontera Oeste',     'Oeste',  'baja')
ON CONFLICT (codigo) DO NOTHING;
