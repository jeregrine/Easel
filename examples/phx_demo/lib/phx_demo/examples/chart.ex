defmodule PhxDemo.Examples.Chart do
  def render do
    width = 600
    height = 400
    padding = 60

    data = [
      {"2018", 45},
      {"2019", 62},
      {"2020", 78},
      {"2021", 95},
      {"2022", 120},
      {"2023", 155},
      {"2024", 190},
      {"2025", 230}
    ]

    max_val = data |> Enum.map(&elem(&1, 1)) |> Enum.max()
    bar_count = length(data)
    chart_w = width - padding * 2
    chart_h = height - padding * 2
    bar_w = chart_w / bar_count * 0.7
    gap = chart_w / bar_count * 0.3

    colors = [
      "#6366f1",
      "#8b5cf6",
      "#a78bfa",
      "#c084fc",
      "#d946ef",
      "#ec4899",
      "#f43f5e",
      "#ef4444"
    ]

    canvas =
      Easel.new(width, height)
      |> Easel.set_fill_style("#fafafa")
      |> Easel.fill_rect(0, 0, width, height)
      |> Easel.set_fill_style("#1f2937")
      |> Easel.set_font("bold 18px sans-serif")
      |> Easel.set_text_align("center")
      |> Easel.fill_text("Elixir Popularity Index", width / 2, 30)
      |> Easel.set_stroke_style("#9ca3af")
      |> Easel.set_line_width(1)
      |> Easel.begin_path()
      |> Easel.move_to(padding, padding)
      |> Easel.line_to(padding, height - padding)
      |> Easel.line_to(width - padding, height - padding)
      |> Easel.stroke()

    canvas =
      Enum.reduce(0..4, canvas, fn i, acc ->
        y = padding + chart_h * (1 - i / 4)
        val = round(max_val * i / 4)

        acc
        |> Easel.set_stroke_style("#e5e7eb")
        |> Easel.set_line_width(0.5)
        |> Easel.begin_path()
        |> Easel.move_to(padding, y)
        |> Easel.line_to(width - padding, y)
        |> Easel.stroke()
        |> Easel.set_fill_style("#6b7280")
        |> Easel.set_font("12px sans-serif")
        |> Easel.set_text_align("right")
        |> Easel.fill_text("#{val}", padding - 8, y + 4)
      end)

    data
    |> Enum.with_index()
    |> Enum.reduce(canvas, fn {{label, value}, i}, acc ->
      x = padding + i * (bar_w + gap) + gap / 2
      bar_h = value / max_val * chart_h
      y = height - padding - bar_h
      color = Enum.at(colors, i)

      acc
      |> Easel.set_fill_style(color)
      |> Easel.fill_rect(x, y, bar_w, bar_h)
      |> Easel.set_stroke_style("rgba(0,0,0,0.1)")
      |> Easel.set_line_width(1)
      |> Easel.stroke_rect(x, y, bar_w, bar_h)
      |> Easel.set_fill_style("#374151")
      |> Easel.set_font("bold 12px sans-serif")
      |> Easel.set_text_align("center")
      |> Easel.fill_text("#{value}", x + bar_w / 2, y - 8)
      |> Easel.set_fill_style("#6b7280")
      |> Easel.set_font("12px sans-serif")
      |> Easel.fill_text(label, x + bar_w / 2, height - padding + 20)
    end)
    |> Easel.render()
  end
end
