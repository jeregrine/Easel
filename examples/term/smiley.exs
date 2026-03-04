# Smiley face
# Run: mix run examples/term/smiley.exs

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

if Easel.Terminal.available?() do
  Easel.Terminal.render(canvas,
    title: "Smiley",
    color: :ansi256,
    dpr: 2.0,
    samples: 2,
    fit: :contain
  )
else
  IO.puts("Easel.Terminal is unavailable.")
  IO.puts("It currently requires wx support, {:termite, \"~> 0.4.0\"}, and an interactive TTY.")
end
