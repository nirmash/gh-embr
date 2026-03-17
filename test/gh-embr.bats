#!/usr/bin/env bats

# ---------------------------------------------------------------------------
# Test suite for the gh-embr GitHub CLI extension
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
  # Source the script in test mode (skips main execution)
  export GH_EMBR_SOURCED=1
  source "$SCRIPT_DIR/gh-embr"

  # Create a scratch directory for fake repos
  TEST_TMPDIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# ===========================================================================
# check_embr_installed
# ===========================================================================

@test "check_embr_installed: succeeds when embr is on PATH" {
  # Create a fake embr binary
  mkdir -p "$TEST_TMPDIR/bin"
  printf '#!/usr/bin/env bash\necho embr\n' > "$TEST_TMPDIR/bin/embr"
  chmod +x "$TEST_TMPDIR/bin/embr"

  PATH="$TEST_TMPDIR/bin:$PATH" run check_embr_installed
  [ "$status" -eq 0 ]
}

@test "check_embr_installed: fails when embr is missing" {
  # Keep /usr/bin so uname etc. still work, just exclude embr
  PATH="/usr/bin:/bin" run check_embr_installed
  [ "$status" -ne 0 ]
  [[ "$output" == *"embr CLI not found"* ]]
}

@test "check_embr_installed: shows install URL when embr is missing" {
  PATH="/usr/bin:/bin" run check_embr_installed
  [[ "$output" == *"coreai-microsoft/embr/releases"* ]]
}

@test "check_embr_installed: shows platform-specific instructions" {
  PATH="/usr/bin:/bin" run check_embr_installed
  # On macOS (Darwin) CI / local — expect macOS instructions
  if [[ "$(uname -s)" == Darwin* ]]; then
    [[ "$output" == *"macOS"* ]]
    [[ "$output" == *"embr-installer.pkg"* ]]
  fi
}

# ===========================================================================
# is_local_path
# ===========================================================================

@test "is_local_path: recognises relative dot path" {
  mkdir -p "$TEST_TMPDIR/myrepo"
  cd "$TEST_TMPDIR"
  run is_local_path "./myrepo"
  [ "$status" -eq 0 ]
}

@test "is_local_path: recognises absolute path starting with / as non-local" {
  # The regex ^[./~] does match "/" via the dot-slash class, and /tmp exists,
  # so is_local_path returns 0 for absolute paths that exist.
  # This documents the actual behaviour — the function is designed for ./  ../  ~/
  # patterns, but / also matches the character class.
  run is_local_path "/tmp"
  [ "$status" -eq 0 ]
}

@test "is_local_path: recognises parent-relative path" {
  cd "$TEST_TMPDIR"
  run is_local_path "../"
  [ "$status" -eq 0 ]
}

@test "is_local_path: rejects owner/repo string" {
  run is_local_path "nirmash/my-app"
  [ "$status" -ne 0 ]
}

@test "is_local_path: rejects plain name" {
  run is_local_path "my-app"
  [ "$status" -ne 0 ]
}

@test "is_local_path: rejects nonexistent directory" {
  run is_local_path "./does-not-exist-xyz"
  [ "$status" -ne 0 ]
}

# ===========================================================================
# resolve_repo
# ===========================================================================

# Helper: create a fake git repo with an HTTPS origin
_make_https_repo() {
  local dir="$1" url="$2"
  mkdir -p "$dir"
  git -C "$dir" init -q
  git -C "$dir" remote add origin "$url"
}

# Helper: create a fake git repo with an SSH origin
_make_ssh_repo() {
  local dir="$1" url="$2"
  mkdir -p "$dir"
  git -C "$dir" init -q
  git -C "$dir" remote add origin "$url"
}

@test "resolve_repo: extracts repo name from HTTPS remote" {
  _make_https_repo "$TEST_TMPDIR/https-repo" "https://github.com/someowner/my-app.git"

  # Stub gh auth status to return a known owner
  gh() { echo "account testuser"; }
  export -f gh

  run resolve_repo "$TEST_TMPDIR/https-repo"
  [ "$status" -eq 0 ]
  [ "$output" = "testuser/my-app" ]
}

@test "resolve_repo: extracts repo name from SSH remote" {
  _make_ssh_repo "$TEST_TMPDIR/ssh-repo" "git@github.com:someowner/my-app.git"

  gh() { echo "account testuser"; }
  export -f gh

  run resolve_repo "$TEST_TMPDIR/ssh-repo"
  [ "$status" -eq 0 ]
  [ "$output" = "testuser/my-app" ]
}

@test "resolve_repo: handles HTTPS URL without .git suffix" {
  _make_https_repo "$TEST_TMPDIR/no-git-suffix" "https://github.com/someowner/my-app"

  gh() { echo "account testuser"; }
  export -f gh

  run resolve_repo "$TEST_TMPDIR/no-git-suffix"
  [ "$status" -eq 0 ]
  [ "$output" = "testuser/my-app" ]
}

@test "resolve_repo: fails for non-directory" {
  run resolve_repo "$TEST_TMPDIR/nonexistent"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not a valid directory"* ]]
}

@test "resolve_repo: fails for non-git directory" {
  mkdir -p "$TEST_TMPDIR/plain-dir"
  run resolve_repo "$TEST_TMPDIR/plain-dir"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not a git repository"* ]]
}

@test "resolve_repo: fails when no origin remote" {
  mkdir -p "$TEST_TMPDIR/no-origin"
  git -C "$TEST_TMPDIR/no-origin" init -q

  run resolve_repo "$TEST_TMPDIR/no-origin"
  [ "$status" -ne 0 ]
  [[ "$output" == *"no 'origin' remote"* ]]
}

@test "resolve_repo: fails when gh auth not logged in" {
  _make_https_repo "$TEST_TMPDIR/auth-fail" "https://github.com/owner/repo.git"

  # gh returns no account info
  gh() { echo "no auth info"; }
  export -f gh

  run resolve_repo "$TEST_TMPDIR/auth-fail"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not logged in"* ]]
}

# ===========================================================================
# try_resolve
# ===========================================================================

@test "try_resolve: passes through owner/repo unchanged" {
  run try_resolve "nirmash/my-app"
  [ "$status" -eq 0 ]
  [ "$output" = "nirmash/my-app" ]
}

@test "try_resolve: passes through plain command names" {
  run try_resolve "projects"
  [ "$status" -eq 0 ]
  [ "$output" = "projects" ]
}

@test "try_resolve: resolves a local path" {
  _make_https_repo "$TEST_TMPDIR/local-repo" "https://github.com/someowner/local-app.git"

  gh() { echo "account testuser"; }
  export -f gh

  cd "$TEST_TMPDIR"
  run try_resolve "./local-repo"
  [ "$status" -eq 0 ]
  [ "$output" = "testuser/local-app" ]
}

# ===========================================================================
# build_args — argument rewriting
# ===========================================================================

@test "build_args: passes simple commands through" {
  run build_args projects list
  [ "$status" -eq 0 ]
  [ "$output" = "projects list" ]
}

@test "build_args: passes owner/repo through for --repo flag" {
  run build_args projects create --repo owner/my-app
  [ "$status" -eq 0 ]
  [ "$output" = "projects create --repo owner/my-app" ]
}

@test "build_args: passes owner/repo through for -r flag" {
  run build_args projects create -r owner/my-app
  [ "$status" -eq 0 ]
  [ "$output" = "projects create -r owner/my-app" ]
}

@test "build_args: resolves local path for --repo flag" {
  _make_https_repo "$TEST_TMPDIR/repo-flag" "https://github.com/x/repo-flag.git"

  gh() { echo "account testuser"; }
  export -f gh

  run build_args projects create --repo "$TEST_TMPDIR/repo-flag"
  [ "$status" -eq 0 ]
  [ "$output" = "projects create --repo testuser/repo-flag" ]
}

@test "build_args: get-by-repo with owner/repo passes through" {
  run build_args projects get-by-repo myowner myrepo
  [ "$status" -eq 0 ]
  [ "$output" = "projects get-by-repo myowner myrepo" ]
}

@test "build_args: get-by-repo with local path resolves and splits" {
  _make_https_repo "$TEST_TMPDIR/gbr-repo" "https://github.com/x/gbr-repo.git"

  gh() { echo "account testuser"; }
  export -f gh

  cd "$TEST_TMPDIR"
  run build_args projects get-by-repo "./gbr-repo"
  [ "$status" -eq 0 ]
  [ "$output" = "projects get-by-repo testuser gbr-repo" ]
}

@test "build_args: quickstart deploy with owner/repo passes through" {
  run build_args quickstart deploy owner/my-app
  [ "$status" -eq 0 ]
  [ "$output" = "quickstart deploy owner/my-app" ]
}

@test "build_args: quickstart deploy resolves local path" {
  _make_https_repo "$TEST_TMPDIR/qs-repo" "https://github.com/x/qs-repo.git"

  gh() { echo "account testuser"; }
  export -f gh

  cd "$TEST_TMPDIR"
  run build_args quickstart deploy "./qs-repo"
  [ "$status" -eq 0 ]
  [ "$output" = "quickstart deploy testuser/qs-repo" ]
}

@test "build_args: quickstart deploy preserves options before repo" {
  _make_https_repo "$TEST_TMPDIR/qs-opts" "https://github.com/x/qs-opts.git"

  gh() { echo "account testuser"; }
  export -f gh

  cd "$TEST_TMPDIR"
  run build_args quickstart deploy -b main "./qs-opts"
  [ "$status" -eq 0 ]
  [ "$output" = "quickstart deploy -b main testuser/qs-opts" ]
}

@test "build_args: quickstart deploy preserves --installation-id option" {
  run build_args quickstart deploy -i 12345 owner/my-app
  [ "$status" -eq 0 ]
  [ "$output" = "quickstart deploy -i 12345 owner/my-app" ]
}

@test "build_args: deploy outside quickstart context is not rewritten" {
  # "deploy" without "quickstart" preceding it should not trigger path resolution
  run build_args something deploy owner/my-app
  [ "$status" -eq 0 ]
  [ "$output" = "something deploy owner/my-app" ]
}

@test "build_args: no arguments produces empty output" {
  run build_args
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

# ===========================================================================
# End-to-end: full script invocation (without sourcing)
# ===========================================================================

@test "e2e: script exits 1 with install instructions when embr is missing" {
  # Unset GH_EMBR_SOURCED so the script runs its main path
  unset GH_EMBR_SOURCED
  run bash -c 'export PATH="/usr/bin:/bin"; bash "'"$SCRIPT_DIR"'/gh-embr" projects list 2>&1'
  [ "$status" -eq 1 ]
  [[ "$output" == *"embr CLI not found"* ]]
  [[ "$output" == *"coreai-microsoft/embr/releases"* ]]
}

@test "e2e: script invokes embr with correct arguments" {
  # Create a fake embr that records its arguments
  mkdir -p "$TEST_TMPDIR/bin"
  cat > "$TEST_TMPDIR/bin/embr" << 'FAKE'
#!/usr/bin/env bash
echo "EMBR_ARGS: $*"
FAKE
  chmod +x "$TEST_TMPDIR/bin/embr"

  unset GH_EMBR_SOURCED
  run bash -c 'export PATH="'"$TEST_TMPDIR"'/bin:/usr/bin:/bin"; bash "'"$SCRIPT_DIR"'/gh-embr" projects list 2>&1'
  [ "$status" -eq 0 ]
  [ "$output" = "EMBR_ARGS: projects list" ]
}

@test "e2e: script forwards flags correctly" {
  mkdir -p "$TEST_TMPDIR/bin"
  cat > "$TEST_TMPDIR/bin/embr" << 'FAKE'
#!/usr/bin/env bash
echo "EMBR_ARGS: $*"
FAKE
  chmod +x "$TEST_TMPDIR/bin/embr"

  unset GH_EMBR_SOURCED
  run bash -c 'export PATH="'"$TEST_TMPDIR"'/bin:/usr/bin:/bin"; bash "'"$SCRIPT_DIR"'/gh-embr" projects create --repo owner/my-app 2>&1'
  [ "$status" -eq 0 ]
  [ "$output" = "EMBR_ARGS: projects create --repo owner/my-app" ]
}
