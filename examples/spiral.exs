# Rainbow spiral
# Run: mix run examples/spiral.exs

alias Easel.API

width = 500
height = 500
cx = width / 2
cy = height / 2
turns = 8
points = turns * 100

canvas =
  Easel.new(width, height)
  |> API.set_fill_style("#111")
  |> API.fill_rect(0, 0, width, height)
  |> API.set_line_width(2)
  |> API.set_line_cap("round")

canvas =
  Enum.reduce(0..points, canvas, fn i, acc ->
    t = i / points
    angle = t * turns * 2 * :math.pi()
    radius = t * 200

    x = cx + radius * :math.cos(angle)
    y = cy + radius * :math.sin(angle)

    # Cycle through hues
    hue = rem(round(t * 360 * 3), 360)
    color = "hsl(#{hue}, 80%, 60%)"

    if i == 0 do
      acc
      |> API.begin_path()
      |> API.move_to(x, y)
    else
      acc
      |> API.set_stroke_style(color)
      |> API.begin_path()
      |> API.move_to(
        cx + (t - 1 / points) * 200 * :math.cos(angle - turns * 2 * :math.pi() / points),
        cy + (t - 1 / points) * 200 * :math.sin(angle - turns * 2 * :math.pi() / points)
      )
      |> API.line_to(x, y)
      |> API.stroke()
    end
  end)
  |> Easel.render()

if Code.ensure_loaded?(Easel.WX) and Easel.WX.available?() do
  Easel.WX.render(canvas, title: "Spiral")
else
  IO.puts("Spiral: #{length(canvas.ops)} operations")
end
