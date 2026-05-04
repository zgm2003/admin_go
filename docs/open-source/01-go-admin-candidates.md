# Go Admin Candidates

## Status

Phase 1 research draft. This is not implementation approval.

Main backend language is already Go. This document only compares domestic/open-source admin and Go backend references so we do not invent architecture in a vacuum.

## Candidate 1: gin-vue-admin

Source:

```text
https://github.com/flipped-aurora/gin-vue-admin
https://www.gin-vue-admin.com/
```

Why it matters:

```text
Domestic Go + Vue admin project
Gin-based backend
RBAC / menu / API permission / dynamic router patterns are close to our target
Good source for admin feature boundaries
```

What to learn:

```text
Admin module decomposition
RBAC resource modeling
Menu and API permission relation
Frontend dynamic route shape
Code generation boundaries, but only after core is stable
```

What to reject:

```text
Do not copy the whole scaffold
Do not adopt generator-first workflow in Phase 2
Do not let generated CRUD shape define our architecture
Do not import every middleware just because the project has it
```

Fit for E:\admin_go:

```text
Adopt now: research RBAC/menu/API permission model
Adopt later: generator ideas if CRUD modules become repetitive
Do not adopt now: full framework wholesale
```

## Candidate 2: go-admin-team/go-admin

Source:

```text
https://github.com/go-admin-team/go-admin
```

Why it matters:

```text
Domestic Go admin ecosystem
Gin-oriented admin backend patterns
Good reference for permission/menu/admin CRUD conventions
```

What to learn:

```text
Module packaging
Middleware order
Admin API grouping
Permission naming style
```

What to reject:

```text
Do not copy directory names blindly
Do not absorb framework-specific abstractions before we know our RBAC model
```

Fit for E:\admin_go:

```text
Adopt now: compare with gin-vue-admin for RBAC and module shape
Adopt later: scaffold conventions if simple enough
```

## Candidate 3: GoFrame / gfast-style admin projects

Source:

```text
https://goframe.org/
Search target: GoFrame admin / gfast / GF admin implementations
```

Why it matters:

```text
GoFrame is popular in domestic Go backend circles
Admin projects around it often have mature permission/menu thinking
```

What to learn:

```text
Config structure
Layer discipline
Error and response conventions
```

What to reject:

```text
Do not switch from Gin to a large framework without strong evidence
Do not import framework-heavy patterns into a simple Gin service
```

Fit for E:\admin_go:

```text
Adopt now: compare architecture ideas only
Do not adopt now: runtime framework switch
```

## Candidate 4: go-zero admin examples

Source:

```text
https://go-zero.dev/
Search target: go-zero admin / RBAC / permission examples
```

Why it matters:

```text
go-zero is a domestic Go framework with strong engineering discipline
Useful as architecture discipline reference even if we do not use it as runtime
```

What to learn:

```text
API contract discipline
Service boundary thinking
Config and middleware conventions
```

What to reject:

```text
Do not bring RPC/microservice shape into Phase 2
Do not over-split modules before the admin core exists
```

Fit for E:\admin_go:

```text
Adopt now: boundary discipline
Do not adopt now: microservice framework structure
```

## Current checkpoint decision

The current direction stays:

```text
Runtime: Gin-based Go backend
Architecture: learn from domestic admin projects, especially gin-vue-admin and go-admin-team
Constraint: no Go module initialization until RBAC and frontend permission research is recorded
```
