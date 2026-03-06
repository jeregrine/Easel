# Braille bloom — neon orbital ribbons
# Run: mix run examples/term/braille_bloom.exs [--mode auto|luma|silhouette|braille|halfblock]

Code.require_file("example_opts.exs", __DIR__)

{term_cols, term_rows} =
  case {:io.columns(), :io.rows()} do
    {{:ok, cols}, {:ok, rows}} -> {cols, rows}
    _ -> {120, 40}
  end

size = max(min(term_cols * 12, term_rows * 22), 720)
width = size
height = size
center_x = size / 2
center_y = size / 2
points = 900
base_radius = size * 0.34

trace = fn canvas, opts ->
  %{
    hue: hue,
    alpha: alpha,
    line_width: line_width,
    phase: phase,
    speed: speed,
    a: a,
    b: b,
    twist: twist
  } = opts

  canvas
  |> Easel.set_stroke_style("hsla(#{hue}, 95%, 68%, #{alpha})")
  |> Easel.set_line_width(line_width)
  |> Easel.begin_path()
  |> then(fn c ->
    Enum.reduce(0..points, c, fn i, acc ->
      theta = i / points * 2 * :math.pi()
      pulse = 0.78 + 0.22 * :math.sin(theta * 6 + phase * 1.7)
      r = base_radius * pulse

      x = center_x + r * :math.sin(theta * a + phase * speed) * :math.cos(theta * twist + phase)

      y =
        center_y +
          r * :math.sin(theta * b - phase * speed * 0.8) * :math.sin(theta * twist + phase * 0.6)

      if i == 0 do
        Easel.move_to(acc, x, y)
      else
        Easel.line_to(acc, x, y)
      end
    end)
  end)
  |> Easel.stroke()
end

render_frame = fn t ->
  canvas =
    Easel.new(width, height)
    |> Easel.set_fill_style("#02030a")
    |> Easel.fill_rect(0, 0, width, height)
    |> Easel.set_global_alpha(0.08)

  canvas =
    Enum.reduce(0..7, canvas, fn i, acc ->
      r = base_radius * (0.32 + i * 0.085)
      hue = 210 + i * 9 + round(:math.sin(t + i) * 7)

      acc
      |> Easel.set_stroke_style("hsla(#{hue}, 100%, 65%, 0.12)")
      |> Easel.set_line_width(1)
      |> Easel.begin_path()
      |> Easel.arc(center_x, center_y, r, 0, 2 * :math.pi())
      |> Easel.stroke()
    end)
    |> Easel.set_global_alpha(1.0)

  traces = [
    %{
      hue: 188 + round(:math.sin(t * 0.3) * 18),
      alpha: 0.96,
      line_width: 2.6,
      phase: t,
      speed: 1.0,
      a: 2.0,
      b: 3.0,
      twist: 0.8
    },
    %{
      hue: 294 + round(:math.sin(t * 0.41) * 20),
      alpha: 0.82,
      line_width: 1.9,
      phase: t + 1.6,
      speed: 1.12,
      a: 3.0,
      b: 4.0,
      twist: 0.58
    },
    %{
      hue: 44 + round(:math.cos(t * 0.37) * 12),
      alpha: 0.66,
      line_width: 1.3,
      phase: t + 3.0,
      speed: 0.84,
      a: 5.0,
      b: 6.0,
      twist: 1.08
    }
  ]

  canvas = Enum.reduce(traces, canvas, fn trace_opts, acc -> trace.(acc, trace_opts) end)

  canvas
  |> Easel.set_fill_style("rgba(255,255,255,0.9)")
  |> Easel.begin_path()
  |> Easel.arc(center_x, center_y, 5, 0, 2 * :math.pi())
  |> Easel.fill()
  |> Easel.set_fill_style("rgba(255,255,255,0.08)")
  |> Easel.begin_path()
  |> Easel.arc(center_x, center_y, 18, 0, 2 * :math.pi())
  |> Easel.fill()
end

if Easel.Terminal.available?() do
  Easel.Terminal.animate(
    width,
    height,
    %{t: 0.0},
    fn %{t: t} = state ->
      {render_frame.(t), %{state | t: t + 0.038}}
    end,
    TermExampleOpts.merge_terminal_mode(
      title: "Braille Bloom",
      mode: :braille,
      fps: 24,
      color: :ansi256,
      dpr: 2.8,
      fit: :contain,
      background_threshold: 0.05,
      char_cache_size: 20_000
    )
  )
else
  IO.puts("Easel.Terminal is unavailable.")
  IO.puts("It currently requires wx support, {:termite, \"~> 0.4.0\"}, and an interactive TTY.")
end
