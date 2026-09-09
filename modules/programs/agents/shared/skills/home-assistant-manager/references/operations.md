# Home Assistant operations

Examples below apply to authorized deployments. Choose the commands needed for the requested change. A configuration edit alone does not authorize a commit, push, restart, notification, or device action.

## Remote Access Patterns

### Using hass-cli (Local, via REST API)

All `hass-cli` commands use environment variables automatically:

```bash
# List entities
hass-cli state list

# Get specific state
hass-cli state get sensor.entity_name

# Call services
hass-cli service call automation.reload
hass-cli service call automation.trigger --arguments entity_id=automation.name
```

### Using SSH for HA CLI

**Important:** Use `bash -l -c '...'` for `ha` commands (login shell required for SUPERVISOR_TOKEN).

```bash
# Check configuration validity
ssh homeassistant "bash -l -c 'ha core check'"

# Restart Home Assistant
ssh homeassistant "bash -l -c 'ha core restart'"

# View logs
ssh homeassistant "bash -l -c 'ha core logs'"

# Tail logs with grep
ssh homeassistant "bash -l -c 'ha core logs'" | grep -i error | tail -20
```

## Deployment Workflows

### Standard Git Workflow (Final Changes)

Use for changes you want in version control:

```bash
# 1. Make changes locally
# 2. Check validity
ssh homeassistant "bash -l -c 'ha core check'"

# 3. Commit and push
git add file.yaml
git commit -m "Description"
git push

# 4. CRITICAL: Pull to HA instance
ssh homeassistant "cd /config && git pull"

# 5. Reload or restart
hass-cli service call automation.reload  # if reload sufficient
# OR
ssh homeassistant "bash -l -c 'ha core restart'"  # if restart needed

# 6. Verify
hass-cli state get sensor.new_entity
ssh homeassistant "bash -l -c 'ha core logs'" | grep -i error | tail -20
```

### Rapid Development Workflow (Testing/Iteration)

Use `scp` for quick testing before committing:

```bash
# 1. Make changes locally
# 2. Quick deploy
scp automations.yaml homeassistant:/config/

# 3. Reload/restart
hass-cli service call automation.reload

# 4. Test and iterate (repeat 1-3 as needed)

# 5. Once finalized, commit to git
git add automations.yaml
git commit -m "Final tested changes"
git push
```

**When to use scp:**
- Rapid iteration and testing
- Frequent small adjustments
- Experimental changes
- UI/Dashboard work

**When to use git:**
- Final tested changes
- Version control tracking
- Important configs
- Changes to document

## Reload vs Restart Decision Making

**ALWAYS assess if reload is sufficient before requiring a full restart.**

### Can be reloaded (fast, preferred):
- Automations: `hass-cli service call automation.reload`
- Scripts: `hass-cli service call script.reload`
- Scenes: `hass-cli service call scene.reload`
- Template entities: `hass-cli service call template.reload`
- Groups: `hass-cli service call group.reload`
- Themes: `hass-cli service call frontend.reload_themes`

### Require full restart:
- Min/Max sensors and platform-based sensors
- New integrations in configuration.yaml
- Core configuration changes
- MQTT sensor/binary_sensor platforms

## Automation Verification Workflow

Verify the changed automation after an authorized deployment. Use the relevant checks below.

### Step 1: Deploy
```bash
git add automations.yaml && git commit -m "..." && git push
ssh homeassistant "cd /config && git pull"
```

### Step 2: Check Configuration
```bash
ssh homeassistant "bash -l -c 'ha core check'"
```

### Step 3: Reload
```bash
hass-cli service call automation.reload
```

### Step 4: Trigger only when the action is authorized
```bash
hass-cli service call automation.trigger --arguments entity_id=automation.name
```

This command executes the automation's real actions. Use it only when those
effects are within the user's request. Otherwise inspect traces, state, and logs.

### Step 5: Check Logs
```bash
sleep 3
ssh homeassistant "bash -l -c 'ha core logs'" | grep -i 'automation_name' | tail -20
```

**Success indicators:**
- `Initialized trigger AutomationName`
- `Running automation actions`
- `Executing step ...`
- No ERROR or WARNING messages

**Error indicators:**
- `Error executing script`
- `Invalid data for call_service`
- `TypeError`, `Template variable warning`

### Step 6: Verify Outcome

**For notifications:**
- Ask user if they received it
- Check logs for mobile_app messages

**For device control:**
```bash
hass-cli state get switch.device_name
```

**For sensors:**
```bash
hass-cli state get sensor.new_sensor
```

### Step 7: Fix and Re-test if Needed
If errors found:
1. Identify root cause from error messages
2. Fix the issue
3. Re-deploy (steps 1-2)
4. Re-verify (steps 3-6)
