# Agents

Context for AI coding agents working on this project.

## What is this?

Easel is an Elixir library for drawing on a canvas. The API mirrors the browser's [CanvasRenderingContext2D](https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D) but in `snake_case`. You build up draw operations, then render them in the browser (via Phoenix LiveView) or natively (via wx).

## Project layout

- `lib/easel.ex` — Core module. Canvas API functions are auto-generated from a WebIDL spec, so don't look for hand-written `fill_rect`, `set_fill_style`, etc. — they come from metaprogramming.
- `lib/easel/` — Supporting modules (LiveView components/hooks, wx backend, etc.)
- `lib/web_idl.ex` — WebIDL parser that drives the API generation.
- `priv/` — Static assets including the JS hook for LiveView.
- `examples/phx_demo/` — A Phoenix app with live demos (static and animated).
- `examples/*.exs` — Standalone scripts for individual examples.
- `test/` — Tests.

## Key concepts

- **Ops** — Draw operations are just lists of `[method, args]` pairs. `Easel.render/1` finalizes them.
- **Templates & instances** — Define a shape once, stamp it out many times with per-instance transforms. The template ops are cached client-side; only instance data (x, y, rotation, color) is sent each frame.
- **Layers** — `canvas_stack` lets you layer independent `<canvas>` elements. Only layers with changed assigns get re-sent.
- **Animation** — `Easel.LiveView.animate/5` runs a server-side tick loop. The LiveView needs a `handle_info` clause for `:easel_tick` messages.

## The phx_demo app

Lives in `examples/phx_demo/`. Drawing logic goes in `lib/phx_demo/examples.ex`, LiveViews in `lib/phx_demo_web/live/`. Static demos are shown on the index page (`DemoLive`), animated ones get their own route and LiveView.

Pattern for adding a new animated demo:
1. Add init/tick/render functions to `PhxDemo.Examples`
2. Create a LiveView in `lib/phx_demo_web/live/`
3. Add a route in `router.ex`
4. Add a link in `DemoLive`

## Running

```bash
cd examples/phx_demo && mix phx.server
```

## Style notes

- No build step for JS — the hook is served from priv.
- Examples should be self-contained in `examples.ex` (pure functions, no processes).
- Keep LiveViews thin — just wiring up assigns and animation, delegate drawing to `Examples`.
