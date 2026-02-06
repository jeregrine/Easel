# Canvas

Canvas allows you to interact and draw on a canvas. The API is a `snake_cased` version of the [CanvasRenderingContext2D](https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D) with the addition of `set` and `call` if you need to set a property or call a function not yet supported.

## Example

Build a set of draw operations:

```elixir
canvas =
  Canvas.new(300, 300)
  |> Canvas.API.set_fill_style("blue")
  |> Canvas.API.fill_rect(0, 0, 100, 100)
  |> Canvas.API.set_line_width(10)
  |> Canvas.API.stroke_rect(100, 100, 100, 100)
  |> Canvas.render()
```

## Phoenix LiveView

Canvas includes an optional Phoenix LiveView component with a colocated runtime hook. No JavaScript build step is required.

### Template

```heex
<Canvas.LiveView.canvas id="my-canvas" width={300} height={300} />
```

### Drawing from a LiveView

```elixir
def handle_event("draw", _, socket) do
  canvas =
    Canvas.new(300, 300)
    |> Canvas.API.set_fill_style("blue")
    |> Canvas.API.fill_rect(0, 0, 100, 100)
    |> Canvas.render()

  {:noreply, Canvas.LiveView.draw(socket, "my-canvas", canvas)}
end
```

You can clear before drawing:

```elixir
Canvas.LiveView.draw(socket, "my-canvas", canvas, clear: true)
```

Or clear independently:

```elixir
Canvas.LiveView.clear(socket, "my-canvas")
```

### Initial ops

Pass ops directly to render on mount:

```heex
<Canvas.LiveView.canvas id="my-canvas" width={300} height={300} ops={@canvas.ops} />
```

## Installation

```elixir
def deps do
  [
    {:canvas, "~> 0.1.0"},
    # optional, for LiveView support
    {:phoenix_live_view, "~> 1.0"}
  ]
end
```
