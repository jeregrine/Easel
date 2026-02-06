# Piet Mondrian–style generative art
# Run: mix run examples/mondrian.exs


width = 500
height = 500

defmodule Mondrian do
  @colors ["#c0392b", "#2980b9", "#f1c40f", "#ecf0f1", "#ecf0f1", "#ecf0f1"]
  @line_width 6

  def generate(canvas, x, y, w, h, depth) when depth > 5 or w < 40 or h < 40 do
    color = Enum.random(@colors)

    canvas
    |> Easel.set_fill_style(color)
    |> Easel.fill_rect(x + @line_width / 2, y + @line_width / 2, w - @line_width, h - @line_width)
    |> Easel.set_stroke_style("#2c3e50")
    |> Easel.set_line_width(@line_width)
    |> Easel.stroke_rect(x, y, w, h)
  end

  def generate(canvas, x, y, w, h, depth) do
    if :rand.uniform() < 0.5 do
      # Vertical split
      split = round(w * (0.3 + :rand.uniform() * 0.4))

      canvas
      |> generate(x, y, split, h, depth + 1)
      |> generate(x + split, y, w - split, h, depth + 1)
    else
      # Horizontal split
      split = round(h * (0.3 + :rand.uniform() * 0.4))

      canvas
      |> generate(x, y, w, split, depth + 1)
      |> generate(x, y + split, w, h - split, depth + 1)
    end
  end
end

:rand.seed(:exsss, {123, 456, 789})

canvas =
  Easel.new(width, height)
  |> Easel.set_fill_style("#ecf0f1")
  |> Easel.fill_rect(0, 0, width, height)

canvas =
  Mondrian.generate(canvas, 0, 0, width, height, 0)
  |> Easel.render()

if Code.ensure_loaded?(Easel.WX) and Easel.WX.available?() do
  Easel.WX.render(canvas, title: "Mondrian")
else
  IO.puts("Mondrian: #{length(canvas.ops)} operations")
end
