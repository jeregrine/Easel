# Smiley face
# Run: mix run examples/smiley.exs


canvas =
  Easel.new(300, 300)
  # Face
  |> Easel.begin_path()
  |> Easel.arc(150, 150, 100, 0, :math.pi() * 2)
  |> Easel.set_fill_style("#FFD700")
  |> Easel.fill()
  |> Easel.set_stroke_style("#333")
  |> Easel.set_line_width(3)
  |> Easel.stroke()
  # Left eye
  |> Easel.begin_path()
  |> Easel.arc(115, 120, 15, 0, :math.pi() * 2)
  |> Easel.set_fill_style("#333")
  |> Easel.fill()
  # Right eye
  |> Easel.begin_path()
  |> Easel.arc(185, 120, 15, 0, :math.pi() * 2)
  |> Easel.fill()
  # Smile
  |> Easel.begin_path()
  |> Easel.arc(150, 155, 60, 0.2, :math.pi() - 0.2)
  |> Easel.set_stroke_style("#333")
  |> Easel.set_line_width(4)
  |> Easel.set_line_cap("round")
  |> Easel.stroke()
  |> Easel.render()

if Code.ensure_loaded?(Easel.WX) and Easel.WX.available?() do
  Easel.WX.render(canvas, title: "Smiley")
else
  IO.puts("Smiley: #{length(canvas.ops)} operations")
end
