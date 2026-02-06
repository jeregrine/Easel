# Canvas

Canvas allows you to interact and draw on a canvas. The API is a `snake_cased` version of the [CanvasRenderingContext2D](https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D) with the addition of `set` and `call` if you need to set a property or call a function not yet supported.

## Example

Generate a 300x300 canvas and draw to it.

```elixir
Canvas.new(300, 300)
|> Canvas.API.set_fill_style("blue")
|> Canvas.API.fill_rect(0, 0, 100, 100)
|> Canvas.API.set_line_width(10)
|> Canvas.API.stroke_rect(100, 100, 100, 100)
|> Canvas.render()
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `canvas` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:canvas, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/canvas>.
