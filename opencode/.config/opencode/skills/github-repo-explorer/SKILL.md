---
name: github-repo-explorer
description: >
  Use when the user asks to explore, understand, analyze, or find files in a
  GitHub repository (github.com/owner/repo). Triggers on phrases like "explore
  this repo", "understand this codebase", "what does this repo do", "find X in
  this repo", "navigate this repo", "read the source at", or any github.com
  URL. Use ONLY for GitHub-hosted repositories.
---

# GitHub Repo Explorer

When the user gives a GitHub repository URL or asks to explore one, follow
this systematic approach to find, read, and understand the relevant files.

---

## 1. Parse the URL

Extract these parts from `github.com/{owner}/{repo}[/tree/{branch}][/path]`:

- `owner` — user or organization
- `repo` — repository name
- `branch` — branch name (default: the repo's default branch)
- `path` — optional subdirectory path

Also handle:
- `github.com/{owner}/{repo}` — root of the repo
- `github.com/{owner}/{repo}/tree/{branch}/{path}` — specific branch + path
- `github.com/{owner}/{repo}/blob/{branch}/{path}` — specific file
- `github.com/{owner}/{repo}/pull/{num}` — pull request (note but do not deeply explore)

---

## 2. Exploration Strategy (3-tier, read-only)

Try in order. Stop when one succeeds.

### Tier 1 — GitHub MCP (if configured)

If `mcp.github` is configured in `opencode.json`, use MCP tools:
- `get_me` — repo metadata, README
- `get_content` — file/directory contents
- `search_code` — find files by name or content
- `list_commits` — understand recent activity

### Tier 2 — GitHub REST API (via webfetch)

Base URL: `https://api.github.com/repos/{owner}/{repo}`

**Discover the repo:**
GET /repos/{owner}/{repo}
  → description, default_branch, language, topics, size
GET /repos/{owner}/{repo}/readme
  → rendered README (decode the base64 content)
GET /repos/{owner}/{repo}/languages
  → language breakdown by bytes

**List directory contents:**
GET /repos/{owner}/{repo}/contents{/path}?ref={branch}
  → array of {name, type: "file"|"dir", path, download_url, sha}

**Get full tree (use sparingly — large repos may be slow):**
GET /repos/{owner}/{repo}/git/trees/{default_branch}?recursive=1
  → full tree array; truncate to first ~200 items if very large

**Read a file:**
GET /repos/{owner}/{repo}/contents/{path}?ref={branch}
  → decode content from base64

**Search within a repo (specific queries):**
GET /search/code?q={query}+repo:{owner}/{repo}&per_page=20

### Tier 3 — HTML scraping (fallback)

When the API is rate-limited or unavailable:
FETCH https://github.com/{owner}/{repo}/tree/{branch}/{path}
  → parse file/directory listings from the page HTML
FETCH https://raw.githubusercontent.com/{owner}/{repo}/{branch}/{path}
  → read file contents directly (raw URLs are not rate-limited)

---

## 3. Framework-Aware Navigation

After fetching the README and top-level file listing, detect the framework
and navigate strategically:

### JavaScript / TypeScript
- `package.json` → `dependencies`: look for react, next, vue, svelte, express
  - **React/Next.js**: `src/app/`, `src/pages/`, `src/components/`, `App.tsx`
  - **Vue**: `src/views/`, `src/components/`, `App.vue`
  - **Svelte**: `src/routes/`, `src/lib/`
  - **Express/Fastify**: `src/routes/`, `src/controllers/`, `app.js`
- `tsconfig.json`, `vite.config.ts`, `next.config.js` — check for config

### Python
- `pyproject.toml` → project metadata, dependencies
- `setup.py`, `setup.cfg`, `requirements.txt` — dependencies
- `src/{package}/`, `{package}/` — main source (look for `__init__.py`, `main.py`, `cli.py`)
- `manage.py` — Django project entry point
- `app.py`, `app/` — Flask / FastAPI

### Rust
- `Cargo.toml` → dependencies, workspace members
- `src/main.rs` — binary entry point
- `src/lib.rs` — library entry point
- `src/bin/` — multiple binaries

### Go
- `go.mod` → module path, dependencies
- `main.go`, `cmd/` — entry points
- `internal/` — private packages
- `pkg/` — public packages

### Java / Kotlin
- `pom.xml`, `build.gradle` — dependencies
- `src/main/java/{package}/` — source
- `src/main/kotlin/{package}/` — source (Kotlin)

---

## 4. Finding Files Relevant to the User's Request

Given a user question like "find the authentication logic" or "how does the
CLI work", do this:

1. **Check the README** first — it often describes the project structure
2. **Look at the directory tree** at the top level and 1-2 levels deep
3. **Search file names** — look for files matching keywords:
   - "auth", "login", "session" → authentication
   - "cli", "cmd", "main" → entry points
   - "db", "database", "model", "entity" → data layer
   - "api", "route", "handler", "controller" → API layer
   - "test", "spec", "*.test.*" → tests
4. **Search file contents** — use GitHub code search API:
   `GET /search/code?q={keyword}+repo:{owner}/{repo}`
5. **Follow imports** — after reading one file, check its import/require/include
   statements and read the referenced files
6. **Read key files in full** — do not truncate; read the entire file

---

## 5. Synthesizing Your Findings

Present a concise summary:

{repo} — {one-line description}
Architecture
- Language / framework: {detected}
- Entry point: {path}
- Key modules: {paths}
Files relevant to "{user's question}"
- {path}: {what it does — 1-2 sentences}
- {path}: {what it does — 1-2 sentences}
Architecture notes
- {how the pieces fit together, data flow, notable patterns}

Always include the **file path** and **line ranges** when referencing specific
code. Use the format `{path}:{line}`.

---

## 6. Error Handling

| Situation | Response |
|-----------|----------|
| API 403 (rate limited) | Wait 10s and retry once, then fall back to HTML scraping |
| API 404 (private/not found) | Report that the repo is private or does not exist |
| Raw URL fails | Repo may be empty or deleted |
| Very large repo (>1000 files) | Focus on top-level + README + package manifest first |
| Binary file | Detect by extension (.png, .jpg, .wasm, .dll) — skip or note it |
