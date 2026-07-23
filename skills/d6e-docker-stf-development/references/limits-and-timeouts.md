# Execution limits and timeouts

Docker STF runs are bounded at several layers. Confusing them leads to
surprise timeouts or queueing behavior.

## Container execution timeout

| Setting | Default | Env var |
|---------|---------|---------|
| Per-container execution | **300 s (5 min)** | `STF_DOCKER_TIMEOUT_SECS` |
| Combined stdout + stderr | **10 MB** | `STF_DOCKER_MAX_OUTPUT_BYTES` |
| Simultaneous containers (per API process) | **2** | `STF_DOCKER_MAX_CONCURRENT` |

Operator overrides are documented in d6e `.env.example` (`STF_DOCKER_MEMORY_LIMIT`,
`STF_DOCKER_CPUS`, `STF_DOCKER_PIDS_LIMIT` are optional per-container caps).

## Concurrency queue vs execution timeout

When all container slots are in use, new STF runs **wait on a semaphore**
(`STF_DOCKER_MAX_CONCURRENT`, default 2) before `docker run` starts.

**Important:** The execution timeout (`STF_DOCKER_TIMEOUT_SECS`) starts **after**
a slot is acquired — not while waiting in the queue. Queue wait time does not
count against the 5-minute container budget.

```
Request accepted
    → (optional) wait for semaphore slot     ← NOT counted in STF_DOCKER_TIMEOUT_SECS
    → acquire slot
    → docker run + stdin write + container work ← timeout starts here
    → parse stdout / enforce output size cap
    → release slot
```

Long queue waits are acceptable because async intent jobs poll for results
instead of holding an HTTP connection open indefinitely. The API logs when
queue wait exceeds 10 seconds.

**Scaling note:** The concurrency limit is **per API process**. Multiple API
replicas multiply the effective host capacity (e.g. 2 replicas × 2 slots = 4
containers).

## stdout contract (10 MB, single JSON)

The engine reads **the entire stdout stream** and parses it as **one** JSON
document with a top-level `output` key.

- Maximum captured stdout/stderr per stream: 10 MB (configurable)
- Any log lines, progress text, or a second JSON object on stdout →
  `Invalid Docker output format`
- Send all diagnostics to **stderr**; reserve stdout for the result only

On failure, write a human-readable message to stderr and exit non-zero — d6e
surfaces stderr as the step error (there is no error JSON contract on stdout).

## Workflow wall time vs container timeout

These are **different** clocks:

| Layer | Typical cap | What it limits |
|-------|-------------|----------------|
| Docker STF container | 5 min (`STF_DOCKER_TIMEOUT_SECS`) | Single container run after slot acquire |
| Execute-by-intent (sync / job runner) | **~30 min** (`INTENT_JOB_TIMEOUT_MS`, default 1_800_000) | Entire LLM-driven workflow including multiple steps, tool calls, and queue waits |
| MCP tool timeout (workspace setting) | 5 min default (`mcp_timeout_ms`) | Individual MCP tool invocation |

A workflow may legally spend minutes queued for a Docker slot and then up to
5 minutes inside the container, while the **overall intent job** still has a
~30-minute wall-clock budget for all steps combined.

Design long-running work accordingly:

- Keep Docker STF logic focused; finish within the 5-minute container window
- Split heavy SaaS or file work into non-Docker steps (see
  [external-apis.md](./external-apis.md))
- For LLM-driven runs that may exceed sync HTTP limits, use async intent jobs
  (poll `GET …/execute-by-intent/jobs/{id}`)

## Operator tuning (self-hosted)

```bash
# .env on the d6e API host
STF_DOCKER_MAX_CONCURRENT=2      # simultaneous containers per API process
STF_DOCKER_TIMEOUT_SECS=300      # seconds after slot acquire
# STF_DOCKER_MAX_OUTPUT_BYTES=10485760
```

Increasing `STF_DOCKER_TIMEOUT_SECS` does **not** extend the ~30-minute intent
job wall clock — adjust both layers independently if needed.
