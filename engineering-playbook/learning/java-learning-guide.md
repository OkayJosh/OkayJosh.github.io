# Accelerated Language Learning Template

## Target Language: Java
**Start Date:** 2026-06-11
**Goal:** Architect scalable, maintainable enterprise backends utilizing modern JVM capabilities.

---

## 1. The Core Paradigm
*Senior engineers don't just learn syntax; they learn the philosophy. What is this language designed to solve?*
- **Memory Management:** Garbage Collected (JVM GC). Very mature, with tunable collectors like G1, ZGC, and Shenandoah designed for low latency or high throughput.
- **Concurrency Model:** OS Threads mapping 1:1 with JVM threads historically. Modern Java (JDK 21+) introduces Virtual Threads (Project Loom) for lightweight, high-concurrency modeling similar to goroutines.
- **Type System:** Static, Strong typing. Features generics (with type erasure) and recently added records and sealed classes for algebraic data types.
- **Primary Use Case:** Enterprise backend systems, large-scale distributed systems, and Android development.

## 2. Tooling & Ecosystem
*Before writing code, understand how code is managed.*
- **Package Manager:** Maven or Gradle (dependency management, build lifecycle, and plugins).
- **Standard Build Command:** `mvn clean install` or `gradlew build`.
- **Standard Test Command:** `mvn test` or `gradlew test`.
- **Linter & Formatter:** Checkstyle, SpotBugs, SonarLint, and IDE-based formatters (IntelliJ).

## 3. Idiomatic Patterns (The "Right" Way)
*How do native developers write this language? Banish idioms from your previous languages.*
- **Error Handling:** Exceptions. Historically distinguished between Checked and Unchecked (Runtime) exceptions. Modern idiom heavily favors Unchecked exceptions to avoid boilerplate `throws` clauses.
- **Object Orientation:** Strict OOP. Everything is in a class. Modern Java embraces functional paradigms with Streams API, Lambdas, and immutable `record` classes.
- **Null Safety:** `NullPointerException` is the billion-dollar mistake. Idiomatic Java now avoids null returns, utilizing `java.util.Optional<T>` to explicitly model absence of a value.

## 4. The "Senior" Sandbox Project
*Avoid "Hello World" or "Todo Apps". Build something that hits network, disk, and concurrency.*
**Project Idea:** Build a concurrent stream processor that ingests HTTP events and aggregates them.
- [ ] Implement an HTTP client to fetch streaming data or paginated results.
- [ ] Parse JSON using Jackson or Gson.
- [ ] Utilize Virtual Threads (JDK 21) or an `ExecutorService` to process events concurrently.
- [ ] Aggregate results in a thread-safe data structure (e.g., `ConcurrentHashMap`).
- [ ] Write integration tests using Testcontainers to spin up real external dependencies.

## 5. Production Readiness Checklist
*What do you need to know before putting this language in production?*
- [ ] How to profile CPU and Memory (e.g., JFR - Java Flight Recorder, VisualVM).
- [ ] JVM tuning flags (Heap size `-Xms`, `-Xmx`, and choosing the right GC algorithm).
- [ ] Standard logging framework ecosystem (SLF4J facade over Logback).
- [ ] Containerizing JVM apps securely (distroless images, understanding JVM container awareness limits).
