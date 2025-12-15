# Raycast Extension: Latest (for Latest macOS app)

Status: Draft  
Author: Jordan Tranchina (product)  
Date: 2025-12-14

---

## One‑liner
A Raycast extension that lets users check for, monitor, and install app updates via Latest — with clear start/completion feedback and minimal permissions — published to the Raycast Store.

---

## Goals & success metrics
- Allow Raycast users to:
  1. Ask Latest to check for updates and display whether updates are available.
  2. Trigger installation of available updates and receive status updates when updates start and complete.
- Success metrics:
  - 90% of user flows complete without permission prompts beyond macOS Automation consent.
  - 0 serious crashes on Raycast review and within first 1000 installs.
  - 30% Day‑1 activation of "Check for updates" command among extension installs.
  - Average install time reports available via opt‑in telemetry (if implemented).

---

## Non‑goals
- Replace the Latest app UI — this is a shortcut/integration surface only.
- Perform system‑level package installs outside the scope of what Latest already does.
- Collect or transmit user data without explicit consent.

---

## User stories & flows

1) As a Raycast user, I want to quickly check if any app updates are available so I can decide whether to update now.
   - Trigger: Command palette -> "Latest: Check for Updates"
   - Outcome: List view showing "No updates" or list of apps with update badge and version info.

2) As a Raycast user, I want to install updates from Raycast and know when installs start and finish.
   - Trigger: From list item -> "Install update"
   - Outcome: A toast (or in‑UI progress) shows "Installing X...", then "X updated" when complete. If multiple updates are queued, show progress for each.

3) As a Raycast user, I want feedback if the Latest app is not installed or if CLI helper is missing.
   - Trigger: Any command when prerequisites missing
   - Outcome: Clear action card with "Open Latest website" and an "Install helper" instruction.

4) As privacy-conscious user, I want to be informed if the extension collects anonymous telemetry.
   - Trigger: First run or Preferences
   - Outcome: Consent dialog + link to privacy policy (if telemetry enabled).

---

## UI & Commands (Raycast extension design)

Top-level extension name: "Latest"

Commands:
- Latest: Check for Updates (Primary)
  - Shortcut (optional): user can map
  - Displays list of updates (List UI)
  - Actions per item: Install, Open in Latest, Copy details
  - Global actions: Install All, Refresh / Re-check

- Latest: Install Update (context action)
  - If selected item has an update, shows install progress UI / toasts.

- Latest: Open Latest App
  - Launches the main app.

- Latest: Configure / Preferences
  - Set CLI path (if helper not auto-detected), enable telemetry.

UI Layouts:
- List view (results from `latest-cli list --json`)
  - Item elements: app icon (if available), app name, installed version, available version, source (App Store / direct), last checked timestamp.
  - Badges: "Update available", "Up to date"
- Detail view
  - Larger description, changelog excerpt (if available), Install button.
- Notifications / Toasts
  - On install start: toast with spinner "Installing <app>..."
  - On completion: success/failure toast with details and action "Open app" (if relevant)

Accessibility:
- Keyboard navigable list and actions.
- Clear ARIA-like labels via Raycast SDK components.

---

## Permissions & Privacy
- macOS Automation permission:
  - If the extension uses AppleScript to talk to Latest, Raycast will prompt in System Settings -> Automation to allow Raycast to control Latest. We must document this and make flows tolerant if the permission is denied.
- No external server calls by default.
- Telemetry (optional): opt‑in only, anonymized, and described in the extension listing and preferences. If enabled, provide privacy policy URL in store entry.

---

## Technical spec

High-level architecture
- Raycast Extension (TypeScript + Raycast SDK)
  - UI + orchestration
  - Calls out to a local helper (preferred) or AppleScript/URL scheme
  - Shows toasts and notifications via Raycast SDK
- Helper CLI (Swift)
  - Command line tool included in Latest app bundle (CommandLineTarget)
  - Exposes JSON machine interface for list/check/install operations
  - Responsible for performing update actions by invoking the app's existing internal code paths (so installations happen via the app itself)
- Latest macOS app (existing)
  - Exposes internal functions to the CLI (shared code or XPC invocation) or the CLI runs embedded code to perform the same operations.

Why a helper CLI?
- More reliable and deterministic IPC than AppleScript for structured data (JSON).
- Easier to parse progress and exit codes from TypeScript.
- Small Swift CLI target is straightforward and can re‑use the app’s update logic; it also means no network calls from the extension.

If you prefer no repo changes: Raycast extension can call AppleScript/osascript to drive the app, but this is brittle and requires Automation permission.

Component details

1) Helper CLI API (contract)
- Binary name: latest-cli (installed within app bundle; Raycast extension can discover in default locations or use `osascript` to invoke Latest)
- Commands and outputs:

a) list
- Command: `latest-cli list --json`
- Output: JSON array
- Schema:
  ```json
  [
    {
      "id": "com.example.app",
      "name": "App Name",
      "installedVersion": "1.2.3",
      "availableVersion": "1.3.0",
      "source": "appstore|sparkle|direct",
      "changelog": "Short release notes",
      "canInstall": true
    }
  ]
  ```
- Exit codes:
  - 0: success
  - >0: error (stderr includes message)

b) check (trigger a re-check)
- Command: `latest-cli check --json`
- Output: same schema as list
- Use case: user forces a check

c) install
- Command: `latest-cli install --id com.example.app --json-stream`
- Behavior:
  - Starts installation and emits newline delimited JSON events for progress; final event includes success/failure.
- Event schema (streamed):
  ```json
  {"event":"started","id":"com.example.app"}
  {"event":"progress","id":"com.example.app","percent":42}
  {"event":"completed","id":"com.example.app","success":true,"message":"Updated to 1.3.0"}
  ```
- Exit codes:
  - 0: success
  - non-zero: failure

d) status (optional)
- Command: `latest-cli status --id com.example.app --json`
- Output: current install/check status

Notes:
- The CLI should avoid prompting the user; failures must be reported via JSON/stderr.
- CLI should be signed and notarized as part of the app release.

2) Raycast extension (TypeScript) behavior
- Discovery:
  - Attempt to locate the helper using common paths:
    - /Applications/Latest.app/Contents/Resources/latest-cli
    - /Applications/Latest.app/Contents/MacOS/latest-cli
    - $HOME/.local/bin/latest-cli
  - If not found, show an action card to open Latest website and instructions to install helper (small UX flow).
- Execution:
  - Use child_process.execFile or Raycast SDK utilities to call the CLI.
  - For listing: call `latest-cli list --json`, parse JSON, render List components.
  - For install: call `latest-cli install --id ... --json-stream`
    - Parse stream events line-by-line, update an inline progress or show toasts using showToast:
      - showToast({ style: Toast.Style.Animated, title: 'Installing …' })
      - On completed: showToast success/failure accordingly.
- Feedback:
  - Provide in-UI progress bar in a dedicated "Install" quick view if possible; otherwise rely on toasts and list refresh after completion.
- Error handling:
  - If CLI returns non-zero or invalid JSON, show failure toast with actionable next steps (Open Latest, View logs).
- Timeouts & retries:
  - For long network or install operations, extend timeouts; allow the user to cancel an install action (if CLI supports cancel).

3) Packaging & distribution
- The Raycast extension is distributed via the Raycast Store as a TypeScript extension.
- The Latest app ships the helper CLI inside its .app (recommended), or the extension documents manual installation steps for users who don't have the app.
- The CLI must be signed and notarized by the app release process.
- Raycast store submission:
  - Include extension manifest, README, screenshots, 512x512 icon (and required sizes per Raycast docs).
  - Provide a short & long description, and a Privacy Policy URL if any data leaves the device.
  - Declare required Automation permissions (if applicable) in the store notes and user-facing docs.

4) Security & privacy
- The extension must not send user app lists or update info to external servers without explicit opt-in.
- If telemetry enabled, store anonymized event types only (e.g., "install_started", "install_succeeded") and provide opt-out.
- Prefer local-only operation.

---

## Developer tasks (high-level)

Phase 0 — Discovery & planning (PM + 1 engineer)
- Confirm CLI approach vs AppleScript.
- Map required API surface in Latest to expose to CLI.

Phase 1 — CLI & app integration (engineer)
- Add Swift CommandLineTarget `latest-cli` that reuses Latest app update logic.
- Implement `list`, `check`, `install`, `status` endpoints and JSON/stream protocol.
- Tests: unit test JSON schema and sample events.

Phase 2 — Raycast extension (engineer)
- Scaffold Raycast extension (TypeScript) using Raycast SDK.
- Implement List, Detail, Install flows and preference UI for CLI path and telemetry.
- Implement robust CLI discovery & graceful degradation.

Phase 3 — QA and review (PM + QA)
- Test flows on clean macOS VM with (a) Latest installed, (b) Latest not installed, (c) Automation denied.
- Validate user consent flow for telemetry.

Phase 4 — Raycast Store submission
- Prepare assets and descriptions, privacy policy, and documentation.
- Submit and respond to reviewer questions.

---

## Acceptance criteria (must pass before publishing)
- CLI reliably returns JSON list and stream events in tests.
- Raycast extension displays list of updates and correctly installs a test update in staging.
- Clear messaging for missing helper or missing Automation consent.
- Build passes Raycast store checks (icons, manifest, no banned APIs).
- Privacy policy present if telemetry enabled; telemetry is opt‑in only.
- No elevated privilege prompts beyond required macOS Automation.

---

## QA checklist
- [ ] List command returns expected JSON for multiple apps.
- [ ] Install command streams events and Raycast shows progress toasts.
- [ ] Handling when Latest not installed: user sees actionable instructions.
- [ ] Handling when helper CLI is missing: actionable instructions + "Open Latest".
- [ ] Test Automation permission denial → extension remains functional but instructs user.
- [ ] Test for concurrency (multiple installs queued).
- [ ] Accessibility keyboard navigation.
- [ ] Edge cases: corrupt JSON, CLI crash, network failures.
- [ ] Raycast Store metadata completed: icon, screenshots, long description, privacy policy URL.

---

## Release & store checklist
- Prepare Raycast extension package and sign with a dev key if required by Raycast.
- Gather assets:
  - Icon(s) (512x512 PNG) and additional sizes per docs.
  - Screenshots (showing list, install progress, success notifications).
  - One-sentence and long descriptions.
  - Category/tags: Utilities, Productivity, System.
- Privacy policy link (if telemetry).
- Provide reviewer notes that explain:
  - The extension calls a helper binary included in Latest.app, or if not installed, instructs users how to install the helper.
  - Automation (AppleScript) is not required if using the CLI; if AppleScript is used, explain Automation prompt behavior.
- Submit via Raycast developer console and monitor review.

---

## Risks & mitigations
- Risk: Automation permission prompts are confusing.
  - Mitigation: Prefer CLI-based integration and document automation flow. Show clear in‑extension instructions.
- Risk: CLI not present for users who only install Latest from the App Store.
  - Mitigation: Ensure CLI is embedded in app bundle and invoked via full path inside app bundle; include fallback UI to instruct user.
- Risk: Long installs block Raycast UI or cause timeouts.
  - Mitigation: Use streaming events and toasts; run installs in background via the CLI; allow user to dismiss Raycast while install continues.

---

## Timeline (example)
- Week 0: Finalize approach (CLI vs AppleScript), wireframes, and acceptance criteria.
- Week 1: Implement CLI and unit tests.
- Week 2: Implement Raycast extension UI and integration.
- Week 3: QA, documentation, asset collection.
- Week 4: Raycast store submission and iterate on review comments.

---

## Appendix

Sample CLI list output (example)
```json
[
  {
    "id": "com.max.codes.app",
    "name": "MaxApp",
    "installedVersion": "2.1.0",
    "availableVersion": "2.2.0",
    "source": "sparkle",
    "changelog": "Bug fixes and improvements",
    "canInstall": true
  }
]
```

Sample install event stream (NDJSON)
```
{"event":"started","id":"com.max.codes.app","time":"2025-12-14T12:00:00Z"}
{"event":"progress","id":"com.max.codes.app","percent":12}
{"event":"progress","id":"com.max.codes.app","percent":50}
{"event":"completed","id":"com.max.codes.app","success":true,"message":"Updated to 2.2.0"}
```

Minimal TypeScript snippet (Raycast) — pseudocode
```ts
import { execFile } from "child_process";
import { showToast, Toast, List } from "@raycast/api";

async function listUpdates() {
  const out = await execFileAsync("/Applications/Latest.app/Contents/Resources/latest-cli", ["list", "--json"]);
  const items = JSON.parse(out);
  return items; // render as List
}

async function install(id) {
  const toast = await showToast({ style: Toast.Style.Animated, title: `Installing ${id}...` });
  const proc = spawn("/path/to/latest-cli", ["install", "--id", id, "--json-stream"]);
  proc.stdout.on("data", (chunk) => {
    parseLineStream(chunk).forEach(handleEvent);
  });
  proc.on("close", (code) => {
    if (code === 0) toast.hide(); // then show success toast
    else showToast({ style: Toast.Style.Failure, title: `Install failed` });
  });
}
```

---

If you want, I can:
- Draft the README / Raycast Store listing copy.
- Scaffold the Raycast extension manifest and sample TypeScript files.
- Draft the Swift CLI contract and a starter Swift ArgumentParser file you can hand to an engineer.

Which of those would you like me to produce next?