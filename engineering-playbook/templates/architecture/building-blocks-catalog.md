# Architecture Building Blocks (ABB) & Solution Building Blocks (SBB) Catalog

*This catalog defines the approved technology stack for [Company Name]. Engineers must select from the "Approved Standard" column. Exceptions require an approved Architecture Dispensation Request.*

## 1. Application Layer
| Capability (ABB) | Description | Approved Standard (SBB) | Legacy / Deprecated (Do Not Use) |
| :--- | :--- | :--- | :--- |
| **Frontend Framework** | Component-based UI library | React / Next.js | AngularJS |
| **Backend API Framework**| High-performance async API | FastAPI (Python) | Django |
| **Backend Service** | High-concurrency systems | Go / Gin | Node.js |
| **API Gateway** | Edge routing and rate limiting | Kong / AWS API Gateway | Nginx (Manual Configs) |

## 2. Data & Analytics Layer
| Capability (ABB) | Description | Approved Standard (SBB) | Legacy / Deprecated (Do Not Use) |
| :--- | :--- | :--- | :--- |
| **Relational Database** | ACID compliant transactional storage | PostgreSQL 16 | MySQL 5.7 |
| **In-Memory Cache** | Key-value store for sessions/speed | Redis 7.0 | Memcached |
| **Data Warehouse** | OLAP queries and BI reporting | Google BigQuery | Redshift |
| **Message Broker** | High-throughput event streaming | Apache Kafka | RabbitMQ |

## 3. Infrastructure & DevOps Layer
| Capability (ABB) | Description | Approved Standard (SBB) | Legacy / Deprecated (Do Not Use) |
| :--- | :--- | :--- | :--- |
| **Container Orchestration**| Managing container lifecycles | Kubernetes (GKE/EKS) | Docker Swarm |
| **Infrastructure as Code**| Provisioning cloud resources | Terraform | Manual Console Clicks |
| **CI/CD Pipeline** | Automated build, test, and deploy | GitHub Actions | Jenkins |

## 4. Security & Identity Layer
| Capability (ABB) | Description | Approved Standard (SBB) | Legacy / Deprecated (Do Not Use) |
| :--- | :--- | :--- | :--- |
| **Identity Provider (IdP)** | AuthN and AuthZ for end users | Auth0 | Custom JWT implementations |
| **Secrets Management** | Storing DB credentials and keys | HashiCorp Vault / AWS Secrets | .env files in production |
| **WAF** | Web Application Firewall | Cloudflare | - |
