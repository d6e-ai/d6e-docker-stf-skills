# Storage and file inputs for Docker STFs

Docker STFs do **not** download workspace files by calling the files API from
inside the container. The `api_token` (`AuthContext::InternalStf`) cannot
access `GET /api/v1/workspaces/{id}/files/{id}/download` or related storage
routes — those require editor permission on `StorageFile` with a real user
subject.

See [external-apis.md](./external-apis.md) for the full API boundary.

## How binaries reach a Docker STF

Files enter the container through **workflow input sources**, resolved before
`docker run` and embedded in the stdin JSON under `sources`.

Each key in `sources` is an **input step name**; the value shape depends on
the step's source type:

| Input source type | Resolved value in `sources` |
|-------------------|----------------------------|
| `Library` | `{ "code", "types", "version" }` |
| `File` (JSON content type) | Parsed JSON value |
| `File` (text content type) | File body as a string |
| `File` (binary) | `{ "filename", "content_type", "size", "data": "<base64>" }` |
| `Fetch` | Parsed JSON response body |

### Binary files (base64 in stdin)

For binary uploads (PDF, images, spreadsheets, etc.), wire a workflow **File**
input step pointing at workspace storage (or an upstream step that produced a
file id). At execution time d6e reads the file server-side and passes:

```json
{
  "sources": {
    "invoice_pdf": {
      "filename": "invoice-2024.pdf",
      "content_type": "application/pdf",
      "size": 245760,
      "data": "JVBERi0xLjQK..."
    }
  }
}
```

Inside the STF, decode base64 from `sources["invoice_pdf"]["data"]` — do not
call the files download API.

**Size consideration:** Large files inflate the stdin payload and count toward
container memory. Very large binaries may be better handled outside the Docker
step (saas-proxy-download + a non-Docker step, or process metadata in SQL and
pass a reference).

## What STFs cannot do with workspace storage

From inside the container, you **cannot**:

- `GET …/files/{id}/download` using `api_token`
- Upload new files via `POST …/files`
- List or delete files via the storage API

If the STF must **produce** a new file for downstream steps:

1. Return structured data in `{"output": …}` (e.g. base64 in the JSON result —
   mind the 10 MB stdout cap; see [limits-and-timeouts.md](./limits-and-timeouts.md))
2. Insert metadata or blob references into workspace SQL tables (if policy allows)
3. Prefer a separate workflow step (Effect, MCP download, custom frontend) to
   persist large binaries via saas-proxy-download or file upload APIs

## Ingesting SaaS binaries

Do not call `POST /api/v1/saas-proxy-download` from the container.

Pattern:

1. **Upstream step** — MCP `d6e_download_external_file`, Effect step, or custom
   frontend persists the file to workspace storage
2. **Docker STF input** — File input source delivers base64 in `sources`
3. **STF** — decode and process locally

Alternatively, call a **public** third-party URL directly from the container
(if credentials are in STF secrets), bypassing d6e storage APIs entirely.

## Example: read a binary input source

```python
import base64
import sys
import json

def load_binary_source(sources, step_name):
    item = sources.get(step_name)
    if not item or "data" not in item:
        print(
            f"load_binary_source: missing binary File source '{step_name}'",
            file=sys.stderr,
        )
        sys.exit(1)
    return {
        "filename": item.get("filename", "unknown"),
        "content_type": item.get("content_type", "application/octet-stream"),
        "bytes": base64.b64decode(item["data"]),
    }
```

## Related workflow design

- Text/JSON files: often simpler as text or JSON `File` sources (no base64 step)
- Multiple files: use multiple named input steps; each appears as its own
  `sources` key
- Chaining: previous STF `output` can feed the next step; only **File** sources
  deliver the base64 binary envelope
