# Guía de Setup — Sistema Supply IA

## Requisitos previos
- Docker + Docker Compose
- Credenciales de Supabase (URL + Service Role Key)
- API Key de Anthropic (Claude)

---

## Paso 1 — Configurar variables de entorno

```bash
cp .env.example .env
# Edita .env con tus credenciales reales
```

Variables obligatorias:
| Variable | Dónde conseguirla |
|---|---|
| `SUPABASE_URL` | Supabase → Project Settings → API |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase → Project Settings → API → service_role |
| `ANTHROPIC_API_KEY` | console.anthropic.com |
| `N8N_BASIC_AUTH_PASSWORD` | Pon una contraseña segura |

---

## Paso 2 — Crear las tablas en Supabase

En el SQL Editor de Supabase, ejecuta en orden:

1. `supabase/migrations/001_schema_inicial.sql`
2. `supabase/migrations/002_datos_semilla.sql` (opcional, datos de ejemplo)

---

## Paso 3 — Levantar n8n y el frontend

```bash
docker compose up -d
```

- **n8n:** http://localhost:5678
- **Terminal web:** http://localhost:3000

---

## Paso 4 — Importar los workflows en n8n

1. Abre n8n (http://localhost:5678)
2. Ve a **Workflows → Import from file**
3. Importa en este orden:
   - `n8n/workflows/01_terminal_ia_principal.json`
   - `n8n/workflows/02_asignacion_automatica.json`
   - `n8n/workflows/03_reporte_diario.json`

4. En cada workflow, configura la credencial **Anthropic API** con tu API key

---

## Paso 5 — Activar los workflows

En n8n, activa cada workflow (toggle en la esquina superior derecha).

---

## Uso de la terminal

Abre http://localhost:3000 y escribe comandos en lenguaje natural:

```
¿Qué fronteras faltan por asignar?
Asigna un equipo a FRO-001
¿Cuántos scanners hay disponibles?
Dame un resumen del estado actual
Marca la frontera FRO-003 como pendiente de compra
```

---

## Arquitectura

```
Terminal Web (puerto 3000)
    ↓ HTTP POST /webhook/terminal-ia
n8n (puerto 5678)
    ↓ Workflow 01: clasificar intención con Claude
    ↓ Consultar Supabase REST API
    ↓ Formatear respuesta con Claude
    ↑ JSON de respuesta
Terminal Web
```
