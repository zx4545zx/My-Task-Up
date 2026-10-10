# My Task Up run plan

## Predicate and scope

M0 passes only when the Flutter app scaffold uses package name `my_task_up`, includes Web, Android, macOS, and Windows targets, and the baseline formatter, analyzer, tests, and native/Web builds succeed. Windows must have an actual Windows-runner result. Device-level behavior is not inferred from a build. M1 must not begin while any required M0 build is blocked.

After M0, the full approved M1–M11 product scope remains in force. Each milestone gets its own implementation and real build/test gate before the next milestone. Completion requires the approved behavior and evidence, including persistence, import rollback, responsive UI, notification lifecycle boundaries, MSIX, Windows CI, and documented manual acceptance. Open gates are reported as blocked or inconclusive, never passed by assumption.

This is a greenfield app with no existing source files. Work is estimated at 12 milestone units, with M0 expected to expose toolchain and platform problems before product code. High rigor is warranted because the user requires multi-platform delivery and explicitly gates progress on platform builds. No irreversible repository action is needed to establish the initial scaffold.

## Bespoke phases

1. **Frame and audit.** Confirm the approved predicate and constraints, inspect the empty worktree, capture the toolchain baseline, and maintain `.audit/decisions.tsv`.
2. **M0 scaffold.** Generate the Flutter app and requested platform folders; add only the build/CI/evidence harness needed to reproduce checks. Run format, analyze, tests, Web, Android APK, and macOS builds. Trigger Windows CI from the task branch. Do not start M1 until all required builds have evidence.
3. **M1 shell, navigation, theme.** Establish app shell and responsive navigation; verify layouts/build/tests.
4. **M2 persistence foundation.** Add typed domain models, Drift storage, repositories and durable Web storage; verify migrations, repository behavior, persistence, and builds.
5. **M3 lists and Inbox.** Implement custom list lifecycle and protected Inbox; verify behavior and persistence.
6. **M4 task CRUD and details.** Implement task lifecycle and quick add; verify against persisted data and widgets.
7. **M5 subtasks and ordering.** Implement single-level subtasks and explicit reorder/move behavior; verify edge cases.
8. **M6 task views.** Implement Today, Upcoming, completed visibility, grouping and filtering; verify local-date boundaries.
9. **M7 dates and recurrence.** Implement optional due time and recurrence; test boundaries and repeated completion.
10. **M8 reminders.** Implement capability-aware local reminders and lifecycle reconciliation; verify supported native behavior and clearly label unavailable device checks.
11. **M9 search and settings.** Implement cross-list search and local settings; verify persistence and shortcuts/accessibility where applicable.
12. **M10 backup.** Implement whole-file JSON validation, export/import and transactional rollback; test invalid data leaves live state unchanged.
13. **M11 release quality.** Complete desktop polish, drag-and-drop, MSIX validation, performance checks, manual acceptance instructions, screenshots, full test/build sweep, and independent review.
14. **Final audit and handoff.** Audit decisions against the active run transcript and evidence, review the full diff, and report verified results and remaining risks to Chief. Chief owns publication.

## Execution discipline

Use milestone-sized verified increments. For each unit, state the hypothesis, change the smallest relevant surface, run its real tests/builds, and record VERIFIED, NOT VERIFIED, or INCONCLUSIVE with evidence. Fix reversible tooling issues without bypassing legal prompts or using sudo. If M0 is blocked, stop at M0 and hand back exact command output and a proposed next step. Avoid fan-out unless a task can be isolated and independently judged; the empty scaffold and sequential milestone dependencies do not justify parallel implementation now.

## Throughput checkpoint

The first checkpoint is M0. The captured machine has Flutter 3.44.0 and Dart 3.12.0, Chrome and Xcode available, but Flutter doctor reports Android licenses not accepted and CocoaPods missing. Android license acceptance is prohibited. Verify whether Android APK compilation needs accepted licenses and whether macOS builds can proceed without CocoaPods before deciding M0 is blocked. Windows requires CI evidence.
