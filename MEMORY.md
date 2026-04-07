# MEMORY.md — Ultron

## Sobre Manuel
- Telegram: @manuek323
- Idioma: Español
- Timezone: America/Caracas (UTC-4)

## Memoria del sistema
- openclaw-memory de https://github.com/robipop22/openclaw-memory
- Triple-layer: SQLite + in-memory + PostgreSQL (AGE graph)
- Instalado en `/root/.openclaw/workspace/openclaw-memory`

## Memory Server (openclaw-memory)
- Servicio: `http://localhost:7777` (systemd: `openclaw-memory.service`)
- Auth token: `change-me`
- Triple-layer: SQLite + Qdrant (BGE 384d) + PostgreSQL AGE
- Agent ID: `ultron`
- API: POST /api/memories (store), POST /api/search (search), GET /api/memories (list)
- Parches aplicados: bun:sqlite named params → positional, Qdrant 384 dims, HuggingFace fetch directo
- Source: /root/.openclaw/workspace/openclaw-memory
- **Usar como memoria principal** antes de MEMORY.md para búsquedas semánticas

## Notas técnicas
### better-sqlite3 v11 — migración de parámetros
- SQL: usar `:name` (con dos puntos)
- Object keys: usar `name` (sin dos puntos)
- Ejemplo correcto: `stmt.get({ name: 'value' })` con query `WHERE name = :name`
- Los prefijos `@` y `$` también funcionan en SQL, pero las keys del objeto siempre son planas
