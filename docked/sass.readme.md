# sass

A Dockerized Sass CSS preprocessor (v3.4.22) for compiling Zabbix themes.

## Overview

sass provides a containerized Ruby Sass compiler for building Zabbix CSS themes from SCSS source files. This ensures consistent compilation across different development environments without requiring local Ruby/Sass installation.

### Supported Themes

| Theme | Description |
|-------|-------------|
| `hc-dark` | High contrast dark theme |
| `hc-light` | High contrast light theme |
| `dark-theme` | Standard dark theme |
| `blue-theme` | Standard blue theme |
| `dark-classic-theme` | Classic dark theme (if present) |
| `blue-classic-theme` | Classic blue theme (if present) |

## Requirements

- Docker

## Installation

Build the Docker image:

```bash
./sass.build.sh
```

## Usage

### Basic Usage

Run from within a Zabbix repository root:

```bash
./sass.dockerized.sh
```

This compiles all themes from `sass/stylesheets/sass/` to `ui/assets/styles/`.

### Custom Directories

Override default paths using environment variables:

```bash
SASS_DIR=custom/sass CSS_DIR=custom/css ./sass.dockerized.sh
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SASS_DIR` | `sass/stylesheets/sass` | Source SCSS directory |
| `CSS_DIR` | `ui/assets/styles` | Output CSS directory |

### Output

For each theme with a corresponding `.scss` file:
- Compiles `${SASS_DIR}/${theme}.scss` → `${CSS_DIR}/${theme}.css`
- No sourcemaps (production-ready output)
- No caching (clean builds)

## How It Works

1. Checks for Docker image, builds if missing
2. Validates source directory exists
3. Iterates through theme list
4. For each existing `.scss` file, runs Docker container to compile
5. Outputs compiled CSS directly to target directory

## Project Structure

```
sass.Dockerfile     # Docker image definition (Ruby 3.2 Alpine + Sass 3.4.22)
sass.build.sh       # Docker image build script
sass.dockerized.sh  # Docker wrapper for theme compilation
```

## Docker Image

Based on `ruby:3.2-alpine` with:
- Bash shell
- Ruby Sass gem v3.4.22

The specific Sass version (3.4.22) is pinned to maintain compatibility with Zabbix theme SCSS syntax.
