defmodule PhxDemo.Examples.Spiral do
  def render do
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

    Enum.reduce(0..points, canvas, fn i, acc ->
      t = i / points
      angle = t * turns * 2 * :math.pi()
      radius = t * 200
      x = cx + radius * :math.cos(angle)
      y = cy + radius * :math.sin(angle)
      hue = rem(round(t * 360 * 3), 360)
      color = "hsl(#{hue}, 80%, 60%)"

      if i == 0 do
        acc |> Easel.begin_path() |> Easel.move_to(x, y)
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
  end
end
