# Canvas Auth Logout Contract Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development for code behavior changes and superpowers:verification-before-completion before reporting completion. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the Canvas logout route owner decision by making `POST /api/canvas/v1/auth/logout` an active Canvas Next frontend call.

**Architecture:** Keep Go backend session revocation as the server truth. Add one typed Canvas Next API wrapper, one async Zustand store action, and wire the existing account dropdown to that action. Backend logout failure must preserve the browser session instead of clearing it as a silent fallback.

**Tech Stack:** Next.js 16, React 19, TypeScript, Zustand, Ant Design, Vitest, PowerShell generated docs/fact guards.

---

### Task 1: Confirm route ownership

**Files:**
- Read: `admin_back_go/internal/module/auth/transport/canvas/route.go`
- Read: `admin_back_go/internal/module/auth/transport/canvas/handler.go`
- Read: `admin_back_go/internal/module/auth/transport/canvas/handler_test.go`
- Read: `docs/knowledge/api-source-only-route-review-2026-06-07.md`

- [ ] **Step 1: Confirm backend route exists**

Expected source facts:

```text
group.POST("/logout", handler.Logout)
Logout reads Authorization bearer token through middleware.ParseBearerToken.
Logout calls authService.Logout(ctx, accessToken).
Handler test sends Authorization: Bearer canvas-token and expects logoutToken == canvas-token.
```

- [ ] **Step 2: Confirm frontend gap exists**

Expected source facts:

```text
canvas_front_next/src/services/api/auth.ts has login/refresh/send-code/login-config/captcha/users-me, but no logout wrapper.
canvas_front_next/src/stores/use-user-store.ts has clearSession() only.
canvas_front_next/src/components/layout/user-status-actions.tsx wires the menu item to clearSession().
```

### Task 2: Red store tests

**Files:**
- Modify: `canvas_front_next/src/stores/use-user-store.test.ts`

- [ ] **Step 1: Add failing tests**

Add tests that mock `@/services/api/auth.logout` and assert the store contract:

```ts
it("revokes the backend session before clearing local session", async () => {
    const logoutSession = vi.fn().mockResolvedValue(null);

    vi.doMock("@/services/api/auth", () => ({
        AUTH_TOKEN_KEY: "canvas-front-next-auth-token-v1",
        fetchCurrentUser: vi.fn(),
        refreshSession: vi.fn(),
        login: vi.fn(),
        logout: logoutSession,
    }));

    const { useUserStore } = await import("./use-user-store");
    useUserStore.setState({ token: "canvas-token", refreshToken: "canvas-refresh", user: authUser, buttonCodes: authUser.buttonCodes, isReady: true });

    await useUserStore.getState().logout();

    expect(logoutSession).toHaveBeenCalledWith("canvas-token");
    expect(useUserStore.getState()).toMatchObject({ token: "", refreshToken: "", user: null, buttonCodes: [], isLoading: false, isReady: true });
});

it("keeps the browser session when backend logout fails", async () => {
    const logoutSession = vi.fn().mockRejectedValue(new Error("logout failed"));

    vi.doMock("@/services/api/auth", () => ({
        AUTH_TOKEN_KEY: "canvas-front-next-auth-token-v1",
        fetchCurrentUser: vi.fn(),
        refreshSession: vi.fn(),
        login: vi.fn(),
        logout: logoutSession,
    }));

    const { useUserStore } = await import("./use-user-store");
    useUserStore.setState({ token: "canvas-token", refreshToken: "canvas-refresh", user: authUser, buttonCodes: authUser.buttonCodes, isReady: true });

    await expect(useUserStore.getState().logout()).rejects.toThrow("logout failed");
    expect(useUserStore.getState()).toMatchObject({ token: "canvas-token", refreshToken: "canvas-refresh", user: authUser, isLoading: false, isReady: true });
});
```

- [ ] **Step 2: Run RED**

```powershell
cd E:\admin_go\canvas_front_next
npm run test -- src/stores/use-user-store.test.ts
```

Expected before implementation:

```text
FAIL because useUserStore.getState().logout is not a function.
```

### Task 3: Red API wrapper test

**Files:**
- Create: `canvas_front_next/src/services/api/auth.test.ts`

- [ ] **Step 1: Add failing API wrapper test**

```ts
import { beforeEach, describe, expect, it, vi } from "vitest";
import { apiPost } from "@/services/api/request";
import { logout } from "./auth";

vi.mock("@/services/api/request", () => ({
    apiGet: vi.fn(),
    apiPost: vi.fn(),
}));

describe("canvas auth API", () => {
    beforeEach(() => {
        vi.clearAllMocks();
        vi.mocked(apiPost).mockResolvedValue(null);
    });

    it("posts logout with the current access token", async () => {
        await logout("canvas-token");

        expect(apiPost).toHaveBeenCalledWith("/api/canvas/v1/auth/logout", null, "canvas-token");
    });
});
```

- [ ] **Step 2: Run RED**

```powershell
cd E:\admin_go\canvas_front_next
npm run test -- src/services/api/auth.test.ts
```

Expected before implementation:

```text
FAIL because auth.ts does not export logout.
```

### Task 4: Implement the minimal Canvas logout path

**Files:**
- Modify: `canvas_front_next/src/services/api/auth.ts`
- Modify: `canvas_front_next/src/stores/use-user-store.ts`
- Modify: `canvas_front_next/src/components/layout/user-status-actions.tsx`

- [ ] **Step 1: Add typed API wrapper**

In `auth.ts` add:

```ts
export async function logout(token: string) {
    return apiPost<null>("/api/canvas/v1/auth/logout", null, token);
}
```

- [ ] **Step 2: Add async store action**

In `use-user-store.ts` import `logout as logoutSession`, add `logout: () => Promise<void>` to `UserStore`, reset `isLoading` in `clearSession()`, and implement:

```ts
logout: async () => {
    const token = get().token;
    if (!token) {
        get().clearSession();
        return;
    }
    set({ isLoading: true });
    try {
        await logoutSession(token);
        get().clearSession();
    } catch (error) {
        set({ isLoading: false });
        throw error;
    }
},
```

- [ ] **Step 3: Wire account menu to async logout**

In `user-status-actions.tsx`, read the store `logout` action instead of `clearSession()`. Use Ant Design `App.useApp()` to show the backend error on rejection:

```ts
const { message } = App.useApp();
const logout = useUserStore((state) => state.logout);
const onLogout = () => {
    logout().catch((error) => {
        message.error(error instanceof Error ? error.message : "退出登录失败");
    });
};
```

Use `onClick: onLogout` for the logout menu item.

- [ ] **Step 4: Run GREEN**

```powershell
cd E:\admin_go\canvas_front_next
npm run test -- src/stores/use-user-store.test.ts src/services/api/auth.test.ts
```

Expected:

```text
Both test files pass.
```

### Task 5: Guard the source boundary

**Files:**
- Modify: `canvas_front_next/tests/shared/canvas-auth-boundary.test.ts`

- [ ] **Step 1: Add source assertions**

Extend the auth boundary tests to require:

```ts
expect(authApi).toContain("/api/canvas/v1/auth/logout");
expect(userStore).toContain("logoutSession(token)");
expect(userStore).toContain("clearSession: () => set({ token: \"\", refreshToken: \"\", user: null, buttonCodes: [], routePaths: new Set<string>(), isReady: true, isLoading: false })");
```

Add a focused read of `src/components/layout/user-status-actions.tsx`:

```ts
const userStatusActions = readFileSync(join(process.cwd(), "src", "components", "layout", "user-status-actions.tsx"), "utf8");
expect(userStatusActions).toContain("state.logout");
expect(userStatusActions).not.toContain("state.clearSession");
```

- [ ] **Step 2: Run guard**

```powershell
cd E:\admin_go\canvas_front_next
npm run test -- tests/shared/canvas-auth-boundary.test.ts
```

Expected:

```text
PASS.
```

### Task 6: Regenerate API inventory and route-review docs

**Files:**
- Modify generated: `docs/knowledge/frontend-api-inventory-2026-06-07.md`
- Modify generated: `docs/knowledge/frontend-backend-api-drift-2026-06-07.md`
- Modify generated: `docs/knowledge/api-source-only-route-review-2026-06-07.md`
- Modify generated: `docs/knowledge/full-stack-module-map-2026-06-07.md`

- [ ] **Step 1: Run exporters in order**

```powershell
cd E:\admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\export-frontend-api-inventory.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-frontend-backend-api-drift.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-api-source-only-route-review.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-full-stack-module-map.ps1 -OutputDate 2026-06-07
```

Expected source facts after regeneration:

```text
frontend exact backend API calls increases by 1.
backend source-only rows decreases by 1.
owner-decision-required routes decreases from 3 to 2.
/api/canvas/v1/auth/logout is not in the source-only review table.
```

### Task 7: Knowledge/status/fact guard sync

**Files:**
- Create: `docs/knowledge/canvas-auth-logout-contract-review-2026-06-07.md`
- Modify: `docs/knowledge/README.md`
- Modify: `docs/knowledge/current-runtime-knowledge.md`
- Modify: `docs/knowledge/runtime-source-map.md`
- Modify: `docs/status/current-status.md`
- Modify: `docs/status/known-issues.md`
- Modify: `scripts/check-runtime-doc-facts.ps1`

- [ ] **Step 1: Add review artifact**

Record the decision:

```text
Canvas logout is an active frontend gap now closed.
Backend route revokes the bearer session.
Frontend calls POST /api/canvas/v1/auth/logout before clearing local state.
Backend logout failure preserves local state.
Remaining API-DRIFT-001 owner decisions are Admin AI agent test and Admin user status.
```

- [ ] **Step 2: Update fact guard**

Change expected owner-decision counts from `3` to `2`, require the new review artifact to be indexed, require frontend inventory to include `POST /api/canvas/v1/auth/logout`, and require source-only review not to include `/api/canvas/v1/auth/logout`.

- [ ] **Step 3: Run root fact checker**

```powershell
cd E:\admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema
```

Expected:

```text
PASS.
```

### Task 8: Final verification

**Files:**
- Verify current working tree only; do not revert unrelated existing changes.

- [ ] **Step 1: Run Canvas targeted tests**

```powershell
cd E:\admin_go\canvas_front_next
npm run test -- src/stores/use-user-store.test.ts src/services/api/auth.test.ts tests/shared/canvas-auth-boundary.test.ts tests/shared/canvas-rbac-shell.test.ts
npm run typecheck
```

- [ ] **Step 2: Run root governance gates**

```powershell
cd E:\admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected:

```text
Targeted tests pass.
Typecheck passes.
Runtime fact checker passes.
Governance checker passes.
git diff --check has no whitespace errors; CRLF warnings are acceptable if no whitespace error is reported.
```
