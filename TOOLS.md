# TOOLS.md - Local Notes

Skills define _how_ tools work. This file is for _your_ specifics — the stuff that's unique to your setup.

## What Goes Here

Things like:

- Camera names and locations
- SSH hosts and aliases
- Preferred voices for TTS
- Speaker/room names
- Device nicknames
- Anything environment-specific

## Why Separate?

Skills are shared. Your setup is yours. Keeping them apart means you can update skills without losing your notes, and share skills without leaking your infrastructure.

---

### Memory Server (openclaw-memory)

- **URL:** http://localhost:7777
- **Auth:** Bearer change-me
- **Agent ID:** ultron
- **Store:** `POST /api/memories` with `{agent_id, scope, content, tags}`
- **Search:** `POST /api/search` with `{agent_id, query, limit}`
- **List:** `GET /api/memories?agent_id=ultron`
- **Health:** `GET /api/health`
- **Service:** `systemctl restart openclaw-memory`
- **Logs:** `journalctl -u openclaw-memory -f`
- **Source:** /root/.openclaw/workspace/openclaw-memory

### Docker Containers

- `openclaw-memory-qdrant` — Qdrant v1.12.0, port 6333-6334
- `openclaw-memory-age` — Apache AGE (PG16), port 5432

### OpenClaw

- **Gateway:** local, port 18789
- **Model:** xiaomi/mimo-v2-pro (custom provider, 1M context)
- **Telegram:** @manuek323

---

Add whatever helps you do your job. This is your cheat sheet.
