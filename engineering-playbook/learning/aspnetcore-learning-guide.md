# Accelerated Framework Learning Template

## Target Framework: ASP.NET Core
**Language:** C#
**Start Date:** 2026-06-11
**Goal:** Architect secure, high-performance web APIs in the .NET ecosystem.

---

## 1. Architectural Philosophy
*What opinions does this framework force upon you?*
- **Pattern:** MVC or Minimal APIs (modern route-to-handler mapping).
- **Opinionation Level:** Opinionated but flexible. Microsoft provides strong conventions for DI, Configuration, and Logging out of the box.
- **State Management:** Stateless APIs typically with JWT, though server-side session middleware exists.

## 2. Core Concepts Deep Dive
*Don't start coding until you understand how the framework routes traffic and handles data.*
- [ ] **Routing:** Minimal APIs (`app.MapGet()`) or Controller-based (`[ApiController]`).
- [ ] **Data Access (ORM):** Entity Framework Core (Data Mapper).
- [ ] **Middleware/Interceptors:** The ASP.NET Core request pipeline consists of composed middleware delegates (`app.Use()`).
- [ ] **Dependency Injection:** First-class citizen. Configured in `Program.cs` (`builder.Services.AddScoped()`).

## 3. The "Day 2" Operations
*Tutorials skip the hard stuff. Focus on what happens when the app gets real traffic.*
- **Database Migrations:** EF Core Code-First Migrations (`dotnet ef migrations add`).
- **Background Jobs:** `IHostedService` / `BackgroundService` for long-running background tasks. Hangfire for persistent queues.
- **Caching:** `IMemoryCache` (in-memory) or `IDistributedCache` (Redis).
- **Environment Management:** `appsettings.json`, `appsettings.Development.json`, and the `IOptions<T>` pattern for strongly-typed config.

## 4. The Sandbox Project
*Build a slice of a production app to test the edges of the framework.*
**Project Idea:** Build a paginated API with Role-Based Access Control (RBAC).
- [ ] Define 3 relational tables (User, Post, Comment) using EF Core `DbContext`.
- [ ] Generate and run DB migrations.
- [ ] Implement Auth (Login/Signup) using ASP.NET Core Identity or custom JWT issuance.
- [ ] Create an endpoint that requires "Admin" role using `[Authorize(Roles = "Admin")]` or Policy-based authorization.
- [ ] Write integration tests for the API endpoints using `WebApplicationFactory`.

## 5. Deployment & CI/CD
- [ ] How is it bundled/compiled for production? `dotnet publish` creates cross-platform binaries (runs embedded Kestrel server).
- [ ] Standard Dockerfile structure (Alpine based, using separate SDK image for build vs ASP.NET runtime image).
- [ ] Known scalability bottlenecks: Not usually bottlenecked by framework performance (Kestrel is extremely fast), but by database queries (N+1 issues in EF Core).
