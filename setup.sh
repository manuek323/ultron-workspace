#!/bin/bash
# ═══════════════════════════════════════════════════════════
#  🤖 Ultron Workspace — One-shot Bootstrap
#  Clona, configura y levanta todo el stack en una VM nueva.
#
#  Uso:
#    curl -sL https://raw.githubusercontent.com/manuek323/ultron-workspace/master/setup.sh | bash
#    # o
#    bash setup.sh
# ═══════════════════════════════════════════════════════════
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

step() { echo -e "\n${CYAN}▸ $1${NC}"; }
ok()   { echo -e "${GREEN}  ✅ $1${NC}"; }
warn() { echo -e "${YELLOW}  ⚠️  $1${NC}"; }
fail() { echo -e "${RED}  ❌ $1${NC}"; exit 1; }

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════╗"
echo "║     🤖 Ultron Workspace Bootstrap        ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"

# ── Config ──────────────────────────────────────────────
REPO_URL="https://github.com/manuek323/ultron-workspace.git"
WORKSPACE="$HOME/.openclaw/workspace"
MEMORY_REPO="https://github.com/robipop22/openclaw-memory.git"
MEMORY_DIR="$WORKSPACE/openclaw-memory"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
HF_API_KEY="${HF_API_KEY:-}"

# ── Check root ──────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
  fail "Ejecuta como root: sudo bash setup.sh"
fi

# ── 1. System dependencies ──────────────────────────────
step "Instalando dependencias del sistema..."
apt-get update -qq
apt-get install -y -qq git curl wget unzip psmisc > /dev/null 2>&1
ok "Dependencias base"

# ── 2. Docker ───────────────────────────────────────────
step "Verificando Docker..."
if ! command -v docker &>/dev/null; then
  curl -fsSL https://get.docker.com | bash > /dev/null 2>&1
  ok "Docker instalado"
else
  ok "Docker ya instalado ($(docker --version | awk '{print $3}'))"
fi
systemctl enable --now docker > /dev/null 2>&1

# ── 3. Node.js ──────────────────────────────────────────
step "Verificando Node.js..."
if ! command -v node &>/dev/null; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash - > /dev/null 2>&1
  apt-get install -y -qq nodejs > /dev/null 2>&1
  ok "Node.js $(node -v) instalado"
else
  ok "Node.js $(node -v)"
fi

# ── 4. Bun ──────────────────────────────────────────────
step "Verificando Bun..."
if ! command -v bun &>/dev/null; then
  curl -fsSL https://bun.sh/install | bash > /dev/null 2>&1
  export BUN_INSTALL="$HOME/.bun"
  export PATH="$BUN_INSTALL/bin:$PATH"
  ok "Bun $(bun --version) instalado"
else
  ok "Bun $(bun --version)"
fi
# Make bun available system-wide
ln -sf "$HOME/.bun/bin/bun" /usr/local/bin/bun 2>/dev/null || true
ln -sf "$HOME/.bun/bin/bunx" /usr/local/bin/bunx 2>/dev/null || true

# ── 5. OpenClaw ─────────────────────────────────────────
step "Verificando OpenClaw..."
if ! command -v openclaw &>/dev/null; then
  npm install -g openclaw > /dev/null 2>&1
  ok "OpenClaw $(openclaw --version 2>/dev/null || echo 'installed')"
else
  ok "OpenClaw $(openclaw --version 2>/dev/null || echo 'installed')"
fi

# ── 6. GitHub CLI ───────────────────────────────────────
step "Verificando GitHub CLI..."
if ! command -v gh &>/dev/null; then
  mkdir -p -m 755 /etc/apt/keyrings
  wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
  apt-get update -qq && apt-get install -y -qq gh > /dev/null 2>&1
  ok "GitHub CLI $(gh --version | awk 'NR==1{print $3}')"
else
  ok "GitHub CLI $(gh --version | awk 'NR==1{print $3}')"
fi

# ── 7. GitHub Auth ──────────────────────────────────────
step "Configurando GitHub auth..."
if [ -n "$GITHUB_TOKEN" ]; then
  echo "$GITHUB_TOKEN" | gh auth login --with-token > /dev/null 2>&1
  ok "Autenticado con token"
elif gh auth status &>/dev/null; then
  ok "Ya autenticado en GitHub"
else
  warn "Sin GitHub token. Configura después con: gh auth login"
  warn "O pasa el token: GITHUB_TOKEN=ghp_xxx bash setup.sh"
fi

# ── 8. Clone workspace ─────────────────────────────────
step "Clonando workspace..."
if [ -d "$WORKSPACE/.git" ]; then
  cd "$WORKSPACE" && git pull --ff-only > /dev/null 2>&1
  ok "Workspace actualizado"
else
  mkdir -p "$(dirname "$WORKSPACE")"
  git clone "$REPO_URL" "$WORKSPACE" > /dev/null 2>&1
  ok "Workspace clonado"
fi

# ── 9. Docker containers ───────────────────────────────
step "Levantando contenedores Docker..."

# Qdrant
if docker ps -a --format '{{.Names}}' | grep -q "openclaw-memory-qdrant"; then
  ok "Qdrant ya existe"
else
  docker run -d \
    --name openclaw-memory-qdrant \
    --restart unless-stopped \
    -p 6333:6333 -p 6334:6334 \
    -v qdrant_data:/qdrant/storage \
    -e QDRANT__SERVICE__GRPC_PORT=6334 \
    --health-cmd "bash -c 'echo > /dev/tcp/localhost/6333'" \
    --health-interval 10s --health-timeout 5s --health-retries 5 \
    qdrant/qdrant:v1.12.0 > /dev/null 2>&1
  ok "Qdrant creado"
fi

# PostgreSQL AGE
if docker ps -a --format '{{.Names}}' | grep -q "openclaw-memory-age"; then
  ok "AGE ya existe"
else
  docker run -d \
    --name openclaw-memory-age \
    --restart unless-stopped \
    -p 5432:5432 \
    -e POSTGRES_USER=openclaw \
    -e POSTGRES_PASSWORD=openclaw-memory \
    -e POSTGRES_DB=agent_memory \
    -v postgres_data:/var/lib/postgresql/data \
    --health-cmd "pg_isready -U openclaw" \
    --health-interval 10s --health-timeout 5s --health-retries 5 \
    apache/age:release_PG16_1.5.0 > /dev/null 2>&1
  ok "AGE creado"
fi

# Wait for containers
step "Esperando contenedores..."
sleep 8

# ── 10. Clone & patch openclaw-memory ──────────────────
step "Configurando openclaw-memory..."
if [ -d "$MEMORY_DIR/.git" ]; then
  ok "openclaw-memory ya existe"
else
  git clone "$MEMORY_REPO" "$MEMORY_DIR" > /dev/null 2>&1
  ok "openclaw-memory clonado"
fi

cd "$MEMORY_DIR"

# Create .env
cat > .env << ENVEOF
PORT=7777
HOST=0.0.0.0
MEMORY_TIER=full
LOG_LEVEL=info
SQLITE_PATH=./data/memory.db
QDRANT_URL=http://localhost:6333
PGHOST=localhost
PGPORT=5432
PGUSER=openclaw
PGPASSWORD=openclaw-memory
PGDATABASE=agent_memory
PG_SSL=false
HF_API_KEY=$HF_API_KEY
ENVEOF
ok ".env creado"

# Create config with patched sqlite path
cat > openclaw-memory.config.ts << 'CFGEOF'
import { defineConfig } from '@poprobertdaniel/openclaw-memory';

export default defineConfig({
  tier: 'full',
  port: 7777,
  auth: {
    token: process.env.MEMORY_AUTH_TOKEN || 'change-me',
  },
  sqlite: {
    path: './data/memory.db',
  },
  qdrant: {
    url: process.env.QDRANT_URL || 'http://localhost:6333',
    collection: 'openclaw_memories',
  },
  embedding: {
    apiKey: process.env.HF_API_KEY || '',
    model: 'BAAI/bge-small-en-v1.5',
    dimensions: 384,
    baseUrl: 'https://router.huggingface.co/hf-inference',
  },
  extraction: {
    apiKey: '',
    model: 'gpt-5-nano',
    enabled: true,
  },
  age: {
    host: process.env.PGHOST || 'localhost',
    port: parseInt(process.env.PGPORT || '5432', 10),
    user: process.env.PGUSER || 'openclaw',
    password: process.env.PGPASSWORD || 'openclaw-memory',
    database: process.env.PGDATABASE || 'agent_memory',
    graph: 'agent_memory',
  },
});
CFGEOF
ok "Config creada"

# Install deps
step "Instalando dependencias de openclaw-memory..."
bun install > /dev/null 2>&1
ok "Dependencias instaladas"

# Apply patches
step "Aplicando parches..."

# Patch 1: bun:sqlite named params → positional
if grep -q "Prefer better-sqlite3" src/storage/sqlite.ts 2>/dev/null; then
  ok "Parche bun:sqlite ya aplicado"
else
  # Apply the named-to-positional conversion for bun:sqlite
  cat > /tmp/sqlite_patch.py << 'PYEOF'
import re, sys

with open(sys.argv[1], 'r') as f:
    content = f.read()

old_bun = '''  const bun = (globalThis as typeof globalThis & { Bun?: unknown }).Bun;
  if (typeof bun !== "undefined") {
    const req = createRequire(import.meta.url);
    const { Database } = req("bun:sqlite") as {
      Database: new (path: string, opts?: { create?: boolean }) => {
        exec(sql: string): void;
        prepare(sql: string): {
          run(params?: Record<string, unknown>): { changes: number };
          get(params?: Record<string, unknown>): unknown;
          all(params?: Record<string, unknown>): unknown[];
        };
        close(): void;
      };
    };
    const db = new Database(dbPath, { create: true });
    return {
      exec: (sql: string) => db.exec(sql),
      prepare: (sql: string) => {
        const stmt = db.prepare(sql);
        return {
          run: (params?: Record<string, unknown>) => stmt.run(params || {}),
          get: (params?: Record<string, unknown>) => stmt.get(params || {}),
          all: (params?: Record<string, unknown>) => stmt.all(params || {}),
        };
      },
      close: () => db.close(),
    };
  }'''

new_bun = '''  const bun = (globalThis as typeof globalThis & { Bun?: unknown }).Bun;
  if (typeof bun !== "undefined") {
    const req = createRequire(import.meta.url);
    const { Database } = req("bun:sqlite") as {
      Database: new (path: string, opts?: { create?: boolean }) => {
        exec(sql: string): void;
        prepare(sql: string): {
          run(...args: unknown[]): { changes: number };
          get(...args: unknown[]): unknown;
          all(...args: unknown[]): unknown[];
        };
        close(): void;
      };
    };
    const db = new Database(dbPath, { create: true });

    // Convert :name params to positional (?) since bun:sqlite named param binding is broken
    function namedToPositional(sql: string): { sql: string; names: string[] } {
      const names: string[] = [];
      const converted = sql.replace(/:(\\w+)/g, (_m, name) => {
        const idx = names.indexOf(name);
        if (idx === -1) names.push(name);
        return '?';
      });
      return { sql: converted, names };
    }

    function objectToPositional(names: string[], params: Record<string, unknown>): unknown[] {
      return names.map(n => params[n]);
    }

    return {
      exec: (sql: string) => db.exec(sql),
      prepare: (sql: string) => {
        const { sql: posSql, names } = namedToPositional(sql);
        const stmt = db.prepare(posSql);
        return {
          run: (params?: Record<string, unknown>) => {
            const args = params && names.length ? objectToPositional(names, params) : [];
            return stmt.run(...args);
          },
          get: (params?: Record<string, unknown>) => {
            const args = params && names.length ? objectToPositional(names, params) : [];
            return stmt.get(...args);
          },
          all: (params?: Record<string, unknown>) => {
            const args = params && names.length ? objectToPositional(names, params) : [];
            return stmt.all(...args);
          },
        };
      },
      close: () => db.close(),
    };
  }'''

if old_bun in content:
    content = content.replace(old_bun, new_bun)
    with open(sys.argv[1], 'w') as f:
        f.write(content)
    print("Patched bun:sqlite")
else:
    print("bun:sqlite pattern not found or already patched")
PYEOF
  python3 /tmp/sqlite_patch.py src/storage/sqlite.ts
  ok "Parche bun:sqlite aplicado"
fi

# Patch 2: Embeddings - use fetch for HuggingFace
if grep -q "Use raw HTTP for HuggingFace" src/extraction/embeddings.ts 2>/dev/null; then
  ok "Parche embeddings ya aplicado"
else
  cat > /tmp/embed_patch.py << 'PYEOF'
import sys

with open(sys.argv[1], 'r') as f:
    content = f.read()

old_embed = '''    try {
      const response = await this.client.embeddings.create({
        model: this.model,
        input: text.slice(0, 8000),
      });

      const embedding = response.data[0]?.embedding;
      if (!embedding || embedding.length === 0) {
        console.warn("[embeddings] Empty embedding returned");
        return null;
      }

      return embedding;
    } catch (error) {
      console.error(`[embeddings] Failed to generate embedding: ${error}`);
      return null;
    }
  }'''

new_embed = '''    try {
      // Use raw HTTP for HuggingFace (not OpenAI-compatible)
      if (this.client.baseURL?.includes("huggingface")) {
        const url = `${this.client.baseURL}/models/${this.model}`;
        const resp = await fetch(url, {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${this.client.apiKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ inputs: text.slice(0, 8000) }),
        });
        if (!resp.ok) {
          console.error(`[embeddings] HTTP ${resp.status}: ${await resp.text()}`);
          return null;
        }
        const data = await resp.json() as number[];
        if (!Array.isArray(data) || data.length === 0) {
          console.warn("[embeddings] Empty embedding returned");
          return null;
        }
        return data;
      }

      const response = await this.client.embeddings.create({
        model: this.model,
        input: text.slice(0, 8000),
      });

      const embedding = response.data[0]?.embedding;
      if (!embedding || embedding.length === 0) {
        console.warn("[embeddings] Empty embedding returned");
        return null;
      }

      return embedding;
    } catch (error) {
      console.error(`[embeddings] Failed to generate embedding: ${error}`);
      return null;
    }
  }'''

if old_embed in content:
    content = content.replace(old_embed, new_embed)
    with open(sys.argv[1], 'w') as f:
        f.write(content)
    print("Patched embeddings")
else:
    print("Embeddings pattern not found or already patched")
PYEOF
  python3 /tmp/embed_patch.py src/extraction/embeddings.ts
  ok "Parche embeddings aplicado"
fi

# ── 11. Fix Qdrant collection dimensions ────────────────
step "Configurando Qdrant (384 dims)..."
curl -s -X DELETE http://localhost:6333/collections/openclaw_memories > /dev/null 2>&1
sleep 1
curl -s -X PUT http://localhost:6333/collections/openclaw_memories \
  -H "Content-Type: application/json" \
  -d '{"vectors":{"size":384,"distance":"Cosine"},"optimizers_config":{"default_segment_number":2}}' > /dev/null 2>&1
ok "Qdrant colección creada (384 dims)"

# ── 12. Systemd: memory server ──────────────────────────
step "Creando servicio systemd: openclaw-memory..."
cat > /etc/systemd/system/openclaw-memory.service << SVCEOF
[Unit]
Description=OpenClaw Memory Server (Triple-Layer)
After=network.target docker.service

[Service]
Type=simple
WorkingDirectory=$MEMORY_DIR
ExecStart=$HOME/.bun/bin/bun run src/server.ts
Restart=on-failure
RestartSec=5
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl enable openclaw-memory > /dev/null 2>&1
systemctl start openclaw-memory
sleep 3
if systemctl is-active --quiet openclaw-memory; then
  ok "openclaw-memory.service activo"
else
  warn "openclaw-memory no arrancó, revisa: journalctl -u openclaw-memory"
fi

# ── 13. Systemd: qdrant health fix ──────────────────────
# Already handled by --health-cmd in docker run

# ── 14. Configure git ───────────────────────────────────
step "Configurando git..."
cd "$WORKSPACE"
git config user.name "Ultron"
git config user.email "ultron@vmi$(hostname | head -c 6).local"
ok "Git configurado"

# ── 15. OpenClaw config placeholder ─────────────────────
step "Verificando OpenClaw..."
if [ -f "$HOME/.openclaw/openclaw.json" ]; then
  ok "OpenClaw config existe"
else
  warn "OpenClaw no configurado. Ejecuta: openclaw configure"
fi

# ── 16. Health check ────────────────────────────────────
step "Health check final..."
sleep 2
HEALTH=$(curl -s http://localhost:7777/api/health 2>/dev/null || echo "error")
if echo "$HEALTH" | grep -q '"sqlite":"ok"'; then
  ok "Memory server: $HEALTH"
else
  warn "Memory server no responde. Revisa: journalctl -u openclaw-memory -f"
fi

# ── Done ────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     🤖 Ultron desplegado y listo!        ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo "  Workspace:  $WORKSPACE"
echo "  Memory:     http://localhost:7777"
echo "  Qdrant:     http://localhost:6333"
echo "  PostgreSQL: localhost:5432"
echo ""
echo "  Servicios:"
echo "    systemctl status openclaw-memory"
echo "    docker ps"
echo ""
echo "  Para embeddings (opcional): HF_API_KEY=hf_xxx bash setup.sh"
echo "  Si falta OpenClaw config:"
echo "    openclaw configure"
echo ""
