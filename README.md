# gh-embr

A [GitHub CLI](https://cli.github.com/) extension that wraps the [Embr CLI](https://github.com/coreai-microsoft/embr), adding convenience features like automatic local-path-to-repo resolution.

## Prerequisites

Install the **Embr CLI** before using this extension. Download the latest installer from the [GitHub Releases page](https://github.com/coreai-microsoft/embr/releases?q=cli):

| Platform    | Install method                                                                                      |
|-------------|-----------------------------------------------------------------------------------------------------|
| **macOS**   | Download `embr-installer.pkg` and double-click to install                                           |
| **Windows** | Download `embr-installer.msi` and double-click (silent: `msiexec /i embr-installer.msi /quiet`)    |
| **Linux**   | `curl -fsSL https://github.com/coreai-microsoft/embr/releases/latest/download/embr-linux-x64 -o /usr/local/bin/embr && chmod +x /usr/local/bin/embr` |
| **npm**     | `npm install -g @coreai-microsoft/embr-cli --registry=https://npm.pkg.github.com`                   |

> **Note:** For npm installs, you must first authenticate to GitHub Packages:
> ```bash
> gh auth login -s read:packages
> npm login --registry=https://npm.pkg.github.com --scope=@coreai-microsoft
> ```

## Install the extension

```bash
gh extension install nirmash/gh-embr
```

## Usage

All Embr CLI commands work through the extension — just replace `embr` with `gh embr`:

```bash
# Authenticate
gh embr login

# Deploy an app
gh embr quickstart deploy owner/repo

# List projects
gh embr projects list
```

### Local path resolution

The extension adds automatic resolution of local directory paths to `owner/repo` format. Instead of typing the full GitHub owner and repo name, you can point to a local clone:

```bash
# These are equivalent:
gh embr quickstart deploy owner/my-app
gh embr quickstart deploy ./my-app
gh embr quickstart deploy ~/Projects/my-app

# Also works with --repo flag:
gh embr projects create --repo ./my-app

# And get-by-repo:
gh embr projects get-by-repo ./my-app
```

## GitHub Copilot Skills

This repo includes Embr skill definitions for AI assistants in the `skills/` directory:

- **`skills/copilot/`** — Skills for GitHub Copilot
- **`skills/claude/`** — Skills for Claude

## Development

### Running tests

Tests use [bats-core](https://github.com/bats-core/bats-core):

```bash
# Install bats (macOS)
brew install bats-core

# Run tests
bats test/
```

## License

See [LICENSE](LICENSE) for details.
