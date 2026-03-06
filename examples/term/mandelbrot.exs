# Mandelbrot set rendered pixel-by-pixel
# Run: mix run examples/term/mandelbrot.exs [--mode auto|luma|silhouette|braille|halfblock]

Code.require_file("example_opts.exs", __DIR__)

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
      |> Easel.set_fill_style(color)
      |> Easel.fill_rect(px, py, 1, 1)
    end)
  end)
  |> Easel.render()

if Easel.Terminal.available?() do
  Easel.Terminal.render(
    canvas,
    TermExampleOpts.merge_terminal_mode(
      title: "Mandelbrot",
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
