# Mandelbrot set rendered pixel-by-pixel
# Run: mix run examples/mandelbrot.exs

alias Easel.API

width = 200
height = 200
max_iter = 50

# Viewport into the Mandelbrot set
x_min = -2.0
x_max = 0.7
y_min = -1.35
y_max = 1.35

defmodule Mandelbrot do
  def iterate(cr, ci, max_iter) do
    iterate(0.0, 0.0, cr, ci, 0, max_iter)
  end

  defp iterate(_zr, _zi, _cr, _ci, n, max) when n >= max, do: max

  defp iterate(zr, zi, cr, ci, n, max) do
    zr2 = zr * zr
    zi2 = zi * zi

    if zr2 + zi2 > 4.0 do
      n
    else
      iterate(zr2 - zi2 + cr, 2.0 * zr * zi + ci, cr, ci, n + 1, max)
    end
  end

  def color(n, max) when n >= max, do: "#000000"

  def color(n, max) do
    t = n / max
    # Smooth coloring with multiple bands
    r = round(9 * (1 - t) * t * t * t * 255)
    g = round(15 * (1 - t) * (1 - t) * t * t * 255)
    b = round(8.5 * (1 - t) * (1 - t) * (1 - t) * t * 255)
    "rgb(#{min(r, 255)}, #{min(g, 255)}, #{min(b, 255)})"
  end
end

canvas = Easel.new(width, height)

canvas =
  Enum.reduce(0..(height - 1), canvas, fn py, acc ->
    ci = y_min + py / height * (y_max - y_min)

    Enum.reduce(0..(width - 1), acc, fn px, acc2 ->
      cr = x_min + px / width * (x_max - x_min)
      n = Mandelbrot.iterate(cr, ci, max_iter)
      color = Mandelbrot.color(n, max_iter)

      acc2
      |> API.set_fill_style(color)
      |> API.fill_rect(px, py, 1, 1)
    end)
  end)
  |> Easel.render()

if Code.ensure_loaded?(Easel.WX) and Easel.WX.available?() do
  Easel.WX.render(canvas, title: "Mandelbrot")
else
  IO.puts("Mandelbrot (#{width}x#{height}, max_iter=#{max_iter}): #{length(canvas.ops)} operations")
end
