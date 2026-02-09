defmodule PhxDemo.Examples.Mondrian do
  @mondrian_colors ["#c0392b", "#2980b9", "#f1c40f", "#ecf0f1", "#ecf0f1", "#ecf0f1"]
  @line_width 6

  def render do
    random_seed()
    width = 500
    height = 500

    canvas =
      Easel.new(width, height)
      |> Easel.set_fill_style("#ecf0f1")
      |> Easel.fill_rect(0, 0, width, height)

    split(canvas, 0, 0, width, height, 0)
    |> Easel.render()
  end

  defp random_seed do
    a = :erlang.unique_integer([:positive])
    b = :erlang.phash2({System.system_time(), self()})
    c = :erlang.phash2({System.monotonic_time(), make_ref()})
    :rand.seed(:exsss, {a, b, c})
  end

  defp split(canvas, x, y, w, h, depth) when depth > 5 or w < 40 or h < 40 do
    color = Enum.random(@mondrian_colors)

    canvas
    |> Easel.set_fill_style(color)
    |> Easel.fill_rect(x + @line_width / 2, y + @line_width / 2, w - @line_width, h - @line_width)
    |> Easel.set_stroke_style("#2c3e50")
    |> Easel.set_line_width(@line_width)
    |> Easel.stroke_rect(x, y, w, h)
  end

  defp split(canvas, x, y, w, h, depth) do
    if :rand.uniform() < 0.5 do
      split_w = round(w * (0.3 + :rand.uniform() * 0.4))

      canvas
      |> split(x, y, split_w, h, depth + 1)
      |> split(x + split_w, y, w - split_w, h, depth + 1)
    else
      split_h = round(h * (0.3 + :rand.uniform() * 0.4))

      canvas
      |> split(x, y, w, split_h, depth + 1)
      |> split(x, y + split_h, w, h - split_h, depth + 1)
    end
  end
end
