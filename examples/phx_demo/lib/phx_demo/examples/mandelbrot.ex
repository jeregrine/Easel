defmodule PhxDemo.Examples.Mandelbrot do
  def render do
    case :persistent_term.get({__MODULE__, :mandelbrot}, :missing) do
      :missing ->
        canvas = build()
        :persistent_term.put({__MODULE__, :mandelbrot}, canvas)
        canvas

      canvas ->
        canvas
    end
  end

  defp build do
    width = 200
    height = 200
    max_iter = 50
    x_min = -2.0
    x_max = 0.7
    y_min = -1.35
    y_max = 1.35

    palette = for n <- 0..max_iter, do: color(n, max_iter)

    Enum.reduce(0..(height - 1), Easel.new(width, height), fn py, acc ->
      ci = y_min + py / height * (y_max - y_min)

      {runs, start_x, last_n} =
        Enum.reduce(0..(width - 1), {[], 0, nil}, fn px, {runs, start_x, last_n} ->
          cr = x_min + px / width * (x_max - x_min)
          n = iterate(0.0, 0.0, cr, ci, 0, max_iter)

          cond do
            is_nil(last_n) -> {runs, px, n}
            n == last_n -> {runs, start_x, last_n}
            true -> {[{start_x, px - start_x, last_n} | runs], px, n}
          end
        end)

      runs = [{start_x, width - start_x, last_n} | runs] |> Enum.reverse()

      Enum.reduce(runs, acc, fn {x, run_w, n}, c ->
        c
        |> Easel.set_fill_style(Enum.at(palette, n))
        |> Easel.fill_rect(x, py, run_w, 1)
      end)
    end)
    |> Easel.render()
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

  defp color(n, max) when n >= max, do: "#000000"

  defp color(n, max) do
    t = n / max
    r = round(9 * (1 - t) * t * t * t * 255)
    g = round(15 * (1 - t) * (1 - t) * t * t * 255)
    b = round(8.5 * (1 - t) * (1 - t) * (1 - t) * t * 255)
    "rgb(#{min(r, 255)}, #{min(g, 255)}, #{min(b, 255)})"
  end
end
