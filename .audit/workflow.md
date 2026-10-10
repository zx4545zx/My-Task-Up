# My Task Up run plan

## Predicate and scope

M0 passes only when the Flutter app scaffold uses package name `my_task_up`, includes Web, Android, macOS, and Windows targets, and the baseline formatter, analyzer, tests, and native/Web builds succeed. Windows must have an actual Windows-runner result. Device-level behavior is not inferred from a build. M1 must not begin while any required M0 build is blocked.

After M0, the full approved M1–M11 product scope remains in force. Each milestone gets its own implementation and real build/test gate before the next milestone. Completion requires the approved behavior and evidence, including persistence, import rollback, responsive UI, notification lifecycle boundaries, MSIX, Windows CI, and documented manual acceptance. Open gates are reported as blocked or inconclusive, never passed by assumption.

This is a greenfield app with no existing source files. Work is estimated at 12 milestone units, with M0 expected to expose toolchain and platform problems before product code. High rigor is warranted because the user requires multi-platform delivery and explicitly gates progress on platform builds. No irreversible repository action is needed to establish the initial scaffold.

## Bespoke phases

1. **Frame and audit.** Confirm the approved predicate and constraints, inspect the empty worktree, capture the toolchain baseline, and maintain `.audit/decisions.tsv`.
2. **M0 scaffold.** Generate the Flutter app and requested platform folders; add only the build/CI/evidence harness needed to reproduce checks. Run format, analyze, tests, Web, Android APK, and macOS builds. Trigger Windows CI from the task branch. Do not start M1 until all required builds have evidence.
3. **Architecture sketch.** Compare two end-to-end domain/application shapes, score them against interface depth and persistence/side-effect invariants, then record the chosen sketch before app code. The configured OpenAI GPT and DeepSeek aliases have no authenticated API keys in this Pi harness, so the candidates use the available Pi agent model equivalent; this reduces model diversity and is recorded as a review limitation.
4. **M1 shell, navigation, theme.** Establish app shell and responsive navigation; verify layouts/build/tests.
5. **M2 persistence foundation.** Add typed domain models, Drift storage, repositories and durable Web storage; verify migrations, repository behavior, persistence, and builds. Use `scripts/verify_web_storage.sh` to build a probe app and confirm the Web database survives closing and reopening. Reject Drift's in-memory and unsafe IndexedDB fallbacks instead of risking silent data loss or cross-tab races.
6. **M3 lists and Inbox.** Implement custom list lifecycle and protected Inbox; verify behavior and persistence.
7. **M4 task CRUD and details.** Implement task lifecycle and quick add; verify against persisted data and widgets.
8. **M5 subtasks and ordering.** Implement single-level subtasks and explicit reorder/move behavior; verify edge cases.
9. **M6 task views.** Implement Today, Upcoming, completed visibility, grouping and filtering; verify local-date boundaries.
10. **M7 dates and recurrence.** Implement optional due time and recurrence; test boundaries and repeated completion.
11. **M8 reminders.** Implement capability-aware local reminders and lifecycle reconciliation; verify supported native behavior and clearly label unavailable device checks.
12. **M9 search and settings.** Implement cross-list search and local settings; verify persistence and shortcuts/accessibility where applicable.
13. **M10 backup.** Implement whole-file JSON validation, export/import and transactional rollback; test invalid data leaves live state unchanged.
14. **M11 release quality.** Complete desktop polish, drag-and-drop, MSIX validation, performance checks, manual acceptance instructions, screenshots, full test/build sweep, and independent review.
15. **Final audit and handoff.** Audit decisions against the active run transcript and evidence, review the full diff, and report verified results and remaining risks to Chief. Chief owns publication.

## Execution discipline

Use milestone-sized verified increments. For each unit, state the hypothesis, change the smallest relevant surface, run its real tests/builds, and record VERIFIED, NOT VERIFIED, or INCONCLUSIVE with evidence. Fix reversible tooling issues without bypassing legal prompts or using sudo. If M0 is blocked, stop at M0 and hand back exact command output and a proposed next step. Avoid fan-out unless a task can be isolated and independently judged; the empty scaffold and sequential milestone dependencies do not justify parallel implementation now.

## Throughput checkpoint

The first checkpoint is M0. The captured machine has Flutter 3.44.0 and Dart 3.12.0, Chrome and Xcode available, but Flutter doctor reports Android licenses not accepted and CocoaPods missing. Android license acceptance is prohibited. Verify whether Android APK compilation needs accepted licenses and whether macOS builds can proceed without CocoaPods before deciding M0 is blocked. Windows requires CI evidence.

M2 passes locally with generated Drift code, formatting, analysis, tests, a real Chrome Web persistence probe, Web release, Android APK release, and macOS release. Evidence is in `.audit/evidence/m2-local-builds.log` and `.audit/evidence/m2-web-storage.log`. The Chrome probe served both Drift assets and verified the task after closing and reopening its database. Windows release verification is pending a task-branch CI run after these dependency changes. Device behavior is not inferred from these builds.

M8 local gates pass in `.audit/evidence/m8-local-builds.log`: formatting, analysis, 35 tests, Web, Android APK, macOS release, and Web storage persistence. Windows CI passed format, analysis, 35 tests, Windows release build, and artifact upload for commit `85c3e63` in run `38088373507`; the runner log and artifact are in `.audit/evidence/m8-windows-ci.log` and the GitHub run. Plugin source confirms pending Windows notifications can be canceled without MSIX identity; package identity is needed for removing delivered notifications from Windows history. Native runtime startup and permission prompts were attempted, but delivery and cancellation remain inconclusive because macOS denied notifications and the Android test task did not retain a due time. M8 build gates are closed; runtime behavior is not verified.

## Fresh continuation workflow

1. Inspect the uncommitted M8 diff and source, validate every prior evidence artifact that will inform decisions, and test actual notification support by checking plugin APIs and available native devices. Fix only verified defects. Gate with formatter, analyzer, automated tests, Web, Android APK, and macOS release before committing.
2. Push the M8 commit and verify the corresponding Windows CI workflow and artifact directly. Do not count a queued or historical run as a pass. Test runtime delivery/cancellation on available macOS and Android native targets; record unavailable device/permission checks as inconclusive with command evidence, never as success.
3. Implement M9 search/settings with persistent repository-backed behavior and widget/repository coverage. Gate all local platforms before proceeding.
4. Implement M10 JSON export/import/delete-all with whole-document validation and transactional rollback. Test both successful round-trip and failure preservation before proceeding.
5. Implement M11 window management, keyboard shortcuts, context menus, task/list drag behaviors, MSIX packaging, large-list runtime/performance, screenshots, and user-facing run/storage/backup/capability/manual-check documentation. Verify Windows-specific packaging and runtime through CI, and capture responsive screenshots from actual app surfaces.
6. Run final all-platform gates, inspect the final diff, validate this run's decision rows and linked evidence, and provide a precise verified/unverified checklist to Chief. Never merge or force-push.

Each implementation gate is a stopping point before dependent work. Permission prompts and legal acceptance are not to be bypassed or accepted; report exactly where native runtime validation is blocked.
