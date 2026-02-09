defmodule PhxDemo.Examples.Clock do
  def render, do: render(Time.utc_now())

  def render(%Time{} = now) do
    size = 400
    cx = size / 2
    cy = size / 2
    radius = 170
    hours = rem(now.hour, 12)
    minutes = now.minute
    seconds = now.second

    Easel.new(size, size)
    |> clock_face(cx, cy, radius)
    |> clock_markers(cx, cy, radius)
    |> clock_numbers(cx, cy, radius)
    |> clock_hands(cx, cy, radius, hours, minutes, seconds)
    |> clock_center(cx, cy, hours, minutes, seconds)
    |> Easel.render()
  end

  defp clock_face(canvas, cx, cy, radius) do
    canvas
    |> Easel.set_fill_style("#1a1a2e")
    |> Easel.fill_rect(0, 0, cx * 2, cy * 2)
    |> Easel.begin_path()
    |> Easel.arc(cx, cy, radius, 0, :math.pi() * 2)
    |> Easel.set_fill_style("#16213e")
    |> Easel.fill()
    |> Easel.set_stroke_style("#e94560")
    |> Easel.set_line_width(4)
    |> Easel.stroke()
    |> Easel.begin_path()
    |> Easel.arc(cx, cy, radius - 10, 0, :math.pi() * 2)
    |> Easel.set_stroke_style("rgba(233, 69, 96, 0.3)")
    |> Easel.set_line_width(1)
    |> Easel.stroke()
  end

  defp clock_markers(canvas, cx, cy, radius) do
    Enum.reduce(1..12, canvas, fn i, acc ->
      angle = i * :math.pi() / 6 - :math.pi() / 2
      is_quarter = rem(i, 3) == 0
      inner_r = if is_quarter, do: radius - 30, else: radius - 20
      outer_r = radius - 12
      width = if is_quarter, do: 3, else: 1.5

      acc
      |> Easel.begin_path()
      |> Easel.move_to(cx + inner_r * :math.cos(angle), cy + inner_r * :math.sin(angle))
      |> Easel.line_to(cx + outer_r * :math.cos(angle), cy + outer_r * :math.sin(angle))
      |> Easel.set_stroke_style(if(is_quarter, do: "#e94560", else: "#a0a0b0"))
      |> Easel.set_line_width(width)
      |> Easel.set_line_cap("round")
      |> Easel.stroke()
    end)
  end

  defp clock_numbers(canvas, cx, cy, radius) do
    Enum.reduce(1..12, canvas, fn i, acc ->
      angle = i * :math.pi() / 6 - :math.pi() / 2
      text_r = radius - 45

      acc
      |> Easel.set_fill_style("#e0e0e0")
      |> Easel.set_font("bold 20px sans-serif")
      |> Easel.set_text_align("center")
      |> Easel.set_text_baseline("middle")
      |> Easel.fill_text("#{i}", cx + text_r * :math.cos(angle), cy + text_r * :math.sin(angle))
    end)
  end

  defp clock_hands(canvas, cx, cy, _radius, hours, minutes, seconds) do
    hour_angle = (hours + minutes / 60) * :math.pi() / 6 - :math.pi() / 2
    minute_angle = (minutes + seconds / 60) * :math.pi() / 30 - :math.pi() / 2
    second_angle = seconds * :math.pi() / 30 - :math.pi() / 2

    canvas
    |> Easel.begin_path()
    |> Easel.move_to(cx - 15 * :math.cos(hour_angle), cy - 15 * :math.sin(hour_angle))
    |> Easel.line_to(cx + 95 * :math.cos(hour_angle), cy + 95 * :math.sin(hour_angle))
    |> Easel.set_stroke_style("#e0e0e0")
    |> Easel.set_line_width(6)
    |> Easel.set_line_cap("round")
    |> Easel.stroke()
    |> Easel.begin_path()
    |> Easel.move_to(cx - 20 * :math.cos(minute_angle), cy - 20 * :math.sin(minute_angle))
    |> Easel.line_to(cx + 130 * :math.cos(minute_angle), cy + 130 * :math.sin(minute_angle))
    |> Easel.set_stroke_style("#e0e0e0")
    |> Easel.set_line_width(3)
    |> Easel.set_line_cap("round")
    |> Easel.stroke()
    |> Easel.begin_path()
    |> Easel.move_to(cx - 25 * :math.cos(second_angle), cy - 25 * :math.sin(second_angle))
    |> Easel.line_to(cx + 140 * :math.cos(second_angle), cy + 140 * :math.sin(second_angle))
    |> Easel.set_stroke_style("#e94560")
    |> Easel.set_line_width(1.5)
    |> Easel.set_line_cap("round")
    |> Easel.stroke()
  end

  defp clock_center(canvas, cx, cy, hours, minutes, seconds) do
    canvas
    |> Easel.begin_path()
    |> Easel.arc(cx, cy, 6, 0, :math.pi() * 2)
    |> Easel.set_fill_style("#e94560")
    |> Easel.fill()
    |> Easel.begin_path()
    |> Easel.arc(cx, cy, 3, 0, :math.pi() * 2)
    |> Easel.set_fill_style("#1a1a2e")
    |> Easel.fill()
    |> Easel.set_fill_style("rgba(233, 69, 96, 0.8)")
    |> Easel.set_font("14px monospace")
    |> Easel.set_text_align("center")
    |> Easel.fill_text(
      "#{String.pad_leading("#{hours}", 2, "0")}:#{String.pad_leading("#{minutes}", 2, "0")}:#{String.pad_leading("#{seconds}", 2, "0")} UTC",
      cx,
      cy + 55
    )
  end
end
