# Docked Tools

Dockerized development tools.

## i18n-diff

Dockerized i18n diff tool for comparing translation files.

### Commands
- Build: `./i18n-diff.build.sh`
- Test: `./i18n-diff.test.sh`
- Run: `./i18n-diff.dockerized.sh`

### Key Files
- `i18n-diff.sh` - Main script
- `i18n-diff.dockerized.sh` - Docker wrapper

## sass

Dockerized Sass CSS preprocessor (v3.4.22) for Zabbix themes.

### Commands
- Build: `./sass.build.sh`
- Run: `./sass.dockerized.sh`

### Usage
```bash
cd /path/to/zabbix
./sass.dockerized.sh    # Compile all themes and copy assets
```

Compiles themes from `sass/` to `ui/assets/styles/`:
- hc-dark, hc-light, dark-theme, blue-theme
- dark-classic-theme, blue-classic-theme (if present)

Also copies favicon and app icons to `ui/assets/img/`.

Environment variables: `SASS_DIR`, `CSS_DIR`, `IMG_DIR`

### Key Files
- `sass.Dockerfile` - Docker image definition
- `sass.build.sh` - Build script
- `sass.dockerized.sh` - Docker wrapper

## Conventions
- Use bash strict mode
- Keep scripts POSIX-compatible where possible
