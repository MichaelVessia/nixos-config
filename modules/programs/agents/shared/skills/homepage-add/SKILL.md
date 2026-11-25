---
name: homepage-add
description: Add a service to the personal Homepage dashboard on hearth.
allowed-tools: Bash, Read, Edit, Write, AskUserQuestion
---

# Add a Homepage service

1. Identify the service by name. Search the personal Executor for its integration and use available tools to confirm its identity and health. Use [homelab](../homelab/SKILL.md) to find its port and URL.
2. Read `/opt/homelab/homepage/config/services.yaml` on `hearth` with `ssh root@hearth`. Use the existing sections and check for a duplicate entry.
3. Add the service to the best matching section. Use Utilities if there is no more specific section. Include a name, an icon, an `href`, and a short description. Prefer the configured HTTPS URL. For a widget, follow the existing secret reference pattern.
4. Within the section, put cards with widgets first. Insert a new widget card after the last widget card. Append a card without a widget at the end. This keeps cards of the same height together.
5. Check the YAML and verify the entry on Homepage. Refresh the page to see the change.
