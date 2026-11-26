#!/usr/bin/env bash

# Stop if a command fails (-e), an unset variable is used (-u), or any command in a pipeline fails (-o pipefail).
set -euo pipefail

# Change to the repository root: the parent of this script's .devcontainer directory, regardless of the current working directory.
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Configure the EOS MCP server.
bash .devcontainer/setup-eos-mcp.sh

pip install --upgrade certifi
pip install 'anta[cli]' -U

# Make the shared EOS MCP skills available without replacing existing skills.
mkdir -p "$HOME/.codex/skills"

for skill_dir in /opt/eos-mcp-skills/*/; do
    [[ -f "${skill_dir}SKILL.md" ]] || continue

    skill_name="$(basename "$skill_dir")"
    destination="$HOME/.codex/skills/$skill_name"

    if [[ ! -e "$destination" && ! -L "$destination" ]]; then
        ln -s "${skill_dir%/}" "$destination"
    fi
done

curl -fsSL \
    https://github.com/siemens/edgeshark/raw/main/deployments/wget/docker-compose.yaml |
    DOCKER_DEFAULT_PLATFORM= docker compose -f - up -d
