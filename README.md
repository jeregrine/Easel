# Easel

[![Hex.pm](https://img.shields.io/hexpm/v/easel.svg)](https://hex.pm/packages/easel)
[![Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/easel)

Easel allows you to interact and draw on a canvas. The API is a `snake_cased` version of the [CanvasRenderingContext2D](https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D) with the addition of `set` and `call` if you need to set a property or call a function not yet supported.

The idea is you create a canvas, apply the draw operations to it then send it off to the Browser or Wx to render. This allows us to use Elixir to draw basically anything, further it comes with the following features:

- Optional Phoenix LiveView components and hooks are available.
  - With support for layers.
  - Animations and Event handling
  - And templating and instancing of drawing, so you don't have to send all the draw commands on every frame, just the values that have changed.
- Optional Wx Rendering for local art and speed using the same Canvas API!.

## Example

Build a set of draw operations:

```elixir
canvas =
  Easel.new(300, 300)
  |> Easel.set_fill_style("blue")
  |> Easel.fill_rect(0, 0, 100, 100)
  |> Easel.set_line_width(10)
  |> Easel.stroke_rect(100, 100, 100, 100)
```

And render it

```elixir
Easel.render(canvas)
```

This basically just reverse the ops list and marks it as rendered. If you want to make a picture you will need a fe

## Phoenix LiveView

Easel includes an optional Phoenix LiveView component with a colocated runtime hook. No JavaScript build step is required.

### Template

```heex
<Easel.LiveView.canvas id="my-canvas" width={300} height={300} />
```

### Drawing from a LiveView

```elixir
def handle_event("draw", _, socket) do
  canvas =
    Easel.new(300, 300)
    |> Easel.set_fill_style("blue")
    |> Easel.fill_rect(0, 0, 100, 100)
    |> Easel.render()

  {:noreply, Easel.LiveView.draw(socket, "my-canvas", canvas)}
end
```

You can clear before drawing:

```elixir
Easel.LiveView.draw(socket, "my-canvas", canvas, clear: true)
```

Or clear independently:

```elixir
Easel.LiveView.clear(socket, "my-canvas")
```

### Initial ops

Pass ops directly to render on mount:

```heex
<Easel.LiveView.canvas id="my-canvas" width={300} height={300} ops={@canvas.ops} />
```

### Events

Enable mouse and keyboard events with boolean attributes:

```heex
<Easel.LiveView.canvas
  id="my-canvas"
  width={300}
  height={300}
  on_click
  on_mouse_move
  on_key_down
/>
```

Events are pushed to your LiveView as `"<id>:<event>"`:

```elixir
def handle_event("my-canvas:click", %{"x" => x, "y" => y}, socket) do
  IO.puts("Clicked at #{x}, #{y}")
  {:noreply, socket}
end

def handle_event("my-canvas:keydown", %{"key" => key}, socket) do
  IO.puts("Key pressed: #{key}")
  {:noreply, socket}
end
```

Available: `on_click`, `on_mouse_down`, `on_mouse_up`, `on_mouse_move`, `on_key_down`.

Key events include `key`, `code`, `ctrl`, `shift`, `alt`, and `meta` fields.

### Layers

Use `canvas_stack/1` to layer multiple canvases. Each layer is an independent
`<canvas>` element stacked via CSS. Only layers whose assigns change get
re-patched by LiveView — static layers like backgrounds are sent once:

```heex
<Easel.LiveView.canvas_stack id="game" width={800} height={600}>
  <:layer id="background" ops={@background.ops} />
  <:layer id="sprites" ops={@sprites.ops} templates={@sprites.templates} />
  <:layer id="ui" ops={@ui.ops} />
</Easel.LiveView.canvas_stack>
```

Event flags go on the layer that should receive them (typically the topmost):

```heex
<:layer id="sprites" ops={@sprites.ops} on_click />
```

### Templates and Instances

For scenes with many similar shapes (particles, sprites, entities), define a
**template** once and stamp out **instances** with per-instance transforms.
Only the instance data is sent each frame while template ops are cached
client-side.

`Easel.instances/4` supports float quantization to reduce websocket payloads,
and you can set defaults once on `Easel.template/4`:

```elixir
canvas =
  Easel.new(800, 600)
  |> Easel.template(:boid, fn c ->
    c
    |> Easel.begin_path()
    |> Easel.move_to(12, 0)
    |> Easel.line_to(-4, -5)
    |> Easel.line_to(-4, 5)
    |> Easel.close_path()
    |> Easel.fill()
  end, x: 1, y: 1, rotate: 3)
```

Per-call overrides still work:

```elixir
Easel.instances(canvas, :boid, instances, rotate: 2)
```

Internally, instance rows are sent in a compact columnar format (`rows + cols`)
so unused fields are omitted instead of sending repeated `null`s.

```elixir
canvas =
  Easel.new(800, 600)
  |> Easel.template(:boid, fn c ->
    c
    |> Easel.begin_path()
    |> Easel.move_to(12, 0)
    |> Easel.line_to(-4, -5)
    |> Easel.line_to(-4, 5)
    |> Easel.close_path()
    |> Easel.fill()
  end)
  |> Easel.instances(:boid, Enum.map(boids, fn b ->
    angle = :math.atan2(b.vy, b.vx)
    hue = round(angle / :math.pi() * 180 + 180)
    %{x: b.x, y: b.y, rotate: angle, fill: "hsl(#{hue}, 70%, 60%)"}
  end))
  |> Easel.render()
```

Pass templates to the canvas component alongside ops:

```heex
<Easel.LiveView.canvas
  id="sprites"
  width={800}
  height={600}
  ops={@canvas.ops}
  templates={@canvas.templates}
/>
```

If templates are cached in one canvas and instances are emitted from another,
carry template instance defaults over with `Easel.with_template_opts/2`:

```elixir
frame_canvas
|> Easel.with_template_opts(template_canvas.template_opts)
|> Easel.instances(:boid, instances)
```

Each instance map may contain:

| Key                    | Description           | Default |
| ---------------------- | --------------------- | ------- |
| `:x`, `:y`             | Translation           | `0`     |
| `:rotate`              | Rotation in radians   | `0`     |
| `:scale_x`, `:scale_y` | Scale factors         | `1`     |
| `:fill`                | Fill style override   | —       |
| `:stroke`              | Stroke style override | —       |
| `:alpha`               | Global alpha override | —       |

For non-JS backends (wx, custom renderers), call `Easel.expand/1` to flatten
instances into plain Canvas 2D ops (save/translate/rotate/fill/restore):

```elixir
canvas |> Easel.expand()  # __instances → plain ops
```

**Payload comparison (100 boids):**

| Approach                  | Ops/frame | Bytes/frame |
| ------------------------- | --------- | ----------- |
| Inline ops (no templates) | ~504      | ~19 KB      |
| Templates + instances     | 1         | ~7.8 KB     |

### Animation

Run a server-side animation loop. Use `:canvas_assign` so the template
re-renders with new ops each frame:

```elixir
def mount(_params, _session, socket) do
  socket =
    socket
    |> assign(:balls, initial_balls())
    |> assign(:canvas, Easel.new(600, 400) |> Easel.render())
    |> Easel.LiveView.animate("my-canvas", :balls, fn balls ->
      new_balls = tick(balls)
      canvas = render_balls(new_balls)
      {canvas, new_balls}
    end, interval: 16, canvas_assign: :canvas)

  {:ok, socket}
end

def handle_info({:easel_tick, id}, socket) do
  {:noreply, Easel.LiveView.tick(socket, id)}
end
```

The template binds ops to the canvas assign:

```heex
<Easel.LiveView.canvas id="my-canvas" width={600} height={400} ops={@canvas.ops} />
```

The hook uses `requestAnimationFrame` to sync drawing with the browser's
refresh rate. If multiple server updates arrive between frames, only the
latest is drawn — no wasted renders.

To stop the animation:

```elixir
Easel.LiveView.stop_animation(socket, "my-canvas")
```

## Examples

This repo has two main example styles:

- **Phoenix/LiveView examples** in `examples/phx_demo`
  - Includes static and animated browser demos
  - Static examples: Smiley, Chart, Starfield, Spiral, Fractal Tree, Mondrian, Sierpinski, Mandelbrot
  - Animated examples: Clock, Boids, Matrix, Game of Life, Lissajous, Flow Field, Wave Grid, Pathfinding (BFS/DFS/A*/Greedy)
  - Demo app entry: `examples/phx_demo/lib/phx_demo_web/live/demo_live.ex`
  - Drawing logic modules: `examples/phx_demo/lib/phx_demo/examples/*.ex`
  - Static per-example pages: `/examples/:id`

- **wx/native examples** using `Easel.WX`
  - Use the same Easel Canvas API, but render to a native wx window instead of the browser
  - Includes both static renders and animated examples
  - Standalone scripts live under `examples/*.exs` (for example boids and other sketches)

Run the Phoenix demo locally:

```bash
cd examples/phx_demo
mix phx.server
```

## wx Backend

Easel includes an optional native rendering backend using Erlang's `:wx` (wxWidgets).
This opens a native desktop window and draws your canvas operations without a browser.

```elixir
Easel.new(400, 300)
|> Easel.set_fill_style("blue")
|> Easel.fill_rect(50, 50, 100, 100)
|> Easel.set_stroke_style("red")
|> Easel.set_line_width(3)
|> Easel.stroke_rect(50, 50, 100, 100)
|> Easel.render()
|> Easel.WX.render(title: "My Drawing")
```

Canvases with templates/instances are automatically expanded via `Easel.expand/1`
before rendering in wx.

### Event handling

Both `render/2` and `animate/5` accept optional event handler callbacks:

```elixir
# Static render — handlers receive (x, y) or (key_event)
Easel.WX.render(canvas,
  on_click: fn x, y -> IO.puts("Clicked at #{x}, #{y}") end,
  on_mouse_move: fn x, y -> IO.puts("Mouse at #{x}, #{y}") end,
  on_key_down: fn %{key: key} -> IO.puts("Key: #{key}") end
)

# Animation — handlers receive args + state, return new state
Easel.WX.animate(600, 400, initial_state, tick_fn,
  on_click: fn x, y, state -> %{state | target: {x, y}} end,
  on_key_down: fn %{key: ?r}, state -> reset(state) end
)
```

Available events: `:on_click`, `:on_mouse_down`, `:on_mouse_up`, `:on_mouse_move`, `:on_key_down`

Not all Canvas 2D operations are supported in wx. Unsupported ops (shadows, filters,
gradients, image data, etc.) will raise `Easel.WX.UnsupportedOpError`. See the
`Easel.WX` module docs for the full list of supported operations.

### wx Prerequisites

Erlang must be compiled with wxWidgets support. If you use [mise](https://mise.jdx.dev)
(or asdf), you'll need to ensure wxWidgets is installed and Erlang is built against it.

1. Install wxWidgets (with compat-3.0 support, required by Erlang's wx):

   ```bash
   # macOS — edit the formula to add --enable-compat30
   brew edit wxwidgets
   # Add "--enable-compat30" to the args list in the formula, then:
   brew reinstall wxwidgets --build-from-source

   # Ubuntu/Debian
   sudo apt install libwxgtk3.2-dev
   ```

2. Configure mise to build Erlang with wx support. In your `.mise.toml`:

   ```toml
   [tools]
   erlang = "latest"
   elixir = "latest"

   [env]
   KERL_CONFIGURE_OPTIONS = "--with-wx"
   ```

3. Force rebuild Erlang (this takes a few minutes):

   ```bash
   mise install erlang@latest --force
   ```

4. Verify wx works:

   ```bash
   erl -noshell -eval 'wx:new(), io:format("wx works!~n"), halt().'
   ```

> **Note:** If you update wxWidgets (e.g. via `brew upgrade`), you'll need to
> rebuild Erlang with `mise install erlang --force` so it links against the new version.

## Installation

Add `easel` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:easel, "~> 0.2.2"},
    # optional, for LiveView support
    {:phoenix_live_view, "~> 1.0"}
  ]
end
```

Then fetch your dependencies:

```bash
mix deps.get
```

Documentation is available on [HexDocs](https://hexdocs.pm/easel).
