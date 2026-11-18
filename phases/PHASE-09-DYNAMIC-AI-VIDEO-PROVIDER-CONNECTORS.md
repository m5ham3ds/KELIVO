# Phase 9 — Dynamic AI Video Provider Connectors

## Objective

Allow the user to install and choose an external AI video-generation service for an individual scene/task without coupling that provider to Kelivo's local video-render engine or bundling a commercial provider SDK into the APK.

## Architecture and boundaries

- A provider is a `kelivo.video-provider.yaml` declarative REST contract, not an executable extension. Kelivo builds the small supported HTTP request set itself; it never executes connector scripts or downloads provider code.
- The manifest declares only HTTPS API origin, a narrow API-key header policy, supported text-to-video/image-to-video capabilities, request JSON field mappings, asynchronous submit/poll paths, status mappings, optional live quote path, model IDs, output hosts, and hard limits.
- Provider records are stored in the existing generic extension registry with a workspace-scoped opaque registry identity. The public `provider_id` remains the manifest ID. The same provider manifest can therefore be independently installed in multiple Workspaces.
- API keys are entered in Workspace settings and stored in Android secure storage under a Workspace/provider-scoped opaque key. A key is never accepted by a conversation tool, written to extension metadata, included in permission arguments, or returned by a tool.
- Provider jobs are asynchronous. Local job records retain the provider ID, remote job ID, Workspace, target production project/scene, state, and non-secret price fields; prompts, image URLs, API keys, and result URLs are not persisted in job metadata.
- Result download is restricted to HTTPS port 443 and the provider API host or explicitly declared download hosts. Redirects are disabled, size and content-type are bounded, and the saved bytes must have an MP4 `ftyp` file signature before they are linked to a scene.
- Providers and their keys are separate from the Phase 7 local render-engine registry. Choosing a provider does not change the local render engine.

## Manifest contract (schema version 1)

Top-level fields:

- `schemaVersion`, `id`, `name`, `version`, `description`.
- `api.baseUrl` and optional `api.apiKey` (`required`, approved header name, and a restricted prefix value).
- `capabilities.textToVideo` and `capabilities.imageToVideo`.
- Optional `models` and `defaultModel`.
- `limits.maxPromptCharacters`, `limits.maxDurationSeconds`, and `limits.maxDownloadBytes`.
- Optional `downloadHosts` allowlist.
- `endpoints.submit` with a relative API path, `jobIdPath`, and explicit request-field mappings.
- `endpoints.poll` with exactly one `{job_id}` placeholder, status/output JSON paths, optional progress/cost paths, and disjoint status lists.
- Optional `endpoints.quote` with a quote path, numeric `costPath`, and ISO 4217-style currency code.

Unknown fields, script-like extension fields, non-HTTPS API origins, non-standard ports, IP/local hosts, unsafe path segments, unknown placeholders, unknown credential headers and unsupported schema versions are rejected. See `examples/kelivo.video-provider.example.yaml`. The example uses reserved example domains and is not a real provider integration.

## Conversation and settings interfaces

The `video_provider` workspace tool supports:

- `list`, `inspect`, `install`, `update`, `remove`.
- `credential_status`, `limits`, `set_limits`.
- `submit`, `poll`, `download`.

Installation accepts inline manifest text, the exact manifest file inside the active Workspace, or a `raw.githubusercontent.com` URL whose final path segment is `kelivo.video-provider.yaml`. Installation/update/removal, limit changes, submission, and download require explicit tool approval. API-key entry is only available through the dedicated secure Workspace settings page.

## Request and cost controls

Default Workspace limits are 20 generation requests per UTC day, 2 active jobs, and 128 MiB per result download. The user can change the daily request count, concurrent-job limit, download ceiling, and an optional daily budget. A positive budget is enforced only when the selected connector provides a live quote endpoint returning a numeric amount in the configured currency. If a quote is absent, invalid, or currency-mismatched, submission is blocked. Price is never fabricated from model names or static assumptions.

Quote amounts are interpreted as decimal units of the manifest-declared currency and converted to integer millionths for local comparison. Existing same-day reservations with another currency block the budget calculation rather than being silently mixed. Quotes are provider-reported values, not independent price verification.

## Tests and CI scope

The focused Android regression manifest is `.github/ci/android-phase9-test-manifest.txt`. It retains the 29 prior Phase 3–8 regression files and adds manifest-parser and credential-store tests. The chat UI regression set adds a dedicated provider-tool card test. The CI workflows use the new Phase 9 analyzer/test scripts while retaining the Android ARM64 APK build and Android-only audit.

## Acceptance criteria

1. Install one declarative connector into a Workspace and inspect its advertised capabilities.
2. Install the same manifest into a second Workspace without registry or credential collision.
3. Store a key in Android secure storage; prove the key never appears in tool schema arguments, extension metadata, job metadata, approval arguments, or tool results.
4. Start asynchronous text-to-video and image-to-video jobs only when the corresponding capability is declared; poll their status without changing the local engine selection.
5. Apply request, concurrency, quote-backed budget, and download-size limits.
6. Download an allowlisted MP4 result into the selected scene and confirm it appears as a project asset.
7. Update/remove a connector without affecting another Workspace, local render engines, existing video projects, or unrelated providers.
8. Pass focused Dart analysis/tests and Android ARM64 Release CI; exercise one real provider end-to-end on an ARM64 device before declaring the phase accepted.

## Deferred

- No provider is bundled or preconfigured. No real commercial provider endpoint or pricing is claimed by this phase.
- OAuth/device authorization, arbitrary custom request headers, multipart or binary image upload, signed asset upload, provider-specific cancellation, retries/webhooks, and automatic provider discovery are deferred.
- Job cancellation is not yet exposed. Polling/download requires the provider to retain its job result until the user downloads it.
- Quote endpoints are trusted only as part of the user-installed manifest; the quote is not independently checked against a billing account.
- Daily counters and concurrency controls are local app-level controls, not provider-side hard quotas and not a distributed reservation service. Simultaneous submissions from multiple devices can exceed this local estimate.
- Live provider behavior, network error handling on device, actual billing semantics, and Android secure-storage lifecycle still require CI/device acceptance.


### Network trust boundary

- Connector API origins, raw GitHub manifests, user image URLs, and result-download hosts are restricted to HTTPS on the default TLS port and checked against public DNS results before requests. Redirects are disabled.
- DNS validation is a best-effort preflight, not IP-pinned DNS resolution or a substitute for a sandboxed network proxy. Runtime acceptance must still validate actual provider connectivity and device behavior.
- A provider manifest is user-installed third-party configuration. Its quote values and response mappings are not independently vouched for by Kelivo; review provider terms and billing before enabling paid generation.
