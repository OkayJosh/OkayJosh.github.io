# Accelerated Framework Learning Template

## Target Framework: NestJS
**Language:** TypeScript
**Start Date:** 2026-06-11
**Goal:** Build highly scalable, structured, and maintainable enterprise Node.js applications.

---

## 1. Architectural Philosophy
*What opinions does this framework force upon you?*
- **Pattern:** N-Tier Architecture (Controllers, Services, Modules). Heavily inspired by Angular's architecture.
- **Opinionation Level:** Highly opinionated. Enforces a strict modular structure and Dependency Injection.
- **State Management:** Stateless APIs.

## 2. Core Concepts Deep Dive
*Don't start coding until you understand how the framework routes traffic and handles data.*
- [ ] **Routing:** Annotation/Decorator based (`@Controller`, `@Get`).
- [ ] **Data Access (ORM):** Unopinionated, but TypeORM and Prisma are the most integrated/popular choices.
- [ ] **Middleware/Interceptors:** Very rich lifecycle. Includes Middlewares, Guards (for Auth/Authz), Interceptors (for request/response transformation), and Exception Filters.
- [ ] **Dependency Injection:** The core of the framework. Classes are marked as `@Injectable()` and provided in module arrays.

## 3. The "Day 2" Operations
*Tutorials skip the hard stuff. Focus on what happens when the app gets real traffic.*
- **Database Migrations:** Handled by the ORM (e.g., TypeORM migrations or Prisma CLI).
- **Background Jobs:** First-class support for BullMQ (Redis-based job queue) and Cron jobs via `@nestjs/schedule`.
- **Caching:** Built-in `CacheModule` with Redis support.
- **Environment Management:** `@nestjs/config` module utilizing `joi` or `class-validator` for schema validation.

## 4. The Sandbox Project
*Build a slice of a production app to test the edges of the framework.*
**Project Idea:** Build a paginated API with Role-Based Access Control (RBAC).
- [ ] Define 3 relational tables (User, Post, Comment) using TypeORM entities or Prisma schemas.
- [ ] Generate and run DB migrations.
- [ ] Implement Auth using `@nestjs/passport` and JWTs.
- [ ] Create an endpoint that requires "Admin" role utilizing custom NestJS `Guards`.
- [ ] Write integration tests using `@nestjs/testing`.

## 5. Deployment & CI/CD
- [ ] How is it bundled/compiled for production? Compiles to standard JavaScript (`nest build`). Runs via `node dist/main.js`.
- [ ] Standard Dockerfile structure (Install dependencies, build TS, then copy only `dist` and `node_modules` for production).
- [ ] Known scalability bottlenecks: V8 Event Loop blocking. NestJS adds slight overhead compared to pure Express/Fastify due to DI and decorators, though it runs fast enough for most use cases (can use Fastify as the underlying engine for better throughput).
