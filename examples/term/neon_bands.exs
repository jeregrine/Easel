# Neon bands — scrolling half-block demo
# Run: mix run examples/term/neon_bands.exs [--mode auto|luma|silhouette|braille|halfblock]

Code.require_file("example_opts.exs", __DIR__)

{term_cols, term_rows} =
  case {:io.columns(), :io.rows()} do
    {{:ok, cols}, {:ok, rows}} -> {cols, rows}
    _ -> {120, 40}
  end

width = max(term_cols * 8, 640)
height = max(term_rows * 14, 420)
center_y = height / 2

band = fn canvas, t, opts ->
  %{
    y: y0,
    thickness: thickness,
    amp: amp,
    hue: hue,
    speed: speed,
    freq: freq,
    phase: phase,
    alpha: alpha
  } = opts

  top_points =
    Enum.map(0..64, fn i ->
      x = i / 64 * width

      y =
        y0 +
          :math.sin(x * freq + t * speed + phase) * amp +
          :math.sin(x * (freq * 0.45) - t * speed * 0.55 + phase) * (amp * 0.32)

      {x, y}
    end)

  bottom_points =
    Enum.map(top_points, fn {x, y} ->
      drift = thickness * 0.12 * :math.sin(x * 0.01 + t * 0.7 + phase)
      {x, y + thickness + drift}
    end)

  [{x0, y_start} | rest] = top_points

  canvas
  |> Easel.set_fill_style("hsla(#{hue}, 100%, 58%, #{alpha})")
  |> Easel.begin_path()
  |> Easel.move_to(x0, y_start)
  |> then(fn c -> Enum.reduce(rest, c, fn {x, y}, acc -> Easel.line_to(acc, x, y) end) end)
  |> then(fn c ->
    Enum.reduce(Enum.reverse(bottom_points), c, fn {x, y}, acc -> Easel.line_to(acc, x, y) end)
  end)
  |> Easel.close_path()
  |> Easel.fill()
end

render_frame = fn t ->
  canvas =
    Easel.new(width, height)
    |> Easel.set_fill_style("#02030a")
    |> Easel.fill_rect(0, 0, width, height)
    |> Easel.set_fill_style("rgba(8, 12, 36, 0.9)")
    |> Easel.fill_rect(0, 0, width, height)

  accent_lines = [
    {center_y - 126, "rgba(0, 255, 255, 0.14)"},
    {center_y - 38, "rgba(255, 0, 220, 0.14)"},
    {center_y + 52, "rgba(80, 255, 120, 0.12)"}
  ]

  canvas =
    Enum.reduce(accent_lines, canvas, fn {y, color}, acc ->
      acc
      |> Easel.set_fill_style(color)
      |> Easel.fill_rect(0, y, width, 3)
    end)

  bands = [
    %{
      y: center_y - 120,
      thickness: 26,
      amp: 18,
      hue: 188,
      speed: 2.0,
      freq: 0.010,
      phase: 0.0,
      alpha: 0.95
    },
    %{
      y: center_y - 54,
      thickness: 32,
      amp: 24,
      hue: 304,
      speed: 1.45,
      freq: 0.008,
      phase: 1.4,
      alpha: 0.88
    },
    %{
      y: center_y + 18,
      thickness: 28,
      amp: 21,
      hue: 124,
      speed: 2.3,
      freq: 0.011,
      phase: 2.2,
      alpha: 0.84
    },
    %{
      y: center_y + 88,
      thickness: 22,
      amp: 16,
      hue: 210,
      speed: 1.7,
      freq: 0.009,
      phase: 3.4,
      alpha: 0.7
    }
  ]

  canvas = Enum.reduce(bands, canvas, fn opts, acc -> band.(acc, t, opts) end)

  canvas
  |> Easel.set_fill_style("rgba(255,255,255,0.05)")
  |> Easel.begin_path()
  |> Easel.arc(width * 0.18, height * 0.22, width * 0.06, 0, 2 * :math.pi())
  |> Easel.fill()
  |> Easel.set_fill_style("rgba(255,255,255,0.04)")
  |> Easel.begin_path()
  |> Easel.arc(width * 0.82, height * 0.72, width * 0.08, 0, 2 * :math.pi())
  |> Easel.fill()
end

if Easel.Terminal.available?() do
  Easel.Terminal.animate(
    width,
    height,
    %{t: 0.0},
    fn %{t: t} = state ->
      {render_frame.(t), %{state | t: t + 0.08}}
    end,
    TermExampleOpts.merge_terminal_mode(
      title: "Half-Block Bands",
      mode: :halfblock,
      fps: 20,
      color: :ansi256,
      dpr: 2.0,
      fit: :contain,
      cell_aspect: 1.0,
      background_threshold: 0.02,
      halfblock_samples: 3,
      halfblock_color_merge_distance: 12
    )
  )
else
  IO.puts("Easel.Terminal is unavailable.")
  IO.puts("It currently requires wx support, {:termite, \"~> 0.4.0\"}, and an interactive TTY.")
end
