"""Default software-engineering vocabulary for VoicePrompt.

Two separate lists serve different purposes:

WHISPER_VOCABULARY (~60 terms)
  Injected into Whisper's `initial_prompt` (hard 224-token limit).
  Focuses on terms Whisper commonly mispronounces or misspells:
  dotted names (Next.js), acronyms (npm, JWT), unusual pronunciations
  (Kubernetes, Nginx, PostgreSQL), and brand names with specific casing.

VOCABULARY_BY_CATEGORY (~400 terms)
  Injected into the LLM cleanup prompt, organized by category so the
  model can see the groupings and preserve exact spelling and casing.
  No token limit here — gpt-4o-mini handles 128k context.
  Not injected for CASUAL mode (iMessage, WhatsApp, Discord).
"""

from __future__ import annotations

# ---------------------------------------------------------------------------
# Whisper initial_prompt vocabulary
# Target: stay under ~180 tokens (leaves headroom for user's personal terms)
# ---------------------------------------------------------------------------

WHISPER_VOCABULARY: list[str] = [
    # JS / TS brand names and dotted names
    "JavaScript", "TypeScript", "Node.js", "Next.js", "Nuxt.js", "Vue.js",
    "React", "SvelteKit", "Remix", "Astro",
    # Package managers and runtimes
    "npm", "npx", "pnpm", "Bun", "Deno",
    # Build / lint tools
    "webpack", "Vite", "esbuild", "ESLint", "Prettier", "Biome",
    # Databases (unusual pronunciation or acronym)
    "PostgreSQL", "MongoDB", "MySQL", "SQLite", "Redis", "Elasticsearch",
    "DynamoDB", "CockroachDB", "Supabase",
    # ORMs / query builders
    "Prisma", "TypeORM", "Sequelize", "Drizzle",
    # Cloud providers and services
    "AWS", "GCP", "Azure", "EC2", "S3", "IAM", "VPC", "ECS", "EKS",
    "Lambda", "CloudFront", "CloudFormation",
    # Container / orchestration
    "Docker", "Kubernetes", "kubectl", "Nginx", "Terraform", "Helm",
    # CI/CD
    "GitHub", "GitLab", "Bitbucket", "GitHub Actions", "CircleCI",
    # Auth / API protocols (commonly mis-spoken)
    "OAuth", "OAuth2", "JWT", "gRPC", "GraphQL", "WebSocket",
    # AI / ML tools
    "OpenAI", "Anthropic", "ChatGPT", "LangChain", "Hugging Face",
    "PyTorch", "TensorFlow", "Ollama",
    # Python tools
    "PyPI", "Pydantic", "FastAPI", "SQLAlchemy",
    # Observability
    "Prometheus", "Grafana", "Datadog", "Sentry", "OpenTelemetry",
    # Misc frequently mispronounced
    "Vercel", "Netlify", "Cloudflare", "DigitalOcean", "Homebrew",
]

# ---------------------------------------------------------------------------
# Full vocabulary by category — injected into the LLM cleanup prompt
# ---------------------------------------------------------------------------

VOCABULARY_BY_CATEGORY: dict[str, list[str]] = {

    "JavaScript / TypeScript / Node.js": [
        "JavaScript", "TypeScript", "Node.js", "Deno", "Bun", "V8",
        "JSX", "TSX", "ECMAScript", "CommonJS", "ESM", "ES2022", "ES2023",
        "npm", "npx", "yarn", "pnpm", "package.json", "package-lock.json",
        "tsconfig.json", ".eslintrc", ".prettierrc", "node_modules",
        "async/await", "Promise", "EventEmitter", "ReadableStream",
        "useEffect", "useState", "useRef", "useCallback", "useMemo",
        "useContext", "useReducer", "useLayoutEffect", "forwardRef",
    ],

    "Frontend frameworks and meta-frameworks": [
        "React", "React Native", "ReactDOM", "Next.js", "Nuxt.js", "Remix",
        "Astro", "SvelteKit", "Svelte", "Vue.js", "Angular", "Qwik",
        "SolidJS", "Preact", "Lit", "HTMX", "Alpine.js",
        "App Router", "Pages Router", "React Server Components", "RSC",
        "SSR", "SSG", "ISR", "CSR", "hydration", "partial hydration",
        "island architecture", "SPA", "MPA", "micro-frontends", "PWA",
    ],

    "Build tools and bundlers": [
        "webpack", "Vite", "esbuild", "Rollup", "Turbopack", "Parcel",
        "Babel", "SWC", "tsc", "tsup", "microbundle", "pkgroll",
        "Nx", "Turborepo", "Lerna", "Rush", "Changesets",
        "tree-shaking", "code splitting", "lazy loading", "HMR",
        "hot module replacement", "dynamic imports", "bundle analysis",
    ],

    "CSS and UI libraries": [
        "Tailwind CSS", "Tailwind", "Bootstrap", "Material UI", "MUI",
        "Chakra UI", "shadcn/ui", "Radix UI", "Headless UI", "Ant Design",
        "Mantine", "Daisy UI", "Flowbite", "Tremor",
        "styled-components", "Emotion", "CSS Modules", "CSS-in-JS",
        "SCSS", "Sass", "Less", "PostCSS", "Linaria", "vanilla-extract",
    ],

    "State management": [
        "Redux", "Redux Toolkit", "RTK Query", "Zustand", "Jotai", "Recoil",
        "MobX", "XState", "Pinia", "Valtio", "Nanostores",
        "React Query", "TanStack Query", "SWR", "Apollo Client", "urql",
    ],

    "API and data layers": [
        "tRPC", "GraphQL", "Apollo", "Apollo Server", "Relay",
        "REST", "RESTful", "gRPC", "WebSocket", "Socket.io",
        "SSE", "Server-Sent Events", "WebRTC", "MQTT", "AMQP",
        "Prisma", "Drizzle ORM", "TypeORM", "Sequelize", "Knex.js",
        "Mikro-ORM", "Objection.js", "Mongoose",
        "Zod", "Yup", "Joi", "Valibot",
        "Axios", "ky", "got", "node-fetch", "ofetch",
    ],

    "Auth and identity": [
        "JWT", "JWK", "JWKS", "OAuth", "OAuth2", "OpenID Connect", "OIDC",
        "SAML", "LDAP", "mTLS", "TLS", "SSO", "PKCE",
        "NextAuth.js", "Auth.js", "Clerk", "Auth0", "Okta",
        "Passport.js", "Lucia", "Better Auth",
    ],

    "Testing": [
        "Jest", "Vitest", "Mocha", "Chai", "Sinon", "Istanbul", "nyc", "c8",
        "Cypress", "Playwright", "Puppeteer", "Selenium", "TestCafe",
        "WebdriverIO", "Nightwatch", "Storybook", "Chromatic",
        "MSW", "Mock Service Worker", "supertest", "nock",
        "TDD", "BDD", "e2e", "unit testing", "integration testing",
        "snapshot testing", "visual regression testing",
    ],

    "Python language and tooling": [
        "Python", "CPython", "PyPy", "PyPI", "pip", "pipx", "pipenv",
        "poetry", "uv", "pdm", "rye", "conda", "virtualenv", "venv",
        "pyproject.toml", "setup.py", "requirements.txt",
        "mypy", "pyright", "ruff", "black", "isort", "flake8",
        "pylint", "bandit", "pyupgrade", "autoflake",
        "pytest", "unittest", "hypothesis", "factory-boy", "faker",
        "Click", "Typer", "argparse", "rich", "textual", "questionary",
    ],

    "Python web frameworks": [
        "Django", "Django REST Framework", "DRF", "Flask", "FastAPI",
        "Starlette", "Tornado", "Sanic", "Litestar", "Falcon", "Bottle",
        "Gunicorn", "Uvicorn", "Hypercorn", "Daphne",
        "SQLAlchemy", "Alembic", "Pydantic", "Celery", "APScheduler",
        "Dramatiq", "aiohttp", "httpx", "requests", "grpcio",
        "Boto3", "botocore",
    ],

    "Python data and ML": [
        "NumPy", "pandas", "polars", "matplotlib", "seaborn", "Plotly",
        "SciPy", "scikit-learn", "statsmodels", "XGBoost", "LightGBM",
        "PyTorch", "TensorFlow", "Keras", "JAX", "Flax",
        "Hugging Face", "Transformers", "Diffusers", "PEFT", "LoRA", "QLoRA",
        "Jupyter", "JupyterLab", "IPython", "nbformat", "nbconvert",
    ],

    "Relational databases": [
        "PostgreSQL", "MySQL", "SQLite", "MariaDB", "CockroachDB", "TiDB",
        "Neon", "PlanetScale", "Xata", "Turso", "LibSQL", "Supabase",
        "pgvector", "pgAdmin", "TablePlus", "DBeaver", "DataGrip",
        "Beekeeper Studio", "psql",
    ],

    "NoSQL and document databases": [
        "MongoDB", "Mongoose", "PyMongo", "DynamoDB", "CosmosDB",
        "Firestore", "Firebase Realtime Database", "CouchDB",
        "FaunaDB", "Deta",
    ],

    "Caching and search": [
        "Redis", "Valkey", "Memcached", "KeyDB", "Dragonfly", "Upstash",
        "Elasticsearch", "OpenSearch", "Meilisearch", "Typesense",
        "Algolia", "Solr", "Lunr",
    ],

    "Analytical and columnar databases": [
        "ClickHouse", "BigQuery", "Snowflake", "Redshift", "Databricks",
        "Trino", "Presto", "DuckDB", "Apache Spark", "Apache Flink",
        "Apache Kafka", "Apache Pulsar", "Confluent", "Kinesis",
    ],

    "Vector databases": [
        "Pinecone", "Weaviate", "Qdrant", "Chroma", "Milvus",
        "LanceDB", "Zilliz", "Faiss", "pgvector", "Marqo",
    ],

    "Graph and wide-column databases": [
        "Cassandra", "ScyllaDB", "HBase", "Bigtable",
        "Neo4j", "ArangoDB", "Neptune", "JanusGraph", "TigerGraph",
    ],

    "Cloud platforms": [
        "AWS", "GCP", "Azure", "DigitalOcean", "Linode", "Akamai",
        "Fly.io", "Railway", "Render", "Hetzner", "OVH",
        "Vercel", "Netlify", "Cloudflare",
    ],

    "AWS services": [
        "EC2", "S3", "Lambda", "CloudFront", "Route 53", "VPC", "IAM",
        "ECS", "EKS", "ECR", "RDS", "Aurora", "SQS", "SNS", "SES",
        "Cognito", "CloudWatch", "CloudFormation", "CDK", "SAM",
        "Amplify", "App Runner", "Fargate", "Bedrock", "SageMaker",
        "ElastiCache", "OpenSearch Service", "DynamoDB Streams",
    ],

    "GCP services": [
        "GKE", "GCS", "Cloud Run", "Cloud Functions", "BigQuery",
        "Pub/Sub", "Cloud SQL", "Spanner", "Firestore", "Firebase",
        "Vertex AI", "Gemini", "Cloud Build", "Artifact Registry",
        "Cloud Armor", "Cloud CDN", "Cloud Load Balancing",
    ],

    "Azure services": [
        "Azure DevOps", "Azure Functions", "Blob Storage", "AKS",
        "Cosmos DB", "App Service", "Azure OpenAI", "Azure AD",
        "Entra ID", "Azure Pipelines", "Azure Container Apps",
    ],

    "Containers and orchestration": [
        "Docker", "Docker Compose", "Dockerfile", "containerd", "Podman",
        "Kubernetes", "kubectl", "Helm", "Kustomize", "k9s", "Lens",
        "OpenShift", "Rancher", "minikube", "kind", "k3s", "k3d",
        "kubectx", "kubens", "stern", "Skaffold", "Tilt",
    ],

    "Infrastructure as code": [
        "Terraform", "OpenTofu", "Pulumi", "Ansible", "Chef", "Puppet",
        "SaltStack", "CloudFormation", "CDK", "Bicep",
        "HCL", "Packer", "Vagrant",
    ],

    "CI/CD and DevOps": [
        "GitHub Actions", "GitLab CI", "Jenkins", "CircleCI", "Travis CI",
        "Buildkite", "Drone CI", "Tekton", "Argo Workflows",
        "ArgoCD", "Flux", "Spinnaker", "Harness",
        "blue-green deployment", "canary deployment", "feature flags",
        "LaunchDarkly", "Unleash",
    ],

    "Networking and load balancing": [
        "Nginx", "Apache", "Caddy", "Traefik", "HAProxy", "Envoy",
        "Istio", "Linkerd", "Consul", "Kong", "APISIX",
        "Cloudflare Workers", "Cloudflare Pages", "Cloudflare D1",
        "Cloudflare R2", "Cloudflare KV", "Cloudflare Tunnel",
    ],

    "Observability and monitoring": [
        "Prometheus", "Grafana", "Loki", "Tempo", "Jaeger", "Zipkin",
        "OpenTelemetry", "OTEL",
        "Datadog", "New Relic", "Dynatrace", "AppDynamics",
        "Honeycomb", "Lightstep", "Signoz",
        "Sentry", "Rollbar", "Bugsnag", "LogRocket", "FullStory",
        "Highlight.io", "PagerDuty", "OpsGenie", "Statuspage",
    ],

    "Secrets and security": [
        "HashiCorp Vault", "Consul", "Nomad",
        "AWS Secrets Manager", "GCP Secret Manager", "Azure Key Vault",
        "SOPS", "age", "1Password", "Doppler", "Infisical",
        "Snyk", "Dependabot", "Renovate", "Trivy", "Grype",
        "Cosign", "Sigstore", "SLSA",
        "OWASP", "XSS", "CSRF", "SQL injection", "SSRF", "XXE",
        "mTLS", "PKI", "HSM", "KMS", "Let's Encrypt", "Certbot",
    ],

    "Version control and collaboration": [
        "Git", "GitHub", "GitLab", "Bitbucket", "Gitea", "Forgejo",
        "git-flow", "trunk-based development", "GitHub Flow", "GitOps",
        "Jira", "Linear", "Notion", "Confluence", "Asana", "ClickUp",
        "Husky", "lint-staged", "commitlint", "conventional commits",
        "semantic-release", "Changesets", "standard-version",
        "CODEOWNERS", "Dependabot", "Renovate", "pr", "LGTM",
    ],

    "Programming languages and runtimes": [
        "Python", "Rust", "Go", "Golang", "Java", "Kotlin", "Swift",
        "C++", "C#", ".NET", "Ruby", "PHP", "Elixir", "Erlang",
        "Haskell", "Scala", "Clojure", "F#", "Dart", "Flutter",
        "Lua", "Perl", "R", "Julia", "Zig", "Nim", "Crystal",
        "OCaml", "ReasonML", "Gleam", "WebAssembly", "WASM", "WASI",
        "JVM", "JRE", "JDK", "GraalVM",
    ],

    "AI and machine learning": [
        "OpenAI", "Anthropic", "Claude", "GPT-4o", "GPT-4", "GPT-3.5",
        "ChatGPT", "DALL-E", "Whisper", "Sora", "o1", "o3",
        "Gemini", "Gemini Pro", "Gemini Flash", "PaLM", "Vertex AI",
        "Mistral", "Mixtral", "Llama", "Llama 3", "Ollama", "llama.cpp",
        "LM Studio", "Jan", "AnythingLLM",
        "LangChain", "LangGraph", "LlamaIndex", "CrewAI", "AutoGen",
        "Semantic Kernel", "Haystack", "DSPy",
        "RAG", "fine-tuning", "embeddings", "tokenizer", "context window",
        "prompt engineering", "function calling", "tool use", "agentic",
        "MCP", "Model Context Protocol", "A2A",
        "MLX", "mlx-whisper", "mlx-lm", "Core ML", "ONNX", "TensorRT",
        "vLLM", "TGI", "Text Generation Inference",
        "RLHF", "DPO", "PPO", "LoRA", "QLoRA", "PEFT",
    ],

    "Package managers and version managers": [
        "npm", "npx", "yarn", "pnpm", "Homebrew", "apt", "apt-get",
        "yum", "dnf", "pacman", "nix", "winget", "scoop", "chocolatey",
        "asdf", "mise", "rtx", "fnm", "nvm", "rbenv", "pyenv",
        "rustup", "sdkman", "jabba",
    ],

    "CLI tools and shell utilities": [
        "curl", "wget", "jq", "yq", "fzf", "ripgrep", "fd", "bat",
        "eza", "lsd", "zoxide", "starship", "oh-my-zsh", "oh-my-posh",
        "tmux", "screen", "htop", "btop", "ncdu", "lsof",
        "dig", "nmap", "tcpdump", "Wireshark", "mtr",
        "gh", "glab", "hub",
        "ffmpeg", "ImageMagick", "pandoc",
        "openssl", "ssh-keygen", "rsync",
        "awscli", "gcloud", "az", "doctl", "flyctl", "wrangler",
    ],

    "Load testing and API tools": [
        "k6", "Locust", "JMeter", "Artillery", "Gatling", "Vegeta",
        "wrk", "autocannon", "hey",
        "Postman", "Insomnia", "Bruno", "Hoppscotch", "HTTPie",
    ],

    "Data formats and protocols": [
        "JSON", "YAML", "TOML", "XML", "CSV", "Protobuf", "MessagePack",
        "Avro", "Parquet", "Arrow", "HDF5", "FlatBuffers",
        "HTTP", "HTTPS", "HTTP/2", "HTTP/3", "QUIC", "WebRTC",
        "OpenAPI", "Swagger", "AsyncAPI", "JSON Schema", "JSON:API",
        "Base64", "UTF-8", "Unicode", "gzip", "brotli", "zstd",
        "Markdown", "MDX",
    ],

    "Architecture and system design patterns": [
        "microservices", "monolith", "serverless", "edge computing",
        "CQRS", "event sourcing", "saga pattern", "circuit breaker",
        "bulkhead", "idempotency", "eventual consistency",
        "CAP theorem", "BASE", "ACID", "two-phase commit",
        "pub/sub", "event-driven", "message queue",
        "SLA", "SLO", "SLI", "MTTR", "RTO", "RPO",
        "CDN", "WAF", "DDoS",
        "CI/CD", "DevOps", "DevSecOps", "GitOps", "MLOps",
        "IaC", "SRE", "Platform Engineering", "FinOps",
        "UUID", "ULID", "nanoid", "CUID", "KSUID",
        "webhook", "polling", "long-polling",
    ],
}

# Flat list derived from the above — used for deduplication against user vocab.
DEFAULT_VOCABULARY: list[str] = [
    term
    for terms in VOCABULARY_BY_CATEGORY.values()
    for term in terms
]
