---
name: embr-dev
description: PRIMARY skill for all Embr workflows. Use this FIRST. Contains everything needed to log in, create projects, build, deploy, and iteratively develop applications on the Embr platform. Covers authentication (device code flow), project setup via quickstart, builds, deployments, branch-based development, and validation.
---

# Embr Developer Workflow Skill

This skill guides developers through the end-to-end workflow of developing and deploying applications using the Embr platform.

## Overview

Embr is a deployment platform that connects to your GitHub repositories and automatically deploys your applications. Each deployment gets a unique URL for easy access and testing, enabling rapid iterative development.

---

## Quick Start Workflow

```
GitHub Repo → Embr Project → Environment (branch) → Build → Deployment → Live URL
```

### The Core Loop

1. **Push code** to GitHub
2. **Build** is triggered (manually or via webhook)
3. **Deployment** is created from successful build
4. **Traffic shifts** to new deployment
5. **Validate** your changes via the environment URL
6. **Repeat**

---

## Step 1: Login to Embr

> **IMPORTANT:** Before doing anything, make sure the user is logged in.
> Login automatically caches the GitHub App installation ID, so it never needs to be provided manually.

### Check auth status

```bash
embr auth status
```

If the output shows "Ready to use Embr CLI", skip to Step 2.

### If not logged in

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

---

## Step 2: Start with a GitHub Repository

Before using Embr, you need:
- A GitHub repository with your application code
- The Embr GitHub App installed on your repository

Your repository should contain:
- Application source code
- A `Dockerfile` or buildable project structure
- Any required configuration files

---

## Step 3: Create a Project

> **ALWAYS use `embr quickstart deploy` to create a project.** This is the only way to set up a new project.
> It handles everything in one command — no installation IDs, no manual steps.
> All you need is the GitHub repo name.

```bash
embr quickstart deploy <owner/repo>
```

**Example:**

```bash
embr quickstart deploy myorg/my-web-app
```

This single command will:
1. Create the project (or use existing)
2. Create a production environment
3. Fetch the latest commit from the default branch
4. Trigger a build
5. Wait for build completion
6. Create a deployment

> **Note:** You do NOT need an installation ID. Once you've run `embr login`, the installation ID is already cached in your CLI context and is resolved automatically.

---

## Step 4: Trigger a Build

Trigger a build from a specific commit:

```bash
# Get your latest commit SHA
git rev-parse HEAD

# Trigger the build
embr builds trigger --commit <sha>

# Example
embr builds trigger --commit abc123def456
```

### Monitor Build Progress

Watch the build logs in real-time:

```bash
# Stream logs as the build progresses
embr builds stream <buildId>

# Or get logs after completion
embr builds logs <buildId>
```

---

## Step 5: Deployment (Automatic on Success)

When a build succeeds, a deployment is automatically created. The deployment:
1. Provisions new instances with your build artifact
2. Starts your application
3. Shifts incoming traffic to the new deployment

### Check Deployment Status

```bash
# List deployments
embr deployments list

# Get specific deployment details
embr deployments get <deploymentId>
```

---

## Step 6: Access Your Application

After the first successful deployment, your environment will have a live URL:

```bash
# Get environment details including the URL
embr environments get
```

The URL format is typically: `https://<environment-name>-<project>-<hash>.embrdev.io`

### Validate Your Changes

Use the Playwright MCP server to launch and validate your application:

```bash
# The environment URL can be opened in a browser for testing
# Use Playwright MCP to automate validation
```

**Tip:** You can use the `mcp_playwright` tools to:
- Navigate to your environment URL
- Take screenshots
- Interact with your application
- Validate that your changes work correctly

---

## Handling Build Failures

If a build fails, you need to diagnose and fix the issue.

### Get Build Logs

```bash
# Get the full build logs
embr builds logs <buildId>

# Or stream if still running
embr builds stream <buildId>
```

### Common Failure Causes

| Issue | Solution |
|-------|----------|
| **Intermittent failure** | Retry the build with the same commit |
| **Dependency issue** | Fix `package.json`, `requirements.txt`, etc. |
| **Dockerfile error** | Fix your Dockerfile and push a new commit |
| **Code compilation error** | Fix the code and push a new commit |
| **Timeout** | Optimize build or increase resources |

### Retry a Build

For intermittent failures, simply trigger a new build with the same commit:

```bash
embr builds trigger --commit <same-sha>
```

For code issues, fix the problem, push to GitHub, and trigger a new build:

```bash
git add .
git commit -m "Fix build issue"
git push

# Trigger build with new commit
embr builds trigger --commit $(git rev-parse HEAD)
```

---

## Iterative Development Workflow

### The Development Cycle

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   ┌──────────┐    ┌───────┐    ┌────────────┐          │
│   │  Code    │───▶│ Push  │───▶│   Build    │          │
│   │ Changes  │    │       │    │            │          │
│   └──────────┘    └───────┘    └─────┬──────┘          │
│        ▲                             │                  │
│        │                             ▼                  │
│        │                       ┌────────────┐          │
│        │                       │  Deploy    │          │
│        │                       │            │          │
│        │                       └─────┬──────┘          │
│        │                             │                  │
│        │                             ▼                  │
│   ┌────┴─────┐                ┌────────────┐          │
│   │  Fix /   │◀───────────────│  Validate  │          │
│   │ Improve  │                │   (URL)    │          │
│   └──────────┘                └────────────┘          │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Quick Iteration Commands

```bash
# Make changes to your code
# ...

# Push to GitHub
git add .
git commit -m "My changes"
git push

# Trigger build
embr builds trigger --commit $(git rev-parse HEAD)

# Watch the build
embr builds stream <buildId>

# Once deployed, check the environment URL
embr environments get

# Validate your changes at the URL
# Use Playwright MCP or browser to test
```

---

## Branch-Based Development

### Creating Feature Branch Environments

When working on a feature branch, create a separate environment:

```bash
# Create and switch to a feature branch
git checkout -b feature/new-feature

# Make your changes and push
git add .
git commit -m "Add new feature"
git push -u origin feature/new-feature

# Create an Embr environment for this branch
embr environments create --name feature-new-feature --branch feature/new-feature

# Set context to work with this environment
embr config context -e <new-environment-id>

# Trigger a build
embr builds trigger --commit $(git rev-parse HEAD)
```

### Managing Multiple Environments

```bash
# List all environments for your project
embr environments list

# Switch context between environments
embr config context -e <environmentId>

# Check a specific environment's URL
embr environments get -e <environmentId>
```

---

## Pull Request Workflow

### Current PR Workflow

1. **Create a PR branch environment** (manual for now)
2. **Test on the PR branch environment**
3. **Merge to main**
4. **Deploy to production**

```bash
# 1. Create environment for your PR branch
embr environments create --name pr-123 --branch feature/my-pr

# 2. Trigger build and test
embr builds trigger --commit <pr-head-sha>
# ... validate at the environment URL ...

# 3. After PR is merged, switch to production
embr config context -e <production-env-id>

# 4. Trigger production build (if webhook didn't fire)
git checkout main
git pull
embr builds trigger --commit $(git rev-parse HEAD)
```

### Webhook Behavior

Embr has webhooks configured to automatically trigger builds on push events. However:

- **Webhooks may not always fire** — network issues, GitHub delays, etc.
- **If no build appears** after pushing, trigger one manually:

```bash
embr builds trigger --commit <sha>
```

### Future: Automatic PR Environments

Soon, PRs will automatically trigger environment creation. Until then, manually create environments for PR branches you want to test.

---

## Traffic and Rollback

### How Traffic Shifts

When a new deployment is created:
1. New instances spin up with the new build
2. Health checks pass
3. Traffic automatically shifts to the new deployment
4. Old deployment becomes inactive (but preserved for rollback)

### Rolling Back

If a deployment has issues, roll back to a previous version:

```bash
# List deployments to find a previous working version
embr deployments list

# Activate (rollback to) a previous deployment
embr deployments activate <previous-deployment-id>
```

Traffic immediately shifts back to the previous deployment.

---

## Complete Development Session Example

Here's a full example of a typical development session:

```bash
# === Initial Setup (one-time) ===

# Login to Embr (caches installation ID automatically)
embr auth login

# Use quickstart to create project, environment, build, and deploy in one step
embr quickstart deploy myorg/my-app

# Set context for future commands
embr config context -p <projectId> -e <environmentId>

# === Daily Development ===

# 1. Make code changes
code src/app.py

# 2. Commit and push
git add .
git commit -m "Add user authentication"
git push

# 3. Trigger build
embr builds trigger --commit $(git rev-parse HEAD)

# 4. Watch build progress
embr builds stream <buildId>

# 5. If build fails, check logs and fix
embr builds logs <buildId>
# ... fix issues ...
git add . && git commit -m "Fix build" && git push
embr builds trigger --commit $(git rev-parse HEAD)

# 6. Once build succeeds, check deployment
embr deployments list

# 7. Get the environment URL
embr environments get
# Output shows: url: https://production-my-app-abc123.embrdev.io

# 8. Validate changes (use Playwright MCP or browser)
# Navigate to the URL and test your changes

# 9. Repeat for next change
```

---

## Using Playwright MCP for Validation

After getting your environment URL, use Playwright MCP to automate validation:

```bash
# Get your environment URL
embr environments get
# → url: https://production-my-app-abc123.embrdev.io
```

Then use Playwright MCP tools to:

1. **Navigate** to your environment URL
2. **Take screenshots** to verify UI changes
3. **Click elements** and test interactions
4. **Fill forms** and test user flows
5. **Assert** that expected content appears

This enables automated validation of your deployments without leaving your development environment.

---

## Tips for Efficient Development

### 1. Use Profiles for Multiple Projects

```bash
# Save current context as a profile
embr config profile save my-app-dev

# Switch between projects easily
embr config profile use my-app-prod
```

### 2. Quick Build-Deploy Cycle

```bash
# One-liner: push and build
git push && embr builds trigger --commit $(git rev-parse HEAD)
```

### 3. Monitor Multiple Builds

```bash
# List recent builds across all environments
embr builds list-project
```

### 4. JSON Output for Scripting

```bash
# Get environment URL programmatically
embr environments get --json | jq -r '.url'
```

### 5. Check Build Status Before Waiting

```bash
# Quick status check
embr builds get <buildId>
```

---

## Troubleshooting

### Build Not Triggering Automatically

If webhooks don't fire after a push:
```bash
embr builds trigger --commit $(git rev-parse HEAD)
```

### Can't Find Environment URL

The URL only appears after the first successful deployment:
```bash
embr environments get
# If url is null, check that a deployment completed successfully
embr deployments list
```

### Deployment Not Receiving Traffic

Check deployment status:
```bash
embr deployments get <deploymentId>
# Status should be "active" to receive traffic
```

### Environment Shows Old Version

A new deployment might still be in progress:
```bash
embr deployments list
# Check for "deploying" status
```

---

## Summary

| Stage | Command | What Happens |
|-------|---------|--------------|
| Login | `embr login` | Authenticates and caches installation ID |
| Setup | `embr quickstart deploy <repo>` | Creates project, environment, builds, and deploys |
| Build | `embr builds trigger` | Builds your code into an artifact |
| Monitor | `embr builds stream` | Watch build logs in real-time |
| Deploy | (automatic) | Successful build creates deployment |
| Validate | `embr environments get` | Get URL to test your app |
| Rollback | `embr deployments activate` | Revert to previous version |

The key is to **iterate quickly**: push code, trigger builds, validate at the URL, and repeat.
