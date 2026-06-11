# Accelerated Framework Learning Template

## Target Framework: Gin
**Language:** Go
**Start Date:** 2026-06-11
**Goal:** Build hyper-fast, low-latency microservices with minimal overhead.

---

## 1. Architectural Philosophy
*What opinions does this framework force upon you?*
- **Pattern:** Micro-framework. It is essentially an HTTP multiplexer with middleware support.
- **Opinionation Level:** Very low. You must decide on project structure, database abstraction, and configuration.
- **State Management:** Stateless APIs. JWT authentication.

## 2. Core Concepts Deep Dive
*Don't start coding until you understand how the framework routes traffic and handles data.*
- [ ] **Routing:** Radix tree-based router. Extremely fast. `router.GET("/path", handler)`.
- [ ] **Data Access (ORM):** Bring your own. `sqlx` for query building or `GORM` if an Active Record style ORM is desired.
- [ ] **Middleware/Interceptors:** Supported via `router.Use()`. Middlewares are just `gin.HandlerFunc` that call `c.Next()`.
- [ ] **Dependency Injection:** None built-in. Usually handled via manual constructor injection (passing structs to handlers).

## 3. The "Day 2" Operations
*Tutorials skip the hard stuff. Focus on what happens when the app gets real traffic.*
- **Database Migrations:** `golang-migrate` or `goose` run as CLI tools.
- **Background Jobs:** Built-in Goroutines are sufficient for in-memory tasks. Machinery or Asynq for Redis-backed queues.
- **Caching:** Standard Redis clients (`go-redis`).
- **Environment Management:** `Viper` for configuration management, or simple `os.Getenv`.

## 4. The Sandbox Project
*Build a slice of a production app to test the edges of the framework.*
**Project Idea:** Build a paginated API with Role-Based Access Control (RBAC).
- [ ] Define 3 relational tables (User, Post, Comment).
- [ ] Generate and run DB migrations using `golang-migrate`.
- [ ] Implement Auth (Login/Signup) utilizing `golang-jwt`.
- [ ] Create an endpoint that requires "Admin" role via a custom Gin middleware.
- [ ] Write integration tests for the API endpoints using `net/http/httptest`.

## 5. Deployment & CI/CD
- [ ] How is it bundled/compiled for production? `go build` creates a statically linked binary.
- [ ] Standard Dockerfile structure (Build in `golang` image, run in `scratch` or `alpine` image).
- [ ] Known scalability bottlenecks: None inherent to Gin. It can handle massive concurrency out of the box due to Go's net/http standard library.
