# Stdin `sources` vs previous STF step outputs

## CRITICAL rule

Docker STF stdin `sources` maps **only workflow input step names** to their
**resolved values**. Output from earlier STF steps in the same workflow is
**never** copied into `sources`.

| Data origin | Available in Docker stdin? | How to reach the container |
|-------------|---------------------------|----------------------------|
| Workflow **input step** (File, Fetch, Library, …) | **Yes** — under `sources.{step_name}` | Resolved server-side before `docker run` |
| Earlier **STF step output** in the same workflow | **No** — not in `sources` | Map with workflow `input_mappings` using `$steps[n]` (Effect / JS STF) or `$input.*` after mapping |
| Workflow top-level `$input` | **Yes** — under `input` | `input_mappings` from `$input.*` |

Inside the container, read:

- `sources["my_file_step"]` — input-step data only
- `input["records"]` — whatever the workflow mapped into this STF's `input` object

Do **not** expect `sources["previous_stf_step"]` or `sources["fetcher"]` when
`fetcher` was an STF step name. That key appears only when `fetcher` is an
**input step** name.

## Where `$steps[n]` belongs

`$steps[n]` (0-based index of a prior STF step's output) is a **workflow
engine variable** used in:

- STF step `input_mappings` (`Variable` source type)
- Effect step mappings
- QuickJS STF code at runtime (`$input` is built from those mappings)

It is **not** a Docker stdin field. The workflow engine evaluates mappings
**before** serializing stdin JSON; the container receives the **result** in
`input`, not the raw `$steps` expression.

```
Workflow engine                          Docker container stdin
─────────────────                        ──────────────────────
input_steps → resolved → sources{}  ──►  sources (input steps only)
$input / $steps[n] → input_mappings ──►  input (mapped fields)
                                         api_token, workspace_id, …
```

## Example: two-step workflow (Fetch input → STF validate → Docker process)

### Workflow definition (conceptual)

```javascript
d6e_create_workflow({
  name: "fetch-validate-process",
  input_steps: [
    {
      name: "catalog_fetch",
      source: { type: "Fetch", url: "https://api.example.com/catalog" },
    },
  ],
  stf_steps: [
    {
      name: "validator",
      stf_version_id: "{js_validator_version_id}",
      input_mappings: [
        { source: { type: "Variable", value: "$sources.catalog_fetch" }, target: "raw_catalog" },
      ],
    },
    {
      name: "processor",
      stf_version_id: "{docker_processor_version_id}",
      input_mappings: [
        // ✅ Previous STF output → input (NOT sources)
        { source: { type: "Variable", value: "$steps[0].valid_items" }, target: "items" },
        { source: { type: "Variable", value: "$input.batch_id" }, target: "batch_id" },
      ],
    },
  ],
  effect_steps: [],
});
```

### Stdin received by the Docker STF (`processor`)

```json
{
  "workspace_id": "019b…",
  "stf_id": "019c…",
  "caller": "019d…",
  "api_url": "http://host.docker.internal:8080",
  "api_token": "<signed>",
  "input": {
    "items": [
      { "sku": "A1", "qty": 10 },
      { "sku": "B2", "qty": 3 }
    ],
    "batch_id": "batch-2024-01"
  },
  "sources": {
    "catalog_fetch": {
      "products": [
        { "sku": "A1", "name": "Widget" },
        { "sku": "B2", "name": "Gadget" }
      ]
    }
  }
}
```

Notes:

- `sources.catalog_fetch` — raw Fetch input step body (still present for **every**
  STF step in the workflow).
- `input.items` — came from `$steps[0].valid_items` (JS validator output), **not**
  from `sources`.
- There is **no** `sources.validator` key — `validator` was an STF step name.

### Correct Python access pattern

```python
def main():
    doc = json.load(sys.stdin)
    user_input = doc["input"]
    sources = doc.get("sources", {})

    # ✅ Mapped from $steps[0] via input_mappings
    items = user_input.get("items", [])

    # ✅ Input step (Fetch) — only if this STF needs the raw fetch
    raw_catalog = sources.get("catalog_fetch", {})

    # ❌ WRONG — earlier STF outputs are not keyed by STF step name
    # validator_out = sources.get("validator")  # always missing / wrong
```

## Example: instant-run with input sources

`POST /api/v1/stfs/instant-run` (or `d6e_instant_run_stf`) accepts a `sources`
object with the **same semantics** as workflow execution: keys must be input step
names and values must already be resolved shapes (not `$steps` expressions).

```json
{
  "stf_id": "{docker_stf_id}",
  "input": { "operation": "process", "limit": 100 },
  "sources": {
    "invoice_pdf": {
      "filename": "inv.pdf",
      "content_type": "application/pdf",
      "size": 12345,
      "data": "<base64>"
    }
  }
}
```

You cannot pass `"sources": { "step_0": { "$ref": "$steps[0]" } }` — the API does
not evaluate workflow variables in `sources`; supply literal resolved values for
testing.

## Common mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| Expect `sources["prior_stf"]` when `prior_stf` is an STF step | Key missing or stale test data | Map `$steps[n].field` → `input` target |
| Put `$steps[0].x` in a File/Fetch input step | Invalid workflow definition | Use `input_mappings` on the Docker STF step |
| Log entire stdin assuming it lists all upstream data | Confusion in debugging | Log `input` keys and `sources` keys separately |
| Local `docker run` test omits `sources` | Works locally, fails in workflow with File input | Include representative `sources` in test JSON |

## Related docs

- Binary File inputs in `sources`: [storage-and-files.md](./storage-and-files.md)
- Workflow variable paths (`$input`, `$sources.*`, `$steps[n]`): main
  [SKILL.md](../SKILL.md) — "Wiring into a workflow"
- Chained workflow example: [examples.md](../examples.md) — "Multi-Step Workflow
  with Input Sources"
