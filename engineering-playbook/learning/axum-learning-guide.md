# Accelerated Framework Learning Template

## Target Framework: Axum
**Language:** Rust
**Start Date:** 2026-06-11
**Goal:** Architect incredibly robust and fast web backends with compile-time safety guarantees.

---

## 1. Architectural Philosophy
*What opinions does this framework force upon you?*
- **Pattern:** Micro-framework.
- **Opinionation Level:** Low. Unopinionated about business logic and databases, but highly opinionated about utilizing the `tower` ecosystem for middleware and `tokio` for async.
- **State Management:** Shared state is managed via `Arc` (Atomic Reference Counted) smart pointers injected into handlers via the `State` extractor.

## 2. Core Concepts Deep Dive
*Don't start coding until you understand how the framework routes traffic and handles data.*
- [ ] **Routing:** Declarative routing using `Router::new().route()`.
- [ ] **Data Access (ORM):** `sqlx` (compile-time checked query builder) or `Diesel` (ORM).
- [ ] **Middleware/Interceptors:** `tower::Service` architecture. Powerful, reusable middleware stack across the Rust ecosystem.
- [ ] **Dependency Injection:** Handled via the `State` extractor mechanism (type-safe dependency injection at route registration).

## 3. The "Day 2" Operations
*Tutorials skip the hard stuff. Focus on what happens when the app gets real traffic.*
- **Database Migrations:** `sqlx-cli` for declarative migrations.
- **Background Jobs:** `tokio::spawn` for simple tasks. Factis or custom Redis/Postgres workers for distributed queues.
- **Caching:** `moka` (in-memory) or Redis via `redis-rs`.
- **Environment Management:** `dotenvy` for `.env` loading and `config` crate.

## 4. The Sandbox Project
*Build a slice of a production app to test the edges of the framework.*
**Project Idea:** Build a paginated API with Role-Based Access Control (RBAC).
- [ ] Define 3 relational tables (User, Post, Comment).
- [ ] Generate and run DB migrations with `sqlx-cli`.
- [ ] Implement Auth (Login/Signup) returning JWTs.
- [ ] Create an endpoint that requires "Admin" role using a custom `FromRequest` extractor or Tower middleware.
- [ ] Write integration tests utilizing `axum::test_helpers`.

## 5. Deployment & CI/CD
- [ ] How is it bundled/compiled for production? `cargo build --release`.
- [ ] Standard Dockerfile structure (Multi-stage using `cargo-chef` to cache dependencies, running a stripped binary in an Alpine or distroless container).
- [ ] Known scalability bottlenecks: None inherent to Axum. The main bottleneck is developer velocity due to strict compile-time checks and long compile times.
