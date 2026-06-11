# Accelerated Language Learning Template

## Target Language: Python
**Start Date:** 2026-06-11
**Goal:** Master writing robust, production-grade concurrent backend services and data pipelines in Python.

---

## 1. The Core Paradigm
*Senior engineers don't just learn syntax; they learn the philosophy. What is this language designed to solve?*
- **Memory Management:** Garbage Collected (Reference Counting with a cyclic garbage collector).
- **Concurrency Model:** OS Threads (limited by the Global Interpreter Lock - GIL), multiprocessing (for CPU-bound tasks), and `asyncio` (cooperative multitasking via an event loop for I/O-bound tasks).
- **Type System:** Dynamic, Strong typing. Modern Python heavily utilizes optional static type hints (PEP 484) checked via `mypy`.
- **Primary Use Case:** Data Science, Machine Learning, scripting, backend web services, and automation.

## 2. Tooling & Ecosystem
*Before writing code, understand how code is managed.*
- **Package Manager:** `pip` (standard), `poetry` or `uv` (modern, robust dependency management and lockfiles).
- **Standard Build Command:** Python is interpreted, so no build step is strictly required. For distribution, `python -m build` is used.
- **Standard Test Command:** `pytest` (the de facto standard testing framework).
- **Linter & Formatter:** `ruff` (extremely fast rust-based linter/formatter replacing flake8/black/isort), `mypy` (static type checker).

## 3. Idiomatic Patterns (The "Right" Way)
*How do native developers write this language? Banish idioms from your previous languages.*
- **Error Handling:** Exceptions (`try/except/finally`). "Easier to Ask for Forgiveness than Permission" (EAFP) is often preferred over "Look Before You Leap" (LBYL).
- **Object Orientation:** Classes with multiple inheritance. Uses "dunder" methods (e.g., `__init__`, `__str__`) to implement protocols and operator overloading. Dataclasses (`@dataclass`) are preferred for data models.
- **Null Safety:** No built-in null safety. Uses `None` heavily. Modern code uses `Optional[T]` or `T | None` in type hints to signal possible null values.

## 4. The "Senior" Sandbox Project
*Avoid "Hello World" or "Todo Apps". Build something that hits network, disk, and concurrency.*
**Project Idea:** Build a highly concurrent URL scraper utilizing `asyncio` and `aiohttp`.
- [ ] Connect to an external API over HTTP asynchronously.
- [ ] Parse JSON responses using `pydantic` models for validation.
- [ ] Write scraped results to local disk or SQLite asynchronously using `aiofiles` or `aiosqlite`.
- [ ] Implement concurrency (scraping 10 URLs at once safely using `asyncio.gather` or semaphores).
- [ ] Write parametrized unit tests using `pytest` and `pytest-asyncio`.

## 5. Production Readiness Checklist
*What do you need to know before putting this language in production?*
- [ ] How to profile CPU and Memory (e.g., `cProfile`, `py-spy`, `memory_profiler`).
- [ ] Standard logging library (`logging` module, or structured JSON logging with `structlog`).
- [ ] Dependency vulnerability scanning (e.g., `pip-audit`, Dependabot).
- [ ] Docker multi-stage build optimization (minimizing image size, handling `requirements.txt` vs `poetry.lock`, ensuring no root user).
