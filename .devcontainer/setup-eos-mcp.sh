#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
import json
import os
from pathlib import Path
import yaml

source = Path(os.environ["EOS_MCP_INVENTORY"])
username = os.environ["EOS_MCP_USERNAME"]
if not os.environ.get("EOS_MCP_PASSWORD"):
    raise SystemExit("EOS_MCP_PASSWORD must be set")

inventory = yaml.safe_load(source.read_text())
fabric = inventory["all"]["children"]["FABRIC"]
variables = fabric.setdefault("vars", {})
variables.pop("ansible_password", None)
variables.update({
    "ansible_network_os": "eos",
    "ansible_user": username,
    "mcp_password_env": "EOS_MCP_PASSWORD",
    "mcp_validate_certs": False,
    "mcp_diagnostics_allowed": True,
    "mcp_packet_capture_allowed": True,
})

inventory_dir = Path.home() / ".config/eos-mcp"
inventory_dir.mkdir(parents=True, exist_ok=True)
output = inventory_dir / "inventory.yml"
output.write_text(yaml.safe_dump(inventory, sort_keys=False))

# Keep the MCP credential private and load it through the MCP launcher,
# rather than shell startup files.
environment_file = inventory_dir / "environment.json"
fd = os.open(environment_file, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
os.fchmod(fd, 0o600)
with os.fdopen(fd, "w") as stream:
    json.dump({"EOS_MCP_PASSWORD": os.environ["EOS_MCP_PASSWORD"]}, stream)

launcher = inventory_dir / "launch.py"
launcher.write_text("""import json
import os
from pathlib import Path

base = Path(__file__).resolve().parent
saved = json.loads((base / "environment.json").read_text())
os.environ.setdefault("EOS_MCP_PASSWORD", saved["EOS_MCP_PASSWORD"])
os.execv("/usr/local/bin/eos-mcp-server", [
    "eos-mcp-server", "serve", "--inventory", str(base / "inventory.yml")
])
""")


# Manage only the eos server section; preserve other Codex settings.
codex_dir = Path(os.environ.get("CODEX_HOME") or Path.home() / ".codex")
codex_dir.mkdir(parents=True, exist_ok=True)
config_path = codex_dir / "config.toml"
config = config_path.read_text() if config_path.exists() else ""

import re
section = re.compile(
    r"(?ms)^\[mcp_servers\.eos(?:\.[^\]\n]+)?\][^\n]*\n.*?(?=^\[|\Z)"
)
config = section.sub("", config).rstrip()

eos_config = f"""
[mcp_servers.eos]
command = "/usr/local/bin/python3"
args = [{json.dumps(str(launcher))}]
env_vars = ["EOS_MCP_PASSWORD"]
"""
config_path.write_text(config + "\n" + eos_config)

print(f"Created MCP inventory: {output}")
print(f"Configured EOS MCP in: {config_path}")
PY

eos-mcp-server validate-inventory \
    --inventory "$HOME/.config/eos-mcp/inventory.yml"
