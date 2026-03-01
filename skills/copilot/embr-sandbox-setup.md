# ADC Embr Sandbox Setup Skill

## Overview
This skill provides step-by-step instructions for creating and configuring an Azure Dev Compute (ADC) sandbox environment with all necessary tools for Embr development and deployment.

## Purpose
Set up a complete Embr development environment in an ADC sandbox that includes:
- Git version control
- GitHub CLI (gh)
- Node.js runtime
- Embr CLI
- Pre-configured API endpoints

## Important: Local File Verification

**Before starting the setup process, verify that the Embr CLI source exists on your machine.** If the directory is not found at its expected path, **stop and ask the user** to provide the correct path. Do not assume it exists or skip steps that depend on it.

Referenced local paths:
| Path | Expected Location | Required For |
|------|--------------|-------------|
| Embr CLI source | `/Users/nirmashkowski/Projects/embr/src/Embr.Cli` | Step 6 (build & upload) |

Required local CLI tools:
| Tool | Used In | Purpose |
|------|---------|--------|
| `curl` | Steps 1-7 | ADC MCP API calls |
| `jq` | Steps 1-7 | JSON response parsing |
| `npm` | Step 6 | Building the Embr CLI release |
| `gh` | Step 6 | Getting a download URL for the CLI bundle |
| `grep` | Steps 1-7 | Parsing SSE responses |
| `sed` | Steps 1-7 | Stripping SSE `data:` prefix |

To verify, run:
```bash
# Check Embr CLI source exists and has the release build script
ls -la /Users/nirmashkowski/Projects/embr/src/Embr.Cli/build-release.mjs

# Check required CLI tools
for tool in curl jq npm gh grep sed node; do
  if command -v "$tool" &>/dev/null; then
    echo "✅ $tool: $(command -v $tool)"
  else
    echo "❌ $tool: NOT FOUND"
  fi
done
```

If a file or tool is missing, **ask the user**: _"I could not find `<filename or tool>` at `<expected-path>`. Can you provide the correct path, install the missing tool, or should I skip this step?"_

## Prerequisites
- ADC MCP API access with API key: `b600b1c576a93217727b7ea50c79a660065557b373c5683ad74742af25aac142`
- ADC MCP endpoint: `https://management.azuredevcompute.io/mcp`
- Embr CLI source: `/Users/nirmashkowski/Projects/embr/src/Embr.Cli` (with `build-release.mjs`)
- `npm` to build the release bundle
- `gh` (GitHub CLI) to get a temporary download URL
- `curl` for API calls
- `jq` for JSON parsing
- Standard Unix tools: `grep`, `sed` (for SSE response parsing)

## Setup Process

### Step 1: Create Disk Image
**Purpose:** Create a base Ubuntu image for the sandbox

```bash
API_KEY="b600b1c576a93217727b7ea50c79a660065557b373c5683ad74742af25aac142"
API_URL="https://management.azuredevcompute.io/mcp"

DISK_IMAGE_RESULT=$(curl -s -X POST "$API_URL" \
    -H "X-API-Key: $API_KEY" \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","id":100,"method":"tools/call","params":{"name":"create_disk_image","arguments":{"imageRef":"ubuntu:latest"}}}' \
    | grep "^data:" | sed 's/^data: //' | jq -r '.result.content[0].text')

DISK_IMAGE_ID=$(echo "$DISK_IMAGE_RESULT" | jq -r '.diskImageId')
```

**Expected Output:** Disk Image ID (GUID)

---

### Step 2: Create Sandbox
**Purpose:** Provision a new ADC sandbox with 2 CPU cores and 2GB RAM

```bash
SANDBOX_RESULT=$(curl -s -X POST "$API_URL" \
    -H "X-API-Key: $API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"jsonrpc\":\"2.0\",\"id\":101,\"method\":\"tools/call\",\"params\":{\"name\":\"create_sandbox\",\"arguments\":{\"diskImageId\":\"$DISK_IMAGE_ID\",\"cpuMillicores\":2000,\"memoryMB\":2048}}}" \
    | grep "^data:" | sed 's/^data: //' | jq -r '.result.content[0].text')

SANDBOX_ID=$(echo "$SANDBOX_RESULT" | jq -r '.sandboxId')
```

**Expected Output:** Sandbox ID (GUID)
**Wait Time:** ~15-20 seconds for sandbox to be ready

---

### Step 3: Install Git
**Purpose:** Install Git version control system

```bash
# Function to execute commands in sandbox
exec_cmd() {
    local cmd="$1"
    local id="$2"
    curl -s -X POST "$API_URL" \
        -H "X-API-Key: $API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"jsonrpc\":\"2.0\",\"id\":$id,\"method\":\"tools/call\",\"params\":{\"name\":\"execute_command\",\"arguments\":{\"sandboxId\":\"$SANDBOX_ID\",\"command\":\"$cmd\"}}}" \
        | grep "^data:" | sed 's/^data: //' | jq -r '.result.content[0].text' | jq -r '.stdout,.stderr'
}

# Install Git
curl -s -X POST "$API_URL" \
    -H "X-API-Key: $API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"jsonrpc\":\"2.0\",\"id\":102,\"method\":\"tools/call\",\"params\":{\"name\":\"execute_command\",\"arguments\":{\"sandboxId\":\"$SANDBOX_ID\",\"command\":\"apt update -qq && apt install git -y\"}}}" > /dev/null

sleep 2

# Verify
GIT_VERSION=$(exec_cmd "git --version" 103)
```

**Expected Output:** `git version 2.43.0` (or similar)
**Wait Time:** ~30-40 seconds for installation

---

### Step 4: Install GitHub CLI
**Purpose:** Install gh CLI for GitHub authentication and operations

```bash
# Option 1: From Ubuntu repositories (simpler, recommended)
curl -s -X POST "$API_URL" \
    -H "X-API-Key: $API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"jsonrpc\":\"2.0\",\"id\":104,\"method\":\"tools/call\",\"params\":{\"name\":\"execute_command\",\"arguments\":{\"sandboxId\":\"$SANDBOX_ID\",\"command\":\"apt install gh -y\"}}}" > /dev/null

sleep 3

# Verify
GH_VERSION=$(exec_cmd "gh --version | head -1" 105)
```

**Alternative:** Install from GitHub CLI repository (for latest version):
```bash
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list
apt update && apt install gh -y
```

**Expected Output:** `gh version 2.45.0` (or similar)
**Wait Time:** ~30-60 seconds for installation

---

### Step 5: Install Node.js
**Purpose:** Install Node.js runtime for Embr CLI

```bash
curl -s -X POST "$API_URL" \
    -H "X-API-Key: $API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"jsonrpc\":\"2.0\",\"id\":106,\"method\":\"tools/call\",\"params\":{\"name\":\"execute_command\",\"arguments\":{\"sandboxId\":\"$SANDBOX_ID\",\"command\":\"curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && apt-get install -y nodejs\"}}}" > /dev/null

sleep 3

# Verify
NODE_VERSION=$(exec_cmd "node --version" 107)
```

**Expected Output:** `v18.19.1` (or similar)
**Wait Time:** ~60-90 seconds for installation

---

### Step 6: Build, Upload, and Install Embr CLI
**Purpose:** Build a minimal single-file release of the Embr CLI, upload it to the sandbox via GitHub, and install it.

The Embr CLI has a release build script (`build-release.mjs`) that uses esbuild to bundle the entire CLI and all npm dependencies into a single ~343 KB JavaScript file. This file is self-contained — no `node_modules` required at runtime.

#### 6a. Build the release (run locally via Bash tool)

> **File check:** Before proceeding, verify the Embr CLI source and build script exist. If not found, **ask the user** for the correct path.
> ```bash
> ls /Users/nirmashkowski/Projects/embr/src/Embr.Cli/build-release.mjs || echo "ERROR: build-release.mjs not found"
> ```

```bash
cd /Users/nirmashkowski/Projects/embr/src/Embr.Cli
npm run build:release
# Output: release/embr.js (~343 KB, minified, self-contained)
```

#### 6b. Push the release file to a temporary branch and get a download URL

ADC sandboxes have internet access and Node.js, but no `curl` or `wget`. The sandbox can use `fetch()` to download files, but EMU GitHub repos require authentication. The approach is:

1. Force-add the gitignored release file to a temporary branch
2. Get a time-limited download URL via the GitHub API (`gh api`)
3. Have the sandbox download the file using that URL
4. Clean up the temporary commit

```bash
cd /Users/nirmashkowski/Projects/embr

# Create or switch to a temporary branch
TEMP_BRANCH="temp/embr-cli-upload-$(date +%s)"
git checkout -b "$TEMP_BRANCH"

# Force-add the release artifact (it's gitignored) and push
git add -f src/Embr.Cli/release/embr.js
git commit -m "temp: add release artifact for sandbox upload"
git push fork "$TEMP_BRANCH"

# Get a time-limited download URL via GitHub API
DOWNLOAD_URL=$(gh api "/repos/<owner>/<repo>/contents/src/Embr.Cli/release/embr.js?ref=$TEMP_BRANCH" --jq '.download_url')
echo "Download URL: $DOWNLOAD_URL"
```

> **Note:** Replace `<owner>/<repo>` with the actual fork path (e.g., `nimashkowski_microsoft/embr`). The `fork` remote name may differ — check with `git remote -v`.

#### 6c. Download and install in the sandbox

Use `mcp__ADC__execute_command` (or equivalent) with the sandbox ID:

```
command: node -e "
const fs = require('fs');
fetch('<DOWNLOAD_URL>')
  .then(r => { if (!r.ok) throw new Error(r.status + ' ' + r.statusText); return r.text(); })
  .then(text => {
    fs.writeFileSync('/usr/local/bin/embr', text);
    fs.chmodSync('/usr/local/bin/embr', 0o755);
    console.log('Written', fs.statSync('/usr/local/bin/embr').size, 'bytes');
  })
  .catch(e => console.error('Error:', e.message));
"
```

Replace `<DOWNLOAD_URL>` with the URL obtained in step 6b.

#### 6d. Verify installation

```
command: gh embr --version
```

**Expected Output:** `0.0.1` (or current version)
**File Location:** `/usr/local/bin/embr` (single self-contained JS file)

#### 6e. Clean up the temporary branch (run locally)

```bash
cd /Users/nirmashkowski/Projects/embr

# Delete remote temp branch
git push fork --delete "$TEMP_BRANCH"

# Switch back to your working branch and delete local temp branch
git checkout -
git branch -D "$TEMP_BRANCH"
```

---

### Step 7: Configure Embr CLI
**Purpose:** Set the Embr API URL

```bash
curl -s -X POST "$API_URL" \
    -H "X-API-Key: $API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"jsonrpc\":\"2.0\",\"id\":302,\"method\":\"tools/call\",\"params\":{\"name\":\"execute_command\",\"arguments\":{\"sandboxId\":\"$SANDBOX_ID\",\"command\":\"gh embr config set apiUrl https://api.embrdev.io\"}}}" > /dev/null

# Verify configuration
exec_cmd "gh embr config get" 303
```

**Expected Output:**
```json
{
  "apiUrl": "https://api.embrdev.io",
  "timeout": 300
}
```

---

### Step 7: Install gh-embr Extension
**Purpose:** Install the gh-embr extension which wraps the Embr CLI and adds local path-to-repo resolution

```bash
curl -s -X POST "$API_URL" \
    -H "X-API-Key: $API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"jsonrpc\":\"2.0\",\"id\":304,\"method\":\"tools/call\",\"params\":{\"name\":\"execute_command\",\"arguments\":{\"sandboxId\":\"$SANDBOX_ID\",\"command\":\"gh extension install nirmash/gh-embr\"}}}" > /dev/null

sleep 2

# Verify
exec_cmd "gh embr version" 305
```

**Expected Output:** Same version as `gh embr --version` (e.g., `0.0.1`)

> The extension requires both `gh` and `embr` to be installed first. It forwards all commands to `embr` and resolves local directory paths to `owner/repo` using the authenticated GitHub user.

---

## Post-Setup Tasks

### Authentication

#### 1. Authenticate GitHub CLI
```bash
# In the sandbox
gh auth login
```
Follow the device code authentication flow.

#### 2. Authenticate Embr CLI
```bash
# In the sandbox
gh embr login
```
Follow the device code authentication flow.

**Note:** Embr uses OAuth with GitHub for authentication.

---

### Verification Commands

Run these in the sandbox to verify everything is working:

```bash
# Check all tool versions
git --version
gh --version
node --version
gh embr --version
gh embr version

# Check authentication status
gh auth status
gh embr auth status

# Check Embr configuration
gh embr config get
```

---

## Usage Example: Deploy an Application

Once the sandbox is set up and authenticated:

```bash
# Clone repository
cd /root
gh repo clone owner/repo-name
cd repo-name

# Deploy to Embr
export NODE_TLS_REJECT_UNAUTHORIZED=0  # If needed for SSL issues
gh embr quickstart deploy owner/repo-name --branch main -i <installation-id>
```

---

## Troubleshooting

### Common Issues

#### 1. SSL Certificate Errors
**Symptom:** `SELF_SIGNED_CERT_IN_CHAIN` errors
**Solution:**
```bash
export NODE_TLS_REJECT_UNAUTHORIZED=0
npm config set strict-ssl false
```

#### 2. GitHub CLI Not Found After Installation
**Symptom:** `gh: not found`
**Solution:** Wait 3-5 seconds after installation, or check:
```bash
which gh
dpkg -l | grep gh
```

#### 3. Embr CLI 403 Forbidden
**Symptom:** `Quickstart failed: Forbidden` with error code 51
**Solution:** Re-authenticate:
```bash
gh embr login
```
The token may have expired or lacks permissions.

#### 4. Installation Timeouts
**Symptom:** Commands seem to hang
**Solution:** Increase wait times between steps:
- Git: 30-40 seconds
- GitHub CLI: 30-60 seconds  
- Node.js: 60-90 seconds

---

## Key Configuration Details

### ADC MCP API
- **Endpoint:** `https://management.azuredevcompute.io/mcp`
- **Method:** JSON-RPC 2.0 over HTTP POST
- **Authentication:** X-API-Key header
- **Response Format:** Server-Sent Events (SSE) with `data:` prefix

### Sandbox Specifications
- **OS:** Ubuntu latest
- **CPU:** 2000 millicores (2 cores)
- **Memory:** 2048 MB (2 GB)
- **Storage:** Ephemeral (sandbox can be deleted)

### Tool Versions (as of 2026-02-27)
- **Git:** 2.43.0
- **GitHub CLI:** 2.45.0
- **Node.js:** 22.x (LTS)
- **Embr CLI:** 0.0.1 (single-file release build, ~343 KB)

---

## Important Notes

1. **Sandbox Persistence:** ADC sandboxes are ephemeral and may be terminated. Save the Sandbox ID if you need to reference it later.

2. **Authentication Tokens:** 
   - GitHub CLI OAuth tokens don't expire automatically
   - Embr CLI tokens may need periodic refresh
   - Always use `auth status` to verify before deployments

3. **SSL Certificates:** The sandbox may have SSL certificate issues with some registries. Use `NODE_TLS_REJECT_UNAUTHORIZED=0` when needed.

4. **Installation Order:** Follow the exact order (Git → GitHub CLI → Node.js → Embr CLI → gh-embr extension) to avoid dependency issues.

5. **Wait Times:** Always wait 2-3 seconds after installations before verification to allow processes to complete.

---

## Quick Reference Commands

```bash
# Build the Embr CLI release
cd /Users/nirmashkowski/Projects/embr/src/Embr.Cli && npm run build:release

# Individual steps via MCP API
curl -X POST "https://management.azuredevcompute.io/mcp" \
  -H "X-API-Key: <api-key>" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{...}}'

# Execute command in sandbox
curl -X POST "https://management.azuredevcompute.io/mcp" \
  -H "X-API-Key: <api-key>" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"execute_command","arguments":{"sandboxId":"<sandbox-id>","command":"<your-command>"}}}'
```

---

## Success Criteria

Setup is complete when all of the following return successfully:

```bash
✅ git --version         # Returns git version
✅ gh --version          # Returns gh version  
✅ node --version        # Returns node version
✅ gh embr --version        # Returns gh embr version
✅ gh embr version       # Returns gh embr version (via gh extension)
✅ gh embr config get       # Shows apiUrl configuration
✅ gh auth status        # Shows authenticated account
✅ gh embr auth status      # Shows cached token
```

---

## Next Steps After Setup

1. **Clone your repository:** `gh repo clone owner/repo`
2. **Authenticate services:** `gh auth login` and `gh embr login`
3. **Deploy application:** `gh embr quickstart deploy owner/repo --branch main`
4. **Verify deployment:** Check the returned URL
5. **Monitor logs:** `gh embr deployments logs <deployment-id>`

---

## Automation Script

The upload method uses a "build → push → download → cleanup" flow:

1. Build locally: `cd src/Embr.Cli && npm run build:release`
2. Push release file to a temp branch on your fork
3. Get a download URL via `gh api`
4. Have the sandbox download it with `node -e "fetch(...).then(...)"`
5. Delete the temp branch

This avoids base64 chunking entirely and works reliably with EMU GitHub repos.
