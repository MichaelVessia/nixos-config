# Home Assistant dashboards

Use these examples for dashboard work. Choose the layout and validation needed for the user's target device. Deployment commands require a deployment request.

## Dashboard Management

### Dashboard Fundamentals

**What are Lovelace Dashboards?**
- JSON files in `.storage/` directory (e.g., `.storage/lovelace.control_center`)
- UI configuration for Home Assistant frontend
- Optimizable for different devices (mobile, tablet, wall panels)

**Critical Understanding:**
- Creating dashboard file is NOT enough - must register in `.storage/lovelace_dashboards`
- Dashboard changes don't require HA restart (just browser refresh)
- Use panel view for full-screen content (maps, cameras)
- Use sections view for organized multi-card layouts

### Dashboard Development Workflow

**Rapid Iteration with scp (Recommended for dashboards):**

```bash
# 1. Make changes locally
vim .storage/lovelace.control_center

# 2. Deploy immediately (no git commit yet)
scp .storage/lovelace.control_center homeassistant:/config/.storage/

# 3. Refresh browser (Ctrl+F5 or Cmd+Shift+R)
# No HA restart needed!

# 4. Iterate: Repeat 1-3 until perfect

# 5. Commit when stable
git add .storage/lovelace.control_center
git commit -m "Update dashboard layout"
git push
ssh homeassistant "cd /config && git pull"
```

**Why scp for dashboards:**
- Instant feedback (no HA restart)
- Iterate quickly on visual changes
- Commit only stable versions

### Creating New Dashboard

**Complete workflow:**

```bash
# Step 1: Create dashboard file
cp .storage/lovelace.my_home .storage/lovelace.new_dashboard

# Step 2: Register in lovelace_dashboards
# Edit .storage/lovelace_dashboards to add:
{
  "id": "new_dashboard",
  "show_in_sidebar": true,
  "icon": "mdi:tablet-dashboard",
  "title": "New Dashboard",
  "require_admin": false,
  "mode": "storage",
  "url_path": "new-dashboard"
}

# Step 3: Deploy both files
scp .storage/lovelace.new_dashboard homeassistant:/config/.storage/
scp .storage/lovelace_dashboards homeassistant:/config/.storage/

# Step 4: Restart HA (required for registry changes)
ssh homeassistant "bash -l -c 'ha core restart'"
sleep 30

# Step 5: Verify appears in sidebar
```

**Update .gitignore to track:**
```gitignore
# Exclude .storage/ by default
.storage/

# Include dashboard files
!.storage/lovelace.new_dashboard
!.storage/lovelace_dashboards
```

### View Types Decision Matrix

**Use Panel View when:**
- Displaying full-screen map (vacuum, cameras)
- Single large card needs full width
- Want zero margins/padding
- Minimize scrolling

**Use Sections View when:**
- Organizing multiple cards
- Need responsive grid layout
- Building multi-section dashboards

**Layout Example:**
```json
// Panel view - full width, no margins
{
  "type": "panel",
  "title": "Vacuum Map",
  "path": "map",
  "cards": [
    {
      "type": "custom:xiaomi-vacuum-map-card",
      "entity": "vacuum.dusty"
    }
  ]
}

// Sections view - organized, has ~10% margins
{
  "type": "sections",
  "title": "Home",
  "sections": [
    {
      "type": "grid",
      "cards": [...]
    }
  ]
}
```

### Card Types Quick Reference

**Mushroom Cards (Modern, Touch-Optimized):**
```json
{
  "type": "custom:mushroom-light-card",
  "entity": "light.living_room",
  "use_light_color": true,
  "show_brightness_control": true,
  "collapsible_controls": true,
  "fill_container": true
}
```
- Best for tablets and touch screens
- Animated, colorful icons
- Built-in slider controls

**Mushroom Template Card (Dynamic Content):**
```json
{
  "type": "custom:mushroom-template-card",
  "primary": "All Doors",
  "secondary": "{% set sensors = ['binary_sensor.front_door'] %}\n{% set open = sensors | select('is_state', 'on') | list | length %}\n{{ open }} / {{ sensors | length }} open",
  "icon": "mdi:door",
  "icon_color": "{% if open > 0 %}red{% else %}green{% endif %}"
}
```
- Use Jinja2 templates for dynamic content
- Color-code status with icon_color
- Multi-line templates use `\n` in JSON

**Tile Card (Built-in, Modern):**
```json
{
  "type": "tile",
  "entity": "climate.thermostat",
  "features": [
    {"type": "climate-hvac-modes", "hvac_modes": ["heat", "cool", "fan_only", "off"]},
    {"type": "target-temperature"}
  ]
}
```
- No custom cards required
- Built-in features for controls

### Common Template Patterns

**Counting Open Doors:**
```jinja2
{% set door_sensors = [
  'binary_sensor.front_door',
  'binary_sensor.back_door'
] %}
{% set open = door_sensors | select('is_state', 'on') | list | length %}
{{ open }} / {{ door_sensors | length }} open
```

**Color-Coded Days Until:**
```jinja2
{% set days = state_attr('sensor.bin_collection', 'daysTo') | int %}
{% if days <= 1 %}red
{% elif days <= 3 %}amber
{% elif days <= 7 %}yellow
{% else %}grey
{% endif %}
```

**Conditional Display:**
```jinja2
{% set bins = [] %}
{% if days and days | int <= 7 %}
  {% set bins = bins + ['Recycling'] %}
{% endif %}
{% if bins %}This week: {{ bins | join(', ') }}{% else %}None this week{% endif %}
```

**IMPORTANT:** Always use `| int` or `| float` to avoid type errors when comparing

### Tablet Optimization

**Screen-specific layouts:**
- 11-inch tablets: 3-4 columns
- Touch targets: minimum 44x44px
- Minimize scrolling: Use panel view for full-screen
- Visual feedback: Color-coded status (red/green/amber)

**Grid Layout for Tablets:**
```json
{
  "type": "grid",
  "columns": 3,
  "square": false,
  "cards": [
    {"type": "custom:mushroom-light-card", "entity": "light.living_room"},
    {"type": "custom:mushroom-light-card", "entity": "light.bedroom"}
  ]
}
```

### Common Dashboard Pitfalls

**Problem 1: Dashboard Not in Sidebar**
- **Cause:** File created but not registered
- **Fix:** Add to `.storage/lovelace_dashboards` and restart HA

**Problem 2: "Configuration Error" in Card**
- **Cause:** Custom card not installed, wrong syntax, template error
- **Fix:**
  - Check HACS for card installation
  - Check browser console (F12) for details
  - Test templates in Developer Tools -> Template

**Problem 3: Auto-Entities Fails**
- **Cause:** `card_param` not supported by card type
- **Fix:** Use cards that accept `entities` parameter:
  - Works: `entities`, `vertical-stack`, `horizontal-stack`
  - Doesn't work: `grid`, `glance` (without specific syntax)

**Problem 4: Vacuum Map Has Margins/Scrolling**
- **Cause:** Using sections view (has margins)
- **Fix:** Use panel view for full-width, no scrolling

**Problem 5: Template Type Errors**
- **Error:** `TypeError: '<' not supported between instances of 'str' and 'int'`
- **Fix:** Use type filters: `states('sensor.days') | int < 7`

### Dashboard Debugging

**1. Browser Console (F12):**
- Check for red errors when loading dashboard
- Common: "Custom element doesn't exist" -> Card not installed

**2. Validate JSON Syntax:**
```bash
python3 -m json.tool .storage/lovelace.my_dashboard > /dev/null
```

**3. Test Templates:**
```
Home Assistant -> Developer Tools -> Template
Paste template to test before adding to dashboard
```

**4. Verify Entities:**
```bash
hass-cli state get binary_sensor.front_door
```

**5. Clear Browser Cache:**
- Hard refresh: Ctrl+F5 or Cmd+Shift+R
- Try incognito window

## Real-World Examples

### Quick Controls Dashboard Section
```json
{
  "type": "grid",
  "title": "Quick Controls",
  "cards": [
    {
      "type": "custom:mushroom-template-card",
      "primary": "All Doors",
      "secondary": "{% set doors = ['binary_sensor.front_door', 'binary_sensor.back_door'] %}\n{% set open = doors | select('is_state', 'on') | list | length %}\n{{ open }} / {{ doors | length }} open",
      "icon": "mdi:door",
      "icon_color": "{% if open > 0 %}red{% else %}green{% endif %}"
    },
    {
      "type": "tile",
      "entity": "climate.thermostat",
      "features": [
        {"type": "climate-hvac-modes", "hvac_modes": ["heat", "cool", "fan_only", "off"]},
        {"type": "target-temperature"}
      ]
    }
  ]
}
```

### Individual Light Cards (Touch-Friendly)
```json
{
  "type": "grid",
  "title": "Lights",
  "columns": 3,
  "cards": [
    {
      "type": "custom:mushroom-light-card",
      "entity": "light.office_studio",
      "name": "Office",
      "use_light_color": true,
      "show_brightness_control": true,
      "collapsible_controls": true
    }
  ]
}
```

### Full-Screen Vacuum Map
```json
{
  "type": "panel",
  "title": "Vacuum",
  "path": "vacuum-map",
  "cards": [
    {
      "type": "custom:xiaomi-vacuum-map-card",
      "vacuum_platform": "Tasshack/dreame-vacuum",
      "entity": "vacuum.dusty"
    }
  ]
}
```
