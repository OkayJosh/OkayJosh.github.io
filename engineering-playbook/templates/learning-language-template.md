# Accelerated Language Learning Template

## Target Language: [e.g., Go, Rust, Zig]
**Start Date:** YYYY-MM-DD
**Goal:** [e.g., Be able to write a production-ready concurrent CLI tool in 2 weeks]

---

## 1. The Core Paradigm
*Senior engineers don't just learn syntax; they learn the philosophy. What is this language designed to solve?*
- **Memory Management:** [e.g., Garbage Collected vs. Borrow Checker vs. Manual]
- **Concurrency Model:** [e.g., OS Threads, Goroutines, async/await, Actor model]
- **Type System:** [e.g., Static/Strong, Structural typing, Duck typing]
- **Primary Use Case:** [e.g., Systems programming, high-concurrency microservices, data science]

## 2. Tooling & Ecosystem
*Before writing code, understand how code is managed.*
- **Package Manager:** [e.g., Cargo, Go Modules, NPM]
- **Standard Build Command:** `[e.g., cargo build --release]`
- **Standard Test Command:** `[e.g., go test ./...]`
- **Linter & Formatter:** [e.g., rustfmt & clippy, gofmt]

## 3. Idiomatic Patterns (The "Right" Way)
*How do native developers write this language? Banish idioms from your previous languages.*
- **Error Handling:** [e.g., Return values (`Result<T, E>`) vs. Exceptions (`try/catch`)]
- **Object Orientation:** [e.g., Structs + Traits (Rust), Structs + Interfaces (Go), Classes (Java)]
- **Null Safety:** [e.g., Option types, Nil checks]

## 4. The "Senior" Sandbox Project
*Avoid "Hello World" or "Todo Apps". Build something that hits network, disk, and concurrency.*
**Project Idea:** Build a highly concurrent URL scraper or a CLI rate-limiter.
- [ ] Connect to an external API over HTTP
- [ ] Parse JSON/XML responses
- [ ] Write to local disk or SQLite
- [ ] Implement concurrency (scraping 10 URLs at once safely)
- [ ] Write table-driven unit tests

## 5. Production Readiness Checklist
*What do you need to know before putting this language in production?*
- [ ] How to profile CPU and Memory (e.g., pprof)
- [ ] Standard logging library
- [ ] Dependency vulnerability scanning
- [ ] Docker multi-stage build optimization
