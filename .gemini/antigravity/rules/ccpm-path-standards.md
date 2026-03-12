# Path Standards Specification

## Overview
This specification defines file path usage standards within the Gemini CLI PM system to ensure document portability, privacy protection, and consistency.

## Core Principles

### 1. Privacy Protection
- **Prohibit** absolute paths containing usernames
- **Prohibit** exposing local directory structure in public documentation  
- **Prohibit** including complete local paths in GitHub Issue comments

### 2. Portability Principles
- **Prefer** relative paths for referencing project files
- **Ensure** documentation works across different development environments
- **Avoid** environment-specific path formats

## Path Format Standards

### Project File References ✅
```markdown
# Correct Examples
- `internal/auth/server.go` 
- `cmd/server/main.go`
- `.gemini/commands/pm/sync.md`

# Incorrect Examples ❌
- `/Users/username/project/internal/auth/server.go`
- `C:\Users\username\project\cmd\server\main.go`
```

### Cross-Project/Worktree References ✅
```markdown
# Correct Examples
- `../project-name/internal/auth/server.go`
- `../worktree-name/src/components/Button.tsx`

# Incorrect Examples ❌
- `/Users/username/parent-dir/project-name/internal/auth/server.go`
- `/home/user/projects/worktree-name/src/components/Button.tsx`
```

### Code Comment File References ✅
```go
// Correct Examples
// See internal/processor/converter.go for data transformation
// Configuration loaded from configs/production.yml

// Incorrect Examples ❌  
// See /Users/username/parent-dir/project-name/internal/processor/converter.go
```

## Implementation Rules

### Documentation Generation Rules
1. **Issue sync templates**: Use relative path template variables
2. **Progress reports**: Automatically convert absolute paths to relative paths
3. **Technical documentation**: Use project root relative paths consistently

### Path Variable Standards
```yaml
# Template variable definitions
project_root: "."              # Current project root directory
worktree_path: "../{name}"     # Worktree relative path  
internal_path: "internal/"     # Internal modules directory
config_path: "configs/"        # Configuration files directory
```

## PM Command Integration

- **issue-sync / epic-sync**: Clean path formats before sync, use relative templates

## Cleanup

Use the normalize function to strip absolute paths before publishing:
```bash
normalize_paths() {
  local content="$1"
  content=$(echo "$content" | sed "s|/Users/[^/]*/[^/]*/|../|g")
  content=$(echo "$content" | sed "s|/home/[^/]*/[^/]*/|../|g")
  echo "$content"
}
```