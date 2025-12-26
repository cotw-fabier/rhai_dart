# Raw Idea

## User's Description

Use @docs/async_solution_proposal.md to fix async calls across the library

## Context

The library currently has a documented limitation where async Dart functions cannot be properly called from Rhai scripts because the Dart event loop doesn't run during FFI callbacks. There's a detailed proposal document at `/home/fabier/Documents/code/rhai_dart/docs/async_solution_proposal.md` that outlines a solution using Tokio runtime and oneshot channels.

## Working Directory

`/home/fabier/Documents/code/rhai_dart`
