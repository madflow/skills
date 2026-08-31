# Syntax Mapping: GitHub Actions to GitLab CI/CD

> Comprehensive keyword and concept mapping for translating `.github/workflows/*.yml` to `.gitlab-ci.yml`.

## At a glance

GitHub Actions and GitLab CI/CD share the same goals (automate build, test, deploy) but use different
vocabulary and mental models. GitHub Actions organizes work as workflows containing jobs containing steps.
GitLab CI/CD organizes work as pipelines containing jobs grouped into stages. The table below is the
official GitLab keyword mapping; the sections that follow expand each row with examples and gotchas.

| GitHub Actions | GitLab CI/CD | Notes |
|---|---|---|
| `env` | `variables` | Global or per-job variable definitions |
| `name` (workflow) | `workflow:name` | Sets the pipeline name displayed in the UI |
| `jobs` | `stages` | Grouping mechanism for parallel/sequential work |
| `on` | Not applicable | GitLab is git-integrated; triggers are implicit; use `rules:` for conditions |
| `run` | Not applicable | Use the `script:` array, one entry per command |
| `runs-on` | `tags` | Runner selection by label |
| `steps` | `script` | Ordered list of commands within a job |
| `uses` | `include` | Only true for reusable workflows; marketplace actions need different treatment |

Source: https://docs.gitlab.com/ci/migration/github_actions/

---

## Triggers (`on:` -> `workflow:` and `rules:`)

`on:` declares which events cause a GitHub Actions workflow to run (push, pull_request, schedule, etc.).
GitLab pipelines run automatically on every push; use `workflow:rules:` to restrict at the pipeline level
and `rules:` at the job level.

**GitHub example:**

```yaml
on:
  push:
    branches:
      - main
      - 'release/**'
  pull_request:
    branches:
      - main
  schedule:
    - cron: '0 6 * * 1'
```

**GitLab equivalent:**

```yaml
workflow:
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
    - if: $CI_COMMIT_BRANCH =~ /^release\//
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_PIPELINE_SOURCE == "schedule"

stages:
  - build
  - test
```

**Notes:**

- GitLab has no `on:` equivalent at the file level. Every push triggers a pipeline unless `workflow:rules:` suppresses it.
- `pull_request` maps to `$CI_PIPELINE_SOURCE == "merge_request_event"` (requires merge request pipelines to be enabled).
- Scheduled pipelines are configured in the GitLab UI under CI/CD > Schedules, not in the YAML. The `schedule` source is available as `$CI_PIPELINE_SOURCE == "schedule"` for conditional logic.

Source: https://docs.gitlab.com/ci/yaml/workflow/

---

### Workflow name (`name:` -> `workflow:name:`)

GitHub:
```yaml
name: CI
```

GitLab:
```yaml
workflow:
  name: CI
```

Sets the pipeline name displayed in the GitLab Pipelines UI. Supports CI/CD variable interpolation, for example `name: 'Pipeline for $CI_COMMIT_REF_NAME'`. Available since GitLab 15.8.

See: https://docs.gitlab.com/ci/yaml/#workflowname

---

## Jobs and stages (`jobs:` -> `stages:` + jobs)

`jobs:` in GitHub Actions is a map of named jobs that run in parallel by default; `needs:` creates
dependencies. GitLab separates the concept: `stages:` defines the execution order, and jobs declare
which stage they belong to.

**GitHub example:**

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: make build

  test:
    runs-on: ubuntu-latest
    needs: build
    steps:
      - run: make test

  deploy:
    runs-on: ubuntu-latest
    needs: test
    steps:
      - run: make deploy
```

**GitLab equivalent:**

```yaml
stages:
  - build
  - test
  - deploy

build:
  stage: build
  script:
    - make build

test:
  stage: test
  script:
    - make test

deploy:
  stage: deploy
  script:
    - make deploy
```

**Notes:**

- Jobs in the same stage run in parallel. Jobs in later stages wait for all jobs in earlier stages to succeed.
- `needs:` exists in GitLab too and enables a DAG (directed acyclic graph) that bypasses stage ordering. It is more powerful than GitHub's `needs:` because it can reference jobs in earlier or same stages.
- Job names in GitLab are top-level YAML keys (not nested under `jobs:`).

Source: https://docs.gitlab.com/ci/yaml/#stages

---

## Steps and scripts (`steps:` -> `script:`)

`steps:` is an ordered list of actions and shell commands within a GitHub Actions job. GitLab's `script:`
is a YAML array of shell commands that runs in sequence.

**GitHub example:**

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install dependencies
        run: npm ci
      - name: Build
        run: npm run build
      - name: Test
        run: npm test
```

**GitLab equivalent:**

```yaml
build:
  image: node:20
  script:
    - npm ci
    - npm run build
    - npm test
```

**Notes:**

- `actions/checkout@v4` has no GitLab equivalent and should be removed. GitLab clones the repository automatically before every job.
- `before_script:` runs before `script:` and is useful for setup commands (install tools, authenticate). It can be defined globally (applies to all jobs) or per-job.
- `after_script:` runs after `script:` even if the job fails, similar to a `finally` block.

---

## Runners (`runs-on:` -> `tags:`)

`runs-on:` selects the runner environment by label (e.g., `ubuntu-latest`, `windows-latest`, `self-hosted`).
GitLab uses `tags:` to match jobs to runners that have been registered with those tags.

**GitHub example:**

```yaml
jobs:
  linux-job:
    runs-on: ubuntu-latest
    steps:
      - run: echo "Running on Linux"

  windows-job:
    runs-on: windows-latest
    steps:
      - run: echo "Running on Windows"
```

**GitLab equivalent:**

```yaml
linux-job:
  tags:
    - linux
  script:
    - echo "Running on Linux"

windows-job:
  tags:
    - windows
  script:
    - echo "Running on Windows"
```

**Notes:**

- GitLab.com shared runners have tags like `saas-linux-small-amd64`. Check your project's available runners under Settings > CI/CD > Runners.
- If no `tags:` are specified, the job runs on any available runner. This is fine for GitLab.com but may cause issues on self-managed instances with specialized runners.
- `runs-on: self-hosted` with additional labels (e.g., `runs-on: [self-hosted, gpu]`) maps to multiple tags in GitLab: `tags: [self-hosted, gpu]`.

Source: https://docs.gitlab.com/ci/runners/configure_runners/#control-jobs-that-a-runner-can-run

---

## Matrix builds (`matrix:` -> `parallel:matrix:`)

`strategy.matrix:` in GitHub Actions generates multiple job instances with different variable combinations.
GitLab's `parallel:matrix:` provides the same capability with different syntax.

**GitHub example:**

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        os: [ubuntu, windows]
        node: [18, 20, 22]
    steps:
      - run: echo "Testing on ${{ matrix.os }} with Node ${{ matrix.node }}"
```

**GitLab equivalent:**

```yaml
test:
  image: node:${NODE_VERSION}
  parallel:
    matrix:
      - OS: [ubuntu, windows]
        NODE_VERSION: [18, 20, 22]
  script:
    - echo "Testing on $OS with Node $NODE_VERSION"
```

**Notes:**

- GitHub matrix variables are accessed as `${{ matrix.key }}`; GitLab matrix variables are injected as regular CI/CD variables accessed as `$KEY`.
- GitLab generates `N x M` jobs (one per combination), same as GitHub. Job names are suffixed with the variable values.
- `strategy.fail-fast: false` (continue running other matrix instances when one fails) is the **default behaviour** in GitLab. GitLab's `parallel:matrix` instances are independent: one failing does not cancel the others. No translation needed; remove the keyword and the workflow behaves the same.
- GitLab does not have a built-in equivalent for `strategy.fail-fast: true` (cancel other matrix instances when one fails). If users rely on this behaviour, document it as a "needs review" item in the migration report.

Source: https://docs.gitlab.com/ci/yaml/#parallelmatrix

---

## Variables and secrets (`env:` and secrets -> `variables:`)

`env:` defines environment variables at the workflow, job, or step level. GitHub secrets are accessed
as `${{ secrets.NAME }}`. In GitLab, both plain variables and secrets are CI/CD variables, defined in
the YAML or in the project/group settings UI.

**GitHub example:**

```yaml
env:
  GREETING: Hello

jobs:
  greet:
    runs-on: ubuntu-latest
    env:
      NAME: World
    steps:
      - run: echo "$GREETING $NAME"
      - run: echo "Token is ${{ secrets.API_TOKEN }}"
        env:
          API_TOKEN: ${{ secrets.API_TOKEN }}
```

**GitLab equivalent:**

```yaml
variables:
  GREETING: Hello

greet:
  variables:
    NAME: World
  script:
    - echo "$GREETING $NAME"
    - echo "Token is $API_TOKEN"
```

**Notes:**

- Secrets in GitLab are CI/CD variables marked as "Masked" and optionally "Protected". Define them in Settings > CI/CD > Variables. They are accessed as `$VAR_NAME`, not `${{ secrets.NAME }}`.
- Protected variables are only available in pipelines for protected branches or tags.
- Step-level `env:` (scoped to a single `run:` step) has no direct equivalent. Use job-level `variables:` or inline shell assignment (`export FOO=bar && command`).

Source: https://docs.gitlab.com/ci/variables/

---

## Containers and services (`container:` -> `image:`, `services:` -> `services:`)

`container:` specifies the Docker image a GitHub Actions job runs inside. `services:` defines sidecar
containers (databases, caches). GitLab uses `image:` and `services:` with nearly identical semantics.

**GitHub example:**

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    container: node:20-alpine
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: secret
        ports:
          - 5432:5432
    steps:
      - run: npm test
```

**GitLab equivalent:**

```yaml
test:
  image: node:20-alpine
  services:
    - name: postgres:15
      alias: postgres
      variables:
        POSTGRES_PASSWORD: secret
  script:
    - npm test
```

**Notes:**

- Service hostnames in GitLab default to the image name with slashes and colons replaced by double underscores. Use `alias:` to set a predictable hostname (e.g., `alias: postgres` makes the service reachable at `postgres`).
- Port mapping (`ports:`) is not needed in GitLab. Services are accessible on their default ports via the alias hostname.
- The `default:` keyword can set a global `image:` for all jobs, equivalent to setting `container:` at the workflow level.

Source: https://docs.gitlab.com/ci/services/

---

## Artifacts (upload/download -> `artifacts:`)

`actions/upload-artifact` and `actions/download-artifact` pass files between jobs in GitHub Actions.
GitLab's `artifacts:` keyword declares files to persist, and they are automatically available to
downstream jobs.

**GitHub example:**

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: make build
      - uses: actions/upload-artifact@v4
        with:
          name: binaries
          path: dist/

  test:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: binaries
          path: dist/
      - run: ./dist/app --test
```

**GitLab equivalent:**

```yaml
stages:
  - build
  - test

build:
  stage: build
  script:
    - make build
  artifacts:
    paths:
      - dist/
    expire_in: 1 hour

test:
  stage: test
  script:
    - ./dist/app --test
```

**Notes:**

- GitLab artifacts from earlier stages are automatically downloaded by later-stage jobs. No explicit download step is needed.
- Use `artifacts:expire_in:` to control storage duration. Default retention is set at the instance level.
- `artifacts:reports:` is a GitLab-specific feature for structured data (JUnit XML, coverage, SAST results) that integrates with merge request UI.

Source: https://docs.gitlab.com/ci/yaml/#artifacts

---

## Caching (`actions/cache` -> `cache:`)

`actions/cache` saves and restores directories keyed by a cache key, typically used for dependency
directories. GitLab's `cache:` keyword provides the same functionality natively.

**GitHub example:**

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/cache@v4
        with:
          path: ~/.npm
          key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
          restore-keys: |
            ${{ runner.os }}-node-
      - run: npm ci
```

**GitLab equivalent:**

```yaml
build:
  script:
    - npm ci
  cache:
    key:
      files:
        - package-lock.json
    paths:
      - .npm/
  variables:
    npm_config_cache: .npm
```

**Notes:**

- `cache:key:files:` computes a hash of the listed files, equivalent to `hashFiles()` in GitHub Actions.
- GitLab cache is per-runner by default. For shared cache across runners, configure a distributed cache backend (S3 or GCS) in the runner configuration.
- Unlike artifacts, cache is not guaranteed to be available. Jobs must handle a cold cache gracefully.

Source: https://docs.gitlab.com/ci/caching/

---

## Conditional execution (`if:` -> `rules:`)

`if:` in GitHub Actions uses `${{ }}` template expressions to conditionally run a job or step.
GitLab's `rules:` keyword evaluates conditions using shell-style expressions with predefined CI/CD variables.

**GitHub example:**

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    steps:
      - run: make deploy

  notify:
    runs-on: ubuntu-latest
    if: failure()
    steps:
      - run: ./notify-slack.sh
```

**GitLab equivalent:**

```yaml
deploy:
  script:
    - make deploy
  rules:
    - if: $CI_COMMIT_BRANCH == "main" && $CI_PIPELINE_SOURCE == "push"

notify:
  script:
    - ./notify-slack.sh
  rules:
    - when: on_failure
```

**Notes:**

- GitHub `${{ github.ref }}` maps to `$CI_COMMIT_REF_NAME` or `$CI_COMMIT_BRANCH`. See the full predefined variable list at https://docs.gitlab.com/ci/variables/predefined_variables/.
- `rules:` is evaluated top-to-bottom; the first matching rule wins. This differs from GitHub's single `if:` expression.
- `rules:changes:` triggers a job only when specific files change, a capability with no direct GitHub Actions equivalent (GitHub requires path filters on `on:push:paths:`).

Source: https://docs.gitlab.com/ci/jobs/job_rules/

---

## Reusable configuration (`uses:` for workflows -> `include:`)

`uses:` in GitHub Actions serves two purposes: referencing marketplace actions and calling reusable
workflows. Only the reusable workflow case maps to GitLab's `include:`. Marketplace actions are a
separate concern (see `references/marketplace-actions.md`).

**GitHub example (reusable workflow call):**

```yaml
jobs:
  call-workflow:
    uses: ./.github/workflows/shared-build.yml
    with:
      environment: staging
    secrets: inherit
```

**GitLab equivalent:**

```yaml
include:
  - local: .gitlab/ci/shared-build.yml

# Or include from another project:
include:
  - project: mygroup/shared-ci
    file: /templates/build.yml
    ref: main
```

**Notes:**

- `uses: actions/checkout@v4` (marketplace action) does NOT map to `include:`. Remove it; GitLab clones automatically.
- `uses: owner/repo/.github/workflows/file.yml@ref` (cross-repo reusable workflow) maps to `include: project:` with `ref:`.
- GitLab `include:` merges configuration at parse time. It does not support passing inputs the way GitHub reusable workflows do. Use `variables:` to parameterize included jobs.

Source: https://docs.gitlab.com/ci/yaml/includes/

---

## Job control (`timeout-minutes:`, `continue-on-error:`, `concurrency:`, `permissions:`)

GitHub Actions provides several job-level control keywords that have GitLab equivalents, though the
semantics differ in important ways.

**GitHub example:**

```yaml
jobs:
  flaky-test:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    continue-on-error: true
    concurrency:
      group: deploy-${{ github.ref }}
      cancel-in-progress: true
    permissions:
      contents: read
      packages: write
    steps:
      - run: make test
```

**GitLab equivalent:**

```yaml
flaky-test:
  script:
    - make test
  timeout: 10 minutes
  allow_failure: true
  resource_group: deploy-$CI_COMMIT_REF_SLUG
  interruptible: true
```

**Notes:**

- `permissions:` has no job-level equivalent in GitLab. Token permissions are configured at the project level under Settings > CI/CD > Token Access. Document this as a manual step in your migration report.
- `concurrency.cancel-in-progress: true` maps to `interruptible: true`. GitLab cancels interruptible jobs when a newer pipeline starts for the same ref.
- `resource_group:` serializes jobs with the same group key, equivalent to GitHub's `concurrency.group:` without cancellation.

Source: https://docs.gitlab.com/ci/yaml/#resource_group

---

## Outputs (`outputs:` -> dotenv pattern)

GitHub Actions jobs can declare `outputs:` that downstream jobs read via `${{ needs.job.outputs.key }}`.
GitLab does not have a native job output mechanism, but the dotenv artifact pattern achieves the same result.

**GitHub example:**

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      version: ${{ steps.get-version.outputs.version }}
    steps:
      - id: get-version
        run: echo "version=$(cat VERSION)" >> $GITHUB_OUTPUT

  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - run: echo "Deploying version ${{ needs.build.outputs.version }}"
```

**GitLab equivalent:**

```yaml
stages:
  - build
  - deploy

build:
  stage: build
  script:
    - echo "VERSION=$(cat VERSION)" > build.env
  artifacts:
    reports:
      dotenv: build.env

deploy:
  stage: deploy
  script:
    - echo "Deploying version $VERSION"
  needs:
    - job: build
      artifacts: true
```

**Notes:**

- The `artifacts:reports:dotenv:` file is sourced as environment variables in downstream jobs that declare `needs: [job: build, artifacts: true]`.
- Variable names in the dotenv file must be valid shell identifiers (no hyphens).
- This pattern only works across jobs with an explicit `needs:` relationship, not across all downstream jobs automatically.

Source: https://docs.gitlab.com/ci/yaml/#artifactsreportsdotenv

---

## Things that don't translate cleanly

Some GitHub Actions concepts have no direct GitLab CI/CD equivalent. These require manual decisions
during migration.

### Composite actions (`uses: ./.github/actions/my-action`)

Composite actions are reusable step sequences defined in a local directory. GitLab has no equivalent
abstraction. Options:

- Extract the steps into a shell script and call it from `script:`.
- Use `extends:` to share job configuration (not step-level reuse, but covers many cases).
- Use `include:` with a local template file for job-level reuse.

### `actions/setup-*` actions

`actions/setup-node`, `actions/setup-python`, `actions/setup-java`, etc. configure a language runtime
on the runner. In GitLab, use `image:` to select a pre-built Docker image with the runtime already
installed. This is cleaner and more reproducible.

```yaml
# GitHub
- uses: actions/setup-node@v4
  with:
    node-version: '20'

# GitLab: just set the image
image: node:20
```

### `github.*` and other context expressions

GitHub Actions exposes context objects (`github.*`, `runner.*`, `env.*`, `vars.*`, `secrets.*`, `steps.*`, `needs.*`, `inputs.*`, `matrix.*`, `job.*`, `strategy.*`). When translating, treat them in two categories:

**Category A: GitHub data exposed as predefined variables.** GitLab provides predefined variables for most `github.*` and some `runner.*` expressions. Use the mapping below.

**Category B: User-defined or runtime data.** `env.*`, `vars.*`, `secrets.*`, `inputs.*`, `matrix.*`, and `steps/needs.*.outputs.*` are not predefined variables. They translate to plain CI/CD variables (`$NAME`), masked variables, or dotenv artifact patterns depending on the source.

#### `github.*` context

| GitHub expression | GitLab equivalent | Notes |
|---|---|---|
| `github.sha` | `$CI_COMMIT_SHA` | |
| `github.ref` | `$CI_COMMIT_REF_NAME` | GitHub keeps `refs/heads/` prefix; GitLab strips it for branches but keeps it for tags |
| `github.ref_name` | `$CI_COMMIT_REF_NAME` | Branch or tag name without prefix |
| `github.repository` | `$CI_PROJECT_PATH` | |
| `github.repository_owner` | `$CI_PROJECT_NAMESPACE` | |
| `github.actor` | `$GITLAB_USER_LOGIN` | |
| `github.triggering_actor` | `$GITLAB_USER_LOGIN` | GitLab does not distinguish triggering actor from actor |
| `github.event_name` | `$CI_PIPELINE_SOURCE` | Values differ: `pull_request` -> `merge_request_event`, `schedule` -> `schedule`, `workflow_dispatch` -> `web` or `api` |
| `github.workflow` | `$CI_PIPELINE_NAME` | Requires GitLab 16.3+ and `workflow:name:` set |
| `github.run_id` | `$CI_PIPELINE_ID` | |
| `github.run_number` | `$CI_PIPELINE_IID` | Project-scoped incrementing number |
| `github.run_attempt` | (no equivalent) | Flag as Needs Review |
| `github.job` | `$CI_JOB_NAME` | |
| `github.head_ref` | `$CI_MERGE_REQUEST_SOURCE_BRANCH_NAME` | MR pipelines only |
| `github.base_ref` | `$CI_MERGE_REQUEST_TARGET_BRANCH_NAME` | MR pipelines only |
| `github.workspace` | `$CI_PROJECT_DIR` | |

#### `runner.*` context

| GitHub expression | GitLab equivalent | Notes |
|---|---|---|
| `runner.os` | (no predefined variable) | Use `image:` selection or set a custom variable based on the runner tag |
| `runner.arch` | (no predefined variable) | Flag as Needs Review |
| `runner.temp` | (no predefined variable) | Use `/tmp` or a path under `$CI_PROJECT_DIR` |
| `runner.workspace` | `$CI_PROJECT_DIR` | Closest equivalent |

#### `env.*`, `vars.*`, `secrets.*` (user-defined data)

| GitHub expression | GitLab equivalent | Notes |
|---|---|---|
| `env.<name>` | `$NAME` | Plain CI/CD variable defined in `variables:` |
| `vars.<name>` | `$NAME` | GitHub's non-secret repo/org variable; same mechanism as `env` in GitLab |
| `secrets.<name>` | `$NAME` | Masked CI/CD variable defined in Project > Settings > CI/CD > Variables |

#### `inputs.*` context

| GitHub expression | GitLab equivalent | Notes |
|---|---|---|
| `inputs.<name>` | `$[[ inputs.<name> ]]` (`spec:inputs`) or `$NAME` (variable form) | See the `workflow_dispatch` inputs section for the full pattern |

#### `steps.*` and `needs.*` context

| GitHub expression | GitLab equivalent | Notes |
|---|---|---|
| `steps.<id>.outputs.<name>` | `$NAME` (via dotenv artifact) | Requires `artifacts:reports:dotenv` and downstream `needs:` relationship |
| `steps.<id>.outcome` | (no equivalent) | Flag as Needs Review |
| `steps.<id>.conclusion` | (no equivalent) | Flag as Needs Review |
| `needs.<job>.outputs.<name>` | `$NAME` (via dotenv artifact) | Same pattern as `steps.outputs` |
| `needs.<job>.result` | (no equivalent) | Flag as Needs Review |

#### `job.*` and `strategy.*` and `matrix.*` context

| GitHub expression | GitLab equivalent | Notes |
|---|---|---|
| `job.status` | `$CI_JOB_STATUS` | Available only in `after_script:` |
| `job.container.id` | (no equivalent) | Flag as Needs Review |
| `matrix.<name>` | `$NAME` | Injected automatically by `parallel:matrix:` |
| `strategy.fail-fast` | (no keyword equivalent for `true`) | GitLab default behavior is `false` |
| `strategy.job-index` | `$CI_NODE_INDEX` | |
| `strategy.job-total` | `$CI_NODE_TOTAL` | |

**Agent instruction:** When translating a GitHub workflow, scan for `${{ ... }}` expressions and substitute the GitLab equivalent from the tables above. For expressions not listed, consult https://docs.gitlab.com/ci/variables/predefined_variables/ and pick the closest match. If no GitLab equivalent exists, leave the expression replaced with a clearly marked placeholder (e.g., `# TODO: no GitLab equivalent for github.run_attempt`) and flag it as Needs Review in the migration report.

Full predefined variable reference: https://docs.gitlab.com/ci/variables/predefined_variables/

### `workflow_dispatch` inputs

GitHub's `on: workflow_dispatch` combines two things: a manual-only trigger and an optional typed input schema. GitLab separates these concerns: `workflow:rules:` controls when the pipeline runs, and `spec:inputs` declares the input schema.

**Critical behavioral difference:** GitHub `workflow_dispatch` workflows run only on manual trigger. GitLab pipelines run on every push by default. A naive translation breaks immediately if any input lacks a default, because auto-triggered pipelines cannot prompt for values. The full translation pattern requires three pieces:

1. `spec:inputs` at the top of `.gitlab-ci.yml` for the typed input schema (pipeline-level, GitLab 17.0+)
2. `workflow:rules:` to restrict the pipeline to manual and API triggers only
3. A `default:` on every input so that if the pipeline IS triggered automatically (e.g., by a schedule or API call without explicit inputs), it does not fail

**GitHub example:**

```yaml
on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        default: 'staging'
        type: choice
        options:
          - staging
          - production
      dry_run:
        description: 'Run without making changes'
        required: false
        default: true
        type: boolean
      version:
        description: 'Version to deploy'
        required: true
        type: string

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - run: echo "Deploying ${{ inputs.version }} to ${{ inputs.environment }}"
```

**GitLab equivalent:**

```yaml
spec:
  inputs:
    environment:
      description: 'Target environment'
      type: string
      default: 'staging'
      options:
        - staging
        - production
    dry_run:
      description: 'Run without making changes'
      type: boolean
      default: true
    version:
      description: 'Version to deploy'
      type: string
      default: ''  # Required in GitHub, but GitLab needs a default for auto-triggered safety

---

workflow:
  rules:
    - if: $CI_PIPELINE_SOURCE == "web"       # "Run pipeline" button
    - if: $CI_PIPELINE_SOURCE == "api"       # Pipeline API / trigger token
    - if: $CI_PIPELINE_SOURCE == "trigger"   # Trigger API

deploy:
  stage: deploy
  script:
    - echo "Deploying $[[ inputs.version ]] to $[[ inputs.environment ]]"
```

**Input type mapping:**

| GitHub `workflow_dispatch` type | GitLab `spec:inputs` type | Notes |
|---|---|---|
| `string` | `type: string` | Direct mapping. Use `regex:` for validation. |
| `boolean` | `type: boolean` | Direct mapping. |
| `number` | `type: number` | Direct mapping. |
| `choice` | `type: string` + `options:` | GitLab uses `options:` on a string input instead of a separate `choice` type. |
| `environment` | `type: string` + `options:` | No native environment type. List environment names in `options:` manually. |

**Notes:**

- `spec:inputs` uses `$[[ inputs.name ]]` interpolation syntax (double brackets), not `${{ }}`. This is resolved at pipeline creation time, before any job runs.
- `required: true` in GitHub has no direct equivalent. In GitLab, omitting `default:` makes the input mandatory, but mandatory inputs break auto-triggered pipelines. Prefer setting a sensible default and validating in the script.
- The `workflow:rules:` block above restricts the pipeline to manual/API sources. Without this, every push creates a pipeline that uses the default input values, which is rarely the intended behavior for a `workflow_dispatch` translation.
- For GitLab versions before 17.0, use top-level `variables:` with `description:`, `value:`, and `options:` as a simpler alternative. This renders a form in the "Run pipeline" UI but provides no type enforcement (all values are strings).

Source: https://docs.gitlab.com/ci/inputs/

### `actions/github-script`

`actions/github-script` runs JavaScript with access to the GitHub API client. The GitLab equivalent
is using `glab` CLI or the GitLab REST/GraphQL API directly in a `script:` block with `$CI_JOB_TOKEN`
for authentication.

### Environment protection rules

GitHub environments (`environment:`) support required reviewers and wait timers before deployment.
GitLab has equivalent functionality via protected environments (Settings > CI/CD > Environments),
but the configuration is in the UI, not the YAML. The `environment:` keyword in GitLab YAML only
declares which environment a job deploys to.

### `permissions:` (GITHUB_TOKEN scopes)

GitHub's `permissions:` restricts the automatically-provided `GITHUB_TOKEN`. GitLab's `CI_JOB_TOKEN`
has a fixed scope controlled at the project level. There is no per-job permission narrowing in GitLab CI/CD YAML.

### Reusable workflow inputs and outputs

GitHub reusable workflows support typed `inputs:` and `outputs:` with schema validation. GitLab `include:`
merges YAML at parse time with no input/output contract. Parameterize included jobs via `variables:` and
document the expected variable names in comments.

---

*Source: https://docs.gitlab.com/ci/migration/github_actions/*
