---
name: pstack-sync
description: Update the pinned t3-pstack source in nixos-config and check local policy compatibility.
---

# Update t3-pstack

1. Read `modules/programs/agents/pstack/README.md` in `~/nixos-config`.
2. Read upstream release changes. Update the same source commit in `flake.nix`
   and `hosts/flomac/flake.nix`, then update both lock files.
3. Check that the local panel patch applies. Run the model policy check in the
   README. Preserve session model inheritance, Executor discovery, task completion,
   and native T3 PR watches.
4. Follow repository checks and commit rules. Activate only when asked.
5. After activation, run `t3-pstack doctor` on each target host. Report failures
   by host. Do not use npm to update outside the Nix pin.
