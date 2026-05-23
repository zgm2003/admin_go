# Admin App Phase 3 Real Login Shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 Flutter App 真实完成“登录 -> 拉取当前用户 -> 首页/我的页展示当前用户 -> 退出登录回到登录页”的闭环。

**Architecture:** 继续沿用当前 `Riverpod + GoRouter + Dio + SharedPreferences` 骨架，不新增 H5/小程序，不改后端接口。登录成功后只写本地会话，页面层统一通过当前用户 provider 读取 `/api/app/v1/users/me`，首页和我的页共享同一份会话数据；退出登录先调用 `/api/app/v1/auth/logout`，再清理本地会话并回到登录页。

**Tech Stack:** Flutter 3.41.7, Dart 3.11.5, Riverpod 3, GoRouter 17, Dio + Retrofit, SharedPreferences, flutter_test.

---

## File Structure

- Modify: `lib/src/domain/use_cases/authentication_use_case.dart`
  - Add a current-user use case so UI 只依赖 domain 层，不直接摸 repository。
- Modify: `lib/src/core/di/parts/use_cases.dart`
  - Register the new current-user use case provider.
- Create: `lib/src/presentation/core/application_state/current_user_provider/current_user_provider.dart`
  - Single source of truth for the current user page state.
- Modify: `lib/src/presentation/features/home/view/home_page.dart`
  - Replace placeholder content with real current-user summary and logout action.
- Modify: `lib/src/presentation/features/profile/view/profile_page.dart`
  - Replace placeholder content with real current-user detail card.
- Modify: `lib/src/presentation/features/authentication/login/riverpod/login_provider.dart`
  - Keep login loading state, and invalidate current-user state after successful login.
- Modify: `lib/src/presentation/core/application_state/logout_provider/logout_provider.dart`
  - Remove fake delay, call real logout, clear session, invalidate current-user state.
- Modify: `lib/src/core/localization/intl_zh.arb`
  - Add labels for current-user / avatar / user id / loading / error / retry.
- Modify: `lib/src/core/localization/intl_en.arb`
  - Mirror the new labels in English.
- Regenerate: `lib/src/core/gen/l10n/*`
  - Refresh generated localization classes after ARB changes.
- Modify: `test/widget_test.dart`
  - Update startup/home/profile expectations to the new authenticated shell behavior.
- Create: `test/current_user_provider_test.dart`
  - Verify the current-user provider resolves the App API user and surfaces failures cleanly.

---

### Task 1: Add current-user use case and provider

**Files:**
- Modify: `lib/src/domain/use_cases/authentication_use_case.dart`
- Modify: `lib/src/core/di/parts/use_cases.dart`
- Create: `lib/src/presentation/core/application_state/current_user_provider/current_user_provider.dart`
- Test: `test/current_user_provider_test.dart`

- [ ] **Step 1: Write the failing test**

Create a provider test that overrides the auth repository with a fake current-user response and asserts the provider yields `UserEntity(id: 7, nickname: '移动端用户', avatar: 'avatar.png')`.

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
flutter test test/current_user_provider_test.dart -r expanded
```

Expected: compile or test failure because `currentUserProvider` and/or the new use case do not exist yet.

- [ ] **Step 3: Write minimal implementation**

Add `CurrentUserUseCase` to the auth use-case file, wire it in `use_cases.dart`, and create a `FutureProvider<UserEntity?>`-style current-user provider that calls the use case.

- [ ] **Step 4: Run test to verify it passes**

Run:

```powershell
flutter test test/current_user_provider_test.dart -r expanded
```

Expected: PASS.

---

### Task 2: Render real current user in Home and Profile

**Files:**
- Modify: `lib/src/presentation/features/home/view/home_page.dart`
- Modify: `lib/src/presentation/features/profile/view/profile_page.dart`
- Modify: `lib/src/core/localization/intl_zh.arb`
- Modify: `lib/src/core/localization/intl_en.arb`
- Regenerate: `lib/src/core/gen/l10n/*`
- Test: `test/widget_test.dart`

- [ ] **Step 1: Write the failing widget assertions**

Update the widget test so HomePage and ProfilePage both display the current user's nickname and avatar placeholder/title from an overridden current-user provider, not the old static placeholder copy.

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
flutter test test/widget_test.dart -r expanded
```

Expected: FAIL because the pages still render template-style static content.

- [ ] **Step 3: Write minimal implementation**

Make HomePage show a compact current-user card plus logout button, and ProfilePage show a richer account card with id, nickname, and avatar. Keep the layout simple, mobile-first, and accessible.

- [ ] **Step 4: Run test to verify it passes**

Run:

```powershell
flutter test test/widget_test.dart -r expanded
```

Expected: PASS.

---

### Task 3: Wire login/logout to the shared session state

**Files:**
- Modify: `lib/src/presentation/features/authentication/login/riverpod/login_provider.dart`
- Modify: `lib/src/presentation/core/application_state/logout_provider/logout_provider.dart`
- Test: `test/app_api_baseline_test.dart` or a new provider test if needed

- [ ] **Step 1: Write the failing test**

Add a small provider test that proves login success invalidates the current-user provider and logout clears the cached session without a fake delay.

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
flutter test test/app_api_baseline_test.dart -r expanded
```

Expected: FAIL on the new session-state assertion.

- [ ] **Step 3: Write minimal implementation**

Invalidate `currentUserProvider` after successful login/logout, remove the artificial `Future.delayed`, and keep logout as a real `/auth/logout` call plus cache cleanup.

- [ ] **Step 4: Run test to verify it passes**

Run:

```powershell
flutter test test/app_api_baseline_test.dart -r expanded
```

Expected: PASS.

---

### Task 4: Refresh generated code and project gates

**Files:**
- Modify: generated localization files under `lib/src/core/gen/l10n/*`
- Modify: any generated Riverpod files changed by build_runner
- Test: `flutter test`
- Test: `flutter analyze`

- [ ] **Step 1: Run generation/build**

Run:

```powershell
flutter gen-l10n
flutter pub run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 2: Run the full Flutter gates**

Run:

```powershell
flutter test
flutter analyze
```

Expected: both pass with no new issues.

- [ ] **Step 3: Commit**

```powershell
git add -A
git commit -m "feat: bind app login shell to real user session"
```
