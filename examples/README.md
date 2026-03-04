# Easel Examples

Examples are grouped by backend:

- `examples/phx_demo` — Phoenix LiveView demo app
- `examples/wx` — wx/native scripts
- `examples/term` — terminal scripts

## wx examples

Run any wx script with `mix run`:

```bash
mix run examples/wx/smiley.exs
mix run examples/wx/chart.exs
mix run examples/wx/clock.exs
mix run examples/wx/starfield.exs
mix run examples/wx/spiral.exs
mix run examples/wx/tree.exs
mix run examples/wx/mondrian.exs
mix run examples/wx/sierpinski.exs
mix run examples/wx/mandelbrot.exs
mix run examples/wx/boids.exs
```

| Example | Description | Ops |
|---------|-------------|-----|
| `wx/smiley.exs` | Smiley face with arcs | ~20 |
| `wx/chart.exs` | Bar chart with axes, grid, labels | ~200 |
| `wx/clock.exs` | Analog clock (current UTC time) | ~400 |
| `wx/starfield.exs` | Random stars with glow effects | ~900 |
| `wx/spiral.exs` | Rainbow spiral with hue cycling | ~4,000 |
| `wx/tree.exs` | Recursive fractal tree with leaves | ~10,000 |
| `wx/sierpinski.exs` | Sierpinski triangle (depth 8) | ~13,000 |
| `wx/mondrian.exs` | Piet Mondrian generative art | ~180 |
| `wx/mandelbrot.exs` | Mandelbrot set (200×200) | ~80,000 |
| `wx/boids.exs` | Boids flocking simulation (~60fps). Uses `Easel.WX.animate/5` when wx is available, otherwise simulates headless. | — |

## terminal examples

Run any terminal script with `mix run`:

```bash
mix run examples/term/smiley.exs
mix run examples/term/chart.exs
mix run examples/term/clock.exs
mix run examples/term/starfield.exs
mix run examples/term/spiral.exs
mix run examples/term/tree.exs
mix run examples/term/mondrian.exs
mix run examples/term/sierpinski.exs
mix run examples/term/mandelbrot.exs
mix run examples/term/boids.exs
mix run examples/term/terminal_wave.exs
```

| Example | Description |
|---------|-------------|
| `term/smiley.exs` | Smiley face in terminal. |
| `term/chart.exs` | Bar chart in terminal. |
| `term/clock.exs` | Animated digital/abstract UTC clock. |
| `term/starfield.exs` | Random starfield in terminal. |
| `term/spiral.exs` | Rainbow spiral in terminal. |
| `term/tree.exs` | Recursive fractal tree in terminal. |
| `term/mondrian.exs` | Mondrian-style generative art in terminal. |
| `term/sierpinski.exs` | Sierpinski triangle fractal in terminal. |
| `term/mandelbrot.exs` | Mandelbrot set in terminal. |
| `term/boids.exs` | Animated boids flocking simulation. |
| `term/terminal_wave.exs` | Experimental wave animation (q to quit). |

Terminal examples must be run in an interactive terminal (TTY).
They use automatic silhouette-based character selection by default.
For animation speed, tune `glyph_width`, `glyph_height`, and `char_cache_size`.
