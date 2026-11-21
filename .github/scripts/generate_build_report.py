#!/usr/bin/env python3
"""Generate a Markdown report and Actions summary from captured Android CI logs."""
from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(os.environ.get("GITHUB_WORKSPACE", Path.cwd())).resolve()
REPORT_DIR = Path(os.environ.get("KELIVO_CI_REPORT_DIR", ROOT / "build-report"))
LOG_DIR = REPORT_DIR / "logs"
REPORT_PATH = REPORT_DIR / "KELIVO_BUILD_REPORT.md"

WARNING_RE = re.compile(
    r"\b(warning|warnings|warn|deprecated|deprecation|obsolete|unchecked)\b|::warning::|^\s*w:",
    re.IGNORECASE,
)
ERROR_RE = re.compile(
    r"\b(error|errors|exception|failed|failure|fatal|not found|could not|cannot)\b|"
    r"\b\w*(?:exception|error)\b|::error::|^\s*e:",
    re.IGNORECASE,
)
ANSI_RE = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")


def env(name: str, default: str = "Not recorded") -> str:
    return os.environ.get(name, default).strip() or default


def now_utc() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")


def read_steps() -> list[dict[str, str]]:
    steps: list[dict[str, str]] = []
    path = REPORT_DIR / "steps.tsv"
    if path.exists():
        for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
            parts = line.split("\t", 4)
            if len(parts) == 5:
                step_id, title, outcome, duration, log_ref = parts
                steps.append({
                    "id": step_id,
                    "title": title,
                    "outcome": outcome,
                    "duration": duration,
                    "log": log_ref,
                })
    return steps


def read_github_action_steps() -> list[dict[str, str]]:
    """Read exact GitHub job-step conclusions, including skipped steps."""
    path = REPORT_DIR / "workflow-jobs.json"
    if not path.exists():
        return []
    try:
        payload = json.loads(path.read_text(encoding="utf-8", errors="replace"))
    except (OSError, json.JSONDecodeError):
        return []

    expected_job = "Audit, Arabic Checks & Build Android ARM64"
    selected = next((job for job in payload.get("jobs", []) if job.get("name") == expected_job), None)
    if not selected:
        return []

    result: list[dict[str, str]] = []
    for item in selected.get("steps", []):
        started = item.get("started_at") or ""
        completed = item.get("completed_at") or ""
        duration = "n/a"
        if started and completed:
            try:
                start_dt = datetime.fromisoformat(started.replace("Z", "+00:00"))
                end_dt = datetime.fromisoformat(completed.replace("Z", "+00:00"))
                duration = str(max(0, int((end_dt - start_dt).total_seconds())))
            except ValueError:
                pass
        result.append({
            "number": str(item.get("number", "")),
            "name": str(item.get("name", "Unnamed GitHub Actions step")),
            "status": str(item.get("status", "unknown")),
            "conclusion": str(item.get("conclusion") or "not completed"),
            "duration": duration,
            "started": started or "n/a",
            "completed": completed or "n/a",
        })
    return result


def collect_matches() -> tuple[list[tuple[str, int, str]], list[tuple[str, int, str]]]:
    warnings: list[tuple[str, int, str]] = []
    errors: list[tuple[str, int, str]] = []
    if not LOG_DIR.exists():
        return warnings, errors
    full_job_log = LOG_DIR / "github-actions-full-job.log"
    if full_job_log.exists() and full_job_log.stat().st_size > 0:
        log_paths = [full_job_log]
        for extra_name in ("report-job.log", "github-actions-full-job-download.log"):
            extra = LOG_DIR / extra_name
            if extra.exists() and extra.stat().st_size > 0:
                log_paths.append(extra)
    else:
        log_paths = sorted(LOG_DIR.glob("*.log"))
    for log_path in log_paths:
        try:
            lines = log_path.read_text(encoding="utf-8", errors="replace").splitlines()
        except OSError:
            continue
        rel = str(log_path.relative_to(REPORT_DIR))
        for number, line in enumerate(lines, 1):
            clean = ANSI_RE.sub("", line).strip()
            if not clean:
                continue
            # Ignore the explicit report footer, not the tool's own output.
            if WARNING_RE.search(clean):
                warnings.append((rel, number, clean))
            if ERROR_RE.search(clean):
                errors.append((rel, number, clean))
    return warnings, errors


def markdown_cell(value: str) -> str:
    return value.replace("|", "\\|").replace("\n", " ")


def git_value(args: list[str]) -> str:
    try:
        return subprocess.check_output(args, cwd=ROOT, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return "Unavailable"


def artifact_details(github_action_steps: list[dict[str, str]]) -> list[str]:
    dist = ROOT / "dist"
    details: list[str] = []
    if dist.exists():
        for path in sorted(dist.glob("*")):
            if not path.is_file():
                continue
            size = path.stat().st_size
            digest = hashlib.sha256(path.read_bytes()).hexdigest() if not path.name.endswith(".sha256") else path.read_text(encoding="utf-8", errors="replace").strip()
            details.append(f"- `{path.name}` — {size:,} bytes — SHA-256: `{digest}`")
    if not details:
        metadata = REPORT_DIR / "apk_metadata.txt"
        if metadata.exists():
            details.extend(
                f"- {line}"
                for line in metadata.read_text(encoding="utf-8", errors="replace").splitlines()
                if line.strip()
            )
    if not details:
        conclusions = {item["name"]: item["conclusion"].lower() for item in github_action_steps}
        prepared = conclusions.get("Prepare APK and SHA-256 checksum") == "success"
        uploaded = conclusions.get("Upload Android ARM64 APK") == "success"
        if prepared and uploaded:
            details.append(
                "GitHub Actions reports that APK preparation and the separate Android ARM64 artifact upload both succeeded. "
                "The APK is available in the workflow's `Kelivo-Android-arm64-v8a` artifact; it is not embedded in this build-report archive. "
                "The APK metadata file was not retained here, so this report cannot independently state its filename, size or SHA-256."
            )
        elif prepared:
            details.append(
                "GitHub Actions reports that APK preparation succeeded, but a successful artifact upload was not recorded. "
                "Check the workflow run before treating the APK as delivered."
            )
        else:
            details.append(
                "No APK metadata or APK file was retained in the report artifact. See the build and packaging step conclusions above."
            )
    return details


def write_report() -> str:
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    LOG_DIR.mkdir(parents=True, exist_ok=True)

    repository = env("GITHUB_REPOSITORY")
    run_id = env("GITHUB_RUN_ID")
    run_number = env("GITHUB_RUN_NUMBER")
    run_url = f"{env('GITHUB_SERVER_URL', 'https://github.com')}/{repository}/actions/runs/{run_id}"
    status = env("FINAL_JOB_STATUS", "unknown").lower()
    build_mode = env("BUILD_MODE", "release")
    phase13_test_mode = "focused Phase 13E–13P regressions; complete Flutter source analysis; independent local package tests; full Android JVM/Robolectric tests; Browser and Skill Android emulator E2E on main; historical Phase 13A–13D suites are not repeated"
    branch = env("GITHUB_REF_NAME", env("GITHUB_REF"))
    sha = env("GITHUB_SHA", git_value(["git", "rev-parse", "HEAD"]))
    short_sha = sha[:12] if sha not in {"Not recorded", "Unavailable"} else sha

    steps = read_steps()
    github_action_steps = read_github_action_steps()
    external = [
        ("checkout", "Checkout source", env("CHECKOUT_OUTCOME", "unknown")),
        ("setup_java", "Set up Java", env("SETUP_JAVA_OUTCOME", "unknown")),
        ("setup_flutter", "Set up Flutter", env("SETUP_FLUTTER_OUTCOME", "unknown")),
    ]
    existing = {s["id"] for s in steps}
    for step_id, title, outcome in external:
        if step_id not in existing:
            steps.append({"id": step_id, "title": title, "outcome": outcome, "duration": "n/a", "log": "GitHub Actions step log"})

    # Canonical execution order from android-build.yml. Some skipped stages are
    # recorded at the end of the job, so never use append order from steps.tsv.
    stage_order = {
        step_id: index for index, step_id in enumerate([
            "checkout", "initialize_report", "android_only_audit", "setup_flutter",
            "toolchain_versions", "flutter_pub_get", "linux_test_native_deps",
            "phase13e_preflight", "phase13e_tests",
            "phase13l_syntax_preflight", "phase13l_ci_self_test", "phase13l_preflight", "phase13l_tests",
            "phase13m_syntax_preflight", "phase13m_ci_self_test", "phase13m_preflight", "phase13m_tests",
            "phase13n_syntax_preflight", "phase13n_ci_self_test", "phase13n_preflight", "phase13n_tests",
            "phase13o_syntax_preflight", "phase13o_ci_self_test", "phase13o_preflight", "phase13o_tests",
            "phase13p_syntax_preflight", "phase13p_ci_self_test", "phase13p_preflight", "phase13p_tests",
            "l10n_parity", "generate_l10n", "full_flutter_analyze",
            "setup_java", "android_sdk_components", "android_full_unit_tests", "phase13p_android_e2e",
            "prepare_android_plugin_registrant", "build_android_arm64", "package_apk", "upload_apk",
        ])
    }
    steps.sort(key=lambda item: stage_order.get(item["id"], len(stage_order)))

    warnings, errors = collect_matches()
    start_file = REPORT_DIR / "started_at_utc.txt"
    started = start_file.read_text(encoding="utf-8").strip() if start_file.exists() else "Not recorded (report initialization did not run)"
    end = now_utc()

    outcome_emoji = {"success": "✅ SUCCESS", "failure": "❌ FAILURE", "cancelled": "⚠️ CANCELLED"}.get(status, f"⚠️ {status.upper()}")
    lines: list[str] = [
        "# Kelivo Android ARM64 — Comprehensive Build Report",
        "",
        f"> **Overall result: {outcome_emoji}**",
        "",
        "## 1. Run information",
        "",
        f"- Repository: `{repository}`",
        f"- Workflow: `Android ARM64 Build & Comprehensive Report`",
        f"- Run: [#{run_number}]({run_url})",
        f"- Run attempt: `{env('GITHUB_RUN_ATTEMPT', '1')}`",
        f"- Event: `{env('GITHUB_EVENT_NAME')}`",
        f"- Branch / ref: `{branch}`",
        f"- Commit: `{short_sha}`",
        f"- Triggered by: `{env('GITHUB_ACTOR')}`",
        f"- Started: `{started}`",
        f"- Report generated: `{end}`",
        f"- Build mode: `{build_mode}`",
        f"- Phase 13 CI test mode: `{phase13_test_mode}`",
        "",
        "## 2. Build configuration",
        "",
        f"- Flutter: `{env('FLUTTER_VERSION', '3.47.6')}`",
        f"- Java: `{env('JAVA_VERSION', '17')}`",
        f"- Android NDK: `{env('ANDROID_NDK_VERSION', '28.2.13676358')}`",
        f"- CMake: `{env('CMAKE_VERSION', '3.22.1')}`",
        f"- Target: `Android arm64-v8a`",
        f"- SDK platform: `{env('ANDROID_PLATFORM', 'Runner-installed Android SDK platform')}`",
        "",
        "## 3. Pipeline stages",
        "",
        "| Stage | Result | Duration (seconds) | Log |",
        "|---|---:|---:|---|",
    ]
    if steps:
        for step in steps:
            result = step["outcome"].upper()
            duration = step["duration"]
            log_ref = step["log"]
            log_link = f"[`{log_ref}`]({log_ref})" if log_ref.startswith("logs/") else "GitHub Actions UI"
            lines.append(
                f"| {markdown_cell(step['title'])} | **{result}** | {duration} | {log_link} |"
            )
    else:
        lines.append("| Report initialization | NOT RECORDED | n/a | No stage log was created. |")

    lines.extend(["", "## 4. GitHub Actions step details", ""])
    if github_action_steps:
        lines.extend([
            "The following conclusions and durations are read from GitHub's workflow-jobs API, "
            "so they also include steps that were skipped or never started.",
            "",
            "| # | GitHub Actions step | Status | Conclusion | Duration (seconds) |",
            "|---:|---|---|---|---:|",
        ])
        for item in github_action_steps:
            lines.append(
                f"| {item['number']} | {markdown_cell(item['name'])} | {item['status']} | "
                f"**{item['conclusion'].upper()}** | {item['duration']} |"
            )
    else:
        lines.append(
            "Structured GitHub step metadata was unavailable. See the complete runner log and "
            "the stage table above; the report-job log records whether the Actions API could be queried."
        )

    lines.extend(["", "## 5. APK artifacts", ""])
    artifacts = artifact_details(github_action_steps)
    if artifacts:
        lines.extend(artifacts)
    else:
        lines.append("No APK artifact was produced or found in `dist/`. This is expected when an earlier stage fails.")

    lines.extend([
        "",
        "## 6. Warnings detected",
        "",
        f"Total warning/deprecation matches in captured command logs: **{len(warnings)}**.",
        "",
    ])
    if warnings:
        for log_ref, number, message in warnings:
            lines.append(f"- `{log_ref}:{number}` — {message}")
    else:
        lines.append("No warning/deprecation patterns were detected in the captured command logs.")

    lines.extend([
        "",
        "## 7. Errors and failure indicators",
        "",
        f"Total error/failure-pattern matches in captured command logs: **{len(errors)}**.",
        "",
    ])
    if errors:
        for log_ref, number, message in errors:
            lines.append(f"- `{log_ref}:{number}` — {message}")
    else:
        lines.append("No error/failure patterns were detected in the captured command logs.")

    lines.extend([
        "",
        "## 8. Complete command logs",
        "",
        "Every wrapped command writes its complete stdout/stderr to a separate UTF-8 `.log` file under `logs/`. "
        "The report job also retrieves the completed build job's complete plain-text GitHub Actions log through the Actions REST API; "
        "when available, this includes checkout, setup-java, Flutter setup, command output and artifact upload diagnostics. "
        "The full job log and the per-stage command logs are included in the `Kelivo-Build-Report` artifact. "
        "If GitHub's log endpoint is unavailable, the report records that limitation and still includes every locally captured command log.",
        "",
        "### Raw log files",
        "",
    ])

    raw_logs = sorted(path for path in LOG_DIR.iterdir() if path.is_file()) if LOG_DIR.exists() else []
    if raw_logs:
        for log_path in raw_logs:
            rel = str(log_path.relative_to(REPORT_DIR))
            size = log_path.stat().st_size
            lines.append(f"- [`{rel}`]({rel}) — {size:,} bytes")
    else:
        lines.append("No raw log files were retained in the report directory.")

    lines.extend(["", "### Dart formatting patch", ""])
    format_patch = REPORT_DIR / "dart-format-fixes.patch"
    format_files = REPORT_DIR / "dart-format-changed-files.txt"
    if format_patch.is_file():
        patch_size = format_patch.stat().st_size
        changed_count = len([line for line in format_files.read_text(encoding="utf-8", errors="replace").splitlines() if line.strip()]) if format_files.is_file() else 0
        lines.append(
            f"The workflow formatted only changed first-party Dart source/test files in its temporary runner workspace. "
            f"The repository itself was not modified. Formatter-adjusted files: **{changed_count}**. "
            f"Patch size: **{patch_size:,} bytes**."
        )
        lines.append("")
        lines.append("- [`dart-format-fixes.patch`](dart-format-fixes.patch) — apply/review the formatting-only changes.")
        if format_files.is_file():
            lines.append("- [`dart-format-changed-files.txt`](dart-format-changed-files.txt) — list of adjusted Dart files.")
    else:
        lines.append("No Dart formatter patch was generated for this run.")

    lines.extend(["", "### Additional diagnostic metadata", ""])
    metadata_names = ("workflow-jobs.json", "steps.tsv", "run-metadata.txt", "started_at_utc.txt", "apk_metadata.txt", "resolved-pubspec.lock", "pubspec-lock-diff.patch", "dart-format-input-files.txt", "dart-format-changed-files.txt", "phase13-dart-analysis.txt", "phase13-test-preflight.txt", "phase13e-preflight.txt", "phase13-pub-dependencies.json")
    metadata_found = False
    for name in metadata_names:
        path = REPORT_DIR / name
        if path.is_file():
            metadata_found = True
            lines.append(f"- [`{name}`]({name}) — {path.stat().st_size:,} bytes")
    if not metadata_found:
        lines.append("No additional metadata files were retained.")

    lines.extend([
        "",
        "## 9. Interpretation notes",
        "",
        "- Warning/error counts are automatic text-pattern matches, not a semantic diagnosis. Review the linked raw log around each line.",
        "- A failed stage stops later build stages; skipped stages are recorded where GitHub exposes their outcome.",
        "- The reporting job depends on the build job with `if: always()`, retrieves the completed runner log, generates the Markdown report and uploads it even when dependency resolution, tests or APK compilation fail (unless the entire workflow is forcibly terminated before artifact upload).",
        "- APK metadata is recorded only after the packaging step verifies that the expected APK file is non-empty and calculates its SHA-256 checksum.",
        "",
        "## 10. Run link",
        "",
        f"[Open the complete GitHub Actions run]({run_url})",
        "",
    ])

    report = "\n".join(lines)
    REPORT_PATH.write_text(report, encoding="utf-8")

    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_path:
        summary = [
            "# Kelivo Android Build Report",
            "",
            f"**Result:** {outcome_emoji}",
            f"**Build mode:** `{build_mode}` · **Commit:** `{short_sha}` · **Event:** `{env('GITHUB_EVENT_NAME')}`",
            f"**Phase 13 tests:** `{phase13_test_mode}`",
            f"**Warnings:** {len(warnings)} · **Error/failure matches:** {len(errors)}",
            f"[Open full report artifact and raw logs]({run_url})",
            "",
            "The complete Markdown report and per-stage logs are uploaded as the `Kelivo-Build-Report` artifact.",
        ]
        with open(summary_path, "a", encoding="utf-8") as f:
            f.write("\n".join(summary) + "\n")
    return str(REPORT_PATH)


if __name__ == "__main__":
    print(f"Generated build report: {write_report()}")
