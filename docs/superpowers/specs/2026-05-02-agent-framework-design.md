# Agent Framework Design

## Outcome

Phase 0 only establishes project rules and agent boundaries. It does not initialize Go, does not migrate PHP, and does not modify frontend business code.

## Core Decisions

```text
Main backend language: Go
Architecture source: open-source-first research
Delivery style: step by step, phase gated
Agent model: Superpowers process + project-specific agents
```

## Project Agents

```text
Architect Agent
API Contract Agent
Backend Worker Agent
Frontend Adapter Agent
Reviewer Agent
```

## Boundary

Legacy PHP provides business facts only. It does not define the new Go architecture.

The existing frontend is preserved and adapted later through explicit API contracts.

## Next Phase

Phase 1 is open-source research. Do not create Go module before the architecture decision record is written.
