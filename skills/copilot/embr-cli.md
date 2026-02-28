---
name: embr-cli
description: Detailed reference for every Embr CLI command and option. Only use this skill if the embr-dev skill does not have the information you need — for example, advanced CLI flags, EV2 deployment commands, or configuration options not covered in the main developer workflow.
---

# Embr CLI Skill

This skill provides guidance for using the Embr CLI to manage Embr platform resources.

## Overview

Embr CLI (`embr`) is a command-line interface for managing the Embr platform — a NextGen PaaS for deploying backend services from GitHub repositories. The CLI allows you to:

- Manage projects, environments, builds, and deployments
- Authenticate with the Embr API
- Deploy to Azure using EV2 (Express V2) workflows
- Stream build logs in real-time

## Prerequisites

- **Node.js 20+** and **npm 9+**
- **Git**
- For EV2 commands: **PowerShell**, **Azure CLI**, **Docker**, **.NET SDK**

## Installation

> **IMPORTANT:** Before running any `embr` commands, verify the CLI is installed by running `embr --help`.
> If `embr` is not recognized, follow the steps below to clone the repo and build the CLI.
> Ask the user where they would like to clone the repository, then proceed with the steps below.

### Step 1: Clone the Embr repository

```bash
# Ask the user for their preferred directory, then clone
cd <user-chosen-directory>
git clone https://github.com/coreai-microsoft/embr.git
cd embr
```

### Step 2: Install dependencies and build

```bash
cd src/Embr.Cli
npm install
npm run build
```

### Step 3: Link the CLI globally

```bash
npm link
```

This makes `embr` available as a global command. Verify with:

```bash
embr --help
```

### Windows PATH troubleshooting

If `embr` is still not recognized after `npm link`, the npm global bin folder may not be on your PATH.

```powershell
# Add npm global bin to your user PATH (adjust username)
$npmBin = "$env:APPDATA\npm"
$current = [Environment]::GetEnvironmentVariable("Path", "User")
if ($current -notlike "*$npmBin*") {
  [Environment]::SetEnvironmentVariable("Path", ($current + ";" + $npmBin), "User")
}
```

**Restart your terminal** after updating PATH, then run `embr --help` again.

### Run without linking (alternative)

If you don't want to install globally, you can run the CLI directly from the repo:

```bash
cd src/Embr.Cli
npm run dev -- --help
# or
node dist/cli.js --help
```

---

## Core Concepts

### Entity Hierarchy

```
Project (prj_xxx)           ← maps to a GitHub repository
└── Environment (env_xxx)   ← tracks a Git branch
    ├── Builds (bld_xxx)    ← artifacts from commits
    └── Deployments (dpl_xxx) ← running instances
```

- **Project**: Represents a GitHub repository
- **Environment**: Represents a branch (production, staging, preview)
- **Build**: An immutable artifact created from a commit
- **Deployment**: A running instance serving traffic

---

## Getting Started

> **IMPORTANT:** Before doing anything else, make sure the user is logged in.
> Login automatically caches the GitHub App installation ID, so you won't need to provide it manually.

### Step 1: Login

```bash
# Check if already logged in
embr auth status
```

If the output shows "Ready to use Embr CLI", skip to Step 2.

#### If not logged in

> **DO NOT run `embr login` yourself.** The login command uses an interactive device code flow
> that blocks until the user completes authorization in their browser. Running it from an agent
> will not work reliably — the process may be killed before the token is saved.
>
> Instead, **ask the user to run `embr login` in their own terminal**:

Tell the user:

```
You need to log in to Embr first. Please run this in your terminal:

  embr login

It will give you a code and open your browser. Enter the code at GitHub to authorize.
Once you see "Logged in as <username>", come back and I'll continue.
```

After the user confirms they have logged in, verify:

```bash
embr auth status
```

**Do NOT proceed until `embr auth status` confirms authentication.**

### Step 2: Create a Project (use quickstart)

> **Always prefer `embr quickstart deploy`** to create a new project. It handles everything in one command:
> project creation, environment setup, build, and deployment. All you need is the GitHub repo.

```bash
# The recommended way to set up a new project — just provide the repo
embr quickstart deploy <owner/repo>

# Example
embr quickstart deploy myorg/my-web-app
```

The installation ID is automatically resolved from your cached login. No need to pass `-i`.

---

## Command Reference

### Authentication (`embr auth`)

| Command | Description | Example |
|---------|-------------|---------|
| `auth login` | Authenticate via GitHub OAuth or token | `embr auth login` |
| `auth login --token <token>` | Login with a token | `embr auth login --token abc123` |
| `auth status` | Check authentication status | `embr auth status` |
| `auth logout` | Clear stored credentials | `embr auth logout` |

### Configuration (`embr config`)

| Command | Description | Example |
|---------|-------------|---------|
| `config get [key]` | Get configuration value(s) | `embr config get apiUrl` |
| `config set <key> <value>` | Set a configuration value | `embr config set apiUrl https://embr.azure.com/api` |
| `config unset <key>` | Clear a configuration value | `embr config unset projectId` |
| `config path` | Show config directory path | `embr config path` |
| `config context` | Show current project/environment context | `embr config context` |
| `config context -p <id> -e <id>` | Set context | `embr config context -p prj_abc -e env_xyz` |
| `config context --clear` | Clear context | `embr config context --clear` |

#### Profile Management (`embr config profile`)

| Command | Description | Example |
|---------|-------------|---------|
| `config profile save <name>` | Save current config as profile | `embr config profile save dev` |
| `config profile use <name>` | Switch to a profile | `embr config profile use prod` |
| `config profile list` | List all profiles | `embr config profile list` |
| `config profile show <name>` | Show profile details | `embr config profile show dev` |
| `config profile delete <name>` | Delete a profile | `embr config profile delete old` |
| `config profile current` | Show active profile | `embr config profile current` |

### Projects (`embr projects`)

| Command | Description | Example |
|---------|-------------|---------|
| `projects list` | List all projects | `embr projects list` |
| `projects get <projectId>` | Get project details | `embr projects get prj_abc123` |
| `projects get-by-repo <owner> <repo>` | Get project by repository | `embr projects get-by-repo myorg myapp` |
| `projects create` | Create a new project | `embr projects create -r owner/repo -i 12345` |
| `projects update <projectId>` | Update project settings | `embr projects update prj_abc -t commit -b main` |
| `projects delete <projectId>` | Delete a project | `embr projects delete prj_abc --force` |

**Options:**
- `-r, --repo <owner/repo>` — Repository full name (required for create)
- `-i, --installation-id <id>` — GitHub App installation ID (required for create)
- `-t, --trigger-mode <mode>` — Trigger mode: `pr` or `commit`
- `-b, --default-branch <branch>` — Default branch name
- `-j, --json` — Output as JSON
- `-f, --force` — Skip confirmation on delete

### Environments (`embr environments`)

| Command | Description | Example |
|---------|-------------|---------|
| `environments list` | List environments in project | `embr environments list -p prj_abc` |
| `environments get` | Get environment details | `embr environments get -p prj_abc -e env_xyz` |
| `environments create` | Create a new environment | `embr environments create -n staging -b develop` |
| `environments delete` | Delete an environment | `embr environments delete -e env_xyz --force` |

**Options:**
- `-p, --project <projectId>` — Project ID (uses context if not set)
- `-e, --environment <environmentId>` — Environment ID (uses context if not set)
- `-n, --name <name>` — Environment name (required for create)
- `-b, --branch <branch>` — Git branch (required for create)
- `--production` — Mark as production environment
- `-j, --json` — Output as JSON

**Getting the live URL:** After a deployment is running, the environment's public URL is available from `embr environments list` or `embr environments get`. The URL column/field contains the stable public URL for the environment (e.g., `https://production-embr-test-apps-7eb9eab8.embrdev.io`). Always use this URL to verify deployments instead of the sandbox URL from `embr deployments get`, which is ephemeral.

### Builds (`embr builds`)

| Command | Description | Example |
|---------|-------------|---------|
| `builds trigger` | Trigger a new build | `embr builds trigger -c abc123` |
| `builds list` | List builds in environment | `embr builds list` |
| `builds list-project` | List builds across all envs | `embr builds list-project` |
| `builds get <buildId>` | Get build details | `embr builds get bld_abc123` |
| `builds get-project <buildId>` | Get build by ID (project-level) | `embr builds get-project bld_abc` |
| `builds logs <buildId>` | Get build logs | `embr builds logs bld_abc123` |
| `builds stream <buildId>` | Stream build logs (SSE) | `embr builds stream bld_abc123` |
| `builds cancel <buildId>` | Cancel a running build | `embr builds cancel bld_abc123` |
| `builds upload` | Upload a zip as build artifact | `embr builds upload -f app.zip` |

**Options:**
- `-p, --project <projectId>` — Project ID
- `-e, --environment <environmentId>` — Environment ID
- `-c, --commit <sha>` — Commit SHA (required for trigger)
- `-m, --message <message>` — Commit message
- `--pr <number>` — Pull request number
- `--status <status>` — Filter by status
- `-f, --file <path>` — Zip file path (for upload)
- `-j, --json` — Output as JSON

### Deployments (`embr deployments`)

| Command | Description | Example |
|---------|-------------|---------|
| `deployments create` | Create deployment from build | `embr deployments create -b bld_abc123` |
| `deployments list` | List deployments | `embr deployments list` |
| `deployments get <deploymentId>` | Get deployment details | `embr deployments get dpl_abc123` |
| `deployments activate <deploymentId>` | Activate/rollback deployment | `embr deployments activate dpl_abc123` |
| `deployments stop <deploymentId>` | Stop a deployment | `embr deployments stop dpl_abc123` |
| `deployments logs <deploymentId>` | Get deployment logs | `embr deployments logs dpl_abc123` |

**Options:**
- `-p, --project <projectId>` — Project ID
- `-e, --environment <environmentId>` — Environment ID
- `-b, --build <buildId>` — Build ID (required for create)
- `--lines <number>` — Number of log lines
- `--follow` — Follow logs in real-time
- `--level <level>` — Log level filter
- `-j, --json` — Output as JSON

### Installations (`embr installations`)

| Command | Description | Example |
|---------|-------------|---------|
| `installations get <installationId>` | Get installation details | `embr installations get 12345` |
| `installations config` | Show installation configuration | `embr installations config` |

### Quickstart (`embr quickstart`) — **PREFERRED for new projects**

| Command | Description | Example |
|---------|-------------|---------|
| `quickstart deploy` | One-command project setup and deploy | `embr quickstart deploy myorg/my-app` |

> **This is the recommended way to create a new project.** It handles everything:
> project creation, environment setup, build triggering, and deployment — all in one command.
> The installation ID is resolved automatically from your cached login.

```bash
# All you need is the repo
embr quickstart deploy <owner/repo>
```

**Options:**
- `-i, --installation-id <id>` — GitHub App installation ID (auto-resolved from login if not provided)
- `-b, --branch <branch>` — Branch to deploy (defaults to repo's default)
- `-n, --env-name <name>` — Environment name (defaults to "production")
- `--skip-deploy` — Skip deployment after build
- `--no-wait` — Don't wait for build to complete

---

## EV2 Deployment Commands (`embr ev2`)

EV2 commands are used for deploying Embr.Global.Api to Azure using Express V2.

| Command | Description | Example |
|---------|-------------|---------|
| `ev2 build-push` | Build and push image to ACR | `embr ev2 build-push --acr embracr --tag 1.0.13` |
| `ev2 set-image-tag` | Update EV2 config image tag | `embr ev2 set-image-tag --env Test --tag 1.0.13` |
| `ev2 set-version` | Update EV2 artifacts version | `embr ev2 set-version --version 1.0.13` |
| `ev2 register` | Register EV2 artifacts | `embr ev2 register --rollout-infra Test` |
| `ev2 rollout` | Start EV2 rollout | `embr ev2 rollout --artifacts-version 1.0.13` |
| `ev2 deploy` | Full deploy workflow | `embr ev2 deploy --acr embracr --artifacts-version 1.0.16` |

### Full Deploy Example

```bash
# Full deploy (build+push, update config+version, register, rollout)
embr ev2 deploy --acr embracr --artifacts-version 1.0.16 --select "regions(australiaeast)"

# Deploy without building (testing)
embr ev2 deploy --acr embracr --artifacts-version 1.0.16 --skip-build
```

### EV2 Options

- `--acr <name>` — ACR name (without .azurecr.io)
- `--tag <tag>` — Image tag
- `--artifacts-version <version>` — Artifacts version
- `--env <name>` — Environment folder (Test or Prod)
- `--select <select>` — Select regions (e.g., "regions(australiaeast)")
- `--rollout-infra <name>` — Rollout infra (Test/Prod)
- `--skip-build` — Skip build and push to ACR
- `--skip-register` — Skip artifact registration
- `--skip-rollout` — Skip rollout
- `--no-wait` — Do not wait for completion

---

## Common Workflows

### Setting Up a New Project

```bash
# 1. Make sure you're logged in
embr auth status
# If not logged in:
embr auth login

# 2. Use quickstart to create project, environment, build, and deploy in one step
embr quickstart deploy myorg/myapp
```

That's it. The quickstart command handles project creation, environment setup, build, and deployment.
The installation ID is automatically resolved from your cached login.

#### Manual setup (if you need more control)

```bash
# 1. Login
embr auth login

# 2. Create project from GitHub repo
embr projects create -r myorg/myapp

# 3. Set context for future commands
embr config context -p prj_abc123

# 4. Create production environment
embr environments create -n production -b main --production

# 5. Set environment context
embr config context -e env_xyz789
```

### Triggering a Build and Deployment

```bash
# Trigger build from commit
embr builds trigger -c abc123def

# Watch build logs
embr builds stream bld_xyz

# Create deployment from successful build
embr deployments create -b bld_xyz

# Check deployment status
embr deployments get dpl_abc

# Get the live public URL for the environment
embr environments list
# The URL column shows the stable public URL
```

### Rolling Back a Deployment

```bash
# List deployments to find previous version
embr deployments list

# Activate (rollback to) a previous deployment
embr deployments activate dpl_previous
```

### Deploying to Azure via EV2

```bash
# Full deploy to Australia East
embr ev2 deploy --acr embracr --artifacts-version 1.0.20 --select "regions(australiaeast)"

# Deploy to production
embr ev2 deploy --acr embracr --artifacts-version 1.0.20 --env Prod --rollout-infra Prod
```

---

## Configuration File

Configuration is stored at:
- **Windows:** `%APPDATA%\embr-cli\config.json`
- **macOS:** `~/Library/Application Support/embr-cli/config.json`
- **Linux:** `~/.config/embr-cli/config.json`

Default settings:
```json
{
  "apiUrl": "https://embr.azure.com/api",
  "timeout": 300
}
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `EMBR_TOKEN` | API token for authentication |
| `EMBR_API_TOKEN` | Alternative API token variable |

## Global Options

All commands support:
- `-v, --verbose` — Enable verbose output for debugging
- `-j, --json` — Output as JSON (where applicable)

## Troubleshooting

### `embr` not recognized
Ensure npm global bin folder is on PATH:
- **Windows:** `C:\Users\<you>\AppData\Roaming\npm`

### EV2 commands fail
Verify EV2 PowerShell modules are installed:
```powershell
Get-Command Register-AzureServiceArtifacts
Get-Command New-AzureServiceRollout
```

### Build/push failures
Verify Azure CLI login, Docker access, and .NET SDK availability.

---

## API Reference

The Embr CLI communicates with the Embr Global API. Key endpoints:

| Resource | Operations |
|----------|------------|
| Projects | CREATE, READ, UPDATE, DELETE |
| Environments | CREATE, READ, UPDATE, DELETE |
| Builds | TRIGGER, READ, LOGS, CANCEL, UPLOAD |
| Deployments | CREATE, READ, ACTIVATE, STOP, LOGS |
