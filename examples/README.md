# Easel Examples

Run any example with `mix run`:

```bash
mix run examples/smiley.exs
mix run examples/chart.exs
mix run examples/clock.exs
mix run examples/starfield.exs
mix run examples/spiral.exs
mix run examples/tree.exs
mix run examples/mondrian.exs
mix run examples/sierpinski.exs
mix run examples/mandelbrot.exs
mix run examples/boids.exs
```

## Static examples

These build a canvas and print the ops list. When wx is available,
add `|> Easel.WX.render()` to the pipeline to see them in a native window.

| Example | Description | Ops |
|---------|-------------|-----|
| `smiley.exs` | Smiley face with arcs | ~20 |
| `chart.exs` | Bar chart with axes, grid, labels | ~200 |
| `clock.exs` | Analog clock (current UTC time) | ~400 |
| `starfield.exs` | Random stars with glow effects | ~900 |
| `spiral.exs` | Rainbow spiral with hue cycling | ~4,000 |
| `tree.exs` | Recursive fractal tree with leaves | ~10,000 |
| `sierpinski.exs` | Sierpinski triangle (depth 8) | ~13,000 |
| `mondrian.exs` | Piet Mondrian generative art | ~180 |
| `mandelbrot.exs` | Mandelbrot set (200×200) | ~80,000 |

## Animated example

| Example | Description |
|---------|-------------|
| `boids.exs` | Boids flocking simulation (~60fps). Uses `Easel.WX.animate/5` when wx is available, otherwise simulates headless. |
