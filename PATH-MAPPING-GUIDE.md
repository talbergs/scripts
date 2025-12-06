# Docker Path Mapping Strategies for Neovim

## Available Scripts

### 1. `v` - Simple & Reliable (Recommended)
Mounts current directory to `/workspace` in the container.

**Pros:**
- Simple and predictable
- No path translation needed
- Works everywhere
- No conflicts with container filesystem

**Cons:**
- Paths differ between host and container
- LSP servers see paths as `/workspace/...`

**Usage:**
```bash
v                    # Open current directory
v file.txt          # Edit file.txt
v src/main.rs       # Edit with relative path
```

### 2. `v-advanced` - One-to-One Path Mapping
Mounts current directory to the SAME path in the container.

**Pros:**
- Absolute paths work consistently
- LSP error messages match host paths
- Better for complex projects with submodules
- Tools that use absolute paths work better

**Cons:**
- More complex setup
- Requires creating directory structure in container
- Might conflict with container's filesystem for system paths

**Usage:**
```bash
v-advanced file.txt                    # Same as v
v-advanced /Users/you/project/file.txt # Absolute paths work
```

## Path Mapping Research Summary

Based on Docker best practices for 2025:

### Mount Syntax
Modern Docker prefers `--mount` over `-v`:
```bash
docker run --mount type=bind,src=/host/path,dst=/container/path
```

### Best Practices

**Development vs Production:**
- Bind mounts are recommended for development workflows
- For production, use Docker volumes for stability and security

**Security Considerations:**
- Never mount sensitive directories like `/etc` or `/root`
- Bind mounts can modify the host filesystem, which has security implications
- Use read-only mounts (`ro`) when possible for external files

**Portability:**
- Containers with bind mounts are tied to the host's directory structure
- Consider this when sharing Docker commands across teams

### Why `/workspace` is the Default Choice

For a Neovim wrapper, the simple `/workspace` mount is preferred because:
1. **Reliability** - Works on any host OS (macOS, Linux, Windows)
2. **Simplicity** - No path translation logic needed
3. **Isolation** - Clear separation between host and container paths
4. **Portability** - Command works the same for all users

### When to Use One-to-One Mapping

Consider `v-advanced` when:
- Working with LSP servers that report absolute paths
- Debugging with stack traces that include file paths
- Using Git submodules with absolute path references
- Sharing paths between multiple containers
- Your workflow involves copying paths from error messages

## Implementation Details

Both scripts:
- Auto-build the Docker image if not present
- Handle relative and absolute file paths
- Mount current directory
- Pass through terminal settings (`TERM`)
- Clean up containers after exit (`--rm`)

The `v-advanced` script additionally:
- Creates parent directory structure in container
- Optionally mounts additional paths for files outside PWD
- Uses shell entrypoint to set up paths before launching Neovim

## Recommendation

**Start with `v`** for daily use. Switch to `v-advanced` only if you encounter issues with absolute paths or LSP integration.
