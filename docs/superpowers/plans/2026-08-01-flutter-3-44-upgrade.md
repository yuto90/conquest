# Flutter 3.44.8 Upgrade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade Conquest from Flutter 2.8.1 / Dart 2.15.1 to Flutter 3.44.8 / Dart 3.12.2 and make Android, iOS, and Web builds pass while preserving app behavior and identifiers.

**Architecture:** Pin Flutter with FVM, resolve the approved Riverpod/hooks/codegen dependency set with the new SDK, and migrate platform scaffolding by comparing a fresh Flutter 3.44.8 project rather than overwriting the app in place. Keep the existing Provider/ChangeNotifier implementation and apply only compatibility edits to Dart code and tests.

**Tech Stack:** Flutter 3.44.8, Dart 3.12.2, FVM 2.2.6, Gradle/Android Gradle Plugin, Kotlin, Xcode, Web bootstrap, Riverpod generator, build_runner

## Global Constraints

- Flutter is pinned to exactly `3.44.8` and Dart to `3.12.2`.
- Dart SDK constraint is `>=3.12.0 <4.0.0`.
- Provider / ChangeNotifier state management remains unchanged; Riverpod migration is tracked separately in GitHub Issue #1.
- Android minimum API is 24 and iOS deployment target is 13.
- Preserve `com.conquest.conquest`, existing icons, launch assets, web assets, and game behavior.
- Do not run `flutter create .` against the app checkout; generate a reference project in a temporary directory and selectively apply its scaffolding.
- Keep the existing `lib/main.dart` app title change.
- Do not include unrelated refactoring or changes to the Codex environment scripts.
- Existing user changes in `lib/main.dart`, `pubspec.yaml`, and `pubspec.lock` are in scope for this approved upgrade and must be preserved semantically.

---

### Task 1: Pin Flutter 3.44.8 and resolve dependencies

**Files:**
- Modify: `.fvm/fvm_config.json`
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`

**Interfaces:**
- Consumes: Existing Flutter package manifest and FVM project configuration.
- Produces: A Flutter 3.44.8 project whose dependency graph resolves under Dart 3.12.2 and includes the approved latest-compatible Riverpod/hooks/codegen packages.

- [ ] **Step 1: Capture the pre-change failure and current dirty scope**

Run:

~~~bash
git status --short --branch
fvm flutter --version
fvm flutter pub get
~~~

Expected: FVM reports Flutter 2.8.1 / Dart 2.15.1, and `pub get` fails because the existing `flutter_lints ^2.0.0` and related dependency set requires a newer SDK. Do not modify files while recording this baseline.

- [ ] **Step 2: Install and pin Flutter 3.44.8 with FVM**

Run:

~~~bash
fvm use 3.44.8 --skip-setup
fvm flutter --version
~~~

Expected: FVM downloads or selects Flutter 3.44.8 and reports Dart 3.12.2. The project configuration records `3.44.8`; do not change the global FVM default.

- [ ] **Step 3: Update the Dart SDK constraint and dependency declarations**

Change only the SDK constraint and approved dependency declarations in `pubspec.yaml`:

~~~yaml
environment:
  sdk: ">=3.12.0 <4.0.0"
~~~

Use Flutter's resolver to choose the newest mutually compatible versions rather than manually guessing versions:

~~~bash
fvm flutter pub add provider
fvm flutter pub add flutter_hooks
fvm flutter pub add flutter_riverpod
fvm flutter pub add riverpod_annotation
fvm flutter pub add --dev flutter_lints build_runner riverpod_generator
~~~

Expected: Provider remains available for current source imports; Riverpod, hooks, annotations, generator, lints, and build_runner are declared; no state-management source files are changed in this task.

- [ ] **Step 4: Resolve and generate the lockfile**

Run:

~~~bash
fvm flutter pub get
fvm dart run build_runner build --delete-conflicting-outputs
~~~

Expected: Both commands exit `0`, `pubspec.lock` records Dart/Flutter constraints compatible with the new SDK, and any generated files are consistent. If the absolute latest package versions conflict, retain the newest resolver-selected compatible set and record the exact versions in the commit description.

- [ ] **Step 5: Verify the dependency task**

Run:

~~~bash
fvm flutter --version
fvm flutter pub outdated
git diff --check -- pubspec.yaml pubspec.lock .fvm/fvm_config.json
~~~

Expected: Flutter 3.44.8 / Dart 3.12.2 is reported; `pub outdated` contains no resolvable upgrade that is required by this task; diff check exits `0`.

- [ ] **Step 6: Commit the toolchain and dependency update**

~~~bash
git add -- .fvm/fvm_config.json pubspec.yaml pubspec.lock
git commit -m "chore: Flutter 3.44.8へ更新"
~~~

Do not stage platform files or Dart source changes in this commit.

---

### Task 2: Migrate Android scaffolding

**Files:**
- Modify: `android/settings.gradle`
- Modify: `android/build.gradle`
- Modify: `android/app/build.gradle`
- Modify: `android/gradle/wrapper/gradle-wrapper.properties`
- Modify: `android/gradle.properties`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Preserve: `android/app/src/main/res/`, `android/app/src/main/kotlin/`, application ID, and app-specific manifest entries

**Interfaces:**
- Consumes: Flutter 3.44.8 SDK and a temporary Flutter 3.44.8 reference project generated with organization `com.conquest` and project name `conquest`.
- Produces: Android project files using current Flutter Gradle Plugin DSL, API 24 minimum, and `com.conquest.conquest` application identity.

- [ ] **Step 1: Generate a reference Android project outside the repository**

Run:

~~~bash
reference_root="$(mktemp -d)"
fvm flutter create --project-name conquest --org com.conquest --platforms android,ios,web "$reference_root"
printf '%s\n' "$reference_root"
~~~

Expected: A complete Flutter 3.44.8 reference project exists in the printed temporary directory. Do not copy the directory wholesale into Conquest.

- [ ] **Step 2: Compare old and reference Android files**

Run:

~~~bash
diff -u android/settings.gradle "$reference_root/android/settings.gradle" || true
diff -u android/build.gradle "$reference_root/android/build.gradle" || true
diff -u android/app/build.gradle "$reference_root/android/app/build.gradle" || true
diff -u android/gradle/wrapper/gradle-wrapper.properties "$reference_root/android/gradle/wrapper/gradle-wrapper.properties" || true
~~~

Identify the reference Plugin DSL, Gradle, AGP, Kotlin, compile SDK, and target SDK values before editing. The `|| true` is only for displaying differences; it must not hide a build failure later.

- [ ] **Step 3: Apply only the Android infrastructure migration**

Port the reference settings and plugin declarations into the tracked Android files. Keep the generated project identity and replace any generated app-specific values with:

~~~groovy
applicationId "com.conquest.conquest"
minSdkVersion 24
~~~

Keep the existing Kotlin activity package and app resources. Do not replace launcher icons, splash assets, or custom manifest metadata with reference assets.

- [ ] **Step 4: Run Android static/build verification**

Run:

~~~bash
fvm flutter build apk --debug
~~~

Expected: Debug APK build exits `0`, and the build output identifies `com.conquest.conquest` with no Gradle plugin application error. If the build fails, classify the error as Gradle/AGP, JDK, Android SDK, or Dart compilation before making one focused change.

- [ ] **Step 5: Commit Android migration**

~~~bash
git add -- android
git commit -m "chore: AndroidをFlutter 3.44構成へ更新"
~~~

Before committing, verify `git diff -- android/app/src/main/res android/app/src/main/kotlin` is empty or contains only explicitly required compatibility changes.

---

### Task 3: Migrate iOS and Web scaffolding

**Files:**
- Modify: `ios/Runner.xcodeproj/project.pbxproj`
- Modify: `ios/Runner.xcodeproj/project.xcworkspace/contents.xcworkspacedata`
- Modify: `ios/Flutter/Debug.xcconfig`
- Modify: `ios/Flutter/Release.xcconfig`
- Modify: `ios/Runner/AppDelegate.swift`
- Modify: `ios/Runner/Info.plist`
- Modify: `web/index.html`
- Modify: `web/manifest.json`
- Modify: `web/icons/` and `web/favicon.png` only when required by the current template format
- Preserve: iOS app icon set, launch screen assets, Bundle Identifier, web title, favicon, and manifest identity

**Interfaces:**
- Consumes: The Flutter 3.44.8 reference project from Task 2 and the existing Conquest platform identity/assets.
- Produces: iOS deployment target 13 and Web bootstrap compatible with Flutter 3.44.8.

- [ ] **Step 1: Compare iOS and Web reference files**

Run:

~~~bash
diff -u ios/Runner.xcodeproj/project.pbxproj "$reference_root/ios/Runner.xcodeproj/project.pbxproj" || true
diff -u ios/Runner/AppDelegate.swift "$reference_root/ios/Runner/AppDelegate.swift" || true
diff -u web/index.html "$reference_root/web/index.html" || true
diff -u web/manifest.json "$reference_root/web/manifest.json" || true
~~~

Use the same reference directory created in Task 2. If a new shell does not retain `reference_root`, locate the existing temporary reference directory before generating another one.

- [ ] **Step 2: Apply iOS project updates**

Port only Flutter/Xcode integration changes and set every tracked iOS deployment target to `13.0`. Preserve:

~~~text
PRODUCT_BUNDLE_IDENTIFIER = com.conquest.conquest;
~~~

Preserve the AppIcon asset catalog, LaunchImage/LaunchScreen resources, and app-specific Info.plist values. Do not introduce a new bundle identifier or replace the app assets with template defaults.

- [ ] **Step 3: Apply Web bootstrap updates**

Update the generated Flutter bootstrap and metadata to the reference format. Keep the user-visible title `conquest`, existing favicon, and manifest icons. Do not add an unrelated web UI change.

- [ ] **Step 4: Build iOS and Web**

Run:

~~~bash
fvm flutter build ios --simulator --no-codesign
fvm flutter build web --release
~~~

Expected: Both builds exit `0`; iOS uses deployment target 13 or newer and Web emits a release bundle. If iOS tooling is unavailable, record the exact Xcode/device prerequisite instead of changing project settings to bypass it.

- [ ] **Step 5: Verify identity and assets before commit**

Run:

~~~bash
rg -n "com\\.conquest\\.conquest|IPHONEOS_DEPLOYMENT_TARGET|<title>|favicon|Icon-" ios web android
git diff --stat -- ios web
~~~

Expected: The bundle/application identifiers remain `com.conquest.conquest`, all iOS deployment target entries are 13.0 or higher, the Web title remains `conquest`, and no app icon set is unexpectedly replaced.

- [ ] **Step 6: Commit iOS and Web migration**

~~~bash
git add -- ios web
git commit -m "chore: iOSとWebをFlutter 3.44構成へ更新"
~~~

---

### Task 4: Update Dart compatibility and the Conquest smoke test

**Files:**
- Modify: `lib/base.dart` only for Flutter API compatibility errors
- Modify: `lib/main.dart` only for Flutter API compatibility errors; preserve the existing `conquest` title
- Modify: `test/widget_test.dart`

**Interfaces:**
- Consumes: Updated SDK, dependencies, and platform projects from Tasks 1–3.
- Produces: The existing Provider/ChangeNotifier behavior under Dart 3.12.2 plus a deterministic Conquest widget smoke test.

- [ ] **Step 1: Run formatter, analyzer, and the existing test to capture failures**

Run:

~~~bash
fvm dart format --output=none --set-exit-if-changed lib test
fvm flutter analyze
fvm flutter test
~~~

Expected: The old counter test fails because the app is not a counter app, and any analyzer/compiler failures identify the exact Dart or Flutter API incompatibilities to fix.

- [ ] **Step 2: Apply only required Dart API compatibility fixes**

For each reported API error, update the smallest affected expression. For example, if Flutter 3.44 rejects legacy `ButtonStyle` color parameters, use the current names while preserving the same colors and shape:

~~~dart
style: ElevatedButton.styleFrom(
  backgroundColor: model.pickColor('$baseIndex'),
  foregroundColor: Colors.white,
)
~~~

Do not replace Provider with Riverpod, restructure `HomeModel`, or alter game state transitions.

- [ ] **Step 3: Replace the stale counter test with a deterministic Conquest smoke test**

Replace the counter assertions in `test/widget_test.dart` with a test that pumps `MyApp`, verifies the initial ready prompt, and confirms the legacy counter UI is absent:

~~~dart
testWidgets('shows the Conquest ready screen', (WidgetTester tester) async {
  await tester.pumpWidget(MyApp());

  expect(find.text('T A P  T O  P L A Y'), findsOneWidget);
  expect(find.byType(Scaffold), findsOneWidget);
  expect(find.text('Counter'), findsNothing);
});
~~~

Do not advance fake time or start the periodic game timer in this smoke test; timer lifecycle migration belongs to Issue #1.

- [ ] **Step 4: Verify Dart behavior**

Run:

~~~bash
fvm dart format --output=none --set-exit-if-changed lib test
fvm flutter analyze
fvm flutter test
~~~

Expected: All commands exit `0` with no analyzer errors and the Conquest smoke test passes.

- [ ] **Step 5: Commit Dart/test compatibility changes**

~~~bash
git add -- lib test
git commit -m "fix: Flutter 3.44互換のテストとDartコードへ更新"
~~~

---

### Task 5: Full cross-platform verification and handoff

**Files:**
- Modify: None unless a verification failure identifies a scoped fix in the files above
- Test: Flutter analyzer, widget tests, Android/iOS/Web builds

**Interfaces:**
- Consumes: All committed changes from Tasks 1–4.
- Produces: Evidence that Flutter 3.44.8 is pinned and Android, iOS Simulator, Web, and Codex setup all work.

- [ ] **Step 1: Run the complete verification suite**

Run:

~~~bash
fvm flutter --version
fvm flutter pub get
fvm dart run build_runner build --delete-conflicting-outputs
fvm dart format --output=none --set-exit-if-changed lib test
fvm flutter analyze
fvm flutter test
fvm flutter build apk --debug
fvm flutter build ios --simulator --no-codesign
fvm flutter build web --release
bash .agent-shared/scripts/codex-worktree-setup.sh
bash .agent-shared/scripts/codex-worktree-cleanup.test.sh
~~~

Expected: Every command exits `0`; Flutter reports 3.44.8 / Dart 3.12.2; setup runs pub get and build_runner; cleanup remains non-destructive.

- [ ] **Step 2: Verify platform constraints and identity**

Run:

~~~bash
rg -n "minSdkVersion|compileSdk|targetSdk|IPHONEOS_DEPLOYMENT_TARGET|PRODUCT_BUNDLE_IDENTIFIER|applicationId" android ios
git diff --check HEAD~4..HEAD
git status --short --branch
~~~

Expected: Android minimum is API 24, iOS target is 13.0 or newer, identifiers remain `com.conquest.conquest`, and no unintentional whitespace or unrelated files are present. Existing user changes may be included in the approved upgrade commits but must not be lost.

- [ ] **Step 3: Record any unavailable host verification**

If Android emulator, iOS Simulator, or Xcode is unavailable, record the exact unavailable tool and retain successful build evidence. Do not lower platform minimums or skip a build by changing the project configuration.

- [ ] **Step 4: Review the final diff**

Run:

~~~bash
git diff --stat origin/main...HEAD
git diff --name-only origin/main...HEAD
git log --oneline --decorate origin/main..HEAD
~~~

Expected: The diff is limited to Flutter SDK/dependency files, Android/iOS/Web scaffolding, Dart compatibility/test changes, and the already-approved Codex environment/docs. Issue #1 remains the separate Riverpod migration scope.
