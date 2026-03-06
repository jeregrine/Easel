# Starfield — random stars with varying sizes and brightness
# Run: mix run examples/term/starfield.exs [--mode auto|luma|silhouette|braille|halfblock]

Code.require_file("example_opts.exs", __DIR__)

width = 600
height = 400

canvas =
  Easel.new(width, height)
  # Dark background
  |> Easel.set_fill_style("#0a0a2e")
  |> Easel.fill_rect(0, 0, width, height)

# Scatter 200 stars
canvas =
  Enum.reduce(1..200, canvas, fn _, acc ->
    x = :rand.uniform(width)
    y = :rand.uniform(height)
    radius = :rand.uniform() * 2.5 + 0.5
    brightness = :rand.uniform(155) + 100

    color =
      "rgba(#{brightness}, #{brightness}, #{min(255, brightness + 50)}, #{Float.round(:rand.uniform(), 2)})"

    acc
    |> Easel.begin_path()
    |> Easel.arc(x, y, radius, 0, :math.pi() * 2)
    |> Easel.set_fill_style(color)
    |> Easel.fill()
  end)

# A few bigger "bright" stars with glow
canvas =
  Enum.reduce(1..8, canvas, fn _, acc ->
    x = :rand.uniform(width)
    y = :rand.uniform(height)

    acc
    |> Easel.save()
    |> Easel.set_global_alpha(0.3)
    |> Easel.begin_path()
    |> Easel.arc(x, y, 8, 0, :math.pi() * 2)
    |> Easel.set_fill_style("rgba(200, 200, 255, 0.3)")
    |> Easel.fill()
    |> Easel.set_global_alpha(1.0)
    |> Easel.begin_path()
    |> Easel.arc(x, y, 2, 0, :math.pi() * 2)
    |> Easel.set_fill_style("white")
    |> Easel.fill()
    |> Easel.restore()
  end)
  |> Easel.render()

if Easel.Terminal.available?() do
  Easel.Terminal.render(
    canvas,
    TermExampleOpts.merge_terminal_mode(
      title: "Starfield",
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
