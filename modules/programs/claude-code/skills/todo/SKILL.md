---
name: todo
description: Manage topic-based todo lists in Obsidian vault
allowed-tools: Bash, Read, Edit
---

Manage tasks in today's daily note at `~/obsidian/Notes/YYYY-MM-DD.md`.

## Usage

- `/todo add [task description]` - Add a new task to today's TODO section
- `/todo complete [task description]` - Mark a task as complete
- `/todo list` - View today's tasks
- `/todo add-sub [parent task] > [sub-task]` - Create a sub-task under a parent task

## Instructions

1. Determine today's note file:
   - Path: `~/obsidian/Notes/$(date +%Y-%m-%d).md`
   - If file doesn't exist, create it with header: `# Journal YYYY-MM-DD`

2. Find or create the TODO section:
   - Look for `## TODO` section in the file
   - If missing, append `## TODO\n\n` to the file

3. Task operations:
   - **Add**: Append task as `- [ ] [task description]` under ## TODO
   - **Complete**: Change `- [ ]` to `- [x]` for matching task
   - **Add-sub**: Nest sub-task under parent with 2-space indent: `  - [ ] [sub-task]`
   - **List**: Display all tasks from ## TODO section

4. Format guidelines:
   - Use markdown checkbox syntax: `- [ ]` for incomplete, `- [x]` for complete
   - Indent sub-tasks with 2 spaces per level
   - Keep consistent formatting throughout

5. After operations:
   - Confirm the action taken
   - Show a preview of the TODO section
