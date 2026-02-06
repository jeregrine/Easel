# Smiley face
# Run: mix run examples/smiley.exs

alias Easel.API

canvas =
  Easel.new(300, 300)
  # Face
  |> API.begin_path()
  |> API.arc(150, 150, 100, 0, :math.pi() * 2)
  |> API.set_fill_style("#FFD700")
  |> API.fill()
  |> API.set_stroke_style("#333")
  |> API.set_line_width(3)
  |> API.stroke()
  # Left eye
  |> API.begin_path()
  |> API.arc(115, 120, 15, 0, :math.pi() * 2)
  |> API.set_fill_style("#333")
  |> API.fill()
  # Right eye
  |> API.begin_path()
  |> API.arc(185, 120, 15, 0, :math.pi() * 2)
  |> API.fill()
  # Smile
  |> API.begin_path()
  |> API.arc(150, 155, 60, 0.2, :math.pi() - 0.2)
  |> API.set_stroke_style("#333")
  |> API.set_line_width(4)
  |> API.set_line_cap("round")
  |> API.stroke()
  |> Easel.render()

IO.inspect(canvas.ops, label: "Smiley ops")
IO.puts("#{length(canvas.ops)} operations")
