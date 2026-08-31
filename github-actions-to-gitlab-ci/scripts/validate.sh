#!/usr/bin/env bash
# Validate a .gitlab-ci.yml file using glci (preferred) or glab (fallback).
# Usage: ./validate.sh [--project <group/project>] [path-to-file]
# Default file: .gitlab-ci.yml in the current directory.
#
# Backend selection (env var VALIDATE_BACKEND):
#   auto (default) - prefer glci if installed, fall back to glab
#   glci           - require glci, do not fall back
#   glab           - require glab, do not fall back
#
# glci lint runs fully offline. It resolves include:, extends:, !reference,
# default:, and workflow: without a GitLab token. No GitLab project context
# required. Deeper than glab ci lint.
#
# glab ci lint calls the GitLab CI Lint API. Requires glab to be installed and
# authenticated, AND a GitLab project context the user can read. The script
# resolves the project from (in order):
#   1. --project <group/project> flag
#   2. VALIDATE_PROJECT environment variable
#   3. git remote origin URL (when run inside a GitLab checkout)
#   4. glab's default host project via `glab config get`
# If none of those resolve, the script exits 2 with a clear error.
#
# Exit codes:
#   0 - file is syntactically valid
#   1 - file is invalid (errors printed)
#   2 - file not found, no backend available, no project for glab backend,
#       or unknown VALIDATE_BACKEND

set -uo pipefail

# Parse args: --project <path>, then positional FILE.
PROJECT_FLAG=""
FILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --project)
      shift
      PROJECT_FLAG="${1:-}"
      shift
      ;;
    --project=*)
      PROJECT_FLAG="${1#--project=}"
      shift
      ;;
    -h|--help)
      sed -n '1,28p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      if [ -z "$FILE" ]; then
        FILE="$1"
      fi
      shift
      ;;
  esac
done
FILE="${FILE:-.gitlab-ci.yml}"
BACKEND="${VALIDATE_BACKEND:-auto}"

if [ ! -f "$FILE" ]; then
  echo "ERROR: $FILE not found" >&2
  exit 2
fi

have_glci=0
have_glab=0
command -v glci >/dev/null 2>&1 && have_glci=1
command -v glab >/dev/null 2>&1 && have_glab=1

# If glci is not on PATH, check common install paths for an existing file that
# is not executable. Manual installs via `sudo mv` often preserve whatever mode
# the downloaded file had and silently produce an inert binary.
broken_glci_path=""
if [ "$have_glci" = 0 ]; then
  for candidate in /usr/local/bin/glci /opt/homebrew/bin/glci "$HOME/bin/glci" "$HOME/.local/bin/glci"; do
    if [ -f "$candidate" ] && [ ! -x "$candidate" ]; then
      broken_glci_path="$candidate"
      break
    fi
  done
fi

print_install_pointers() {
  # The install script at main/install.sh always pins to the latest tag.
  echo "Install glci (preferred, offline, no token):" >&2
  echo "  curl -fsSL https://gitlab.com/gitlab-org/ci-cd/runner-tools/glci/-/raw/main/install.sh | bash" >&2
  echo "  (or browse releases: https://gitlab.com/gitlab-org/ci-cd/runner-tools/glci/-/releases)" >&2
  echo "Install glab (fallback, requires authenticated GitLab account):" >&2
  echo "  https://gitlab.com/gitlab-org/cli#installation" >&2
}

# Resolution chain for the glab backend's project context.
# Echoes the resolved "group/project" path on stdout, empty if none found.
resolve_glab_project() {
  # 1. Explicit --project flag
  if [ -n "$PROJECT_FLAG" ]; then
    echo "$PROJECT_FLAG"
    return 0
  fi
  # 2. VALIDATE_PROJECT env var
  if [ -n "${VALIDATE_PROJECT:-}" ]; then
    echo "$VALIDATE_PROJECT"
    return 0
  fi
  # 3. git remote origin URL, parsed for gitlab host
  local remote_url
  remote_url="$(git config --get remote.origin.url 2>/dev/null || true)"
  if [ -n "$remote_url" ]; then
    # Strip protocol and host for both SSH and HTTPS remotes. Only matches
    # gitlab.com or any *.gitlab.* host; non-GitLab hosts (github.com, etc.)
    # are left intact and rejected by the equality check below. The .git
    # suffix is stripped separately so a github.com URL with .git does not
    # masquerade as a "stripped" GitLab path.
    local stripped
    stripped="$(echo "$remote_url" \
      | sed -E 's#^(https?://|git@)[^/:]*gitlab[^/:]*[:/]##')"
    if [ -n "$stripped" ] && [ "$stripped" != "$remote_url" ]; then
      echo "${stripped%.git}"
      return 0
    fi
  fi
  # 4. glab's default host project, if glab is installed
  if [ "$have_glab" = 1 ]; then
    local glab_default
    glab_default="$(glab config get -g host 2>/dev/null || true)"
    # glab config does not expose a "default project" directly; users must
    # set one explicitly. Skip this step rather than guessing.
    : "${glab_default:=}"
  fi
  echo ""
}

print_no_project_error() {
  echo "ERROR: glab backend requires a GitLab project context." >&2
  echo "  No project found via --project flag, VALIDATE_PROJECT env var, git remote, or glab config." >&2
  echo "" >&2
  echo "You have three options:" >&2
  echo "  1. Install glci (preferred; works offline, no GitLab project required):" >&2
  echo "     curl -fsSL https://gitlab.com/gitlab-org/ci-cd/runner-tools/glci/-/raw/main/install.sh | bash" >&2
  echo "     (or browse releases: https://gitlab.com/gitlab-org/ci-cd/runner-tools/glci/-/releases)" >&2
  echo "  2. Set VALIDATE_PROJECT to a GitLab project you own (or can read):" >&2
  echo "     VALIDATE_PROJECT=your-group/your-project bash scripts/validate.sh <file>" >&2
  echo "  3. Pass --project explicitly per invocation:" >&2
  echo "     bash scripts/validate.sh --project your-group/your-project <file>" >&2
}

case "$BACKEND" in
  auto)
    if [ "$have_glci" = 1 ]; then
      BACKEND=glci
    elif [ -n "$broken_glci_path" ]; then
      echo "ERROR: found glci at $broken_glci_path but it is not executable." >&2
      echo "  Fix it and re-run:" >&2
      echo "    chmod +x $broken_glci_path" >&2
      exit 2
    elif [ "$have_glab" = 1 ]; then
      BACKEND=glab
      echo "Note: glci not detected on PATH; falling back to glab ci lint." >&2
    else
      echo "ERROR: neither glci nor glab is installed." >&2
      print_install_pointers
      exit 2
    fi
    ;;
  glci)
    if [ "$have_glci" != 1 ]; then
      if [ -n "$broken_glci_path" ]; then
        echo "ERROR: VALIDATE_BACKEND=glci but glci at $broken_glci_path is not executable." >&2
        echo "  Fix it and re-run:" >&2
        echo "    chmod +x $broken_glci_path" >&2
      else
        echo "ERROR: VALIDATE_BACKEND=glci but glci is not installed." >&2
        print_install_pointers
      fi
      exit 2
    fi
    ;;
  glab)
    if [ "$have_glab" != 1 ]; then
      echo "ERROR: VALIDATE_BACKEND=glab but glab is not installed." >&2
      print_install_pointers
      exit 2
    fi
    ;;
  *)
    echo "ERROR: unknown VALIDATE_BACKEND: $BACKEND (expected auto, glci, or glab)" >&2
    exit 2
    ;;
esac

case "$BACKEND" in
  glci)
    echo "Validating $FILE via glci lint..."
    exec glci lint --quiet -f "$FILE"
    ;;
  glab)
    PROJECT="$(resolve_glab_project)"
    if [ -z "$PROJECT" ]; then
      print_no_project_error
      exit 2
    fi
    echo "Validating $FILE via glab ci lint (project: $PROJECT)..."
    exec glab ci lint --repo "$PROJECT" "$FILE"
    ;;
esac
