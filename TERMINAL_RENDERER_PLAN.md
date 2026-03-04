# Experimental Terminal Renderer Plan

Branch: `exp/terminal-renderer`

## Goal

Add an experimental terminal backend that can render existing `%Easel{}` draw ops using a terminal UI stack (`termite` first), while keeping a backend API shape similar to `Easel.WX`.

## Recommendation

Start with **wx off-screen rasterization + ASCII conversion + Termite display**.

Why:
- Reuses Easel's existing Canvas op execution logic (highest compatibility now)
- Fastest path to prove feasibility
- Avoids implementing a full Canvas software rasterizer from scratch

Not chosen for v1:
- Full pure-Elixir off-screen Canvas rasterizer (very large scope)
- BackBreeze/Breeze as core renderer (great for layout/TUI apps, but not pixel/canvas rasterization)

## High-level architecture

1. **Rasterize canvas to pixels (RGB)**
   - Add off-screen raster function in wx backend (no window required)
   - Input: `%Easel{}` + target pixel dimensions
   - Output: `%{width: w, height: h, rgb: <<...>>}`

2. **Convert pixels to terminal frame string**
   - Luma-based ASCII ramp (`" .:-=+*#%@"`) initially
   - Optional mode later: ANSI256 color + unicode half-blocks (`▀`) for better fidelity

3. **Display/animate via Termite**
   - Alt-screen + hidden cursor
   - Cursor home each frame + write full frame
   - Clean restore on exit

## Proposed public API (experimental)

```elixir
Easel.Terminal.render(canvas, opts \\ [])
Easel.Terminal.animate(width, height, state, tick_fun, opts \\ [])
Easel.Terminal.available?()
```

Options (initial):
- `:columns`, `:rows` (fallback to terminal size)
- `:charset` (ASCII ramp)
- `:invert` (dark/light inversion)
- `:fps` (for animate)
- `:title` (terminal title)

## File-level plan

- `lib/easel/terminal.ex` (new)
  - Termite integration (render + animation loop)
  - Frame conversion pipeline orchestration

- `lib/easel/wx.ex`
  - Extract/add off-screen raster helper (shared draw execution path)
  - Keep wx window rendering behavior unchanged

- `mix.exs`
  - Add optional dependency for `termite` (`{:termite, "~> 0.4.0", optional: true}`)

- `README.md`
  - Add “Experimental Terminal backend” section + caveats

- `test/easel_terminal_test.exs` (new)
  - Pure conversion tests (pixel -> ASCII mapping)
  - Optional integration tests gated by availability checks

## Milestones

### M1 — Feasibility spike
- [x] Add minimal off-screen wx raster function
- [x] Convert a simple `fill_rect` canvas into ASCII string
- [x] Print one frame in terminal via Termite

### M2 — Public backend module
- [x] Implement `Easel.Terminal.render/2`
- [x] Add `available?/0` + graceful runtime errors when deps missing
- [x] Document supported/unsupported behavior

### M3 — Animation loop parity
- [x] Implement `animate/5` with tick function parity to wx
- [x] Add basic key handling (`q` to quit)
- [x] Stabilize cleanup (cursor/show, alt-screen restore)

### M4 — Quality/perf improvements
- [x] Aspect-ratio compensation
- [x] Optional ANSI256 color mode
- [ ] Optional line-diff rendering to reduce terminal writes

## Risks / caveats

- This backend likely depends on wx initially (for rasterization), so it is not a pure terminal renderer yet.
- Fidelity will differ from browser/wx due to coarse character grid.
- Performance may be limited for large terminal sizes and high FPS.

## Future path (if experiment succeeds)

- Consider extracting a backend-agnostic raster executor from `Easel.WX`
- Explore a pure software rasterizer for a wx-free terminal backend
- Optionally provide Breeze wrapper view for embedding Easel frames in TUI apps
