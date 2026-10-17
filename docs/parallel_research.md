# Web research with Parallel Search MCP

Use [Parallel Search MCP](https://docs.parallel.ai/integrations/mcp/search-mcp)
in Claude Code to find current Flutter documentation and fetch relevant pages
while developing 360Ghar. It provides `web_search` and `web_fetch` without a
Parallel account or API key. Anonymous search uses Fast mode and has lower rate
limits, suitable for light research.

This is optional developer tooling. The app's property search still uses its
existing backend, and the shared Dart and Exa servers in [`.mcp.json`](../.mcp.json)
stay unchanged.

## Set up Claude Code

Install [Claude Code](https://code.claude.com/docs/en/setup) and complete its
normal sign-in. From the root of your 360Ghar checkout, run:

```bash
claude mcp add --transport http --scope local parallel-search \
  https://search.parallel.ai/mcp \
  --header "User-Agent: 360-ghar-app-dev-research"
claude mcp get parallel-search
```

The explicit `local` scope saves this server for you in this checkout, outside
the tracked `.mcp.json`. It does not enable it for other contributors or other
projects. If you already have a server named `parallel-search`, inspect it with
`claude mcp get parallel-search` before adding or removing anything.

Start a new Claude Code session in the same checkout, run `/mcp`, and confirm
`parallel-search` is connected. Allow its search and fetch tools when prompted.
The anonymous `/mcp` endpoint needs no Parallel sign-in or Authorization header.
See [Claude Code's MCP guide](https://code.claude.com/docs/en/mcp) for connection
troubleshooting and scope details.

## Research a mapping change

The app uses `maplibre_gl` in [`pubspec.yaml`](../pubspec.yaml), with a shared
controller in [`lib/core/map/map_controller.dart`](../lib/core/map/map_controller.dart).
Try this prompt before changing map behavior:

```text
Read pubspec.yaml and lib/core/map/map_controller.dart. Use parallel-search's
web_search to find the maplibre_gl package documentation and upstream examples
for the version declared in this project. Research map tap callbacks and
converting screen coordinates to LatLng on Android and iOS.

Use parallel-search's web_fetch to read the relevant pages. Summarize the
supported APIs and platform differences with source URLs. State which package
version each source covers; flag sources that only describe newer versions.
Do not edit files yet.
```

Check the cited documentation against the installed package version before
applying a suggested change. Keep research queries focused on public technical
information; do not include `.env` values, credentials, or private user data.

If the service reports a rate limit, retry after the indicated interval. Higher
limits require the authenticated setup in the Parallel guide linked above.

## Remove the local server

Run from the same checkout:

```bash
claude mcp remove parallel-search --scope local
```

This removes the local Parallel entry and leaves the shared MCP configuration
in place.
