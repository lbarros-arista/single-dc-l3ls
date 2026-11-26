# Run the lab at home

You can use the same lab at home to explore the fabric, try the skills, and ask Codex your own questions. Start by cloning or downloading the [public repository](https://github.com/lbarros-arista/single-dc-l3ls).

## Prepare your environment

You will need VS Code with the **Dev Containers** extension, a working Docker engine, and an Arista cEOS image available to that engine as `arista/ceos:latest`, the image name used in the [topology](clab/topology.clab.yml).

The included [devcontainer configuration](.devcontainer/devcontainer.json) also expects:

- A clone of the [EOS MCP server repository](https://github.com/aristanetworks/eos-mcp-server) at `~/Downloads/eos-mcp-server` on your host. Its skills folder is mounted inside the devcontainer.
- The host environment variables `EOS_MCP_USERNAME` and `EOS_MCP_PASSWORD`, available to VS Code before opening the devcontainer. Use the lab's `mcp-reader` account configured in [aaa.yml](avd/group_vars/FABRIC/aaa.yml).

Open the lab repository in VS Code and choose **Dev Containers: Reopen in Container** from the Command Palette. Run all the following commands from the repository root in a devcontainer terminal.

### Download and import the cEOS image

You can automate the cEOS download and Docker import with [eos-downloader](https://titom73.github.io/eos-downloader/stable/), which provides the `ardl` command. The project source is available in the [eos-downloader repository](https://github.com/titom73/eos-downloader).

Run these steps against the same Docker engine that will run the lab. This ensures Containerlab can find the imported image when you run `make start`.

First, install eos-downloader in a Python virtual environment. It requires Python 3.10 or newer, which the lab devcontainer provides:

```bash
python3 -m venv "$HOME/.venvs/eos-downloader"
source "$HOME/.venvs/eos-downloader/bin/activate"
python -m pip install --upgrade eos-downloader
```

Generate or copy your personal API key from your arista.com account, which needs access to cEOS downloads. Enter it at the prompt below. `read -s` hides your input, and `ARISTA_TOKEN` supplies the key to eos-downloader:

```bash
printf 'Enter your arista.com API key: '
read -r -s ARISTA_TOKEN
printf '\n'
export ARISTA_TOKEN
```

On an **Apple Silicon Mac**, use the `cEOSarm` format. This command downloads the latest feature release, imports it into Docker, and assigns the exact image name and tag used by this lab:

```bash
mkdir -p "$HOME/Downloads/ceos"
ardl get eos --latest --release-type F --format cEOSarm \
  --output "$HOME/Downloads/ceos" \
  --import-docker --docker-name arista/ceos --docker-tag latest
```

For an **Intel or AMD x86-64 machine**, replace `--format cEOSarm` with `--format cEOS64`. To select a specific EOS release, replace `--latest --release-type F` with `--version` followed by the release, such as `--version 4.34.3M`. See the [supported image formats](https://titom73.github.io/eos-downloader/stable/usage/mapping/) and [download options](https://titom73.github.io/eos-downloader/stable/usage/eos/) for more examples.

Confirm that Docker can find the image, then clear the API key from the shell and leave the virtual environment:

```bash
docker image ls arista/ceos:latest
unset ARISTA_TOKEN
deactivate
```

The image list should include repository `arista/ceos` with tag `latest`. The API key is only needed for downloading the software. The EOS MCP server uses the separate device credentials configured through `EOS_MCP_USERNAME` and `EOS_MCP_PASSWORD`. For more on authentication, see the [eos-downloader environment variables](https://titom73.github.io/eos-downloader/stable/usage/environment/).

## Build and start the lab

[Arista Validated Designs (AVD)](https://avd.arista.com) turns the lab's YAML definitions into EOS switch configurations. Generate those configurations first:

```bash
make build
```

Before the first deployment, build the Linux server image:

```bash
make build-server-image
```

Then deploy the switches and servers with Containerlab:

```bash
make start
```

Once the devices are ready, you can [enter the server namespaces and test connectivity](README.md#enter-a-namespace-and-test-connectivity), or ask Codex to inspect the fabric through the EOS MCP server. If you change the AVD YAML definitions, run `make build` again before redeploying with `make start`.

## Check the fabric and security advisories

[Arista Network Test Automation (ANTA)](https://anta.arista.com) provides automated checks for EOS devices. With the lab running, try these extras:

| Command      | What it does                                                                                      |
| ------------ | ------------------------------------------------------------------------------------------------- |
| `make test`  | Runs ANTA fabric validation through the AVD `anta_runner` role.                                   |
| `make psirt` | Checks the devices' EOS versions against Arista PSIRT security advisories and generates a report. |

`make psirt` prompts for the lab's **admin password** and saves its Markdown report to `avd/anta/reports/sa-report.md`. Review the report to see which advisories are reported for the EOS versions in your lab.

## Stop the lab

When you are finished, remove the lab containers and clean up their management network:

```bash
make stop
```

You can deploy the lab again with `make start`. Run `make help` to see the other commands available in the [Makefile](Makefile).
