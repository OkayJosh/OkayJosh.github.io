# Accelerated Language Learning Template

## Target Language: C#
**Start Date:** 2026-06-11
**Goal:** Build high-performance, cross-platform cloud services and APIs.

---

## 1. The Core Paradigm
*Senior engineers don't just learn syntax; they learn the philosophy. What is this language designed to solve?*
- **Memory Management:** Garbage Collected (.NET CLR). Highly optimized generational GC. Supports manual memory management in `unsafe` blocks if absolutely necessary.
- **Concurrency Model:** OS Threads wrapped in the Task Parallel Library (TPL). Relies heavily on the `async / await` state machine compiler feature for non-blocking I/O.
- **Type System:** Static, Strong. Extremely rich type system including generics, structs (value types), classes (reference types), delegates, and pattern matching.
- **Primary Use Case:** Enterprise backends, cloud-native microservices, desktop apps (WPF/MAUI), and game development (Unity).

## 2. Tooling & Ecosystem
*Before writing code, understand how code is managed.*
- **Package Manager:** NuGet.
- **Standard Build Command:** `dotnet build` or `dotnet publish`.
- **Standard Test Command:** `dotnet test`.
- **Linter & Formatter:** Roslyn analyzers (built into the compiler), `.editorconfig` for formatting enforcement.

## 3. Idiomatic Patterns (The "Right" Way)
*How do native developers write this language? Banish idioms from your previous languages.*
- **Error Handling:** Exceptions. `try/catch/finally`. 
- **Object Orientation:** Object-oriented but multiparadigm. Heavy use of Interfaces for Dependency Injection. Modern C# leans functional with `record` types for immutable data, Pattern Matching, and LINQ (Language Integrated Query) for declarative data manipulation.
- **Null Safety:** Nullable Reference Types. Enabled by default in modern .NET (`<Nullable>enable</Nullable>`). The compiler warns if a reference type that isn't explicitly marked as nullable (`string?`) might be assigned a null value.

## 4. The "Senior" Sandbox Project
*Avoid "Hello World" or "Todo Apps". Build something that hits network, disk, and concurrency.*
**Project Idea:** Build a resilient HTTP forward proxy or rate-limiter.
- [ ] Connect to external APIs using `HttpClient` and `IHttpClientFactory`.
- [ ] Process incoming streams of JSON data using `System.Text.Json`.
- [ ] Implement concurrency using `async/await` and `Task.WhenAll`.
- [ ] Apply resilience patterns (Retry, Circuit Breaker) using the Polly library.
- [ ] Write unit tests utilizing `xUnit` and `Moq` or `NSubstitute`.

## 5. Production Readiness Checklist
*What do you need to know before putting this language in production?*
- [ ] How to profile CPU and Memory (e.g., `dotnet-trace`, `dotnet-dump`, `dotnet-counters`).
- [ ] Standard logging (built-in `Microsoft.Extensions.Logging` injected into classes, often backed by Serilog for structured logging).
- [ ] Dependency injection container basics (built into modern .NET Core).
- [ ] Docker multi-stage build optimization (`dotnet publish -c Release` trimming and single-file executables).
