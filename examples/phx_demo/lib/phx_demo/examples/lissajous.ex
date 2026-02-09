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
    points = 480

    yaw = t / 180
    pitch = :math.sin(t / 140) * 0.8

    Enum.reduce(0..points, canvas, fn i, acc ->
      u = i / points
      angle = u * 2 * :math.pi()

      # base lissajous in a faux 3D space
      x0 = 180 * :math.sin(a * angle + delta)
      y0 = 140 * :math.sin(b * angle)
      z0 = 110 * :math.sin(4 * angle + delta * 1.3)

      # rotate around Y (yaw)
      x1 = x0 * :math.cos(yaw) + z0 * :math.sin(yaw)
      z1 = -x0 * :math.sin(yaw) + z0 * :math.cos(yaw)

      # rotate around X (pitch)
      y2 = y0 * :math.cos(pitch) - z1 * :math.sin(pitch)
      z2 = y0 * :math.sin(pitch) + z1 * :math.cos(pitch)

      perspective = 1.0 + z2 / 420
      x = cx + x1 * perspective
      y = cy + y2 * perspective

      hue = rem(round(u * 360 + t), 360)
      lw = 1.0 + perspective * 1.6

      if i == 0 do
        acc
        |> Easel.begin_path()
        |> Easel.move_to(x, y)
      else
        acc
        |> Easel.set_stroke_style("hsl(#{hue}, 90%, 65%)")
        |> Easel.set_line_width(lw)
        |> Easel.line_to(x, y)
        |> Easel.stroke()
      end
    end)
  end
end
