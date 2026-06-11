# Accelerated Language Learning Template

## Target Language: TypeScript
**Start Date:** 2026-06-11
**Goal:** Master writing scalable, type-safe full-stack applications and backend services in the Node.js/Deno ecosystem.

---

## 1. The Core Paradigm
*Senior engineers don't just learn syntax; they learn the philosophy. What is this language designed to solve?*
- **Memory Management:** Garbage Collected (V8 Engine).
- **Concurrency Model:** Single-threaded Event Loop (Node.js). Asynchronous I/O via Promises and `async/await`. Worker Threads are available for CPU-bound tasks.
- **Type System:** Static, Gradual, Structural (duck typing). TypeScript is a superset of JavaScript that compiles down to JS, adding compile-time type safety.
- **Primary Use Case:** Frontend web development, backend web servers (Node.js/Deno), serverless functions, and cross-platform desktop apps (Electron).

## 2. Tooling & Ecosystem
*Before writing code, understand how code is managed.*
- **Package Manager:** `npm`, `yarn`, `pnpm`, or `bun`.
- **Standard Build Command:** `tsc` (TypeScript Compiler) or bundlers like `esbuild`, `webpack`, or `vite`.
- **Standard Test Command:** `jest`, `vitest`, or Node's native test runner.
- **Linter & Formatter:** `eslint` (linting) and `prettier` (formatting).

## 3. Idiomatic Patterns (The "Right" Way)
*How do native developers write this language? Banish idioms from your previous languages.*
- **Error Handling:** Exceptions (`try/catch`). Asynchronous errors must be caught, or they result in unhandled promise rejections.
- **Object Orientation:** Supports full class-based OOP, but idiomatic modern TS leans heavily functional: utilizing pure functions, higher-order functions, and immutability.
- **Null Safety:** Strict Null Checks (`"strictNullChecks": true` in `tsconfig.json`). Uses union types (e.g., `string | null | undefined`) and optional chaining (`obj?.prop`) to handle nulls safely.

## 4. The "Senior" Sandbox Project
*Avoid "Hello World" or "Todo Apps". Build something that hits network, disk, and concurrency.*
**Project Idea:** Build a concurrent API aggregator or webhook dispatcher.
- [ ] Connect to external APIs over HTTP using `fetch` or `axios`.
- [ ] Parse JSON responses and validate runtime shapes using `zod`.
- [ ] Write to local disk using Node's `fs/promises`.
- [ ] Implement concurrency: Aggregate 10 APIs simultaneously using `Promise.all()` or `Promise.allSettled()`.
- [ ] Write table-driven/parameterized unit tests using `jest` or `vitest`.

## 5. Production Readiness Checklist
*What do you need to know before putting this language in production?*
- [ ] How to profile CPU and Memory (e.g., Chrome DevTools integration with Node.js, V8 heap snapshots).
- [ ] Understanding Event Loop blocking and identifying synchronous bottlenecks.
- [ ] Standard logging library (`pino` or `winston` for JSON logging).
- [ ] Docker multi-stage build optimization (transpiling TS to JS in a build stage, only copying JS to the final production image).
