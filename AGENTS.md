# Agents

Context for AI coding agents working on this project.

## What is this?

Easel is an Elixir library for drawing on a canvas. The API mirrors the browser's [CanvasRenderingContext2D](https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D) but in `snake_case`. You build draw operations, then render in the browser (Phoenix LiveView) or natively (wx).

## Project layout

- `lib/easel.ex` — Core module. Canvas API functions are generated from WebIDL.
- `lib/easel/` — LiveView integration + wx backend.
- `priv/static/easel.js` — Static JS hook runtime (non-colocated usage path).
- `lib/easel/live_view.ex` — Colocated hook runtime + LiveView helpers.
- `examples/phx_demo/` — Demo Phoenix app.
- `examples/phx_demo/lib/phx_demo/examples/*.ex` — Per-demo drawing/sim modules.
- `examples/phx_demo/lib/phx_demo/examples.ex` — Delegator module for demos.
- `examples/phx_demo/lib/phx_demo/source_code.ex` — Compile-time embedded source files for demo code display.

## Key concepts

- **Ops** — Draw operations are `[method, args]` entries. `Easel.render/1` finalizes order.
- **Templates & instances** — Define shape once, send instance transforms/styles each frame.
- **Compact instances payload** — `__instances` now sends `[name, rows, palette, cols]` where `cols` describes active fields to avoid repeated nulls.
- **Quantization** — Instance float precision can be configured on `Easel.template/4` and overridden per `Easel.instances/4` call.
- **Cross-canvas template opts** — Use `Easel.with_template_opts/2` when templates are cached separately from frame canvases.
- **Layers** — `canvas_stack` for independent layered canvases.
- **Animation** — `Easel.LiveView.animate/5` + `handle_info({:easel_tick, id}, ...)`.

## Important implementation notes

- If you change `__instances` encoding/decoding, keep these in sync:
  - `lib/easel.ex`
  - `lib/easel/live_view.ex` (colocated hook)
  - `priv/static/easel.js` (static hook)
  - `test/easel_test.exs`
- Backward compatibility for old instance row payloads is currently supported in decoders.

## phx_demo specifics

- Homepage is `DemoLive` with animated + static cards.
- Static demos also have dedicated pages at `/examples/:id`.
- Demo pages render source code inline below the canvas via `<.demo code_id=...>`.
- Pathfinding supports BFS/DFS/A*/Greedy modes.
- Homepage background animation has a stop/start toggle.
- LiveView longpoll fallback is disabled in phx_demo (`endpoint.ex` + `assets/js/app.js`).

## Running

```bash
cd examples/phx_demo && mix phx.server
```

## Style notes

- Keep LiveViews thin; delegate drawing/sim logic to `examples/*` modules.
- Prefer template/instance rendering for large repeated geometry.
- Reduce payload sizes (quantization, compact rows) when animating many entities.
