# Terminal wave animation
# Run: mix run examples/term/terminal_wave.exs [--mode auto|luma|silhouette|braille|halfblock]

Code.require_file("example_opts.exs", __DIR__)

{term_cols, term_rows} =
  case {:io.columns(), :io.rows()} do
    {{:ok, cols}, {:ok, rows}} -> {cols, rows}
    _ -> {120, 40}
  end

# Render to a larger off-screen canvas, then scale down into terminal cells.
# Keep aspect aligned with `cell_aspect: 2.0` so we don't letterbox/shrink.
render_scale = 1
width = max(term_cols * render_scale, 240)
height = max(term_rows * render_scale * 2, 160)
label_font = 28
amp1 = height * 0.18
amp2 = height * 0.08
initial = %{t: 0.0}

render_frame = fn t ->
  Easel.new(width, height)
  |> Easel.set_fill_style("black")
  |> Easel.fill_rect(0, 0, width, height)
  |> Easel.set_stroke_style("hsl(190, 80%, 65%)")
  |> Easel.set_line_width(2)
  |> Easel.begin_path()
  |> then(fn c ->
    Enum.reduce(0..(width - 1), c, fn x, acc ->
      y = height * 0.5 + :math.sin(x * 0.08 + t * 2.0) * amp1 + :math.sin(x * 0.03 - t) * amp2

      if x == 0 do
        Easel.move_to(acc, x, y)
      else
        Easel.line_to(acc, x, y)
      end
    end)
  end)
  |> Easel.stroke()
  |> then(fn c ->
    if term_cols < 80 do
      c
    else
      c
      |> Easel.set_fill_style("white")
      |> Easel.set_font("bold #{label_font}px monospace")
      |> Easel.fill_text("Easel Terminal [q]", 8, label_font + 10)
    end
  end)
end

if Easel.Terminal.available?() do
  Easel.Terminal.animate(
    width,
    height,
    initial,
    fn %{t: t} = state ->
      {render_frame.(t), %{state | t: t + 0.08}}
    end,
    TermExampleOpts.merge_terminal_mode(
      fps: 24,
      color: :none,
      fit: :contain,
      cell_aspect: 2.0,
      dpr: 2.0,
      samples: 3,
      glyph_width: 7,
      glyph_height: 15,
      background_threshold: 0.08,
      char_cache_size: 20_000
    )
  )
else
  IO.puts("Easel.Terminal is unavailable.")
  IO.puts("It currently requires wx support, {:termite, \"~> 0.4.0\"}, and an interactive TTY.")
end
