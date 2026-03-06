# Rainbow spiral
# Run: mix run examples/term/spiral.exs [--mode auto|luma|silhouette|braille]

Code.require_file("example_opts.exs", __DIR__)

width = 500
height = 500
cx = width / 2
cy = height / 2
turns = 8
points = turns * 100

canvas =
  Easel.new(width, height)
  |> Easel.set_fill_style("#111")
  |> Easel.fill_rect(0, 0, width, height)
  |> Easel.set_line_width(2)
  |> Easel.set_line_cap("round")

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
      |> Easel.begin_path()
      |> Easel.move_to(x, y)
    else
      acc
      |> Easel.set_stroke_style(color)
      |> Easel.begin_path()
      |> Easel.move_to(
        cx + (t - 1 / points) * 200 * :math.cos(angle - turns * 2 * :math.pi() / points),
        cy + (t - 1 / points) * 200 * :math.sin(angle - turns * 2 * :math.pi() / points)
      )
      |> Easel.line_to(x, y)
      |> Easel.stroke()
    end
  end)
  |> Easel.render()

if Easel.Terminal.available?() do
  Easel.Terminal.render(
    canvas,
    TermExampleOpts.merge_terminal_mode(
      title: "Spiral",
      color: :ansi256,
      dpr: 2.0,
      samples: 2,
      fit: :contain
    )
  )
else
  IO.puts("Easel.Terminal is unavailable.")
  IO.puts("It currently requires wx support, {:termite, \"~> 0.4.0\"}, and an interactive TTY.")
end
