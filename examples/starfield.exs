# Starfield — random stars with varying sizes and brightness
# Run: mix run examples/starfield.exs

alias Easel.API

width = 600
height = 400

canvas =
  Easel.new(width, height)
  # Dark background
  |> API.set_fill_style("#0a0a2e")
  |> API.fill_rect(0, 0, width, height)

# Scatter 200 stars
canvas =
  Enum.reduce(1..200, canvas, fn _, acc ->
    x = :rand.uniform(width)
    y = :rand.uniform(height)
    radius = :rand.uniform() * 2.5 + 0.5
    brightness = :rand.uniform(155) + 100
    color = "rgba(#{brightness}, #{brightness}, #{min(255, brightness + 50)}, #{Float.round(:rand.uniform(), 2)})"

    acc
    |> API.begin_path()
    |> API.arc(x, y, radius, 0, :math.pi() * 2)
    |> API.set_fill_style(color)
    |> API.fill()
  end)

# A few bigger "bright" stars with glow
canvas =
  Enum.reduce(1..8, canvas, fn _, acc ->
    x = :rand.uniform(width)
    y = :rand.uniform(height)

    acc
    |> API.save()
    |> API.set_global_alpha(0.3)
    |> API.begin_path()
    |> API.arc(x, y, 8, 0, :math.pi() * 2)
    |> API.set_fill_style("rgba(200, 200, 255, 0.3)")
    |> API.fill()
    |> API.set_global_alpha(1.0)
    |> API.begin_path()
    |> API.arc(x, y, 2, 0, :math.pi() * 2)
    |> API.set_fill_style("white")
    |> API.fill()
    |> API.restore()
  end)
  |> Easel.render()

IO.puts("Starfield: #{length(canvas.ops)} operations")
