---
name: embr-sandbox-dev
description: Deploys and manages Embr apps using an ADC sandbox as the execution environment. Invoke when the user provides a sandbox ID and either a GitHub repo name (to deploy) or a project ID with an action like delete. Handles auth verification, quickstart deploy, deployment status checks, and project deletion.
---

# Embr Deploy via ADC Sandbox

This skill deploys and manages Embr apps using an ADC sandbox as the execution environment. Invoke it when the user provides a sandbox ID and either a GitHub repo name (to deploy) or a project ID with an action like `delete`.

## Required Inputs

- **Sandbox ID** — the ADC sandbox to run embr commands in (e.g. `621ba7d5-3d98-45b2-9c24-fd60545dfd84`)
- **GitHub repo** — in `owner/repo` format (e.g. `nirmash/nir-embr-test-apps`)

---

## Step 1: Verify Auth in the Sandbox

Run `embr auth status` in the sandbox using the `ADC-execute_command` tool:

```
sandboxId: <sandbox-id>
command: embr auth status 2>&1
```

- If output contains "Ready to use Embr CLI" → proceed.
- If not authenticated → ask the user to run `embr login` in a terminal that has access to the sandbox, then re-check.

> **Do NOT run `embr login` yourself.** It requires an interactive browser flow.

---

## Step 2: Run Quickstart Deploy

```
sandboxId: <sandbox-id>
command: embr quickstart deploy <owner/repo> 2>&1
```

This single command creates the project, production environment, triggers a build, and waits for deployment.

### Expected outcomes

**Success:** All steps complete and output shows a deployment ID and environment URL. Proceed to Step 3 to confirm.

**Polling timeout / "Deployment failed: fetch failed (connect ECONNREFUSED ...)":**
This is a known intermittent issue in ADC sandboxes — the CLI loses its polling connection, but the deployment **continues running in the background**. Do NOT treat this as a real failure. Proceed to Step 3 to check the actual status.

**First-attempt ECONNREFUSED before anything is created:**
Retry the quickstart once. The connection issue is typically transient.

---

## Step 3: Verify Deployment Status

The quickstart output includes a deployment ID (`dpl_...`). Use it to confirm the real status:

```
sandboxId: <sandbox-id>
command: embr deployments get <deploymentId> 2>&1
```

- **Status: active, Traffic: 100%** → deployment succeeded. Proceed to Step 4.
- **Status: failed** → check build logs:
  ```
  command: embr deployments logs <deploymentId> --step build 2>&1
  ```
  Fix the issue, push a new commit, and trigger a new build:
  ```
  command: embr builds trigger --commit <sha> 2>&1
  ```

---

## Step 4: Get the Live URL

```
sandboxId: <sandbox-id>
command: embr environments get 2>&1
```

The output includes:
- Environment ID and name
- Branch
- **URL** — the live app URL (`https://<env>-<project>-<hash>.embrdev.io`)
- Auto-deploy status

Report the URL to the user.

---

## Summary Output to User

After a successful deployment, report:

| Field | Value |
|-------|-------|
| Project ID | `prj_...` |
| Environment | `production` (`env_...`) |
| Branch | `<branch>` |
| Deployment | `dpl_...` (active, 100% traffic) |
| URL | `https://...embrdev.io` |

---

## Deleting a Project

```
sandboxId: <sandbox-id>
command: echo "y" | embr projects delete <projectId> 2>&1
```

Use `echo "y" |` to bypass the interactive confirmation prompt. Confirm the deletion with the user before running, as it is irreversible.

---

## Key Lessons Learned

- **Always use the ADC sandbox** via `ADC-execute_command` — do not run embr locally.
- **ECONNREFUSED during polling is not a real failure.** The embr CLI uses a long-poll to stream deployment progress, and the sandbox may drop that connection. Always verify with `embr deployments get`.
- **Retry quickstart once** if it fails before creating any resources (first-attempt network blip).
- **Auto-deploy is always on** — Embr automatically deploys on every push to the tracked branch. Never manually trigger a build or deployment after a code change; just push to GitHub and the platform handles it.
- **Interactive confirmations** (e.g. delete) require `echo "y" |` piped to the command since the sandbox is non-interactive.
- The `NODE_EXTRA_CA_CERTS` warning about a missing ADC proxy cert is harmless and can be ignored.
