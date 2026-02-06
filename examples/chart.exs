# Bar chart — Elixir popularity by year (fictional data)
# Run: mix run examples/chart.exs

alias Easel.API

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

colors = ["#6366f1", "#8b5cf6", "#a78bfa", "#c084fc", "#d946ef", "#ec4899", "#f43f5e", "#ef4444"]

canvas =
  Easel.new(width, height)
  # Background
  |> API.set_fill_style("#fafafa")
  |> API.fill_rect(0, 0, width, height)
  # Title
  |> API.set_fill_style("#1f2937")
  |> API.set_font("bold 18px sans-serif")
  |> API.set_text_align("center")
  |> API.fill_text("Elixir Popularity Index", width / 2, 30)
  # Axes
  |> API.set_stroke_style("#9ca3af")
  |> API.set_line_width(1)
  |> API.begin_path()
  |> API.move_to(padding, padding)
  |> API.line_to(padding, height - padding)
  |> API.line_to(width - padding, height - padding)
  |> API.stroke()

# Draw grid lines
canvas =
  Enum.reduce(0..4, canvas, fn i, acc ->
    y = padding + chart_h * (1 - i / 4)
    val = round(max_val * i / 4)

    acc
    |> API.set_stroke_style("#e5e7eb")
    |> API.set_line_width(0.5)
    |> API.begin_path()
    |> API.move_to(padding, y)
    |> API.line_to(width - padding, y)
    |> API.stroke()
    |> API.set_fill_style("#6b7280")
    |> API.set_font("12px sans-serif")
    |> API.set_text_align("right")
    |> API.fill_text("#{val}", padding - 8, y + 4)
  end)

# Draw bars
canvas =
  data
  |> Enum.with_index()
  |> Enum.reduce(canvas, fn {{label, value}, i}, acc ->
    x = padding + i * (bar_w + gap) + gap / 2
    bar_h = value / max_val * chart_h
    y = height - padding - bar_h
    color = Enum.at(colors, i)

    acc
    # Bar
    |> API.set_fill_style(color)
    |> API.fill_rect(x, y, bar_w, bar_h)
    # Bar border
    |> API.set_stroke_style("rgba(0,0,0,0.1)")
    |> API.set_line_width(1)
    |> API.stroke_rect(x, y, bar_w, bar_h)
    # Value label
    |> API.set_fill_style("#374151")
    |> API.set_font("bold 12px sans-serif")
    |> API.set_text_align("center")
    |> API.fill_text("#{value}", x + bar_w / 2, y - 8)
    # X-axis label
    |> API.set_fill_style("#6b7280")
    |> API.set_font("12px sans-serif")
    |> API.fill_text(label, x + bar_w / 2, height - padding + 20)
  end)
  |> Easel.render()

if Code.ensure_loaded?(Easel.WX) and Easel.WX.available?() do
  Easel.WX.render(canvas, title: "Chart")
else
  IO.puts("Chart: #{length(canvas.ops)} operations")
end
