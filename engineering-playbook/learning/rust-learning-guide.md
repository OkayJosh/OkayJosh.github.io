# Accelerated Language Learning Template

## Target Language: Rust
**Start Date:** 2026-06-11
**Goal:** Write safe, blazingly fast systems software with zero-cost abstractions and memory safety without a garbage collector.

---

## 1. The Core Paradigm
*Senior engineers don't just learn syntax; they learn the philosophy. What is this language designed to solve?*
- **Memory Management:** Borrow Checker & Ownership Model. Memory is managed at compile time; no garbage collector, no manual `malloc/free`.
- **Concurrency Model:** OS Threads (std::thread) and async/await for cooperative multitasking. "Fearless concurrency" - data races are caught at compile time.
- **Type System:** Static, Strong. Extremely expressive. Traits, lifetimes, and algebraic data types (enums containing data).
- **Primary Use Case:** Systems programming, WebAssembly, high-performance network services, embedded systems, and tooling.

## 2. Tooling & Ecosystem
*Before writing code, understand how code is managed.*
- **Package Manager:** Cargo (`Cargo.toml`). The gold standard for modern language tooling.
- **Standard Build Command:** `cargo build` (debug) or `cargo build --release` (optimized).
- **Standard Test Command:** `cargo test`.
- **Linter & Formatter:** `rustfmt` (formatting) and `clippy` (an incredibly helpful linter).

## 3. Idiomatic Patterns (The "Right" Way)
*How do native developers write this language? Banish idioms from your previous languages.*
- **Error Handling:** Return values. `Result<T, E>` enum. The `?` operator is used to propagate errors elegantly. Panics are reserved for unrecoverable state, not normal errors.
- **Object Orientation:** Structs hold data, Traits define behavior (similar to interfaces). No inheritance, pure composition and trait implementation.
- **Null Safety:** No `null`. The `Option<T>` enum models the presence (`Some`) or absence (`None`) of a value. The compiler forces you to handle the `None` case via pattern matching.

## 4. The "Senior" Sandbox Project
*Avoid "Hello World" or "Todo Apps". Build something that hits network, disk, and concurrency.*
**Project Idea:** Build a highly concurrent URL scraper utilizing `tokio`.
- [ ] Connect to an external API over HTTP using the `reqwest` crate.
- [ ] Parse JSON responses using `serde` and `serde_json`.
- [ ] Write to local disk using `tokio::fs`.
- [ ] Implement concurrency: Scrape 10 URLs at once using `tokio::spawn` and `FuturesUnordered`.
- [ ] Write unit tests and async tests (`#[tokio::test]`).

## 5. Production Readiness Checklist
*What do you need to know before putting this language in production?*
- [ ] How to profile CPU and Memory (e.g., flamegraphs, Valgrind, or platform-specific tools like `perf`).
- [ ] Standard logging library (`tracing` or `log` facade).
- [ ] Dependency vulnerability scanning (`cargo audit`).
- [ ] Docker multi-stage build optimization (managing the long compilation times via `cargo-chef` or Docker layer caching).
