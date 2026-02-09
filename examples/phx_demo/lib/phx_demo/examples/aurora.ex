defmodule PhxDemo.Examples.Aurora do
  @width 1920
  @height 1080

  def init, do: %{t: 0.0}

  def tick(%{t: t} = state), do: %{state | t: t + 1}

  def render(%{t: t}) do
    rows = 28
    steps = 120
    dx = @width / steps

    canvas = Easel.new(@width, @height)

    Enum.reduce(0..rows, canvas, fn row, c ->
      y0 = @height * 0.08 + row * (@height * 0.033)
      hue = rem(round(200 + row * 4 + t * 0.22), 360)
      major = rem(row, 5) == 0
      alpha = if major, do: 0.42, else: 0.2
      line_w = if major, do: 1.6, else: 1.0

      c =
        c
        |> Easel.begin_path()
        |> Easel.move_to(0, contour_y(0, y0, row, t))

      c =
        Enum.reduce(1..steps, c, fn step, acc ->
          x = step * dx
          Easel.line_to(acc, x, contour_y(x, y0, row, t))
        end)

      c
      |> Easel.save()
      |> Easel.set_global_alpha(alpha)
      |> Easel.set_stroke_style("hsl(#{hue}, 85%, 72%)")
      |> Easel.set_line_width(line_w)
      |> Easel.stroke()
      |> Easel.restore()
    end)
    |> Easel.render()
  end

  defp contour_y(x, y0, row, t) do
    y0 +
      :math.sin(x * 0.008 + t * 0.02 + row * 0.35) * 20 +
      :math.cos(x * 0.004 - t * 0.015 + row * 0.5) * 14 +
      :math.sin((x + y0) * 0.0018 + t * 0.01) * 7
  end
end
