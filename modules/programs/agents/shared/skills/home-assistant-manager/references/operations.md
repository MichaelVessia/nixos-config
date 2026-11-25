# Home Assistant operations

## Access

Use the Home Assistant tools in the personal Executor for supported operations. For other REST calls, `hass-cli` reads `HASS_SERVER` and `HASS_TOKEN`. Use `hass-cli state get sensor.entity_name` to inspect an entity.

Run the HA CLI in a login shell so it has `SUPERVISOR_TOKEN`.

```bash
ssh homeassistant "bash -l -c 'ha core check'"
ssh homeassistant "bash -l -c 'ha core logs'"
```

## Deploy via Git

1. Make the configuration change in the local repository. For an authorized Git deployment, commit and push the selected files.
2. Pull the change with `ssh homeassistant "cd /config && git pull"`.
3. Run `ha core check` on the guest. Fix any errors before reload or restart.
4. Reload the affected configuration if the integration supports reload. Restart when the change requires it.
5. Check the affected entities, traces, and logs.

For authorized test deployments, copy only the changed files with `scp` to the corresponding location under `homeassistant:/config/`. Check the configuration and verify the change before the final Git deployment.

## Select reload or restart

| Change | Action |
| --- | --- |
| Automations, scripts, scenes, template entities, or groups | Call `automation.reload`, `script.reload`, `scene.reload`, `template.reload`, or `group.reload` as applicable. |
| Themes | Call `frontend.reload_themes`. |
| New integration, core configuration, or platform that requires restart | Run `ssh homeassistant "bash -l -c 'ha core restart'"`. |

Use `hass-cli service call <service>` when Executor does not provide the reload action. An automation trigger executes real actions. Use it only if the user authorized those effects.
