---
name: init-homebrew
description: Set up Homebrew releases for a Bun/TypeScript CLI project
allowed-tools: Read, Edit, Write, Bash(git:*), Bash(gh:*), Bash(mkdir:*), Bash(ls:*), Bash(cat:*), Bash(base64:*), Glob, AskUserQuestion
---

## Purpose

Initialize a project for multi-platform releases via GitHub Actions with automatic Homebrew tap updates. Creates release workflow, sets up secrets, and updates READMEs.

## Arguments

`$ARGUMENTS` - Optional flags:
- `--dry-run`: Show what would be created without making changes
- `--skip-readme`: Don't update project README with install instructions

## Prerequisites

- Project must be a git repo with GitHub remote
- Project must use Bun (bun.lock or bun.lockb present)
- Project must have package.json
- User must have `gh` CLI authenticated
- Homebrew tap repo must exist at `MichaelVessia/homebrew-tap`

## Process

### 1. Gather Project Info

```bash
git rev-parse --show-toplevel
git remote get-url origin
```

Extract:
- `PROJECT_NAME`: from package.json `name` field (strip scope like `@foo/`)
- `GITHUB_REPO`: owner/repo from git remote
- `DESCRIPTION`: from package.json `description` or prompt user
- `ENTRYPOINT`: detect main entry (check for `src/main.ts`, `src/index.ts`, `packages/*/src/main.ts`, etc.)

### 2. Ensure Version Field

Check package.json for `version` field. If missing, add `"version": "0.1.0"`.

### 3. Create Release Workflow

Create `.github/workflows/release.yml`:

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

permissions:
  contents: write

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: oven-sh/setup-bun@v2
        with:
          bun-version: latest

      - run: bun install

      - name: Typecheck
        run: bun run typecheck

      - name: Lint
        run: bun run lint

      - name: Test
        run: bun test

      - name: Build all targets
        run: |
          mkdir -p dist
          bun build ${ENTRYPOINT} --compile --target=bun-linux-x64 --outfile dist/${PROJECT_NAME}-linux-x64
          bun build ${ENTRYPOINT} --compile --target=bun-darwin-x64 --outfile dist/${PROJECT_NAME}-darwin-x64
          bun build ${ENTRYPOINT} --compile --target=bun-darwin-arm64 --outfile dist/${PROJECT_NAME}-darwin-arm64

      - name: Create checksums
        run: |
          cd dist
          sha256sum * > checksums.txt

      - name: Release
        uses: softprops/action-gh-release@v2
        with:
          files: dist/*
          generate_release_notes: true

      - name: Update Homebrew tap
        env:
          HOMEBREW_TAP_TOKEN: ${{ secrets.HOMEBREW_TAP_TOKEN }}
        run: |
          VERSION=${GITHUB_REF#refs/tags/v}
          # ... (generate formula and push to tap)
```

### 4. Set Up Secret

Check if `HOMEBREW_TAP_TOKEN` exists:

```bash
gh secret list --repo ${GITHUB_REPO}
```

If not present, prompt user to add it:
```
Secret HOMEBREW_TAP_TOKEN not found.
Run: gh secret set HOMEBREW_TAP_TOKEN --repo ${GITHUB_REPO}
(Paste your GitHub PAT with 'repo' scope)
```

Wait for user confirmation before proceeding.

### 5. Update Homebrew Tap README

Fetch current README from `MichaelVessia/homebrew-tap`, add new formula entry to the table if not present:

```markdown
| [${PROJECT_NAME}](https://github.com/${GITHUB_REPO}) | ${DESCRIPTION} |
```

Use GitHub API to update:
```bash
gh api repos/MichaelVessia/homebrew-tap/contents/README.md --method PUT ...
```

### 6. Update Project README

Unless `--skip-readme`, add/update Installation section with:

```markdown
## Installation

### Homebrew (macOS)

\`\`\`bash
brew tap MichaelVessia/tap
brew install ${PROJECT_NAME}
\`\`\`

### Download Binary

\`\`\`bash
# macOS ARM64 (Apple Silicon)
curl -L https://github.com/${GITHUB_REPO}/releases/latest/download/${PROJECT_NAME}-darwin-arm64 -o ${PROJECT_NAME}
chmod +x ${PROJECT_NAME} && mv ${PROJECT_NAME} /usr/local/bin/

# macOS x64 (Intel)
curl -L https://github.com/${GITHUB_REPO}/releases/latest/download/${PROJECT_NAME}-darwin-x64 -o ${PROJECT_NAME}
chmod +x ${PROJECT_NAME} && mv ${PROJECT_NAME} /usr/local/bin/

# Linux x64
curl -L https://github.com/${GITHUB_REPO}/releases/latest/download/${PROJECT_NAME}-linux-x64 -o ${PROJECT_NAME}
chmod +x ${PROJECT_NAME} && sudo mv ${PROJECT_NAME} /usr/local/bin/
\`\`\`
```

### 7. Commit and Push

```bash
git add package.json .github/workflows/release.yml README.md
git commit -m "feat: add multi-platform packaging with GitHub releases and Homebrew"
git push
```

### 8. Output Summary

```
Homebrew release setup complete!

Created:
  - .github/workflows/release.yml
  - Updated package.json with version field
  - Updated README.md with install instructions
  - Added ${PROJECT_NAME} to homebrew-tap README

Next steps:
  1. Run '/release' to create first release
  2. Install via: brew tap MichaelVessia/tap && brew install ${PROJECT_NAME}
```

## Formula Template

The Homebrew formula generated in the workflow:

```ruby
class ${CLASS_NAME} < Formula
  desc "${DESCRIPTION}"
  homepage "https://github.com/${GITHUB_REPO}"
  version "${VERSION}"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/${GITHUB_REPO}/releases/download/v${VERSION}/${PROJECT_NAME}-darwin-arm64"
      sha256 "${SHA_DARWIN_ARM64}"
    end
    on_intel do
      url "https://github.com/${GITHUB_REPO}/releases/download/v${VERSION}/${PROJECT_NAME}-darwin-x64"
      sha256 "${SHA_DARWIN_X64}"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/${GITHUB_REPO}/releases/download/v${VERSION}/${PROJECT_NAME}-linux-x64"
      sha256 "${SHA_LINUX_X64}"
    end
  end

  def install
    if OS.mac?
      bin.install "${PROJECT_NAME}-darwin-#{Hardware::CPU.arm? ? "arm64" : "x64"}" => "${PROJECT_NAME}"
    else
      bin.install "${PROJECT_NAME}-linux-x64" => "${PROJECT_NAME}"
    end
  end

  test do
    assert_match "${PROJECT_NAME}", shell_output("#{bin}/${PROJECT_NAME} --help")
  end
end
```

## Caveats Detection

If project has specific env vars (detected from `.env.example`, `README.md`, or config files), add a `caveats` block to the formula prompting users to configure them.

## Not Supported

- Non-Bun projects (Cargo, Python, etc.)
- Monorepos with multiple publishable packages
- Private repositories
- Custom tap repositories (hardcoded to MichaelVessia/homebrew-tap)
