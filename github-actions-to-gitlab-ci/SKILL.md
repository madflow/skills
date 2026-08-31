---
name: github-actions-to-gitlab-ci
description: Use this skill whenever the user wants to migrate, translate, or convert GitHub Actions workflows to GitLab CI/CD pipelines. This includes converting `.github/workflows/*.yml` files to `.gitlab-ci.yml`, comparing GitHub Actions and GitLab CI/CD syntax, mapping GitHub Actions marketplace actions to GitLab equivalents, or evaluating what a workflow would look like in GitLab. Use this skill if the user mentions both GitHub Actions and GitLab CI in the same context, asks about migrating from GitHub to GitLab, or shows you a workflow YAML and asks how it would work in GitLab. Even if the user does not explicitly say "migrate", if they are exploring GitLab CI/CD coming from a GitHub Actions background, use this skill.
---

# GitHub Actions to GitLab CI/CD Migration

This skill translates GitHub Actions workflows to GitLab CI/CD pipelines. It handles single-file conversions, maps marketplace actions to GitLab equivalents, and produces a migration report categorizing what translates cleanly, what needs approximation, and what requires human review. Use this skill when a user shows you a GitHub workflow and asks how it would work in GitLab, or when they are evaluating GitLab CI/CD coming from a GitHub Actions background.

## When to use this skill

Use this skill whenever the user mentions GitHub Actions and GitLab CI/CD in the same context. Concrete triggers include:

- User shows you a `.github/workflows/*.yml` file and asks "how would this work in GitLab?"
- User asks to migrate, convert, or translate a GitHub Actions workflow
- User compares GitHub Actions syntax to GitLab CI/CD syntax
- User asks about GitLab equivalents for specific GitHub Actions (e.g., "what replaces actions/checkout?")
- User is evaluating GitLab CI/CD as an alternative to GitHub Actions
- User mentions both platforms in a single question, even if they don't explicitly say "migrate"
- User pastes a GitHub workflow and asks for the GitLab equivalent
- User asks how to set up a CI/CD pipeline in GitLab after using GitHub Actions

Even if the user does not explicitly say "migrate" or "convert", if they are exploring GitLab CI/CD coming from a GitHub Actions background, use this skill.

## What this skill does well

- **Real CI/CD workflows**: build, test, deploy, lint, release workflows translate cleanly with high confidence
- **Single-file translations**: one `.github/workflows/*.yml` to one `.gitlab-ci.yml`
- **Marketplace action mapping**: top 50 GitHub Actions have curated GitLab equivalents
- **Caching and artifacts**: native GitLab features map directly from GitHub Actions equivalents
- **Matrix builds**: GitHub's `matrix:` translates to GitLab's `parallel:matrix:` with cleaner syntax
- **Conditional execution**: `if:` conditions translate to `rules:if:` with semantic preservation
- **Migration reporting**: every source line categorized as Translated, Approximated, Needs Review, or Lost
- **Docker-based workflows**: docker/build-push-action and related actions have clear GitLab equivalents
- **Secrets and variables**: GitHub secrets map to GitLab CI/CD variables with clear setup instructions

## Known limitations

- **Repo automation workflows**: GitHub Actions like `actions/stale`, `actions/first-interaction`, and `actions/labeler` have no GitLab CI/CD equivalent because they respond to issue/MR/comment events. GitLab CI/CD runs only on git events (push, tag, MR, schedule, manual, API). For these workflows, recommend `gitlab-triage` on a schedule or webhooks + external service.
- **Composite actions**: not supported in v1. Composite actions (`.github/actions/*/action.yml`) require manual translation to `extends:` patterns or `include:` snippets.
- **Reusable workflows with inputs/outputs**: GitHub's `inputs:` and `outputs:` in reusable workflows have no direct GitLab equivalent. Recommend `include:` with variable substitution or child pipelines.
- **Permissions**: GitHub's `permissions:` keyword has no per-job equivalent in GitLab. Workaround: configure at project level (CI/CD token access, project access tokens stored as masked variables).
- **GitHub Enterprise specifics**: this skill targets github.com. GitHub Enterprise Server may have different API endpoints or features.
- **Workflow dispatch inputs**: GitHub's `workflow_dispatch.inputs` translates to GitLab's `spec:inputs` (pipeline-level). The translation requires three pieces: `spec:inputs` for the typed input schema, `workflow:rules:` to gate the pipeline to manual/API triggers only, and a default value on every input (auto-triggered pipelines cannot prompt for inputs and will fail without defaults). See `references/syntax-mapping.md` for a full before/after example.
- **Step outputs**: GitHub's `steps.*.outputs` have no direct GitLab equivalent. Workaround: use artifacts or environment files.

## High-level workflow

When invoked, follow this sequence:

### 1. Read the source workflow

Read the user's `.github/workflows/*.yml` file. If they paste it inline, work from the paste. If they reference a file path, read it from their repository. Confirm you have the complete workflow before proceeding. Note the workflow name, triggers, and overall structure.

### 2. Classify the workflow

Determine which category the workflow falls into:

- **Real CI/CD workflow** (build, test, deploy, lint, release, publish): high-confidence translation path. Use the references to translate keyword by keyword. These workflows typically have `jobs:` that run `script:` commands and produce artifacts. Examples: Node.js test suite, Docker image build and push, Python package release.
- **Repo automation workflow** (stale, greetings, labeler, dependabot-style, issue triage): limited GitLab CI/CD support. Document the constraint upfront. Suggest alternatives: `gitlab-triage` on a schedule, webhooks + external service, or project access tokens.

### 3. Translate

Walk through the workflow keyword by keyword. For each line:

1. Look up the keyword in `references/syntax-mapping.md` (e.g., `env:`, `jobs:`, `steps:`, `uses:`, `if:`, `runs-on:`, `needs:`)
2. For `uses:` lines, look up the action in `references/marketplace-actions.md`
3. If the lookup fails, apply the "Pattern: actions not in this list" decision tree from marketplace-actions.md
4. Note items that need human review (e.g., complex `if:` conditions, custom actions, permissions)
5. Preserve the logical flow and intent of the original workflow
6. Maintain the same job dependencies and execution order

### 4. Produce a migration report

The migration report is the trust mechanism. Categorize every line of the source workflow as:

- **Translated**: clean 1:1 mapping, no semantic loss
- **Approximated**: GitLab equivalent exists but with caveats (note the caveat)
- **Needs review**: no equivalent or significant semantic differences (the user must decide)
- **Lost**: GitHub feature with no GitLab analogue (e.g., step `name:` labels, `defaults:run:` shell selection)

Format the report as a markdown table the user can copy into their migration tracking spreadsheet. Include columns: Source Line, Category, GitLab Equivalent, Notes.

### 4.5. Validate the translated `.gitlab-ci.yml`

Before presenting the final translation, run the bundled validator. It catches mechanical errors before they reach the user: unknown keywords, malformed YAML, invalid `include:` / `extends:` / `rules:` expressions.

Invoke it via `bash` from the skill bundle directory:

```bash
bash <skill-dir>/scripts/validate.sh /path/to/translated.gitlab-ci.yml
```

The script prefers `glci lint` (offline, no token, deeper parse that resolves `include:`, `extends:`, `!reference`, `default:`, and `workflow:`) and falls back to `glab ci lint`. The validator does not catch semantic or runtime errors; those remain the user's responsibility, surfaced via the migration report.

Read the script's stdout, not just its exit code: it announces which backend ran. If you see "falling back to glab ci lint" and the user's remote is on GitHub, that fallback will likely produce a 404. Verify `glci` is genuinely absent with `ls -l /usr/local/bin/glci /opt/homebrew/bin/glci ~/bin/glci ~/.local/bin/glci 2>/dev/null` before treating the glab failure as authoritative.

If anything goes wrong (script not found, permission denied, neither backend installed, no shell access, no network, validation fails, or the `glab` backend needs a project), see [`references/validator.md`](./references/validator.md) for the full handling guide.

### 5. Suggest GitLab improvements (the upgrade moment)

After producing the basic translation, opportunistically suggest GitLab features that would improve on the GitHub original. Only suggest these when they actually improve the user's specific workflow:

- **DAG with `needs:`**: eliminate stage barriers for faster pipelines (jobs run as soon as dependencies complete, not waiting for stage boundaries)
- **`parallel:matrix:`**: cleaner matrix syntax than GitHub's matrix, with better variable scoping
- **`rules:changes:`**: monorepo path-based job filtering (run jobs only when specific files change)
- **Child pipelines**: break very large workflows into smaller, reusable pipelines with `trigger:`
- **`include:`**: share config across projects and workflows
- **GitLab CI templates**: Auto DevOps, Security Scanning, Terraform, SAST, DAST, etc. (no GitHub Actions equivalent)
- **Resource groups**: serialize job execution to prevent concurrent deployments to the same environment
- **Protected environments**: gate deployments by approval rules and environment-specific variables

## Reference files

Load these references when translating:

- 📋 [`references/syntax-mapping.md`](./references/syntax-mapping.md) — Load when translating workflow keywords (jobs, stages, steps, rules, variables, artifacts, caching, matrix, if conditions, runs-on, needs, etc.)
- 🧩 [`references/marketplace-actions.md`](./references/marketplace-actions.md) — Load when you encounter a `uses:` line referencing a marketplace action (actions/checkout, actions/setup-node, docker/build-push-action, codecov/codecov-action, etc.)
- 🛠️ [`references/validator.md`](./references/validator.md) — Load when running `scripts/validate.sh` produces an error, when neither backend is installed, when the agent has no shell or network access, or when you need to handle a validation failure.

## Self-check rubric

Before producing the final translation, verify:

- [ ] Did I remove `actions/checkout` (no equivalent, GitLab clones automatically)?
- [ ] Did I translate `runs-on:` to either an `image:` choice or `tags:` for runner selection?
- [ ] Did I translate `env:` and secrets to `variables:` (with masked variables noted as a manual setup step)?
- [ ] Did I handle every `uses:` line (looked up in marketplace-actions.md or applied the fallback pattern)?
- [ ] Did I translate `if:` conditions to `rules:if:` (NOT a string substitution; semantics differ)?
- [ ] Did I handle artifacts (`upload-artifact` -> `artifacts:`, `download-artifact` -> automatic between stages or `needs:artifacts:`)?
- [ ] Did I document `permissions:` items as manual project-level setup (no per-job equivalent)?
- [ ] Did I translate `concurrency:` to `resource_group:` and `interruptible:` where applicable?
- [ ] Did I produce a migration report categorizing every source item?
- [ ] Did I flag items that need human review explicitly?
- [ ] Did I suggest GitLab-only features that would improve the workflow (only where they apply)?

## Output format for the user

When the translation is complete, structure your response as:

1. **Brief overview** (1-2 sentences: workflow name, complexity, overall verdict)
2. **The translated `.gitlab-ci.yml`** in a fenced code block, ready to copy
3. **Migration report** (markdown table with source line, category, GitLab equivalent, notes)
4. **Manual setup steps** (numbered list, e.g., "Configure CI/CD variable X", "Set schedule in CI/CD > Schedules")
5. **Suggested GitLab improvements** (bulleted, optional, only if applicable)
6. **Honest caveats** (any "needs review" items called out plainly)

## Common translation patterns

### Environment variables and secrets

GitHub:
```yaml
env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}
jobs:
  build:
    env:
      BUILD_ENV: production
    steps:
      - run: echo $REGISTRY
```

GitLab:
```yaml
variables:
  REGISTRY: ghcr.io
  IMAGE_NAME: $CI_PROJECT_PATH
build:
  variables:
    BUILD_ENV: production
  script:
    - echo $REGISTRY
```

Key differences: GitLab uses `$VAR_NAME` (not `${{ }}`), and secrets are CI/CD variables (configured in UI, not in YAML). Masked variables are set in Project > Settings > CI/CD > Variables.

### Conditional execution

GitHub:
```yaml
jobs:
  deploy:
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
```

GitLab:
```yaml
deploy:
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
  image: ubuntu:latest
```

Key differences: `if:` becomes `rules:if:`, and the condition syntax changes from `${{ }}` expressions to shell-like expressions. Common variables: `$CI_COMMIT_BRANCH`, `$CI_COMMIT_TAG`, `$CI_PIPELINE_SOURCE`. When translating GitHub context expressions (`${{ github.X }}`, `${{ runner.X }}`, `${{ inputs.X }}`, etc.), look up the GitLab predefined variable equivalent and substitute it directly. Use the mapping table in `references/syntax-mapping.md` (`### github.* context expressions` section) for common expressions. For expressions not in the table, consult the canonical reference at https://docs.gitlab.com/ci/variables/predefined_variables/ and pick the closest match. Flag mappings with no GitLab equivalent (e.g., `github.run_attempt`, `runner.arch`) as Needs Review in the migration report.

### Matrix builds

GitHub:
```yaml
jobs:
  test:
    strategy:
      matrix:
        node-version: [14, 16, 18]
        os: [ubuntu-latest, macos-latest]
```

GitLab:
```yaml
test:
  parallel:
    matrix:
      - NODE_VERSION: ["14", "16", "18"]
        OS: ["ubuntu-latest", "macos-latest"]
```

Key differences: GitLab's `parallel:matrix:` is cleaner and uses environment variables directly. Variables are automatically available in the job.

### Artifacts and caching

GitHub:
```yaml
- uses: actions/upload-artifact@v3
  with:
    name: build-output
    path: dist/
- uses: actions/cache@v3
  with:
    path: node_modules
    key: ${{ runner.os }}-npm-${{ hashFiles('**/package-lock.json') }}
```

GitLab:
```yaml
artifacts:
  name: build-output
  paths:
    - dist/
cache:
  key: $CI_COMMIT_REF_SLUG
  paths:
    - node_modules/
```

Key differences: GitLab artifacts are automatic between stages. Cache keys use GitLab variables. No explicit download step needed.

### Docker image building

GitHub:
```yaml
- uses: docker/build-push-action@v4
  with:
    push: true
    tags: ghcr.io/user/image:latest
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
```

GitLab:
```yaml
script:
  - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
  - docker build -t $CI_REGISTRY_IMAGE:latest .
  - docker push $CI_REGISTRY_IMAGE:latest
```

Key differences: GitLab provides built-in registry variables (`$CI_REGISTRY`, `$CI_REGISTRY_IMAGE`, `$CI_REGISTRY_USER`, `$CI_REGISTRY_PASSWORD`). Use `services: docker:dind` for Docker-in-Docker.

## Style guide

- Imperative, direct, factual
- No em dashes (use commas, periods, colons instead)
- Tone neutral, not GitLab-evangelical
- Acknowledge GitHub Actions as a legitimate prior choice
- When something cannot translate, say so plainly and suggest alternatives
- Avoid "MUST" and "NEVER" in all caps; use imperative form instead

## Critical facts (do not get wrong)

- `actions/checkout` has NO equivalent. GitLab clones the repository automatically.
- GitLab CI/CD pipelines run on git events only (push, tag, MR, schedule, manual, API). They do NOT run on issue/MR/comment/discussion events.
- `permissions:` has no per-job equivalent in GitLab. Use project-level CI/CD token access settings or project access tokens stored as masked variables.
- Schedules are configured in the GitLab UI under CI/CD > Schedules, not in YAML. Use `rules:if: $CI_PIPELINE_SOURCE == "schedule"` to gate jobs.
- Secrets in GitLab are CI/CD variables (masked, protected). Access syntax is `$VAR_NAME`, not `${{ secrets.NAME }}`.
- `if:` syntax differs significantly. NOT a direct string substitution. GitHub uses `${{ }}` expressions; GitLab uses shell-like expressions in `rules:if:`.
- For workflows that handle issues/MRs/comments (stale, greetings, labelers): there is no GitLab CI/CD equivalent. Recommend `gitlab-triage` on a schedule, or webhooks + an external service.
- `needs:` in GitLab has stricter rules around stages than GitHub's `needs:`. A job can only depend on jobs in earlier stages unless you use DAG mode.
- `services:` in GitLab is equivalent to GitHub's `services:` for running sidecar containers (databases, registries, etc.).
- `artifacts:` in GitLab is equivalent to GitHub's `upload-artifact` and `download-artifact` combined.
- `before_script:` and `after_script:` are GitLab equivalents for setup and cleanup steps.
- `tags:` in GitLab selects runners by label, equivalent to GitHub's `runs-on:` for self-hosted runners.

## Workflow structure comparison

### GitHub Actions structure

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 18
      - run: npm install
      - run: npm test
```

### GitLab CI/CD equivalent

```yaml
stages:
  - test

test:
  stage: test
  image: node:18
  script:
    - npm install
    - npm test
```

Key structural differences: GitLab uses `stages:` to group jobs, not `jobs:` with triggers. Triggers are implicit (every push runs the pipeline). Use `rules:` to filter which jobs run.

## Troubleshooting common issues

**Issue: "My workflow uses `actions/checkout` but I don't see it in the GitLab version"**
Solution: GitLab clones the repository automatically. Remove the checkout step entirely. The working directory is already populated with the repository contents.

**Issue: "My `if:` condition doesn't work in GitLab"**
Solution: GitHub's `if:` uses `${{ }}` expression syntax. GitLab's `rules:if:` uses shell-like expressions. Common conversions:
- `github.ref == 'refs/heads/main'` -> `$CI_COMMIT_BRANCH == "main"`
- `github.event_name == 'pull_request'` -> `$CI_PIPELINE_SOURCE == "merge_request_event"`
- `contains(github.event.head_commit.message, '[skip ci]')` -> `$CI_COMMIT_MESSAGE =~ /\[skip ci\]/`

**Issue: "My secrets aren't available in GitLab"**
Solution: GitLab CI/CD variables are configured in the UI (Project > Settings > CI/CD > Variables), not in YAML. Create masked variables for sensitive data. Access them with `$VAR_NAME` in scripts.

**Issue: "My matrix build isn't working"**
Solution: GitLab's `parallel:matrix:` syntax differs from GitHub's. Use environment variable names (uppercase) and quote all values. Variables are automatically available in the job.

**Issue: "I need to run a job only on schedule"**
Solution: Use `rules:if: $CI_PIPELINE_SOURCE == "schedule"`. Configure the schedule in Project > CI/CD > Schedules.

## Next steps after translation

1. **Validate the YAML**: Use `gitlab-ci-lint` or the GitLab UI (CI/CD > Pipelines > CI/CD Lint) to check syntax.
2. **Set up CI/CD variables**: Configure secrets and environment variables in Project > Settings > CI/CD > Variables.
3. **Configure runners**: Ensure you have runners available (shared runners or self-hosted). Check Project > Settings > CI/CD > Runners.
4. **Test the pipeline**: Push a commit to trigger the pipeline. Monitor the pipeline in CI/CD > Pipelines.
5. **Iterate**: Adjust the `.gitlab-ci.yml` based on pipeline results. Common issues: missing dependencies, incorrect image, permission errors.

## When to ask for help

- If a GitHub Actions marketplace action has no clear GitLab equivalent, check the "Pattern: actions not in this list" section of `references/marketplace-actions.md`.
- If a workflow uses composite actions or reusable workflows, manual translation may be needed. Consider `include:` or child pipelines.
- If a workflow responds to issue/MR/comment events, recommend `gitlab-triage` or webhooks + external service.
- If you're unsure about a translation, flag it as "Needs review" in the migration report and let the user decide.
