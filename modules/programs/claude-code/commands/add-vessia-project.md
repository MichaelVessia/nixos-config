---
allowed-tools: Read, Glob, Grep, Bash(git:*), Bash(ls:*), Write, Edit, AskUserQuestion
description: Add a project to vessia.net projects page
---

# Add Project to vessia.net

Add a project entry to ~/Projects/vessiadotnet/src/pages/projects.astro.

## Steps

1. **Gather project info** from the current directory (or user-specified path):
   - Read package.json, SPEC.md, README.md, AGENTS.md, or similar
   - Check git remote for GitHub URL
   - Identify key technologies (frameworks, languages, notable libraries)

2. **Draft project entry** following this TypeScript interface:
   ```typescript
   interface Project {
     name: string;
     github?: string;        // GitHub URL if public
     url?: string;           // Live site URL if deployed
     logo: string;           // Path like "/logos/project-name.svg"
     coloredLogo: boolean;   // true for colored SVGs, false for monochrome masks
     description: string;    // One-line description (~60 chars)
     tags: Tag[];            // Key technologies with optional notes
     notes?: string;         // HTML string with <p> tags for modal content
   }

   interface Tag {
     name: string;
     note?: string;  // Tooltip explaining how this tech is used
   }
   ```

3. **Ask user to review** the drafted entry and make adjustments

4. **Create logo SVG** in ~/Projects/vessiadotnet/public/logos/ if needed
   - Use Catppuccin Mocha colors (lavender: #cba6f7, text: #cdd6f4, surface: #313244)
   - Simple geometric/iconic design

5. **Add entry** to projects.astro in appropriate position (similar projects grouped)

6. **Commit and push** to vessiadotnet repo

## Guidelines

- Keep descriptions concise and focused on what the project does
- Tags should highlight notable tech choices, not obvious ones
- Tag notes explain HOW the tech is used, not what it is
- Notes section is optional but good for context/story
- Don't mention competitor products by name
