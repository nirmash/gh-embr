# ADC Embr Sandbox Setup

This skill creates and configures a new ADC sandbox with all tools needed for Embr development: Git, GitHub CLI, Node.js, and the Embr CLI. Use it when the user wants to set up a fresh sandbox before deploying an Embr app.

---

## Before Starting: Verify Local Files

Check that the Embr CLI source exists locally before proceeding. If missing, ask the user for the correct path — do not skip steps that depend on it.

```bash
ls -la /Users/nirmashkowski/Projects/embr/src/Embr.Cli/build-release.mjs
```

| Path | Expected Location | Required For |
|------|--------------|-------------|
| Embr CLI source | `/Users/nirmashkowski/Projects/embr/src/Embr.Cli` | Step 4 (build & upload) |

---

## Step 1: Create Disk Image

Use `mcp__ADC__create_disk_image` with `imageRef: "ubuntu:latest"`.

Save the returned `diskImageId` for the next step.

---

## Step 2: Create Sandbox

Use `mcp__ADC__create_sandbox` with:
- `diskImageId`: from Step 1
- `cpuMillicores`: 2000
- `memoryMB`: 2048

Save the returned `sandboxId`. Wait ~15–20 seconds for the sandbox to be ready.

---

## Step 3: Install Git, GitHub CLI, and Node.js

Run each as `mcp__ADC__execute_command` with the sandbox ID from Step 2.

**Install Git:**
```
command: apt update -qq && apt install git -y
```
Wait ~30–40 seconds, then verify: `git --version`

**Install GitHub CLI:**
```
command: apt install gh -y
```
Wait ~30–60 seconds, then verify: `gh --version`

**Install Node.js (v22.x):**
```
command: curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && apt-get install -y nodejs
```
Wait ~60–90 seconds, then verify: `node --version`

> Always wait the indicated time before verifying. Processes may still be completing.

---

## Step 4: Build, Upload, and Install Embr CLI

The Embr CLI has a release build script (`build-release.mjs`) that uses esbuild to bundle the entire CLI and all npm dependencies into a single ~343 KB JavaScript file. No `node_modules` required at runtime.

### 4a. Build the release (run locally via Bash tool)

> If `build-release.mjs` is not found, ask the user for the correct path.

```bash
cd /Users/nirmashkowski/Projects/embr/src/Embr.Cli
npm run build:release
# Output: release/embr.js (~343 KB, minified, self-contained)
```

### 4b. Push to a temporary branch and get a download URL

ADC sandboxes have internet access and Node.js with `fetch()`, but no `curl` or `wget`. EMU GitHub repos require auth for raw downloads. The approach:

1. Force-add the gitignored release file to a temp branch on your fork
2. Get a time-limited download URL via `gh api`
3. Have the sandbox download the file using Node.js `fetch()`
4. Clean up the temporary commit

```bash
cd /Users/nirmashkowski/Projects/embr

TEMP_BRANCH="temp/embr-cli-upload-$(date +%s)"
git checkout -b "$TEMP_BRANCH"
git add -f src/Embr.Cli/release/embr.js
git commit -m "temp: add release artifact for sandbox upload"
git push fork "$TEMP_BRANCH"

# Get a time-limited download URL
DOWNLOAD_URL=$(gh api "/repos/<owner>/<repo>/contents/src/Embr.Cli/release/embr.js?ref=$TEMP_BRANCH" --jq '.download_url')
```

> Replace `<owner>/<repo>` with the fork path (e.g., `nimashkowski_microsoft/embr`). Check `git remote -v` for the remote name.

### 4c. Download and install in the sandbox

Run via `mcp__ADC__execute_command` with the sandbox ID:

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

Replace `<DOWNLOAD_URL>` with the URL from step 4b.

### 4d. Verify

```
command: embr --version
```

### 4e. Clean up the temp branch (run locally)

```bash
cd /Users/nirmashkowski/Projects/embr
git push fork --delete "$TEMP_BRANCH"
git checkout -
git branch -D "$TEMP_BRANCH"
```

---

## Step 5: Install gh-embr Extension

Install the `gh-embr` extension, which wraps the Embr CLI and adds local path-to-repo resolution.

Run via `mcp__ADC__execute_command` with the sandbox ID:

```
command: gh extension install nirmash/gh-embr
```

Verify:
```
command: gh embr version
```

**Expected Output:** Same version as `embr --version` (e.g., `0.0.1`)

> The extension requires both `gh` and `embr` to be installed first. It forwards all commands to `embr` and resolves local directory paths to `owner/repo` using the authenticated GitHub user.

---

## Step 6: Configure Embr CLI

```
command: embr config set apiUrl https://api.embrdev.io
```

Verify:
```
command: embr config get
```

Expected output:
```json
{
  "apiUrl": "https://api.embrdev.io",
  "timeout": 300
}
```

---

## Step 7: Authenticate

Both CLIs use an interactive device code flow. **Do NOT run these yourself** — ask the user to run them in a terminal connected to the sandbox.

Tell the user:
```
The sandbox is ready. Please authenticate by running these commands in your terminal:

  gh auth login
  embr login

Both will give you a code to enter in your browser.
Once done, come back and I'll verify the setup.
```

After the user confirms, verify both:
```
command: gh auth status 2>&1
command: embr auth status 2>&1
```

---

## Verification Checklist

Run these in the sandbox and confirm all pass:

```
git --version       → git version 2.x.x
gh --version        → gh version 2.x.x
node --version      → v22.x.x
embr --version      → 0.0.x
gh embr version     → 0.0.x
embr config get     → shows apiUrl: https://api.embrdev.io
gh auth status      → shows authenticated account
embr auth status    → shows "Ready to use Embr CLI"
```

---

## Troubleshooting

| Issue | Symptom | Fix |
|-------|---------|-----|
| SSL errors | `SELF_SIGNED_CERT_IN_CHAIN` | Run `export NODE_TLS_REJECT_UNAUTHORIZED=0` in sandbox |
| gh not found after install | `gh: not found` | Wait 3–5s, check `which gh` and `dpkg -l \| grep gh` |
| Embr 403 Forbidden | `Quickstart failed: Forbidden` | Re-run `embr login` — token expired |
| Install hangs | Commands appear stuck | Increase wait times; apt installs can be slow |

---

## Key Notes

- **Installation order matters:** Git → GitHub CLI → Node.js → Embr CLI → gh-embr extension
- **Sandboxes are ephemeral** — save the sandbox ID; the environment is lost if deleted
- **Auth tokens:** Embr tokens expire; always check `embr auth status` before deploying
- **The `NODE_EXTRA_CA_CERTS` warning** about a missing ADC proxy cert is harmless and can be ignored
- **The Embr CLI release build** is a single ~343 KB file (`/usr/local/bin/embr`) — no `node_modules` needed
- **After setup**, use the `embr-sandbox-dev` skill to deploy apps into this sandbox
