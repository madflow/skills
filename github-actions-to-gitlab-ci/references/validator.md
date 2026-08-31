# Validator reference

Detailed handling for `scripts/validate.sh`. Load when something other than the happy path occurs: script not found, permission denied, neither backend installed, no shell or network access, validation fails, or the `glab` backend needs a project.

The happy path itself stays in `SKILL.md` step 4.5: `bash <skill-dir>/scripts/validate.sh /path/to/translated.gitlab-ci.yml`.

## Finding the script

The script is at `scripts/validate.sh` inside the skill bundle. The path depends on the host tool:

- **Claude Code**: use `${CLAUDE_SKILL_DIR}/scripts/validate.sh`
- **opencode and other tools**: the skill is at one of the discovery paths (`~/.claude/skills/github-actions-to-gitlab-ci/`, `~/.config/opencode/skills/github-actions-to-gitlab-ci/`, `~/.agents/skills/github-actions-to-gitlab-ci/`, or a project-local equivalent). Locate the directory you loaded this skill from and append `/scripts/validate.sh`.
- **Fallback**: if you cannot locate the bundled script, run the underlying tool directly: `glci lint -f <path>` (preferred) or `glab ci lint <path>` (fallback). The bundled script is a thin wrapper around exactly those commands.

## Backend selection

Set `VALIDATE_BACKEND=glci|glab` to force a specific backend. The default is `auto`, which prefers `glci` when installed and falls back to `glab`.

## `glab` backend project resolution

The `glab` backend needs a GitLab project context (the lint API is per-project). The script resolves the project from, in order:

1. A `--project <group/project>` flag passed to the script.
2. The `VALIDATE_PROJECT` environment variable.
3. The git remote of the current directory (when the user is inside a GitLab checkout).
4. The user's `glab` default.

The skill does not hardcode any project. If none of these resolves, the script exits 2 with a clear error explaining the three options the user has: install `glci` instead, set `VALIDATE_PROJECT`, or pass `--project`. For users migrating from GitHub Actions who do not have a GitLab project they can use, the simplest path is to install `glci`, which validates entirely offline and needs no project.

## Migrating from a GitHub-hosted repo

Users invoking this skill are almost always sitting in a repo whose origin is on GitHub. That has two consequences:

- The git-remote step of the `glab` project resolver will never produce a GitLab path. The script's resolver rejects non-GitLab hosts.
- Unless the user has set `VALIDATE_PROJECT` or `--project`, the `glab` path can only fail.

When you detect (or anticipate) a non-GitLab origin, lead with `glci` from the start: recommend installing it before invoking the validator. This avoids the failed `glab` fallback entirely.

## Permission denied / missing executable bit

Two binaries can hit this: the bundled `scripts/validate.sh` itself, and the `glci` binary when installed manually.

**`validate.sh`**: the executable bit is lost when the skill is copied via tarball or zip (not via `git clone`). Fix once with `chmod +x <skill-dir>/scripts/validate.sh`, or always invoke via `bash` as shown in SKILL.md.

**`glci`**: manual installs via `sudo mv` often preserve whatever mode the downloaded file had and silently produce a binary without the `x` bit. `validate.sh` detects this in standard locations and exits 2 with a pointer. If the script reports glci as missing despite a prior install, check the standard paths:

```bash
ls -l /usr/local/bin/glci /opt/homebrew/bin/glci ~/bin/glci ~/.local/bin/glci 2>/dev/null
```

If a file is present without `x` in its mode, fix it with `sudo chmod +x <path>` (or without sudo if the file is under `$HOME`).

## Neither backend installed (exit code 2)

The script prints install commands for both tools. The agent should not run any install command itself without explicit user consent, and even with consent, prefer asking the user to run it themselves. This sidesteps environments where the agent is sandboxed (no shell access, `curl` blocked, or otherwise restricted) and keeps the user in control of what gets installed on their machine.

Surface both options with their tradeoffs and let the user pick:

- **glci** (recommended when the user does not yet have GitLab tooling). Runs offline, no GitLab account or token required, deeper parse, unlocks future structural validation. The bundled `scripts/validate.sh` prints the install one-liner in its error output, pointing at `main/install.sh` which always installs the latest tag. If `curl` is restricted in the user's environment or they prefer a manual install, point them to the releases page: https://gitlab.com/gitlab-org/ci-cd/runner-tools/glci/-/releases. They can download the binary matching their OS/arch (`glci-darwin-arm64`, `glci-linux-amd64`, etc.), mark it executable with `chmod +x`, and move it to a directory on PATH.
- **glab** (recommended if the user already has a GitLab account). Calls the GitLab CI Lint API. Install via the user's preferred method (Homebrew, apt, dnf, winget, manual download). See https://gitlab.com/gitlab-org/cli#installation for the full list. After install, the user runs `glab auth login` once.

When the user is migrating from GitHub Actions and does not yet have GitLab tooling, lead with `glci` because it does not assume an existing GitLab account. If the user already mentioned a GitLab account or `glab` set up, lead with `glab`. Hand the user the relevant install command (or the releases URL for a manual download), ask them to run it themselves, and once they confirm, re-run `validate.sh` and continue.

If the user declines both, skip validation in this run and clearly note in the migration report that the translated `.gitlab-ci.yml` was not validated locally. Recommend they validate in the GitLab UI Pipeline editor (**Build > Pipeline editor > Validate**, or **CI/CD > Pipelines > CI/CD Lint** on older versions) after pushing.

## No shell access

Some hosts (web-only chat surfaces, read-only review agents, sandboxed environments without shell access) cannot invoke `bash` or run the bundled validator. In that case:

- Skip the script invocation; do not pretend it ran.
- Mark "local validation skipped (agent has no shell access)" in the migration report so the user knows they are receiving an unvalidated translation.
- Tell the user to validate the YAML in the GitLab UI: open the project on GitLab and go to **Build > Pipeline editor > Validate** (or **CI/CD > Pipelines > CI/CD Lint** on older versions). Paste the YAML, click Validate. Zero local tooling required.
- For future runs, recommend the user install `glci` (preferred) or `glab` locally so subsequent translations can be validated end-to-end. The bundled `scripts/validate.sh` will work on hosts that support bash.

## No network access

Two paths to be aware of:

- `glci lint` is offline by design. If `glci` is installed locally, validation still works without any network.
- `glab ci lint` calls the GitLab CI Lint API and will fail without network. If only `glab` is installed, validation will exit non-zero with a network error; document this in the migration report as "could not validate (no network)" and recommend the user retry when network is available, install `glci` for offline validation, or use the GitLab UI Pipeline editor.

## Validation failures

The output lists errors with line numbers. Two responses:

- **Syntax error**: fix it and re-run the validator.
- **Translation gap**: document the error as a "Needs review" item in the migration report rather than silently shipping a broken file.

## What the validator does not catch

The validator does not catch semantic errors (does the pipeline do what the user intended?) or runtime errors (will the scripts succeed?). Those remain the user's responsibility, surfaced via the migration report.
