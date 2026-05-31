# Changelog

All notable changes to the self-hosted distribution are documented here.

## 1.20.0 — 2026-05-31

### Features

- **Scanner Health Dashboard**: New `GET /api/metrics/scanner-health` endpoint returning per-scanner metrics (total scans, success rate, avg duration, last success/failure). Admin-only page at `/dashboard/scanner-health` with overview cards, metrics table with color-coded success bars, and 60s auto-refresh
- **Scan Coverage endpoint**: New `GET /api/coverage` endpoint showing projects without recent scans. Frontend badges ("Never Scanned", "Xd ago", "Recent") and "Needs Coverage" filter on Projects page

### Improvements

- **CI build caching**: Worker Dockerfile consolidated all 9 scanner binary downloads into a single deterministic RUN with pinned versions. Eliminated `curl | sh` install scripts (trivy, grype) and `latest/download` URLs (osv-scanner, tfsec). Docker layer caching via `cache-from: type=gha` now reduces CI build time from ~10 minutes to ~30 seconds on cache hit

## 1.19.1 — 2026-05-29

### Fixes

- **MCP SSE endpoint event format**: `SSEClientTransport` (used by OpenCode, Claude Desktop, and Cursor) expects the SSE `endpoint` event data to be a plain URL string. Previous JSON-wrapped format (`{"endpoint":"/v1/mcp?...","session_id":"..."}`) caused malformed POST URLs and connection failures. Fixed by sending `/v1/mcp?session_id=xxx` as plain URL data.

## 1.19.0 — 2026-05-28

### Features

- **MCP Server for LLM Integration**: New `/v1/mcp` endpoint with SSE transport exposing 7 tools (`list_projects`, `create_project`, `trigger_scan`, `get_scan_status`, `query_findings`, `get_vulnerabilities`, `get_dashboard_summary`). Auth via existing `X-API-Key` tokens. Compatible with Claude Desktop, Cursor, and OpenCode.

### Security

- **MCP session isolation**: Token-to-session binding prevents session hijacking — each POST must use the same API token that created the SSE session
- **MCP per-token session limit**: Max 5 concurrent SSE sessions per API token prevents resource exhaustion from unbounded connections
- **Dynamic corroboration_count**: Removed physical column writes; computed via subquery counting distinct scanners among findings linked to the same `vulnerability_id` — eliminates stale data and redundant UPDATE writes

### Documentation

- **MCP integration guide**: Full setup guide at `HenKaiPan-docs/src/app/architecture/mcp-integration.md` covering Claude Desktop, Cursor, and OpenCode configuration
- **E2E correlation test**: New `scripts/e2e-vulnerability-correlation.sql` — seeds 3 scan batches with overlapping vuln_uids and verifies dedup, confidence progression, scanner_coverage accumulation, and uncoupled finding independence

## 1.18.0 — 2026-05-25

### Features

- **Vulnerability status management**: New `PATCH /api/vulnerabilities/{id}/status` endpoint for changing individual vulnerability status (open, in_review, accepted_risk, fixed, verified) — gated behind admin role, with validation and full updated object returned

### Improvements

- **Status dropdown on vulnerabilities page**: Each vulnerability row now has an inline status selector for rapid triage without leaving the list — updates persist immediately via the new API
- **Project filter on vulnerabilities page**: New project dropdown filter scopes the vulnerability list to a specific project — leverages existing `?project_id=` query parameter support
- **Breadcrumb navigation added**: Breadcrumbs on the vulnerabilities page (Dashboard → Vulnerabilities) and finding detail page (Findings → Vulnerability → ID) for clearer orientation
- **Vulnerability context in finding detail**: Finding detail page now shows a "Vulnerability Context" card when the finding belongs to a vulnerability, with a direct link to the vulnerabilities page
- **Finding model enriched**: `vulnerability_id` field added to the Finding API response, enabling frontend features that reference parent vulnerabilities
- **Frontend API client extended**: New `updateVulnerabilityStatus` method, `projectId` parameter on `getVulnerabilities`, and `vulnerability_id` field on the Finding TypeScript interface

### Fixes

- **No user-facing fixes in this release**

## 1.17.0 — 2026-05-22

### Features

- **Vulnerability model — cross-batch correlation & dedup**: Replaced findings-as-primary with vulnerabilities-as-primary. Each real vulnerability (GHSA, CVE, secret hash, etc.) is now a single canonical row with N linked findings as evidence across scans and batches
- **Deterministic vuln_uid per engine**: SCA, Secrets, SAST, IaC, Containers, and DAST each compute a stable `vuln_uid` (SHA-256 based) so the same vulnerability is recognized regardless of which scanner reports it or when
- **Automatic vulnerability linking**: Worker now upserts vulnerabilities and links findings in real-time as scan results arrive — no manual correlation needed
- **Backfill on startup**: Existing findings are automatically backfilled into vulnerabilities on worker startup (batched, non-blocking)
- **Cross-batch confidence scoring**: Confidence now considers corroborating scanners across ALL scans in a project, not just within a single batch (formula: `0.5 + 0.5 * (uniqueScanners - 1) / uniqueScanners`)
- **Version check endpoint**: `GET /api/version/check` detects new versions available in GHCR for update notifications

### Improvements

- **Vulnerabilities page migrated to new table**: `/dashboard/vulns` now uses the canonical `vulnerabilities` table — shows engine type, confidence score, scanner coverage, and expands to individual findings
- **Repository layer refactored**: Migrated from positional SQL params (`$1, $2...`) to `pgx.NamedArgs` (`@name`) — eliminates off-by-one parameter bugs, self-documenting queries
- **Repository interface cleanup**: Audit, knowledge, notification, projects, schedules, settings, and webhook repositories unified with consistent patterns
- **Frontend API client extended**: New `vulnerabilities` API methods, improved error handling with `code` and `status` properties
- **Dashboard layout updated**: Navigation and sidebar improvements for vulnerabilities section

### Fixes

- **Duplicate vulnerabilities removed**: Old `vulnerabilities.go` repository replaced with new implementation (`vulnerability_new.go`) — eliminates conflicting correlation logic
- **Docker builds optimized**: API and worker Dockerfiles streamlined for faster builds

### Configuration Changes

- **Migration 040**: New `vulnerabilities` table with unique index on `(project_id, vuln_uid)`, `vulnerability_id` FK added to `findings` table

## 1.16.0 — 2026-05-20

### Features

- **SCA cross-scanner correlation**: Findings from trivy, grype, and osv-scanner are now automatically correlated within the same scan batch by CVE ID, rule ID, and package name
- **Package-based matching**: SCA findings correlate by `pkg_name` even when scanners report different vulnerability IDs (e.g. GHSA-xxx vs CVE-xxx for the same package)
- **Confidence score exposed**: `confidence_score` and `corroboration_count` now visible in the API and UI — findings corroborated by multiple scanners get higher scores (0.5 base → 1.0 with full corroboration)
- **Corroborating scanners display**: Findings list shows which specific scanners corroborate each finding (e.g. "trivy, grype")
- **Correlation reason detection**: Finding detail page explains WHY findings are correlated (CVE match, package match, rule match, same file)

### Improvements

- **Credibility sorting now functional**: Sort by confidence score or corroboration count — previously the fields were not serialized in JSON responses
- **Scanner parsers enriched**: Trivy, grype, and osv-scanner parsers now extract package name and version for correlation

### Fixes

- **confidence_score and corroboration_count not sent to frontend**: Model fields had `json:"-"` tags, preventing the API from returning them. Changed to proper JSON serialization — all existing UI badges and sorting now work

## 1.15.0 — 2026-05-19

### Features

- **Project search bar**: Search projects by name, URL, or description with real-time filtering and clear button
- **Project detail page**: New dedicated detail view for individual projects with direct access from the projects list
- **Risk acceptance feature flag**: `features.risk_acceptance` added to config status endpoint — license-gated feature toggle

### Improvements

- **Rate limits increased**: General pool 100→300 req/min, auth 10→20 req/min, heavy 60→120 req/min — normal navigation no longer triggers limits
- **Bulk actions gated by write access**: Findings page bulk operations now properly respect viewer role permissions
- **Scan interface extended**: `project_id` field added to Scan type for better project association

### Fixes

- **Findings page auth race condition**: `canWrite()` called before `getCurrentUser()` completed — now awaits user load before checking permissions
- **Finding detail page user role loading**: Switched from `api.getMe()` to `getCurrentUser()` for consistent auth state, added null guard

## 1.14.0 — 2026-05-20

### Fixes

- **Private repo clone failing with stored tokens**: `http.extraHeader` was not working for GitHub PATs in Alpine containers. Switched to URL-based token auth (`https://<TOKEN>@github.com/...`) — the most reliable method for HTTPS cloning with PATs
- **Findings page stuck on loading**: `loadFindings()` had no error handling — API failures left the page showing "Loading..." indefinitely. Added try/catch with error UI and retry button
- **SQL correlation errors**: `pgx` could not infer type for NULL `*string` parameters (`$5 IS NOT NULL`). Fixed with explicit `$5::text` cast. Also handled `pgx.ErrNoRows` gracefully in `GetProjectGitHubToken`

### Improvements

- **Scans page simplified**: Removed "Or enter URL directly" input — scans now require selecting an app or project from the combobox, enforcing the project-first workflow

## 1.13.1 — 2026-05-20

### Fixes

- **Migration 037 failed on fresh installs**: Referenced legacy `repos` table already dropped by migration 038. Removed `ALTER TABLE repos` and `DROP INDEX idx_repos_has_token` — only `projects.github_token_expires_at` is added
- **Seed scripts incompatible with migration 038**: Both `seed-demo.sql` and `seed-100-projects.sql` inserted into `repos` table and used `repo_id` columns. Updated to insert directly into `projects` with `repo_url` as source of truth

## 1.13.0 — 2026-05-19

### Security

- **Private repo token leak fixed**: GitHub PATs were embedded in clone URLs, leaking into scan logs and process listings. Now passed via `git -c http.extraHeader=Authorization: token <token>` — no token exposure in logs or `ps` output
- **Token validation before saving**: GitHub PATs are now validated against the GitHub API before storage. Invalid tokens are rejected with a clear error. Token scopes and expiry are captured for visibility
- **PAT expiry tracking**: New `github_token_expires_at` field shows when a token will expire, preventing silent scan failures from expired credentials

### Fixes

- **Worker could not read stored tokens**: `bytea` column was scanned into `*string` instead of `[]byte`, causing `cannot scan bytea into **string` errors. Worker now correctly decrypts and uses stored tokens for private repo cloning
- **Legacy repos page removed**: Orphaned `/dashboard/repos` page called non-existent APIs. Removed to eliminate confusion

### Improvements

- **Audit logging for token changes**: Setting or removing a GitHub token now creates an audit log entry (`project.token.set` / `project.token.remove`)
- **Standalone repos table removed**: The legacy `repos` table and `repo_id` foreign keys have been dropped. Projects are now the sole unit for repository connections

## 1.12.2 — 2026-05-19

### Fixes

- **Admin password not updating when `ADMIN_PASS` changed in `.env`**: The default admin was seeded via SQL migration with a hardcoded hash and `ON CONFLICT DO NOTHING`, so changing the env var had no effect. The API now reads `ADMIN_USER`/`ADMIN_PASS` on every startup and upserts the admin with a fresh bcrypt hash. Changing `.env` + restart now correctly updates the password

### Improvements

- **Settings page restructured with tabs**: Integrations now has Scanners/Jira tabs; Notifications now has Alerts/Webhooks tabs. Reuses existing tab pattern from the app for consistency
- **Removed dead settings fields**: Platform Name, API Base URL, and Admin Username were stored in localStorage but never consumed anywhere — removed to reduce confusion
- **Scanner cards simplified**: Removed duplicate scanner name in card footer and meaningless green status dot. Cards now show icon, name, type badge, and description only

## 1.12.1 — 2026-05-18

### Improvements

- **Capability-based RBAC**: Replaced hardcoded role checks with a capability matrix (`canRead`/`canWrite`). Adding new roles now requires a single line in the matrix instead of touching every route and UI component
- **Viewer read-only access**: Viewers can now view all finding details, correlations, analysis, comments, and risk acceptance status across all projects — no longer restricted to team-owned resources

### Fixes

- **Ownership middleware blocked viewers from finding details**: `RequireOwnership` middleware was checking team membership for all non-admin users, but viewers are not in team_members. Now allows read-only (GET) access for viewers regardless of ownership

## 1.12.0 — 2026-05-18

### Fixes

- **Rate limits too aggressive**: Increased `heavy` limit from 20 to 60 requests/min. Moved `/api/scans` from heavy to general pool (100 req/min) — normal navigation no longer triggers rate limits
- **Ownership middleware broken for non-admin users**: `extractResourceID` only matched singular resource names (`finding`) but URLs use plural (`/api/findings/`). Fixed to match both forms. Viewers can now access finding details, scan details, and other owned resources
- **Duplicate route groups**: Removed 3 duplicate Comments route groups (kept 1) and 2 duplicate Risk Acceptance groups (kept 1) in API router

### Improvements

- **Error logging**: All API errors now logged with code, message, status, and path via structured logging. Previously ~200 error responses were silent
- **Standardized error format**: API errors now return `{ "code": "...", "message": "..." }` instead of `{ "error": "..." }`. Frontend reads `code` for programmatic handling
- **Error detail sanitization**: Internal/database error details no longer exposed in production responses. 12 locations sanitized while preserving validation feedback
- **Audit logging coverage**: Added audit entries for App CRUD, Project CRUD, Webhook CRUD + test, and Scan creation. Coverage now spans 10 entities with 30 audit points
- **Frontend error handling**: API client now carries `code` and `status` on thrown errors. Finding detail page shows toast messages on load failures instead of silent "not found"

## 1.11.0 — 2026-05-18

### Features

- **Role simplification**: Reduced from 3 roles (admin/analyst/viewer) to 2 (admin/viewer). Existing analyst users are automatically migrated to viewer. Simplifies access control for early-stage self-hosted deployments
- **Generic role guards**: New `requireRole()` utility and `data-required-role` attribute for declarative page-level and nav-level access control. Settings page now admin-only
- **Generic config guards**: New `applyConfigGuards()` system with `data-requires-config` attribute. AI buttons (remediation, summary, validation) and email test button are automatically disabled when their providers/env vars are not configured
- **Config status endpoint**: New `GET /api/config/status` returns availability of AI providers, email, frontend URL, and webhook secret

### Improvements

- **Import aliases**: All frontend imports migrated from relative paths (`../../lib/`) to path aliases (`@lib/`, `@layouts/`) for cleaner, more maintainable code
- **Schedule visibility**: Viewers can now view schedules (read-only). Only creation, editing, and deletion remain admin-only
- **Scan detail access**: Removed ownership check temporarily from `GET /api/scans/{id}` and `GET /api/scans/{id}/findings` to allow cross-user visibility until team/project scoping is implemented

### Fixes

- **Audit log action strings**: Schedule and API token actions now use dotted format (`schedule.create`, `api_token.delete`) instead of bare verbs, fixing "create undefined" display in audit log
- **Audit log filters**: Added schedule and api_token entries to audit page filters, icons, and colors
- **Login default values**: Removed hardcoded `value="admin"` from login form inputs

### Configuration Changes

- `analyst` role removed from database constraint and validation allowlist. Migration `036_remove_analyst_role.sql` converts existing analysts to viewers

## 1.10.0 — 2026-05-17

### Features

- **Scanner `ExecVia` shell execution**: Scanners can now run via a shell (e.g. `sh -c '...'`) instead of direct binary execution. KICS scanner migrated to this model for complex pipeline commands
- **Container image scanning**: New `trivy-image` and `grype-image` scanner targets for scanning Docker/container images by reference

### Improvements

- **Scanner environment inheritance**: Scanner processes now inherit `os.Environ()` in addition to custom env vars, fixing issues with PATH and system variables
- **Grype DB cache directory**: Added `GRYPE_DB_CACHE_DIR=/tmp/grype-db` to grype and grype-image scanners for consistent cache behavior
- **Friendly error messages**: Added human-readable messages for `invalid body` and `enabled required` API errors in the frontend

## 1.9.0 — 2026-05-17

### Security

- **License key signing secret embedded in binary**: The HMAC-SHA256 signing secret is now XOR-obfuscated and compiled into the API binary. Customers no longer need to set `LICENSE_SIGNING_SECRET` — only `LICENSE_KEY` is required. Prevents trivial self-licensing by removing the customer-controlled secret
- **Default admin password no longer `admin/admin`**: First-run password is now a random UUID v4, displayed once at the end of the install script. Login form fields are empty by default

### Improvements

- **Simplified license setup**: `generate-license.sh` no longer requires `-s` flag or `LICENSE_SIGNING_SECRET` env var — keys are generated with the embedded binary secret
- **Cleaner license UX**: Login page no longer pre-fills credentials; license settings page shows generic placeholder

### Configuration Changes

- `LICENSE_SIGNING_SECRET` environment variable removed — signing secret is embedded in the compiled binary
- `ADMIN_PASS` defaults to auto-generated UUID v4 instead of `"admin"`

## 1.8.2 — 2026-05-16

### Fixes

- **PR merge ref clone failure**: `git clone --branch refs/pull/N/merge` failed because PR refs are internal GitHub refs that don't exist in the remote. Now clones normally, then fetches the specific ref via `git fetch`
- **Action PR comments not posting**: `PR_NUMBER` was never passed to the Docker container. Now extracted from `$GITHUB_EVENT_PATH` at runtime. `GITHUB_TOKEN` also properly passed via `env:` block

## 1.8.1 — 2026-05-15

### Fixes

- **Migration idempotency**: Added `IF NOT EXISTS` to `CREATE TABLE` and `CREATE INDEX` in migration 035 so it can be re-run safely
- **Advisory lock for migrations**: Acquires a `pg_advisory_lock` during `RunMigrations` to prevent concurrent runs from api and worker containers colliding
- **Empty tokens array**: `GET /api/v1/tokens` now returns `[]` instead of `null` when no tokens exist, for consistent frontend handling

### Improvements

- **Branch syntax in clone URL**: Support `url#branch` syntax in project repo URLs (e.g. `https://github.com/user/repo#main`) — the specified branch is passed to `git clone --branch`
- **Copy project ID**: Each project card now shows its UUID with a copy-to-clipboard button for quick reference
- **Cleaner scanner UI**: Removed redundant "Via Docker" label in scanner settings

## 1.8.0 — 2026-05-14

### Features

- **CI/CD Integration API**: New `POST /api/v1/scans/external` endpoint allows external CI/CD systems (GitHub Actions, GitLab CI, Jenkins, CircleCI) to trigger security scans via API key authentication
- **API Token Management**: Full CRUD for API tokens at `/api/v1/tokens` (JWT auth). Tokens use `hkp_<64 hex>` format, bcrypt-hashed, shown only once at creation, with optional per-project scope
- **GitHub Action (`dyallab/henkaipan-action`)**: Docker-based action with `fail-on-severity`, automatic PR comments, and full findings summary. Available at GitHub Marketplace
- **Token UI in Settings**: New "API Tokens" section in Settings → Tokens with create modal (name + project scope) and token shown once on creation, revoke with confirmation

### Improvements

- **Shared scan creation helpers**: `resolveScanners()` and `createScanRecords()` unified between internal and external scan creation paths
- **API versioning**: External CI/CD endpoints live at `/api/v1/scans/external` and `/api/v1/scans/{id}/status` with separate API key auth (no JWT passthrough)
- **Documentation**: New setup guides for GitHub Actions, GitLab CI, Jenkins, CircleCI, and workflow examples for Node.js, Go, Python, and Docker stacks

## 1.7.0 — 2026-05-12

### Features

- **`--skip-ollama` flag**: New installer flag to skip Ollama installation, model pulling, and .env configuration. Useful when Ollama is already running elsewhere or AI summaries aren't needed
- **Auto-start stack**: Installer now runs `docker compose up -d` automatically after pulling images — no manual step needed
- **IP detection in summary**: Installer displays the machine's IP address instead of `localhost` in the done message, so users can open the UI from another PC

### Improvements

- **Simplified docker-compose**: Removed all `cap_drop` / `cap_add` hardening for a cleaner development experience
- **Streamlined installer**: Removed admin password prompt — defaults to `admin / admin` on first login (as documented)
- **Robust image pulling**: Replaced broken background-subshell pull loop with synchronous `docker compose pull`
- **Better error resilience**: Added `|| true` to grep pipelines to prevent `pipefail` from crashing the script on missing variables

### Fixes

- **Missing `REDIS_ADDR`**: Added `REDIS_ADDR=redis:6379` to `.env.example` and installer — API would crash on startup without it
- **Missing `POSTGRES_*` variables**: Added `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD` to `.env.example` and installer — required by the postgres container
- **Missing `ADMIN_PASS`**: Added `ADMIN_PASS=admin` to `.env.example` so the installer's sed replacement works correctly
- **Ollama vars always active**: Commented out `OLLAMA_URL` and `OLLAMA_MODEL` in `.env.example` so `--skip-ollama` actually disables them


## 1.6.0 — 2026-05-09

### Features

- **Per-app scan scheduling**: Schedules can now target entire apps (`app_id` column on `scan_schedules`). When an app is selected, the schedule triggers scans for all projects belonging to that app — mutually exclusive with per-project schedules
- **GitHub repository discovery**: New pattern-based repo resolution engine (`internal/github/` package) supporting glob patterns (`org/*`, `@user/*`, `org/repo-*`) via GitHub API search — simplifies project onboarding at scale
- **Bulk project import**: `POST /api/projects/bulk` endpoint to import multiple projects at once from a GitHub pattern match, with `BulkCreateProjects` repository operation
- **Bulk project assignment**: `POST /api/projects/bulk-assign` endpoint to batch-reassign projects to an app, with `AssignProjectsToApp` repository operation
- **Vulnerability Inventory**: New free-tier routes `/api/vulnerabilities` and `/api/vulnerabilities/{vulnID}/affected` for aggregating and tracking vulnerability entries across the organization
- **Pattern-based project filtering**: `GET /api/projects` now supports `?pattern=` query param for glob-based project lookup via `ListStandaloneByPattern`

### Improvements

- **Scanner packs**: `ResolvePack` groups related scanners for bulk execution — a single scanner selector can now trigger multiple scanners
- **Per-app scan triggering**: Create scans targeting entire apps from the UI and API (`app_id` field in scan creation payload)
- **Enhanced projects dashboard**: Major UI rework with app context, pattern-based filtering, and project management actions
- **Enhanced scans dashboard**: Major UI rework with per-app filtering and scan triggering
- **Enhanced schedules dashboard**: Major UI rework with app-level schedule management, app selector, and schedule status visibility
- **Validation struct tags**: Added proper `json:` tags to `CreateProjectRequest` and extended model with `Provider` and `DefaultBranch` fields
- **Defensive nil-safety**: Apps list now returns empty slice instead of nil for `Projects` field

### Fixes

- **Rate limiting refinements**: Adjusted rate limiting middleware for better reliability under concurrent requests
- **Frontend API client cleanup**: Removed unused code paths from `api.ts`

## 1.5.1 — 2026-05-09

### Fixes

- **API Docker build**: Fixed `pnpm install` failure in API Docker image — pnpm 11 blocks esbuild/sharp build scripts by default, now uses `--ignore-scripts` + explicit `pnpm rebuild`

## 1.5.0 — 2026-05-09

### Improvements

- **Scanner execution model**: Scanners now run as embedded binaries in the worker process instead of Docker containers — eliminates Docker socket requirement entirely
- **Reduced attack surface**: Worker no longer mounts `/var/run/docker.sock` — no root-equivalent access needed
- **Simplified deployment**: No per-scanner container orchestration, no image pulls, no volume mounts
- **Kubernetes manifests**: Removed `docker.sock` hostPath volume from worker deployment
- **Docker Compose hardening**: Worker now runs as non-root user (uid 1000) with read-only root filesystem, matching Kubernetes security context

### Fixes

- **Semgrep scan failure**: Fixed exit code 2 caused by incorrect target path argument (`semgrep` was passed as scan target instead of repo directory)

### Removed

- **Docker-based scanner execution**: `docker/scanners/*.Dockerfile` deleted (semgrep, gosec, checkov standalone images)
- **Makefile targets**: `build-scanner-slim` and `build-all` removed — scanner binaries bundled in worker image
- **Dead code**: `Scanner.Image`, `Scanner.MountDst`, `Scanner.Entrypoint`, `Scanner.ExtraVolumes` fields removed from registry

## 1.4.1 — 2026-05-09

### Fixes

- **Worker seccomp profile**: Added `clone`, `clone3`, `arch_prctl`, `mbind` syscalls required by Go 1.26 runtime (prevented worker startup with segmentation fault)
- **Scanner compatibility**: Checkov prebuilt binaries incompatible with Alpine musl libc — reverted to pip installation
- **Semgrep pysemgrep wrapper**: Added wrapper script for Python module execution
- **GitHub release URLs**: Fixed asset download URLs for gitleaks, trufflehog, kics, nuclei, gosec (version-specific instead of `latest/download` which returns 404)

## 1.4.0 — 2026-05-08

### Security

- **Defense-in-depth hardening**: All services now follow least-privilege principle
- **cap_drop ALL**: Baseline capability restriction on every service
- **Minimal cap_add**: Only required capabilities added per service:
  - postgres: CHOWN, SETUID, SETGID, DAC_OVERRIDE
  - redis: CHOWN, SETUID, SETGID
  - worker: FOWNER, FSETID, DAC_OVERRIDE, CHOWN, SETUID, SETGID
  - api: no additional capabilities
- **no-new-privileges**: Applied to all services
- **Docker socket removed**: Worker no longer mounts `/var/run/docker.sock`
- **Scanner binary execution**: Scanners run as binaries via `os/exec` (no Docker)
- **Security headers**: CSP, X-Frame-Options, X-XSS-Protection, HSTS on all API responses
- **Input validation**: Backend (go-playground/validator) + Frontend (Zod) on all endpoints
- **IDOR prevention**: Ownership middleware on all resource endpoints with admin bypass
- **JWT hardening**: No default secret, expiration required, SetSecret() enforcement
- **Error sanitization**: Production mode hides internal error details
- **Rate limiting fail-closed**: Requests blocked when Redis is unavailable

## 1.3.0 — 2026-05-07

### Features

- **Real-time SSE updates**: Server-Sent Events system delivers AI summary, validation, scan, webhook, and notification events to the browser without polling
- **Redis pub/sub bridge**: Cross-process event delivery from worker to API via Redis channel `aspm:events`, enabling real-time updates in Docker Compose and multi-process deployments
- **SSE client library**: Frontend SSEClient singleton with automatic reconnection, event type filtering, and connection status monitoring

### Improvements

- **AI summary deduplication**: `PrepareAISummary()` sets `summary_state = pending` immediately in DB, preventing duplicate requests (returns 202 for pending, 200 for ready)
- **Asynq Unique(5min)**: Summary and validation tasks now use deduplication to prevent duplicate queue entries
- **SSE event architecture**: All known event types registered as EventSource listeners — pages subscribe via `.on()` handlers without specifying types upfront

### Fixes

- **SSE events never reached browser**: SSEClient singleton only registered filtered event types in `addEventListener`. Pages subscribing later got stale instance with wrong filters. Fix: ALL_SSE_EVENT_TYPES constant, always register all known types
- **AI summary auto-request on page load**: Removed `maybeQueueFindingSummary` from `GetFinding` handler and disabled `enqueueFindingSummary` in scan_run (commented out for future re-enablement)
- **Blue information toast on finding detail**: Removed invasive toast notification that appeared when viewing findings without descriptions
- **SSE disconnect on page navigation**: Removed `beforeunload` handler that killed the shared singleton connection

### Configuration

- **Redis pub/sub**: Worker publishes events to Redis channel `aspm:events`; API subscribes and relays to browser clients. No additional configuration needed — uses existing `REDIS_ADDR`

## 1.2.0 — 2026-05-05

### Operations & Production Documentation

- **Production Deployment Guide** (`docs/production-deployment.md`): Reverse proxy setup (nginx + certbot, Caddy), TLS/HTTPS, security hardening (Docker socket mitigation, firewall rules, secrets management), upgrade with rollback procedures, monitoring (Prometheus, health checks), resource sizing guide, production checklist
- **Operations Guide** (`docs/operations.md`): Worker scaling (multi-worker, queue monitoring), scanner runtime requirements (13 scanners with RAM/CPU/network specs), comprehensive troubleshooting guide (13 common issues with diagnosis and fixes), routine maintenance (log rotation, DB maintenance, SSL renewal, Docker cleanup)

### Improvements from Sentry Self-Hosted

Adopted best practices from https://github.com/getsentry/self-hosted (9.3k stars):

- **YAML anchors in docker-compose.yml**: DRY configuration with shared healthcheck defaults, restart policies, and environment file references
- **Enhanced install.sh**: Cleanup on exit, better error handling, architecture detection, fail-fast on minimum requirements
- **Optimized healthchecks**: 30s intervals (vs 5s) to reduce CPU usage - references moby/moby#39102, getsentry/self-hosted#1000
- **PostgreSQL optimizations**: shared_buffers=256MB, max_connections=1000, shm_size=256m
- **Redis optimizations**: AOF persistence, maxmemory=512mb, LRU eviction policy
- **Pull policy**: `pull_policy: always` for predictable updates

### Documentation

- **Kubernetes manifests**: Production-ready K8s deployment files (Deployments, Services, ConfigMaps, Secrets, Ingress)
- **Kubernetes deployment guide**: Comprehensive documentation for K8s deployment, scaling, monitoring, and troubleshooting
- **AI feature clarification**: Documented that self-hosted free tier only supports AI Summary (via Ollama); AI Remediation and Validation require license key
- **Admin password clarification**: Documented that `ADMIN_PASS` is optional and defaults to `admin`

### Configuration

- **Kubernetes support**: Added `kubernetes/` directory with manifests for production deployment
- **Monitoring configuration**: Added `monitoring/prometheus.yml` example configuration
- **Environment variable updates**:
  - `ADMIN_PASS` is now optional (previously listed as required)
  - Default admin credentials: `admin`/`admin` (hardcoded in migration)

### Files Added

- `kubernetes/namespace.yaml` — Namespace definition
- `kubernetes/configmap.yaml` — Non-sensitive configuration
- `kubernetes/secrets.yaml` — Sensitive credentials template
- `kubernetes/postgres.yaml` — PostgreSQL deployment + PVC + Service
- `kubernetes/redis.yaml` — Redis deployment + Service
- `kubernetes/api.yaml` — API deployment + Service
- `kubernetes/worker.yaml` — Worker deployment (Docker socket required)
- `kubernetes/ingress.yaml` — Ingress with TLS support
- `kubernetes/all-in-one.yaml` — Single manifest for testing
- `kubernetes/README.md` — Kubernetes file reference
- `monitoring/prometheus.yml` — Prometheus scrape configuration
- `docs/kubernetes-deployment.md` — Comprehensive K8s deployment guide

---

## 1.1.0 — 2026-05-03

### Security

- **Rate limiting middleware**: Redis-based rate limiter with per-endpoint tiers (auth: 10/min, heavy: 20/min, general: 100/min), X-RateLimit-* headers, and fail-open behavior on Redis errors
- **Webhook payload signing**: HMAC-SHA256 signing with constant-time comparison and 5-minute timestamp window for all webhook notifications
- **CORS configuration**: New `CORS_ALLOWED_ORIGINS` environment variable for multi-origin setups

### Features

- **Ollama AI provider**: Free, self-hosted AI option for remediation, summary, and validation tasks. Configure via `OLLAMA_URL` and `OLLAMA_MODEL` environment variables
- **Prometheus metrics**: Metrics endpoint exposed on port 9090 with queue/DB collectors for monitoring
- **Standardized error responses**: Centralized error handling with machine-readable error codes and metadata support

### Fixes

- **Frontend embedding**: Added `embed.go` and `noembed.go` with build tags for proper frontend embedding in production builds
- **Gitignore patterns**: Fixed `api` and `worker` patterns to only match root-level binaries, preventing `cmd/api/` from being ignored

### Configuration Changes

- **New environment variables**:
  - `CORS_ALLOWED_ORIGINS` — Comma-separated list of allowed origins
  - `OLLAMA_URL` — Ollama API URL (default: `http://localhost:11434`)
  - `OLLAMA_MODEL` — Ollama model (default: `gemma4:e4b`)
  - `AI_REMEDIATION_PROVIDER` — AI provider for remediation (`ollama`, `openrouter`, `cloudflare`)
  - `AI_SUMMARY_PROVIDER` — AI provider for summaries
  - `AI_VALIDATION_PROVIDER` — AI provider for validation
  - `PROMETHEUS_PORT` — Metrics endpoint port (default: `9090`)

---

## 1.0.0 — 2026-05-02

Initial release of the self-hosted edition.

### Features

- **Single-container deployment**: API with embedded frontend on port 8080
- **Unlimited free tier**: projects, users, all scanners, webhooks — no license key required
- **13 security scanners**: SAST (semgrep, gosec), SCA (trivy, grype, osv-scanner), Secrets (trufflehog, gitleaks), IaC (checkov, tfsec, kics), Containers (trivy-image, grype-image), DAST (nuclei)
- **Findings management**: triage workflow, SLA tracking, severity filters, CSV export
- **Scheduled scans**: cron-based periodic scanning
- **Policies & auto-triage**: rule-based finding suppression and status assignment
- **Compliance frameworks**: SOC 2 Type II, ISO 27001, PCI-DSS control mapping
- **Integrations**: Jira, GitHub PR comments, Slack webhooks, email notifications
- **AI remediation**: automated fix suggestions via OpenRouter or Cloudflare Workers AI
- **Team management**: role-based access (admin, analyst, viewer)
- **Audit log**: full compliance trail of security-relevant changes
- **Risk acceptance workflow**: formal risk acceptance process

### Packaging

- Docker images published to `ghcr.io/henkaipan/`
- Optional slim scanner images via `make build-scanner-slim`
- Backup/restore documentation
- Self-hosted licensing documentation

### System Requirements

- Docker & Docker Compose v2.24+
- 8 GB RAM minimum (16 GB recommended)
- 30 GB free disk
