# Animated analog clock
# Run: mix run examples/clock.exs
# (Must use `mix run`, not `elixir`, to load project modules)

alias Easel.API

size = 400
cx = size / 2
cy = size / 2
radius = 170

defmodule Clock do
  def render(size, cx, cy, radius) do
    now = Time.utc_now()
    hours = now.hour |> rem(12)
    minutes = now.minute
    seconds = now.second

    Easel.new(size, size)
    |> draw_face(cx, cy, radius)
    |> draw_markers(cx, cy, radius)
    |> draw_numbers(cx, cy, radius)
    |> draw_minute_ticks(cx, cy, radius)
    |> draw_hands(cx, cy, hours, minutes, seconds)
    |> draw_center(cx, cy, hours, minutes, seconds)
  end

  defp draw_face(canvas, cx, cy, radius) do
    canvas
    |> API.set_fill_style("#1a1a2e")
    |> API.fill_rect(0, 0, cx * 2, cy * 2)
    |> API.begin_path()
    |> API.arc(cx, cy, radius, 0, :math.pi() * 2)
    |> API.set_fill_style("#16213e")
    |> API.fill()
    |> API.set_stroke_style("#e94560")
    |> API.set_line_width(4)
    |> API.stroke()
    |> API.begin_path()
    |> API.arc(cx, cy, radius - 10, 0, :math.pi() * 2)
    |> API.set_stroke_style("rgba(233, 69, 96, 0.3)")
    |> API.set_line_width(1)
    |> API.stroke()
  end

  defp draw_markers(canvas, cx, cy, radius) do
    Enum.reduce(1..12, canvas, fn i, acc ->
      angle = i * :math.pi() / 6 - :math.pi() / 2
      is_quarter = rem(i, 3) == 0
      inner_r = if is_quarter, do: radius - 30, else: radius - 20
      outer_r = radius - 12
      width = if is_quarter, do: 3, else: 1.5

      acc
      |> API.begin_path()
      |> API.move_to(cx + inner_r * :math.cos(angle), cy + inner_r * :math.sin(angle))
      |> API.line_to(cx + outer_r * :math.cos(angle), cy + outer_r * :math.sin(angle))
      |> API.set_stroke_style(if(is_quarter, do: "#e94560", else: "#a0a0b0"))
      |> API.set_line_width(width)
      |> API.set_line_cap("round")
      |> API.stroke()
    end)
  end

  defp draw_numbers(canvas, cx, cy, radius) do
    Enum.reduce(1..12, canvas, fn i, acc ->
      angle = i * :math.pi() / 6 - :math.pi() / 2
      text_r = radius - 45

      acc
      |> API.set_fill_style("#e0e0e0")
      |> API.set_font("bold 20px sans-serif")
      |> API.set_text_align("center")
      |> API.set_text_baseline("middle")
      |> API.fill_text("#{i}", cx + text_r * :math.cos(angle), cy + text_r * :math.sin(angle))
    end)
  end

  defp draw_minute_ticks(canvas, cx, cy, radius) do
    Enum.reduce(0..59, canvas, fn i, acc ->
      if rem(i, 5) != 0 do
        angle = i * :math.pi() / 30 - :math.pi() / 2

        acc
        |> API.begin_path()
        |> API.move_to(cx + (radius - 15) * :math.cos(angle), cy + (radius - 15) * :math.sin(angle))
        |> API.line_to(cx + (radius - 12) * :math.cos(angle), cy + (radius - 12) * :math.sin(angle))
        |> API.set_stroke_style("rgba(160, 160, 176, 0.5)")
        |> API.set_line_width(0.5)
        |> API.stroke()
      else
        acc
      end
    end)
  end

  defp draw_hands(canvas, cx, cy, hours, minutes, seconds) do
    # Hour hand
    hour_angle = (hours + minutes / 60) * :math.pi() / 6 - :math.pi() / 2

    canvas =
      canvas
      |> API.begin_path()
      |> API.move_to(cx - 15 * :math.cos(hour_angle), cy - 15 * :math.sin(hour_angle))
      |> API.line_to(cx + 95 * :math.cos(hour_angle), cy + 95 * :math.sin(hour_angle))
      |> API.set_stroke_style("#e0e0e0")
      |> API.set_line_width(6)
      |> API.set_line_cap("round")
      |> API.stroke()

    # Minute hand
    minute_angle = (minutes + seconds / 60) * :math.pi() / 30 - :math.pi() / 2

    canvas =
      canvas
      |> API.begin_path()
      |> API.move_to(cx - 20 * :math.cos(minute_angle), cy - 20 * :math.sin(minute_angle))
      |> API.line_to(cx + 130 * :math.cos(minute_angle), cy + 130 * :math.sin(minute_angle))
      |> API.set_stroke_style("#e0e0e0")
      |> API.set_line_width(3)
      |> API.set_line_cap("round")
      |> API.stroke()

    # Second hand
    second_angle = seconds * :math.pi() / 30 - :math.pi() / 2

    canvas
    |> API.begin_path()
    |> API.move_to(cx - 25 * :math.cos(second_angle), cy - 25 * :math.sin(second_angle))
    |> API.line_to(cx + 140 * :math.cos(second_angle), cy + 140 * :math.sin(second_angle))
    |> API.set_stroke_style("#e94560")
    |> API.set_line_width(1.5)
    |> API.set_line_cap("round")
    |> API.stroke()
  end

  defp draw_center(canvas, cx, cy, hours, minutes, seconds) do
    canvas
    |> API.begin_path()
    |> API.arc(cx, cy, 6, 0, :math.pi() * 2)
    |> API.set_fill_style("#e94560")
    |> API.fill()
    |> API.begin_path()
    |> API.arc(cx, cy, 3, 0, :math.pi() * 2)
    |> API.set_fill_style("#1a1a2e")
    |> API.fill()
    |> API.set_fill_style("rgba(233, 69, 96, 0.8)")
    |> API.set_font("14px monospace")
    |> API.set_text_align("center")
    |> API.fill_text(
      "#{String.pad_leading("#{hours}", 2, "0")}:#{String.pad_leading("#{minutes}", 2, "0")}:#{String.pad_leading("#{seconds}", 2, "0")} UTC",
      cx,
      cy + 55
    )
  end
end

if Code.ensure_loaded?(Easel.WX) and Easel.WX.available?() do
  Easel.WX.animate(size, size, nil, fn _state ->
    canvas = Clock.render(size, cx, cy, radius)
    {canvas, nil}
  end, title: "Clock", interval: 1000)
else
  canvas = Clock.render(size, cx, cy, radius) |> Easel.render()
  IO.puts("Clock at #{Time.utc_now()}: #{length(canvas.ops)} operations")
  IO.puts("Run with wx to see the animated clock.")
end
