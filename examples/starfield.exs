# Starfield — random stars with varying sizes and brightness
# Run: mix run examples/starfield.exs


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
    color = "rgba(#{brightness}, #{brightness}, #{min(255, brightness + 50)}, #{Float.round(:rand.uniform(), 2)})"

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

if Code.ensure_loaded?(Easel.WX) and Easel.WX.available?() do
  Easel.WX.render(canvas, title: "Starfield")
else
  IO.puts("Starfield: #{length(canvas.ops)} operations")
end
