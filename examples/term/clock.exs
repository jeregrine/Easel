# Animated terminal clock (digital + abstract progress bar)
# Run: mix run examples/term/clock.exs [--mode auto|luma|silhouette|braille|halfblock]

Code.require_file("example_opts.exs", __DIR__)

width = 640
height = 260

defmodule Clock do
  def render(width, height, tick) do
    now = Time.utc_now()

    hh = String.pad_leading(Integer.to_string(now.hour), 2, "0")
    mm = String.pad_leading(Integer.to_string(now.minute), 2, "0")
    ss = String.pad_leading(Integer.to_string(now.second), 2, "0")

    colon = if rem(tick, 2) == 0, do: ":", else: " "
    time_text = "#{hh}#{colon}#{mm}#{colon}#{ss}"

    hue = rem(now.second * 6 + tick * 4, 360)

    bar_w = width * 0.72
    bar_x = (width - bar_w) / 2
    bar_y = height - 52
    progress = now.second / 60

    Easel.new(width, height)
    |> Easel.set_fill_style("#0a0a12")
    |> Easel.fill_rect(0, 0, width, height)
    |> Easel.set_fill_style("hsl(#{hue}, 90%, 65%)")
    |> Easel.set_font("bold 124px monospace")
    |> Easel.set_text_align("center")
    |> Easel.set_text_baseline("middle")
    |> Easel.fill_text(time_text, width / 2, height * 0.44)
    |> Easel.set_fill_style("rgba(220,220,235,0.9)")
    |> Easel.set_font("bold 26px monospace")
    |> Easel.fill_text("UTC", width / 2, height * 0.7)
    |> Easel.set_fill_style("rgba(180,180,200,0.25)")
    |> Easel.fill_rect(bar_x, bar_y, bar_w, 12)
    |> Easel.set_fill_style("hsl(#{hue}, 90%, 58%)")
    |> Easel.fill_rect(bar_x, bar_y, bar_w * progress, 12)
  end
end

if Easel.Terminal.available?() do
  Easel.Terminal.animate(
    width,
    height,
    %{tick: 0},
    fn %{tick: tick} = state ->
      {Clock.render(width, height, tick), %{state | tick: tick + 1}}
    end,
    TermExampleOpts.merge_terminal_mode(
      title: "Clock",
      fps: 8,
      color: :ansi256,
      dpr: 2.0,
      samples: 2,
      glyph_width: 7,
      glyph_height: 15,
      background_threshold: 0.1,
      fit: :contain,
      char_cache_size: 20_000
    )
  )
else
  IO.puts("Easel.Terminal is unavailable.")
  IO.puts("It currently requires wx support, {:termite, \"~> 0.4.0\"}, and an interactive TTY.")
end
