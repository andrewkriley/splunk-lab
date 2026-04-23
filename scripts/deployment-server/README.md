# Splunk Deployment Server + Receiver Setup

Step-through scripts that turn the lab's Splunk Enterprise container into:

1. A **receiver** for forwarder traffic on TCP `9997` (universal and heavy forwarders).
2. A **deployment server** that pushes curated apps to forwarders grouped into three server classes: `all_forwarders`, `universal_forwarders`, `heavy_forwarders`.

All steps operate against the running `splunk` service in `docker-compose.yml`, so the lab stack must already be up (`docker compose up -d`).

## Steps

| # | Script | What it does |
|---|---|---|
| 00 | `00-check-prereqs.sh` | Confirms the container is running and `splunkd` responds. |
| 01 | `01-enable-receiving.sh` | Opens the splunktcp listener on `:9997` via `splunk enable listen`. |
| 02 | `02-enable-deployment-server.sh` | Seeds `etc/system/local/serverclass.conf` with a `[global]` stanza. |
| 03 | `03-install-deployment-apps.sh` | Copies the apps under `apps/` into `etc/deployment-apps/`. |
| 04 | `04-configure-serverclasses.sh` | Writes three server classes and binds apps to them. |
| 05 | `05-reload-deployment-server.sh` | Runs `splunk reload deploy-server` so forwarders see the changes. |
| 99 | `99-verify.sh` | Read-only checks: listener, apps on disk, server class stanzas. |
| — | `run-all.sh` | Runs every step in order. Each step is idempotent. |

Run one at a time while you learn the flow, or just:

```bash
./scripts/deployment-server/run-all.sh
```

## Deployment apps

Lives under `apps/`, one directory per app. Each is a complete Splunk app skeleton (`local/*.conf` + `metadata/local.meta`) so it can be pushed as-is.

| App | Target class | Purpose |
|---|---|---|
| `all_forwarders_outputs` | `all_forwarders` | `outputs.conf` — every forwarder ships events to `splunk:9997`. |
| `uf_base_inputs` | `universal_forwarders` | Baseline `inputs.conf` for UF-class hosts. |
| `hf_base_inputs` | `heavy_forwarders` | Baseline `inputs.conf` for HF-class hosts (HEC input included). |
| `hf_indexing_routes` | `heavy_forwarders` | `props.conf` + `transforms.conf` — parsing-time routing. UFs cannot apply these. |
| `forwarder-client-template` | — | Not pushed. Drop-in `deploymentclient.conf` for the forwarder side. |

## Server classes

Matching is by `clientName` from each forwarder's `deploymentclient.conf`.

| Class | Whitelist | Apps attached |
|---|---|---|
| `all_forwarders` | `*` | `all_forwarders_outputs` |
| `universal_forwarders` | `uf-*` | `uf_base_inputs` |
| `heavy_forwarders` | `hf-*` | `hf_base_inputs`, `hf_indexing_routes` |

## Connecting a forwarder

On each forwarder (UF or HF):

```bash
cp apps/forwarder-client-template/local/deploymentclient.conf \
  $SPLUNK_HOME/etc/system/local/deploymentclient.conf
# edit clientName to 'uf-<hostname>' or 'hf-<hostname>'
# edit targetUri to <lab-host>:8089
$SPLUNK_HOME/bin/splunk restart
```

Within ~60 seconds the forwarder phones home, the deployment server matches it against the server classes, and it installs the apps scoped to its class.

## Verifying end-to-end

- Splunk Web → **Settings → Forwarder management** lists each connected client, its class, and the app bundle deployed.
- Splunk Web → **Settings → Forwarding and receiving** shows `Configure receiving → 9997`.
- Run `./99-verify.sh` for the CLI view.

## Caveats

- The lab's `splunk:9997` receiver is only reachable from inside the Docker network. To forward from the host or another machine, publish the port by adding `- "127.0.0.1:9997:9997"` to the `splunk` service in `docker-compose.yml`.
- `restartSplunkd = true` on app bindings means forwarders will restart when a new version of an app arrives. Disable in `04-configure-serverclasses.sh` if you need zero-restart pushes (inputs will reload via `splunk reload` on the forwarder instead).
