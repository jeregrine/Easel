defmodule PhxDemo.Examples.Lissajous do
  @width 700
  @height 500

  def width, do: @width
  def height, do: @height

  def render(t) do
    cx = @width / 2
    cy = @height / 2

    Easel.new(@width, @height)
    |> Easel.set_fill_style("rgba(5, 10, 24, 0.12)")
    |> Easel.fill_rect(0, 0, @width, @height)
    |> draw_curve(cx, cy, t)
    |> Easel.render()
  end

  def background do
    Easel.new(@width, @height)
    |> Easel.set_fill_style("#050a18")
    |> Easel.fill_rect(0, 0, @width, @height)
    |> Easel.render()
  end

  defp draw_curve(canvas, cx, cy, t) do
    a = 3
    b = 2
    delta = t / 40
    points = 400

    Enum.reduce(0..points, canvas, fn i, acc ->
      u = i / points
      angle = u * 2 * :math.pi()
      x = cx + 180 * :math.sin(a * angle + delta)
      y = cy + 140 * :math.sin(b * angle)
      hue = rem(round(u * 360 + t), 360)

      if i == 0 do
        acc
        |> Easel.begin_path()
        |> Easel.move_to(x, y)
      else
        acc
        |> Easel.set_stroke_style("hsl(#{hue}, 90%, 65%)")
        |> Easel.set_line_width(2)
        |> Easel.line_to(x, y)
        |> Easel.stroke()
      end
    end)
  end
end
