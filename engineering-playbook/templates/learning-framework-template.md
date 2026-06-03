# Accelerated Framework Learning Template

## Target Framework: [e.g., Next.js, Django, FastAPI]
**Language:** [e.g., TypeScript, Python]
**Start Date:** YYYY-MM-DD
**Goal:** [e.g., Architect a scalable e-commerce backend in FastAPI]

---

## 1. Architectural Philosophy
*What opinions does this framework force upon you?*
- **Pattern:** [e.g., MVC, MVT, Component-based, Event-driven]
- **Opinionation Level:** [e.g., Highly opinionated (Django/Rails) vs. Unopinionated (Express/FastAPI)]
- **State Management:** [e.g., Server-side sessions, JWT, React Context]

## 2. Core Concepts Deep Dive
*Don't start coding until you understand how the framework routes traffic and handles data.*
- [ ] **Routing:** File-system based (Next.js) or Registry based (Django)?
- [ ] **Data Access (ORM):** Active Record or Data Mapper? (e.g., Prisma, Django ORM, SQLAlchemy)
- [ ] **Middleware/Interceptors:** How do we intercept requests for Auth or Logging?
- [ ] **Dependency Injection:** Does the framework provide an IoC container? (e.g., NestJS, Spring)

## 3. The "Day 2" Operations
*Tutorials skip the hard stuff. Focus on what happens when the app gets real traffic.*
- **Database Migrations:** How are schema changes generated and applied?
- **Background Jobs:** How do we queue tasks off the main thread? (e.g., Celery, BullMQ, Sidekiq)
- **Caching:** How do we implement Redis caching at the route or DB level?
- **Environment Management:** `.env` handling and secret injection.

## 4. The Sandbox Project
*Build a slice of a production app to test the edges of the framework.*
**Project Idea:** Build a paginated API with Role-Based Access Control (RBAC).
- [ ] Define 3 relational tables (User, Post, Comment)
- [ ] Generate and run DB migrations
- [ ] Implement Auth (Login/Signup)
- [ ] Create an endpoint that requires "Admin" role
- [ ] Write integration tests for the API endpoints

## 5. Deployment & CI/CD
- [ ] How is it bundled/compiled for production? (e.g., `next build`, `gunicorn`)
- [ ] Standard Dockerfile structure
- [ ] Known scalability bottlenecks (e.g., Python GIL, Node Event Loop)
