# Accelerated Language Learning Template

## Target Language: Go (Golang)
**Start Date:** 2026-06-11
**Goal:** Develop simple, highly concurrent network services and microservices that compile to fast native binaries.

---

## 1. The Core Paradigm
*Senior engineers don't just learn syntax; they learn the philosophy. What is this language designed to solve?*
- **Memory Management:** Garbage Collected. Engineered for very low-latency pauses, favoring predictable latency over raw throughput.
- **Concurrency Model:** Goroutines (lightweight green threads managed by the Go runtime) and Channels (for communication between goroutines). "Do not communicate by sharing memory; instead, share memory by communicating."
- **Type System:** Static, Strong. Structural typing (Interfaces are satisfied implicitly, not explicitly declared). Recently added Generics.
- **Primary Use Case:** Cloud infrastructure (Docker, Kubernetes are written in Go), CLI tools, network proxies, and high-concurrency microservices.

## 2. Tooling & Ecosystem
*Before writing code, understand how code is managed.*
- **Package Manager:** Go Modules (`go.mod`).
- **Standard Build Command:** `go build` (compiles to a single statically linked binary).
- **Standard Test Command:** `go test ./...`.
- **Linter & Formatter:** `gofmt` (strict, unconfigurable standard formatting) and `golangci-lint` (aggregator of many linters).

## 3. Idiomatic Patterns (The "Right" Way)
*How do native developers write this language? Banish idioms from your previous languages.*
- **Error Handling:** Multiple return values. Functions return `(Value, error)`. Explicit checking `if err != nil` is ubiquitous. No exceptions.
- **Object Orientation:** No classes or inheritance. Uses Structs for state and Interfaces for behavior. Composition over inheritance is strictly enforced.
- **Null Safety:** No option types. Pointers can be `nil`. Nil interface values and nil pointers must be guarded manually.

## 4. The "Senior" Sandbox Project
*Avoid "Hello World" or "Todo Apps". Build something that hits network, disk, and concurrency.*
**Project Idea:** Build a concurrent URL scraper or a CLI rate-limiter.
- [ ] Connect to an external API over HTTP using the standard `net/http` client.
- [ ] Parse JSON/XML responses using `encoding/json` structs with tags.
- [ ] Write to local disk or SQLite.
- [ ] Implement concurrency: Scrape 10 URLs at once safely utilizing Goroutines, a `sync.WaitGroup`, and an error-group (`errgroup`).
- [ ] Write table-driven unit tests (the standard Go testing paradigm).

## 5. Production Readiness Checklist
*What do you need to know before putting this language in production?*
- [ ] How to profile CPU and Memory (e.g., standard library `net/http/pprof`).
- [ ] Standard logging library (standard `log`, or structured loggers like `slog` or `zap`).
- [ ] Dealing with contexts: Passing `context.Context` everywhere to manage timeouts and cancellation.
- [ ] Docker multi-stage build optimization (e.g., `FROM scratch` containers running single statically linked binaries).
