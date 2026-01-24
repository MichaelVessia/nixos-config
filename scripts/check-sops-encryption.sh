#!/usr/bin/env bash
# Check that secrets files are sops-encrypted before committing

set -euo pipefail

if [[ $# -eq 0 ]]; then
    exit 0
fi

errors=0
for file in "$@"; do
    if [[ ! -f "$file" ]]; then
        continue
    fi

    # sops-encrypted files have a "sops:" metadata key
    if ! grep -q '^sops:' "$file"; then
        echo "ERROR: $file is NOT encrypted!"
        echo "       Use 'nix run nixpkgs#sops -- $file' to encrypt it."
        errors=$((errors + 1))
    fi
done

if [[ $errors -gt 0 ]]; then
    echo ""
    echo "Commit blocked: $errors unencrypted secret file(s) found."
    exit 1
fi

exit 0
