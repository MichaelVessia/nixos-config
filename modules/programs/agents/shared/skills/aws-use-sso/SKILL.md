---
name: aws-use-sso
description: >
  Manage AWS SSO credentials during agent sessions. Detects expired or missing
  AWS credentials, runs aws-use-sso to authenticate via SSO, and sources
  credentials into the shell. Use when AWS commands fail due to credentials,
  when the user asks to log in to AWS, or when setting up aws-use-sso for the
  first time.
compatibility: Requires nix or devbox. Designed for Claude Code (or similar products).
metadata:
  author: jordangarrison
  version: "1.1.0"
allowed-tools: Bash(nix:*) Bash(devbox:*) Bash(aws:*) Bash(source:*) Read
---

# aws-use-sso

A lightweight tool that automates AWS SSO login and exports credentials to environment variables. It bridges the gap between AWS SSO authentication and tools that need `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_SESSION_TOKEN` in the environment.

## Environment Detection

Before doing anything, run the detection script to understand the user's environment:

```bash
bash <skill-dir>/scripts/detect-env.sh
```

Parse the key=value output. The keys are:

| Key | Values | Meaning |
|-----|--------|---------|
| `AWS_USE_SSO_INSTALLED` | `true`/`false` | Whether `aws-use-sso` is on PATH |
| `AWS_USE_SSO_PATH` | path or empty | Location of the binary |
| `NIX_AVAILABLE` | `true`/`false` | Whether `nix` is available |
| `DEVBOX_AVAILABLE` | `true`/`false` | Whether `devbox` is available |
| `DEVBOX_PROJECT_LOCAL` | `true`/`false` | Whether `devbox.json` exists in current directory |
| `NIXOS` | `true`/`false` | Whether running on NixOS |
| `AWS_CONFIG_EXISTS` | `true`/`false` | Whether `~/.aws/config` exists |
| `SSO_PROFILES` | comma-separated | SSO-enabled profile names |
| `SSO_PROFILE_COUNT` | number | Count of SSO profiles |
| `CREDS_FILE_EXISTS` | `true`/`false` | Whether `~/.aws/sso-creds.sh` exists |
| `AWS_PROFILE_SET` | `true`/`false` | Whether `AWS_PROFILE` env var is set |
| `AWS_PROFILE_VALUE` | string or empty | Value of `AWS_PROFILE` |

## Installation

If `AWS_USE_SSO_INSTALLED=false`, guide the user through installation based on their environment.

### Nix Available (`NIX_AVAILABLE=true`)

Offer these options:

1. **Add as flake input** (for Nix projects with a `flake.nix`):
   ```nix
   inputs.aws-use-sso.url = "github:jordangarrison/aws-use-sso";
   ```

2. **Install to profile** (persistent, user-wide):
   ```bash
   nix profile install github:jordangarrison/aws-use-sso
   ```

3. **One-off run** (no install needed):
   ```bash
   nix run github:jordangarrison/aws-use-sso -- <profile-name>
   ```

### Devbox Available (`DEVBOX_AVAILABLE=true`)

- **Project-local** (if `DEVBOX_PROJECT_LOCAL=true` or user has a `devbox.json`):
  ```bash
  devbox add github:jordangarrison/aws-use-sso
  ```

- **Global** (system-wide via devbox):
  ```bash
  devbox global add github:jordangarrison/aws-use-sso
  ```

### Neither Available

- If `NIXOS=true`: Nix should already be installed. Suggest running `nix-channel --update` or checking their PATH.
- If `NIXOS=false`: Guide the user to install Nix via the [Determinate Systems installer](https://github.com/DeterminateSystems/nix-installer):
  ```bash
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
  ```
  After Nix is installed, return to the Nix installation options above.

## Proactive Login Flow

Use this flow when the user explicitly asks to log in to AWS, set up credentials, or authenticate.

### Step 1: Detect Profiles

Run the detection script. Check `SSO_PROFILES` and `SSO_PROFILE_COUNT`:

- **0 profiles**: Tell the user they need to configure an SSO profile in `~/.aws/config`. Link them to [AWS SSO configuration docs](https://docs.aws.amazon.com/cli/latest/userguide/sso-configure-profile-token.html).
- **1 profile**: Auto-select it.
- **Multiple profiles**: If `AWS_PROFILE_SET=true`, suggest `AWS_PROFILE_VALUE` as the default. Present all profiles and let the user choose.

### Step 2: Run aws-use-sso

```bash
aws-use-sso <profile-name>
```

This will:
1. Open a browser for SSO authentication (user must complete this)
2. Export credentials to `~/.aws/sso-creds.sh`

### Step 3: Offer Sourcing Choice

Present the user with two options:

**Option A — Agent sources credentials:**
The agent runs `source ~/.aws/sso-creds.sh` in its shell. Credentials are available for subsequent commands in this session.

**Option B — User sources manually:**
Tell the user to run the following in their terminal, then resume the conversation:
```bash
source ~/.aws/sso-creds.sh
```
This is useful when the user wants credentials in their own shell (e.g., for IDE integration or other tools outside the agent session).

## Mid-Task Auto-Fix Flow

Use this flow when an AWS command fails during normal work. Do NOT prompt the user — fix silently and retry.

### Error Patterns

Watch for these patterns in command output:

- `ExpiredTokenException`
- `ExpiredToken`
- `The SSO session associated with this profile has expired`
- `Unable to locate credentials`
- `AuthFailure`
- `InvalidClientTokenId`
- `The security token included in the request is expired`
- `UnauthorizedAccess`
- `NoCredentialProviders`
- `SSOTokenProviderFailure`

### Recovery Steps

1. **Identify the profile**: Use `AWS_PROFILE_VALUE` if set, otherwise parse `SSO_PROFILES` from the detection script. If only one profile exists, use it. If multiple, use the one most recently used or ask the user.

2. **Run aws-use-sso**:
   ```bash
   aws-use-sso <profile-name>
   ```

3. **Source credentials**:
   ```bash
   source ~/.aws/sso-creds.sh
   ```

4. **Retry the failed command**.

5. **If sourcing fails** (e.g., agent shell context doesn't support it), fall back to asking the user:
   > Your AWS credentials have expired. I've re-authenticated, but I can't source the credentials in my current shell. Please run `source ~/.aws/sso-creds.sh` in your terminal, then let me know when you're ready to continue.

## Troubleshooting

### SSO session requires browser authentication
The `aws sso login` command opens a browser window. If running in a headless environment, the user must complete authentication on a machine with a browser. The CLI will display a URL and code to enter.

### No SSO profiles configured
The user needs to add SSO profile configuration to `~/.aws/config`. Example:

```ini
[profile my-sso-profile]
sso_session = my-sso
sso_account_id = 123456789012
sso_role_name = MyRole
region = us-east-1

[sso-session my-sso]
sso_start_url = https://my-sso-portal.awsapps.com/start
sso_region = us-east-1
```

### aws-use-sso not found after installation
If installed via `nix profile install`, the user may need to restart their shell or run `hash -r` to refresh the PATH cache. If using devbox, ensure they are inside a `devbox shell` or have run `eval "$(devbox global shellenv)"`.

### Credentials expire quickly
AWS SSO session tokens have a limited lifetime (typically 1-12 hours depending on the IdP configuration). Re-run `aws-use-sso <profile>` when they expire. The mid-task auto-fix flow handles this automatically.
