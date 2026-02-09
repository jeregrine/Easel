defmodule PhxDemo.Examples.Tree do
  def render do
    random_seed()
    width = 600
    height = 500

    canvas =
      Easel.new(width, height)
      |> Easel.set_fill_style("#87CEEB")
      |> Easel.fill_rect(0, 0, width, height)
      |> Easel.set_fill_style("#3d5a1e")
      |> Easel.fill_rect(0, height - 40, width, 40)

    draw_tree(canvas, width / 2, height - 40, 100, -:math.pi() / 2, 0, 10)
    |> Easel.render()
  end

  defp random_seed do
    a = :erlang.unique_integer([:positive])
    b = :erlang.phash2({System.system_time(), self()})
    c = :erlang.phash2({System.monotonic_time(), make_ref()})
    :rand.seed(:exsss, {a, b, c})
  end

  defp draw_tree(canvas, _x, _y, _length, _angle, depth, max) when depth >= max, do: canvas

  defp draw_tree(canvas, x, y, length, angle, depth, max_depth) do
    end_x = x + length * :math.cos(angle)
    end_y = y + length * :math.sin(angle)

    t = depth / max_depth
    r = round(80 * (1 - t) + 34 * t)
    g = round(50 * (1 - t) + 139 * t)
    b = round(20 * (1 - t) + 34 * t)
    line_w = max(1, (max_depth - depth) * 1.5)

    canvas =
      canvas
      |> Easel.begin_path()
      |> Easel.move_to(x, y)
      |> Easel.line_to(end_x, end_y)
      |> Easel.set_stroke_style("rgb(#{r}, #{g}, #{b})")
      |> Easel.set_line_width(line_w)
      |> Easel.set_line_cap("round")
      |> Easel.stroke()

    canvas =
      if depth >= max_depth - 2 do
        size = 3 + :rand.uniform(4)

        canvas
        |> Easel.begin_path()
        |> Easel.arc(end_x, end_y, size, 0, :math.pi() * 2)
        |> Easel.set_fill_style("rgba(34, #{100 + :rand.uniform(100)}, 34, 0.6)")
        |> Easel.fill()
      else
        canvas
      end

    new_length = length * (0.65 + :rand.uniform() * 0.1)
    spread = 0.4 + :rand.uniform() * 0.2

    canvas
    |> draw_tree(end_x, end_y, new_length, angle - spread, depth + 1, max_depth)
    |> draw_tree(end_x, end_y, new_length, angle + spread, depth + 1, max_depth)
  end
end
