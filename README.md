# Easel

Easel allows you to interact and draw on a canvas. The API is a `snake_cased` version of the [CanvasRenderingContext2D](https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D) with the addition of `set` and `call` if you need to set a property or call a function not yet supported.

## Example

Build a set of draw operations:

```elixir
canvas =
  Easel.new(300, 300)
  |> Easel.API.set_fill_style("blue")
  |> Easel.API.fill_rect(0, 0, 100, 100)
  |> Easel.API.set_line_width(10)
  |> Easel.API.stroke_rect(100, 100, 100, 100)
  |> Easel.render()
```

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
    |> Easel.API.set_fill_style("blue")
    |> Easel.API.fill_rect(0, 0, 100, 100)
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

### Animation

Run a server-side animation loop that pushes frames to the client:

```elixir
def mount(_params, _session, socket) do
  socket =
    socket
    |> assign(:balls, initial_balls())
    |> Easel.LiveView.animate("my-canvas", :balls, fn balls ->
      new_balls = tick(balls)
      canvas = render_balls(new_balls)
      {canvas, new_balls}
    end, interval: 16)

  {:ok, socket}
end
```

Your LiveView must handle the tick message:

```elixir
def handle_info({:easel_tick, id}, socket) do
  {:noreply, Easel.LiveView.tick(socket, id)}
end
```

To stop the animation:

```elixir
Easel.LiveView.stop_animation(socket, "my-canvas")
```

## wx Backend

Easel includes an optional native rendering backend using Erlang's `:wx` (wxWidgets).
This opens a native desktop window and draws your canvas operations without a browser.

```elixir
Easel.new(400, 300)
|> Easel.API.set_fill_style("blue")
|> Easel.API.fill_rect(50, 50, 100, 100)
|> Easel.API.set_stroke_style("red")
|> Easel.API.set_line_width(3)
|> Easel.API.stroke_rect(50, 50, 100, 100)
|> Easel.render()
|> Easel.WX.render(title: "My Drawing")
```

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

```elixir
def deps do
  [
    {:easel, "~> 0.1.0"},
    # optional, for LiveView support
    {:phoenix_live_view, "~> 1.0"}
  ]
end
```
