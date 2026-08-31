# Marketplace Actions Mapping

This reference maps popular GitHub Actions marketplace actions to their GitLab CI/CD equivalents. Use this guide when migrating workflows from GitHub Actions to GitLab CI/CD to quickly identify the right approach for each action your workflow depends on.

## How to use this reference

1. Find your action in the list below, organized by tier (frequency of use).
2. Read the "What it does" section to confirm it matches your use case.
3. Follow the "Before/After" example to translate the step.
4. Check "Notes" for any gotchas or special handling required.
5. For actions not listed, see the "Pattern: actions not in this list" section.

## At a glance (table)

| Action | Tier | GitLab Equivalent | Notes |
|--------|------|-------------------|-------|
| actions/checkout | 1 | Remove (auto-cloned) | GitLab clones repo automatically |
| actions/setup-node | 1 | `image: node:<version>` | Use Docker image or asdf |
| actions/setup-python | 1 | `image: python:<version>` | Use Docker image or asdf |
| actions/setup-java | 1 | `image: eclipse-temurin:<version>` | Use Docker image or asdf |
| actions/setup-go | 1 | `image: golang:<version>` | Use Docker image or asdf |
| actions/setup-ruby | 1 | `image: ruby:<version>` | Use Docker image or asdf |
| actions/cache | 1 | `cache:` keyword | Native GitLab feature |
| actions/upload-artifact | 1 | `artifacts:` keyword | Native GitLab feature |
| actions/download-artifact | 1 | `needs:artifacts:` or `artifacts:` | Automatic between stages |
| docker/build-push-action | 1 | `docker build` + `docker push` | Use `services: docker:dind` |
| docker/login-action | 1 | `docker login` in script | Use CI/CD variables |
| docker/setup-buildx-action | 1 | `docker buildx` in script | Use `services: docker:dind` |
| docker/setup-qemu-action | 1 | `docker run --rm --privileged tonistiigi/binfmt` | Multi-arch builds |
| actions/github-script | 1 | GitLab API calls or glab | Needs review, no direct equivalent |
| actions/setup-dotnet | 2 | `image: mcr.microsoft.com/dotnet/sdk:<version>` | Use Docker image |
| shivammathur/setup-php | 2 | `image: php:<version>` | Use Docker image or custom |
| aws-actions/configure-aws-credentials | 2 | CI/CD variables or OIDC | Use GitLab OIDC to AWS |
| google-github-actions/auth | 2 | CI/CD variables or OIDC | Use GitLab OIDC to GCP |
| azure/login | 2 | CI/CD variables or OIDC | Use GitLab OIDC to Azure |
| hashicorp/setup-terraform | 2 | `include: 'Terraform/Base.latest.gitlab-ci.yml'` | GitLab template |
| codecov/codecov-action | 2 | `codecov-cli` in script | Use codecov CLI directly |
| softprops/action-gh-release | 2 | `glab release create` or API | Use glab or REST API |
| peter-evans/create-pull-request | 2 | `glab mr create` or API | Needs review, use glab |
| JamesIves/github-pages-deploy-action | 2 | GitLab Pages native | Use `pages:` job |
| pnpm/action-setup | 2 | `image: node:<version>` + pnpm script | Install pnpm in script |
| oven-sh/setup-bun | 2 | `image: oven/bun:<version>` | Use Docker image |
| gradle/gradle-build-action | 2 | `image: gradle:<version>` | Use Docker image |
| cypress-io/github-action | 2 | `image: cypress/browsers:<version>` | Use Docker image |
| tj-actions/changed-files | 3 | `git diff` in script | Use git commands directly |
| dorny/paths-filter | 3 | `rules:changes:` keyword | Native GitLab feature |
| nick-invision/retry | 3 | `retry:` keyword | Native GitLab feature |
| pre-commit/action | 3 | `pre-commit run` in script | Run pre-commit in script |
| slackapi/slack-github-action | 3 | Slack webhook or API | Use curl or Slack SDK |

## Tier 1: Used in 80%+ of workflows

### actions/checkout

**What it does**: Clones the repository into the runner's workspace.

**GitLab equivalent**: Remove this step entirely. GitLab CI/CD automatically clones the repository before running each job.

**Before** (GitHub Actions):
```yaml
- uses: actions/checkout@v4
  with:
    fetch-depth: 0
```

**After** (GitLab CI/CD):
```yaml
# No step needed. GitLab clones automatically.
# To fetch full history, use:
variables:
  GIT_DEPTH: 0
```

**Notes**:
- GitLab clones the repository automatically for every job. There is no equivalent action to add.
- Use `GIT_DEPTH: 0` to fetch full history instead of shallow clones.
- Use `GIT_SUBMODULE_STRATEGY: recursive` to clone submodules.

### actions/setup-node

**What it does**: Installs Node.js and optionally configures npm/yarn/pnpm caching.

**GitLab equivalent**: Use a Node.js Docker image, optionally combined with `cache:` for package manager caching.

**Before** (GitHub Actions):
```yaml
- uses: actions/setup-node@v4
  with:
    node-version: '20'
    cache: 'npm'
```

**After** (GitLab CI/CD):
```yaml
image: node:20

cache:
  paths:
    - node_modules/
```

**Notes**:
- Docker images are the preferred approach in GitLab CI/CD. Use `node:<version>` for LTS versions or `node:latest` for the latest version.
- For caching, use the `cache:` keyword with paths like `node_modules/` or `.npm/`.
- If you need multiple Node.js versions in one pipeline, use `image:` at the job level instead of globally.

### actions/setup-python

**What it does**: Installs Python and optionally configures pip caching.

**GitLab equivalent**: Use a Python Docker image, optionally combined with `cache:` for pip caching.

**Before** (GitHub Actions):
```yaml
- uses: actions/setup-python@v4
  with:
    python-version: '3.11'
    cache: 'pip'
```

**After** (GitLab CI/CD):
```yaml
image: python:3.11

cache:
  paths:
    - .cache/pip/
```

**Notes**:
- Use `python:<version>` Docker images. For specific patch versions, use `python:3.11.5`.
- Configure pip to use a cache directory with `pip install --cache-dir .cache/pip`.
- For Poetry or other package managers, adjust the cache path accordingly.

### actions/setup-java

**What it does**: Installs Java and optionally configures Maven/Gradle caching.

**GitLab equivalent**: Use an Eclipse Temurin or OpenJDK Docker image, optionally combined with `cache:`.

**Before** (GitHub Actions):
```yaml
- uses: actions/setup-java@v3
  with:
    java-version: '17'
    distribution: 'temurin'
    cache: 'maven'
```

**After** (GitLab CI/CD):
```yaml
image: eclipse-temurin:17

cache:
  paths:
    - .m2/repository/
```

**Notes**:
- Use `eclipse-temurin:<version>` for the official Eclipse Temurin images.
- For Maven, cache `.m2/repository/`. For Gradle, cache `.gradle/`.
- Ensure your build tool is configured to use the cache directory.

### actions/setup-go

**What it does**: Installs Go and optionally configures module caching.

**GitLab equivalent**: Use a Go Docker image, optionally combined with `cache:`.

**Before** (GitHub Actions):
```yaml
- uses: actions/setup-go@v4
  with:
    go-version: '1.21'
    cache: true
```

**After** (GitLab CI/CD):
```yaml
image: golang:1.21

cache:
  paths:
    - .cache/go-build/
    - go/pkg/mod/
```

**Notes**:
- Use `golang:<version>` Docker images.
- Go modules are cached automatically in `$GOPATH/pkg/mod/`. Set `GOMODCACHE` to customize the location.
- Build cache is stored in `$GOCACHE`, typically `.cache/go-build/`.

### actions/setup-ruby

**What it does**: Installs Ruby and optionally configures Bundler caching.

**GitLab equivalent**: Use a Ruby Docker image, optionally combined with `cache:`.

**Before** (GitHub Actions):
```yaml
- uses: actions/setup-ruby@v1
  with:
    ruby-version: '3.2'
    bundler-cache: true
```

**After** (GitLab CI/CD):
```yaml
image: ruby:3.2

cache:
  paths:
    - vendor/bundle/

before_script:
  - bundle install --jobs $(nproc) --retry 3 --path vendor/bundle
```

**Notes**:
- Use `ruby:<version>` Docker images.
- Bundler caches gems in `vendor/bundle/` by default when using `bundle install --path vendor/bundle`.
- The `ruby/setup-ruby` action is similar; use the same Docker image approach.

### actions/cache

**What it does**: Caches dependencies or build artifacts between workflow runs.

**GitLab equivalent**: Use the native `cache:` keyword in your job definition.

**Before** (GitHub Actions):
```yaml
- uses: actions/cache@v3
  with:
    path: ~/.npm
    key: ${{ runner.os }}-npm-${{ hashFiles('**/package-lock.json') }}
    restore-keys: |
      ${{ runner.os }}-npm-
```

**After** (GitLab CI/CD):
```yaml
cache:
  key:
    files:
      - package-lock.json
  paths:
    - .npm/
```

**Notes**:
- GitLab's `cache:` keyword is simpler and more integrated. Keys are automatically generated from file hashes.
- Use `cache:key:files:` to generate cache keys based on file contents.
- Cache is shared across all jobs in a pipeline by default. Use `cache:key:` to create separate caches.

### actions/upload-artifact

**What it does**: Uploads build artifacts or test results for later download or retention.

**GitLab equivalent**: Use the native `artifacts:` keyword in your job definition.

**Before** (GitHub Actions):
```yaml
- uses: actions/upload-artifact@v3
  with:
    name: test-results
    path: test-results/
    retention-days: 30
```

**After** (GitLab CI/CD):
```yaml
artifacts:
  name: test-results
  paths:
    - test-results/
  expire_in: 30 days
```

**Notes**:
- GitLab's `artifacts:` keyword is native and automatically available to downstream jobs.
- Use `expire_in:` to set retention time (e.g., `30 days`, `1 week`).
- Artifacts are automatically passed to jobs that depend on this job via `needs:`.

### actions/download-artifact

**What it does**: Downloads artifacts uploaded by a previous job in the workflow.

**GitLab equivalent**: Use `needs:artifacts:` or rely on automatic artifact passing between stages.

**Before** (GitHub Actions):
```yaml
- uses: actions/download-artifact@v3
  with:
    name: test-results
    path: ./test-results/
```

**After** (GitLab CI/CD):
```yaml
# Option 1: Automatic (if job is in previous stage)
# Artifacts are automatically available

# Option 2: Explicit dependency
needs:
  - job: build-job
    artifacts: true
```

**Notes**:
- In GitLab CI/CD, artifacts from jobs in previous stages are automatically available.
- Use `needs:artifacts:` only when you need artifacts from a job outside the normal stage dependency.
- Artifacts are extracted to the job's working directory automatically.

### docker/build-push-action

**What it does**: Builds a Docker image and pushes it to a registry.

**GitLab equivalent**: Use `docker build` and `docker push` commands in a script, with `services: docker:dind`.

**Before** (GitHub Actions):
```yaml
- uses: docker/build-push-action@v5
  with:
    context: .
    push: true
    tags: myregistry.azurecr.io/myimage:latest
    username: ${{ secrets.REGISTRY_USERNAME }}
    password: ${{ secrets.REGISTRY_PASSWORD }}
```

**After** (GitLab CI/CD):
```yaml
image: docker:latest
services:
  - docker:dind

script:
  - docker login -u $REGISTRY_USERNAME -p $REGISTRY_PASSWORD myregistry.azurecr.io
  - docker build -t myregistry.azurecr.io/myimage:latest .
  - docker push myregistry.azurecr.io/myimage:latest
```

**Notes**:
- Use `services: docker:dind` to enable Docker-in-Docker for building images.
- Credentials should be stored as CI/CD variables (e.g., `REGISTRY_USERNAME`, `REGISTRY_PASSWORD`).
- For advanced builds, consider using GitLab's `Docker.latest.gitlab-ci.yml` template.

### docker/login-action

**What it does**: Authenticates with a Docker registry.

**GitLab equivalent**: Use `docker login` command in a script with CI/CD variables.

**Before** (GitHub Actions):
```yaml
- uses: docker/login-action@v2
  with:
    registry: myregistry.azurecr.io
    username: ${{ secrets.REGISTRY_USERNAME }}
    password: ${{ secrets.REGISTRY_PASSWORD }}
```

**After** (GitLab CI/CD):
```yaml
script:
  - docker login -u $REGISTRY_USERNAME -p $REGISTRY_PASSWORD myregistry.azurecr.io
```

**Notes**:
- Store registry credentials as CI/CD variables (masked for security).
- For Docker Hub, omit the registry URL or use `docker.io`.
- For AWS ECR, use `aws ecr get-login-password` instead.

### docker/setup-buildx-action

**What it does**: Sets up Docker Buildx for advanced multi-platform builds.

**GitLab equivalent**: Use `docker buildx` commands in a script with `services: docker:dind`.

**Before** (GitHub Actions):
```yaml
- uses: docker/setup-buildx-action@v2
```

**After** (GitLab CI/CD):
```yaml
image: docker:latest
services:
  - docker:dind

script:
  - docker run --rm --privileged docker/binfmt:latest
  - docker buildx create --use
  - docker buildx build --platform linux/amd64,linux/arm64 -t myimage:latest .
```

**Notes**:
- Buildx is included in recent Docker images. Enable it with `docker buildx create --use`.
- For multi-platform builds, use `docker run --rm --privileged docker/binfmt:latest` to register additional architectures.

### docker/setup-qemu-action

**What it does**: Sets up QEMU for multi-architecture Docker builds.

**GitLab equivalent**: Run `docker run --rm --privileged tonistiigi/binfmt` to register additional architectures.

**Before** (GitHub Actions):
```yaml
- uses: docker/setup-qemu-action@v2
  with:
    platforms: linux/amd64,linux/arm64
```

**After** (GitLab CI/CD):
```yaml
image: docker:latest
services:
  - docker:dind

script:
  - docker run --rm --privileged tonistiigi/binfmt --install linux/amd64,linux/arm64
  - docker buildx build --platform linux/amd64,linux/arm64 -t myimage:latest .
```

**Notes**:
- QEMU is required for building images for architectures different from the host.
- Use `tonistiigi/binfmt` to register additional architectures.

### actions/github-script

**What it does**: Runs JavaScript code with access to the GitHub API.

**GitLab equivalent**: Use GitLab API calls via `curl` or the `glab` CLI, or use a scripting language like Python or Node.js.

**Before** (GitHub Actions):
```yaml
- uses: actions/github-script@v7
  with:
    script: |
      const issues = await github.rest.issues.listForRepo({
        owner: context.repo.owner,
        repo: context.repo.repo,
      });
      console.log(issues.data);
```

**After** (GitLab CI/CD):
```yaml
image: curlimages/curl:latest

script:
  - curl --header "PRIVATE-TOKEN: $CI_JOB_TOKEN" \
      "https://gitlab.com/api/v4/projects/$CI_PROJECT_ID/issues" \
      | jq .
```

**Notes**:
- There is no direct equivalent to `actions/github-script`. Use the GitLab API directly via `curl` or `glab`.
- Use `$CI_JOB_TOKEN` for authentication within the same GitLab instance.
- For complex logic, use a scripting language like Python or Node.js.
- This translation often requires review to ensure API calls are correct.

## Tier 2: Common (20-80%)

### actions/setup-dotnet

**What it does**: Installs .NET SDK and optionally configures NuGet caching.

**GitLab equivalent**: Use a .NET Docker image, optionally combined with `cache:`.

**Before** (GitHub Actions):
```yaml
- uses: actions/setup-dotnet@v3
  with:
    dotnet-version: '7.0'
```

**After** (GitLab CI/CD):
```yaml
image: mcr.microsoft.com/dotnet/sdk:7.0

cache:
  paths:
    - ~/.nuget/packages/
```

**Notes**:
- Use `mcr.microsoft.com/dotnet/sdk:<version>` for the official Microsoft .NET images.
- NuGet packages are cached in `~/.nuget/packages/` by default.

### shivammathur/setup-php

**What it does**: Installs PHP with extensions and optionally configures Composer caching.

**GitLab equivalent**: Use a PHP Docker image with extensions, optionally combined with `cache:`.

**Before** (GitHub Actions):
```yaml
- uses: shivammathur/setup-php@v2
  with:
    php-version: '8.2'
    extensions: mbstring, intl
    tools: composer:v2
```

**After** (GitLab CI/CD):
```yaml
image: php:8.2

before_script:
  - apt-get update && apt-get install -y libicu-dev
  - docker-php-ext-install mbstring intl
  - curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

cache:
  paths:
    - vendor/
```

**Notes**:
- PHP Docker images require manual extension installation via `docker-php-ext-install`.
- Install system dependencies before PHP extensions.
- Composer is not included by default; install it in `before_script:`.

### aws-actions/configure-aws-credentials

**What it does**: Configures AWS credentials for use in subsequent steps.

**GitLab equivalent**: Set AWS environment variables via CI/CD variables, or use GitLab's native OIDC to AWS.

**Before** (GitHub Actions):
```yaml
- uses: aws-actions/configure-aws-credentials@v2
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-region: us-east-1
```

**After** (GitLab CI/CD):
```yaml
variables:
  AWS_ACCESS_KEY_ID: $AWS_ACCESS_KEY_ID
  AWS_SECRET_ACCESS_KEY: $AWS_SECRET_ACCESS_KEY
  AWS_DEFAULT_REGION: us-east-1

script:
  - aws s3 ls
```

**Notes**:
- Store AWS credentials as CI/CD variables (masked for security).
- For better security, use GitLab's native OIDC to AWS instead of long-lived credentials.
- Set `AWS_DEFAULT_REGION` to specify the region.

### google-github-actions/auth

**What it does**: Authenticates with Google Cloud Platform.

**GitLab equivalent**: Use CI/CD variables or GitLab's native OIDC to GCP.

**Before** (GitHub Actions):
```yaml
- uses: google-github-actions/auth@v1
  with:
    credentials_json: ${{ secrets.GCP_SA_KEY }}
```

**After** (GitLab CI/CD):
```yaml
variables:
  GOOGLE_APPLICATION_CREDENTIALS: /tmp/gcp-key.json

before_script:
  - echo $GCP_SA_KEY | base64 -d > $GOOGLE_APPLICATION_CREDENTIALS

script:
  - gcloud auth activate-service-account --key-file=$GOOGLE_APPLICATION_CREDENTIALS
```

**Notes**:
- Store the GCP service account key as a CI/CD variable (base64-encoded).
- For better security, use GitLab's native OIDC to GCP.
- Decode the key before using it with `gcloud` or other tools.

### azure/login

**What it does**: Authenticates with Microsoft Azure.

**GitLab equivalent**: Use CI/CD variables or GitLab's native OIDC to Azure.

**Before** (GitHub Actions):
```yaml
- uses: azure/login@v1
  with:
    creds: ${{ secrets.AZURE_CREDENTIALS }}
```

**After** (GitLab CI/CD):
```yaml
variables:
  AZURE_SUBSCRIPTION_ID: $AZURE_SUBSCRIPTION_ID
  AZURE_TENANT_ID: $AZURE_TENANT_ID
  AZURE_CLIENT_ID: $AZURE_CLIENT_ID
  AZURE_CLIENT_SECRET: $AZURE_CLIENT_SECRET

before_script:
  - az login --service-principal -u $AZURE_CLIENT_ID -p $AZURE_CLIENT_SECRET --tenant $AZURE_TENANT_ID

script:
  - az vm list
```

**Notes**:
- Store Azure credentials as CI/CD variables (masked for security).
- For better security, use GitLab's native OIDC to Azure.
- Use `az login` with service principal credentials.

### hashicorp/setup-terraform

**What it does**: Installs Terraform and optionally configures caching.

**GitLab equivalent**: Use GitLab's `Terraform/Base.latest.gitlab-ci.yml` template or a Terraform Docker image.

**Before** (GitHub Actions):
```yaml
- uses: hashicorp/setup-terraform@v2
  with:
    terraform_version: 1.5.0
```

**After** (GitLab CI/CD):
```yaml
include:
  - template: Terraform/Base.latest.gitlab-ci.yml

variables:
  TF_VERSION: 1.5.0
```

**Notes**:
- GitLab provides a built-in Terraform template that handles setup and caching.
- Alternatively, use `image: hashicorp/terraform:<version>` for a Docker-based approach.
- The template includes best practices for Terraform in CI/CD.

### codecov/codecov-action

**What it does**: Uploads code coverage reports to Codecov.

**GitLab equivalent**: Use the `codecov-cli` tool directly in a script.

**Before** (GitHub Actions):
```yaml
- uses: codecov/codecov-action@v3
  with:
    files: ./coverage.xml
    token: ${{ secrets.CODECOV_TOKEN }}
```

**After** (GitLab CI/CD):
```yaml
image: python:3.11

script:
  - pip install codecov-cli
  - codecov upload-file --file coverage.xml --token $CODECOV_TOKEN
```

**Notes**:
- Install `codecov-cli` via pip or use a Docker image that includes it.
- Store the Codecov token as a CI/CD variable (masked for security).
- Ensure your test runner generates coverage reports in a format Codecov supports.

### softprops/action-gh-release

**What it does**: Creates a GitHub release with assets.

**GitLab equivalent**: Use `glab release create` or the GitLab REST API.

**Before** (GitHub Actions):
```yaml
- uses: softprops/action-gh-release@v1
  with:
    files: dist/*
    token: ${{ secrets.GITHUB_TOKEN }}
```

**After** (GitLab CI/CD):
```yaml
image: alpine:latest

before_script:
  - apk add --no-cache curl

script:
  - glab release create v1.0.0 --assets dist/*
```

**Notes**:
- Use `glab release create` for GitLab releases.
- For GitHub releases, use the GitHub REST API via `curl`.
- Store authentication tokens as CI/CD variables (masked for security).

### peter-evans/create-pull-request

**What it does**: Creates a pull request (or merge request) with changes.

**GitLab equivalent**: Use `glab mr create` or the GitLab REST API.

**Before** (GitHub Actions):
```yaml
- uses: peter-evans/create-pull-request@v5
  with:
    commit-message: 'Update dependencies'
    title: 'Automated dependency update'
    body: 'This PR updates dependencies.'
```

**After** (GitLab CI/CD):
```yaml
image: alpine:latest

before_script:
  - apk add --no-cache git curl

script:
  - git config user.email "ci@example.com"
  - git config user.name "CI Bot"
  - git checkout -b update-deps
  - git add .
  - git commit -m "Update dependencies"
  - glab mr create --title "Automated dependency update" --description "This MR updates dependencies."
```

**Notes**:
- Use `glab mr create` for GitLab merge requests.
- Configure git user before committing.
- This translation often requires review to ensure the MR is created correctly.

### JamesIves/github-pages-deploy-action

**What it does**: Deploys a static site to GitHub Pages.

**GitLab equivalent**: Use GitLab Pages native feature with the `pages:` job.

**Before** (GitHub Actions):
```yaml
- uses: JamesIves/github-pages-deploy-action@v4
  with:
    folder: build
```

**After** (GitLab CI/CD):
```yaml
pages:
  stage: deploy
  script:
    - mkdir -p public
    - cp -r build/* public/
  artifacts:
    paths:
      - public
  only:
    - master
```

**Notes**:
- GitLab Pages is a native feature. Use the `pages:` job to deploy.
- Artifacts must be in the `public/` directory.
- The `pages:` job automatically deploys to GitLab Pages.

### pnpm/action-setup

**What it does**: Installs pnpm package manager.

**GitLab equivalent**: Install pnpm in a script using npm or curl.

**Before** (GitHub Actions):
```yaml
- uses: pnpm/action-setup@v2
  with:
    version: 8
```

**After** (GitLab CI/CD):
```yaml
image: node:20

before_script:
  - npm install -g pnpm@8
  - pnpm install
```

**Notes**:
- Install pnpm globally via npm: `npm install -g pnpm@<version>`.
- Alternatively, use `curl -fsSL https://get.pnpm.io/install.sh | sh -`.
- Cache pnpm store with `cache:paths: - .pnpm-store/`.

### oven-sh/setup-bun

**What it does**: Installs Bun JavaScript runtime.

**GitLab equivalent**: Use a Bun Docker image.

**Before** (GitHub Actions):
```yaml
- uses: oven-sh/setup-bun@v1
  with:
    bun-version: latest
```

**After** (GitLab CI/CD):
```yaml
image: oven/bun:latest

cache:
  paths:
    - .bun/install/cache/
```

**Notes**:
- Use `oven/bun:<version>` Docker images.
- Bun caches dependencies in `.bun/install/cache/`.

### gradle/gradle-build-action

**What it does**: Installs Gradle and configures caching.

**GitLab equivalent**: Use a Gradle Docker image, optionally combined with `cache:`.

**Before** (GitHub Actions):
```yaml
- uses: gradle/gradle-build-action@v2
  with:
    gradle-version: 8.0
```

**After** (GitLab CI/CD):
```yaml
image: gradle:8.0

cache:
  paths:
    - .gradle/
```

**Notes**:
- Use `gradle:<version>` Docker images.
- Gradle caches in `.gradle/` by default.

### cypress-io/github-action

**What it does**: Installs Cypress and runs end-to-end tests.

**GitLab equivalent**: Use a Cypress Docker image and run tests in a script.

**Before** (GitHub Actions):
```yaml
- uses: cypress-io/github-action@v5
  with:
    browser: chrome
    start: npm start
```

**After** (GitLab CI/CD):
```yaml
image: cypress/browsers:latest

script:
  - npm install
  - npm start &
  - npx cypress run --browser chrome
```

**Notes**:
- Use `cypress/browsers:<version>` Docker images which include Cypress and browsers.
- Start your application before running Cypress tests.
- Use `npx cypress run` to run tests in CI mode.

## Tier 3: Specialized

### tj-actions/changed-files

**What it does**: Detects which files changed in the current commit or pull request.

**GitLab equivalent**: Use `git diff` commands in a script.

**Before** (GitHub Actions):
```yaml
- uses: tj-actions/changed-files@v40
  with:
    files: src/**
```

**After** (GitLab CI/CD):
```yaml
script:
  - git diff --name-only $CI_COMMIT_BEFORE_SHA $CI_COMMIT_SHA | grep "^src/"
```

**Notes**:
- Use `git diff` to detect changed files.
- Use `$CI_COMMIT_BEFORE_SHA` and `$CI_COMMIT_SHA` for commit ranges.

### dorny/paths-filter

**What it does**: Filters jobs based on changed file paths.

**GitLab equivalent**: Use the native `rules:changes:` keyword.

**Before** (GitHub Actions):
```yaml
- uses: dorny/paths-filter@v2
  with:
    filters: |
      backend:
        - 'src/backend/**'
```

**After** (GitLab CI/CD):
```yaml
test-backend:
  script:
    - npm test
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
      changes:
        - src/backend/**
```

**Notes**:
- Use `rules:changes:` to conditionally run jobs based on file changes.
- This is a native GitLab feature and simpler than the GitHub Actions equivalent.

### nick-invision/retry

**What it does**: Retries a step if it fails.

**GitLab equivalent**: Use the native `retry:` keyword.

**Before** (GitHub Actions):
```yaml
- uses: nick-invision/retry@v2
  with:
    timeout_minutes: 10
    max_attempts: 3
    command: npm test
```

**After** (GitLab CI/CD):
```yaml
test:
  script:
    - npm test
  retry:
    max: 3
    when:
      - script_failure
```

**Notes**:
- Use `retry:` to automatically retry failed jobs.
- Specify `max:` for the number of retries and `when:` for the failure type.

### pre-commit/action

**What it does**: Runs pre-commit hooks.

**GitLab equivalent**: Run `pre-commit run` in a script.

**Before** (GitHub Actions):
```yaml
- uses: pre-commit/action@v3
```

**After** (GitLab CI/CD):
```yaml
image: python:3.11

before_script:
  - pip install pre-commit

script:
  - pre-commit run --all-files
```

**Notes**:
- Install `pre-commit` via pip.
- Run `pre-commit run --all-files` to check all files.

### slackapi/slack-github-action

**What it does**: Sends notifications to Slack.

**GitLab equivalent**: Use a Slack webhook or the Slack SDK via curl or a scripting language.

**Before** (GitHub Actions):
```yaml
- uses: slackapi/slack-github-action@v1
  with:
    webhook-url: ${{ secrets.SLACK_WEBHOOK }}
    payload: |
      {
        "text": "Build completed"
      }
```

**After** (GitLab CI/CD):
```yaml
image: curlimages/curl:latest

script:
  - curl -X POST -H 'Content-type: application/json' \
      --data '{"text":"Build completed"}' \
      $SLACK_WEBHOOK_URL
```

**Notes**:
- Use a Slack webhook URL stored as a CI/CD variable.
- Send JSON payloads via `curl` to the webhook.
- For more complex messages, use the Slack SDK in Python or Node.js.

## Pattern: actions not in this list

If an action is not listed above, follow this decision tree:

1. **Does it set up a tool or language?** Use a Docker image instead.
   - Example: `actions/setup-rust` -> `image: rust:latest`

2. **Does it interact with an external service?** Use the service's CLI or API.
   - Example: `aws-actions/s3-cp` -> `aws s3 cp` in a script

3. **Does it perform a simple file operation?** Use shell commands.
   - Example: `actions/upload-release-asset` -> `curl` to upload via API

4. **Does it require complex logic?** Use a scripting language.
   - Example: Custom action with JavaScript -> Python or Node.js script

5. **Is there no clear equivalent?** Flag for review.
   - Document the action, its purpose, and ask for guidance.

For any action not covered, search the GitLab CI/CD documentation for equivalent features or consider using a Docker image that includes the tool.
