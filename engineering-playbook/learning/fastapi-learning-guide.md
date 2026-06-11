# Accelerated Framework Learning Template

## Target Framework: FastAPI
**Language:** Python
**Start Date:** 2026-06-11
**Goal:** Architect a scalable, highly concurrent, and type-safe backend API.

---

## 1. Architectural Philosophy
*What opinions does this framework force upon you?*
- **Pattern:** Micro-framework. Heavily relies on decorators for routing.
- **Opinionation Level:** Unopinionated about project structure and database, but highly opinionated about API schema generation and input validation.
- **State Management:** Stateless APIs. JWT is the standard for stateless authentication.

## 2. Core Concepts Deep Dive
*Don't start coding until you understand how the framework routes traffic and handles data.*
- [ ] **Routing:** Registry based using `@app.get()` decorators on functions. `APIRouter` for modularizing routes.
- [ ] **Data Access (ORM):** Bring your own. SQLAlchemy (Data Mapper) is the industry standard for relational databases in Python.
- [ ] **Middleware/Interceptors:** Utilizes ASGI middleware. You can add functions with `@app.middleware("http")` to intercept requests.
- [ ] **Dependency Injection:** First-class, built-in feature utilizing `Depends()`. Used heavily for database sessions and auth dependencies.

## 3. The "Day 2" Operations
*Tutorials skip the hard stuff. Focus on what happens when the app gets real traffic.*
- **Database Migrations:** Alembic (tightly integrated with SQLAlchemy).
- **Background Jobs:** `BackgroundTasks` provided for very simple tasks. For real scale, Celery or ARQ (asyncio Redis Queue).
- **Caching:** `fastapi-cache` utilizing Redis for declarative caching on endpoints.
- **Environment Management:** `pydantic-settings` (inherits from `pydantic.BaseModel` to validate `.env` files).

## 4. The Sandbox Project
*Build a slice of a production app to test the edges of the framework.*
**Project Idea:** Build a paginated API with Role-Based Access Control (RBAC).
- [ ] Define 3 relational tables (User, Post, Comment) using SQLAlchemy declarative base.
- [ ] Generate and run DB migrations with Alembic.
- [ ] Implement Auth (Login/Signup) returning JWTs.
- [ ] Create an endpoint that requires "Admin" role using FastAPI `Depends()`.
- [ ] Write integration tests for the API endpoints using `TestClient` or `httpx.AsyncClient`.

## 5. Deployment & CI/CD
- [ ] How is it bundled/compiled for production? Run behind `gunicorn` with `uvicorn` workers (ASGI).
- [ ] Standard Dockerfile structure (multistage, slim python image, non-root user).
- [ ] Known scalability bottlenecks: Blocking the event loop. Make sure any CPU bound tasks or synchronous I/O use `run_in_threadpool`.
