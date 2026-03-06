defmodule Easel.Terminal do
  import Bitwise

  @moduledoc """
  Experimental terminal backend for Easel.

  This backend renders Easel canvas ops by rasterizing off-screen with
  `Easel.WX.rasterize/2`, then converting pixels into terminal glyphs.

  It is currently optimized for feasibility over perfect fidelity.
  """

  @default_charset " .:-=+*#%@"
  @default_cell_aspect 2.0
  @default_bg_threshold 0.05
  @default_glyph_width 9
  @default_glyph_height 19
  @default_glyph_threshold 0.5
  @default_dark_min_luma 0.28
  @default_light_max_luma 0.72
  @glyph_profile_cache_table :easel_terminal_glyph_profile_cache
  @glyph_profile_cache_limit 128
  @sample_map_cache_limit 64

  @termite_available Code.ensure_loaded?(Module.concat([Termite, Terminal])) and
                       Code.ensure_loaded?(Module.concat([Termite, Screen]))

  @doc """
  Returns `true` when both wx rasterization and Termite terminal I/O are available.
  """
  def available? do
    @termite_available and Easel.WX.available?() and tty_available?()
  end

  @doc """
  Converts raw RGB pixels into a terminal frame string.

  ## Arguments

    * `image` - `%{width: w, height: h, rgb: <<r, g, b, ...>>}`
    * `columns` - output character columns
    * `rows` - output character rows

  ## Options

    * `:charset` - manual luma ramp string for `:luma` mode
    * `:mode` - explicitly choose `:luma`, `:silhouette`, `:braille`, or `:halfblock`
    * `:invert` - invert luma ramp mapping (only for manual charset mode, default `false`)
    * `:fit` - `:contain` (default) or `:fill`
    * `:cell_aspect` - character cell height/width ratio (default `2.0`)
    * `:samples` - per-cell supersampling edge length (manual charset mode, default `2`)
    * `:background_threshold` - brightness below which pixels are treated as background in silhouette mode (default `0.05`)
    * `:glyph_width` / `:glyph_height` - silhouette glyph mask size (defaults `9x19`)
    * `:glyph_threshold` - threshold for binarizing glyph masks (default `0.5`)
    * `:char_cache` - cache silhouette mask→glyph lookups (default `true`)
    * `:char_cache_size` - max cached masks before reset (default `8192`)
    * `:theme` - `:auto` (default), `:dark`, or `:light` for optional contrast adaptation
    * `:auto_contrast` - adapt colors to terminal theme (default `false`)
    * `:dark_min_luma` - minimum foreground luma on dark terminals (default `0.28`)
    * `:light_max_luma` - maximum foreground luma on light terminals (default `0.72`)
    * `:color` - `:none` (default) or `:ansi256`
  """
  def frame_from_rgb(%{width: width, height: height, rgb: rgb}, columns, rows, opts \\ [])
      when is_integer(width) and width > 0 and is_integer(height) and height > 0 and
             is_binary(rgb) and is_integer(columns) and columns > 0 and is_integer(rows) and
             rows > 0 do
    expected = width * height * 3

    if byte_size(rgb) < expected do
      raise ArgumentError,
            "rgb buffer is too small: got #{byte_size(rgb)} bytes, expected at least #{expected}"
    end

    case render_mode(opts) do
      :silhouette ->
        frame_from_rgb_silhouette(%{width: width, height: height, rgb: rgb}, columns, rows, opts)

      :braille ->
        frame_from_rgb_braille(%{width: width, height: height, rgb: rgb}, columns, rows, opts)

      :halfblock ->
        frame_from_rgb_halfblock(%{width: width, height: height, rgb: rgb}, columns, rows, opts)

      :luma ->
        frame_from_rgb_luma(%{width: width, height: height, rgb: rgb}, columns, rows, opts)
    end
  end

  if @termite_available do
    @doc """
    Renders a canvas in the terminal.

    Defaults to alt-screen mode and waits for `q` (or Ctrl+C) before returning.

    ## Options

      * `:columns`, `:rows` - output frame size (defaults to terminal size)
      * `:charset`, `:invert`, `:fit`, `:cell_aspect`, `:samples`, `:char_cache`, `:char_cache_size`, `:theme`, `:auto_contrast`, `:color` - see `frame_from_rgb/4`
      * `:dpr` - rasterization DPR (default `1.0`, higher looks better but costs more)
      * `:title` - terminal title (OSC)
      * `:wait` - wait for quit key (default `true`)
      * `:alt_screen` - use alternate screen buffer (default `true`)
      * `:hide_cursor` - hide cursor during rendering (default `true`)
      * `:on_key_down` - callback for key events in wait loop (`fn key_event -> ... end`)
    """
    def render(%Easel{} = canvas, opts \\ []) do
      ensure_wx_available!()
      ensure_tty_available!()

      with_terminal(opts, fn term ->
        term = refresh_terminal_size(term, opts)
        {term, cols, rows} = terminal_grid(term, opts)
        frame = canvas_to_frame(canvas, cols, rows, nil, nil, opts)
        {term, frame_state} = draw_frame(term, frame)

        if Keyword.get(opts, :wait, true) do
          wait_for_quit(term, canvas, frame_state, opts)
        else
          :ok
        end
      end)
    end

    @doc """
    Runs a terminal animation loop.

    The `fun` receives the current animation state and must return
    `{%Easel{}, new_state}`.

    Press `q` (or Ctrl+C) to stop.

    ## Options

      * `:fps` - frames per second (default `30`)
      * `:interval` - frame interval in ms (overrides `:fps`)
      * `:columns`, `:rows` - output frame size (defaults to terminal size)
      * `:on_key_down` - `fn key_event, state -> new_state end`
      * `:alt_screen` - use alternate screen buffer (default `true`)
      * `:hide_cursor` - hide cursor during rendering (default `true`)
      * `:title` - terminal title (OSC)
      * `:charset`, `:invert`, `:fit`, `:cell_aspect`, `:samples`, `:char_cache`, `:char_cache_size`, `:theme`, `:auto_contrast`, `:color`, `:dpr`
    """
    def animate(width, height, state, fun, opts \\ []) when is_function(fun, 1) do
      ensure_wx_available!()
      ensure_tty_available!()
      interval_ms = animation_interval_ms(opts)

      with_terminal(opts, fn term ->
        term = refresh_terminal_size(term, opts)
        animate_loop(term, width, height, state, fun, opts, interval_ms, nil)
      end)
    end

    defp ensure_wx_available! do
      if Easel.WX.available?() do
        :ok
      else
        raise "Easel.Terminal requires Erlang compiled with wx support."
      end
    end

    defp ensure_tty_available! do
      if tty_available?() do
        :ok
      else
        raise "Easel.Terminal requires an interactive TTY. Run it from a real terminal session."
      end
    end

    defp animate_loop(term, width, height, state, fun, opts, interval_ms, previous_frame) do
      {canvas, next_state} = fun.(state)
      {term, cols, rows} = terminal_grid(term, opts)
      frame = canvas_to_frame(canvas, cols, rows, width, height, opts)
      {term, previous_frame} = draw_frame(term, frame, previous_frame)

      deadline = now_ms() + interval_ms

      case consume_events_until(term, next_state, deadline, opts) do
        {:stop, _term, _state} ->
          :ok

        {:cont, term, state} ->
          animate_loop(term, width, height, state, fun, opts, interval_ms, previous_frame)
      end
    end

    defp consume_events_until(term, state, deadline, opts) do
      remaining = deadline - now_ms()

      if remaining <= 0 do
        {:cont, term, state}
      else
        case t_poll_event(term, remaining) do
          :timeout ->
            {:cont, term, state}

          {:signal, :winch} ->
            term = t_resize(term)
            consume_events_until(term, state, deadline, opts)

          {:data, data} ->
            key_event = key_event_from_data(data)
            state = apply_animate_key_handler(opts, key_event, state)

            if quit_key?(key_event) do
              {:stop, term, state}
            else
              consume_events_until(term, state, deadline, opts)
            end

          _other ->
            consume_events_until(term, state, deadline, opts)
        end
      end
    end

    defp wait_for_quit(term, canvas, previous_frame, opts) do
      case t_poll_event(term, 50) do
        :timeout ->
          wait_for_quit(term, canvas, previous_frame, opts)

        {:signal, :winch} ->
          term = refresh_terminal_size(term, opts)
          {term, cols, rows} = terminal_grid(term, opts)
          frame = canvas_to_frame(canvas, cols, rows, nil, nil, opts)
          {term, previous_frame} = draw_frame(term, frame, previous_frame)
          wait_for_quit(term, canvas, previous_frame, opts)

        {:data, data} ->
          key_event = key_event_from_data(data)
          apply_static_key_handler(opts, key_event)

          if quit_key?(key_event) do
            :ok
          else
            wait_for_quit(term, canvas, previous_frame, opts)
          end

        _other ->
          wait_for_quit(term, canvas, previous_frame, opts)
      end
    end

    defp apply_static_key_handler(opts, key_event) do
      case Keyword.get(opts, :on_key_down) do
        handler when is_function(handler, 1) and not is_nil(key_event) ->
          handler.(key_event)

        _ ->
          :ok
      end
    end

    defp apply_animate_key_handler(opts, key_event, state) do
      case Keyword.get(opts, :on_key_down) do
        handler when is_function(handler, 2) and not is_nil(key_event) ->
          handler.(key_event, state)

        _ ->
          state
      end
    end

    defp draw_frame(term, frame), do: draw_frame(term, frame, nil)

    defp draw_frame(term, frame, nil) do
      term =
        term
        |> t_cursor_position(1, 1)
        |> t_write(frame)

      {term, frame_state(frame)}
    end

    defp draw_frame(term, frame, %{frame: frame} = previous_frame) do
      {term, previous_frame}
    end

    defp draw_frame(term, frame, previous_frame) do
      current_frame = frame_state(frame)

      term =
        if current_frame.line_count != previous_frame.line_count do
          term
          |> t_cursor_position(1, 1)
          |> t_write(frame)
        else
          Enum.reduce(0..(current_frame.line_count - 1), term, fn line_idx, term_acc ->
            current_line = elem(current_frame.lines, line_idx)
            previous_line = elem(previous_frame.lines, line_idx)

            if current_line == previous_line do
              term_acc
            else
              term_acc
              |> t_cursor_position(1, line_idx + 1)
              |> t_write(current_line)
            end
          end)
        end

      {term, current_frame}
    end

    defp frame_state(frame) do
      lines = :binary.split(frame, "\n", [:global])
      %{frame: frame, lines: List.to_tuple(lines), line_count: length(lines)}
    end

    defp terminal_grid(term, opts) do
      size = Map.get(term, :size) || %{}
      term_cols = Map.get(size, :width) || 80
      term_rows = Map.get(size, :height) || 24

      columns =
        opts
        |> Keyword.get(:columns, term_cols)
        |> normalize_positive_int(80)

      rows =
        opts
        |> Keyword.get(:rows, term_rows)
        |> normalize_positive_int(24)

      {term, columns, rows}
    end

    defp refresh_terminal_size(term, opts) do
      if Keyword.has_key?(opts, :columns) and Keyword.has_key?(opts, :rows) do
        term
      else
        t_resize(term)
      end
    end

    defp canvas_to_frame(canvas, columns, rows, fallback_width, fallback_height, opts) do
      {raster_w, raster_h} =
        raster_dimensions(canvas, columns, rows, fallback_width, fallback_height, opts)

      dpr = Keyword.get(opts, :dpr, 1.0)

      image = Easel.WX.rasterize(canvas, width: raster_w, height: raster_h, dpr: dpr)
      frame_from_rgb(image, columns, rows, opts)
    end

    defp raster_dimensions(canvas, columns, rows, fallback_width, fallback_height, opts) do
      cell_aspect = cell_aspect(opts)

      width =
        canvas.width || fallback_width || Keyword.get(opts, :canvas_width) || max(columns, 1)

      height =
        canvas.height || fallback_height || Keyword.get(opts, :canvas_height) ||
          max(round(rows * cell_aspect), 1)

      {normalize_positive_int(width, max(columns, 1)),
       normalize_positive_int(height, max(round(rows * cell_aspect), 1))}
    end

    defp with_terminal(opts, fun) do
      wx_env_created? = ensure_wx_raster_env()
      term = t_start()
      term = setup_terminal(term, opts)

      try do
        fun.(term)
      after
        if Keyword.get(opts, :restore_on_exit, true) do
          restore_terminal(opts)
        end

        stop_terminal(term)
        teardown_char_mask_cache()
        teardown_sample_map_cache()
        teardown_wx_raster_env(wx_env_created?)
      end
    end

    defp setup_terminal(term, opts) do
      term =
        case Keyword.get(opts, :title) do
          nil -> term
          title -> t_title(term, to_string(title))
        end

      term =
        if Keyword.get(opts, :alt_screen, true),
          do: t_alt_screen(term),
          else: term

      term =
        if Keyword.get(opts, :hide_cursor, true),
          do: t_hide_cursor(term),
          else: term

      if Keyword.get(opts, :clear, true),
        do: t_clear_screen(term),
        else: term
    end

    defp restore_terminal(opts) do
      screen_mod = Module.concat([Termite, Screen])

      if function_exported?(screen_mod, :emergency_restore, 0) do
        apply(screen_mod, :emergency_restore, [])
      else
        [
          IO.ANSI.reset(),
          if(Keyword.get(opts, :alt_screen, true), do: "\e[?1049l", else: ""),
          if(Keyword.get(opts, :hide_cursor, true), do: "\e[?25h", else: "")
        ]
        |> IO.iodata_to_binary()
        |> IO.write()
      end

      :ok
    rescue
      _ -> :ok
    end

    defp ensure_wx_raster_env do
      try do
        _ = :wx.get_env()
        false
      rescue
        _ ->
          :wx.new(silent_start: true)
          true
      end
    end

    defp teardown_wx_raster_env(true) do
      :wx.destroy()
    rescue
      _ -> :ok
    end

    defp teardown_wx_raster_env(false), do: :ok

    defp stop_terminal(%{adapter: {adapter_mod, adapter_state}}) do
      shell_mod = Module.concat([Termite, Terminal, Shell])

      if adapter_mod == shell_mod and is_map(adapter_state) do
        case Map.get(adapter_state, :pid) do
          pid when is_pid(pid) -> Process.exit(pid, :shutdown)
          _ -> :ok
        end
      else
        :ok
      end
    end

    defp stop_terminal(_), do: :ok

    defp animation_interval_ms(opts) do
      case Keyword.get(opts, :interval) do
        n when is_integer(n) and n > 0 -> n
        n when is_float(n) and n > 0 -> round(n)
        _ -> max(round(1000 / Keyword.get(opts, :fps, 30)), 1)
      end
    end

    defp now_ms, do: System.monotonic_time(:millisecond)

    defp key_event_from_data(data) when is_binary(data) do
      case data do
        "\e[A" ->
          %{key: "ArrowUp", raw: data, ctrl: false, alt: false, shift: false, meta: false}

        "\e[B" ->
          %{key: "ArrowDown", raw: data, ctrl: false, alt: false, shift: false, meta: false}

        "\e[C" ->
          %{key: "ArrowRight", raw: data, ctrl: false, alt: false, shift: false, meta: false}

        "\e[D" ->
          %{key: "ArrowLeft", raw: data, ctrl: false, alt: false, shift: false, meta: false}

        "\r" ->
          %{key: "Enter", raw: data, ctrl: false, alt: false, shift: false, meta: false}

        "\n" ->
          %{key: "Enter", raw: data, ctrl: false, alt: false, shift: false, meta: false}

        <<3>> ->
          %{key: "c", raw: data, ctrl: true, alt: false, shift: false, meta: false}

        <<code>> when code in 1..26 ->
          <<ch>> = <<code + 96>>
          %{key: ch, raw: data, ctrl: true, alt: false, shift: false, meta: false}

        _ ->
          key_from_utf8(data)
      end
    end

    defp key_event_from_data(_), do: nil

    defp key_from_utf8(data) do
      case String.next_grapheme(data) do
        {ch, ""} -> %{key: ch, raw: data, ctrl: false, alt: false, shift: false, meta: false}
        _ -> nil
      end
    end

    defp quit_key?(nil), do: false

    defp quit_key?(%{ctrl: true, key: "c"}), do: true

    defp quit_key?(%{key: key}) when is_binary(key) do
      String.downcase(key) == "q"
    end

    defp quit_key?(_), do: false

    defp t_start do
      apply(Module.concat([Termite, Terminal]), :start, [])
    rescue
      MatchError ->
        raise "Easel.Terminal requires an interactive TTY. Run it from a real terminal session."
    end

    defp t_resize(term), do: apply(Module.concat([Termite, Terminal]), :resize, [term])

    defp t_poll_event(term, timeout) do
      apply(Module.concat([Termite, Terminal]), :poll, [term, timeout])
      |> normalize_poll_message()
    end

    defp normalize_poll_message(message), do: message

    defp t_write(term, value), do: apply(Module.concat([Termite, Screen]), :write, [term, value])
    defp t_clear_screen(term), do: apply(Module.concat([Termite, Screen]), :clear_screen, [term])
    defp t_alt_screen(term), do: apply(Module.concat([Termite, Screen]), :alt_screen, [term])
    defp t_hide_cursor(term), do: apply(Module.concat([Termite, Screen]), :hide_cursor, [term])
    defp t_title(term, title), do: apply(Module.concat([Termite, Screen]), :title, [term, title])

    defp t_cursor_position(term, x, y),
      do: apply(Module.concat([Termite, Screen]), :cursor_position, [term, x, y])

    defp teardown_char_mask_cache do
      key = {__MODULE__, :char_mask_cache_table}

      case Process.get(key) do
        tid when is_reference(tid) ->
          :ets.delete(tid)
          Process.delete(key)

        _ ->
          :ok
      end
    rescue
      _ -> :ok
    end

    defp teardown_sample_map_cache do
      key = {__MODULE__, :sample_map_cache_table}

      case Process.get(key) do
        tid when is_reference(tid) ->
          :ets.delete(tid)
          Process.delete(key)

        _ ->
          :ok
      end
    rescue
      _ -> :ok
    end
  else
    @doc """
    Renders a canvas in the terminal.

    Requires `:termite` at runtime.
    """
    def render(%Easel{} = _canvas, _opts \\ []) do
      raise "Easel.Terminal requires the :termite dependency. Add {:termite, \"~> 0.4.0\"} and recompile."
    end

    @doc """
    Runs a terminal animation loop.

    Requires `:termite` at runtime.
    """
    def animate(_width, _height, _state, _fun, _opts \\ []) do
      raise "Easel.Terminal requires the :termite dependency. Add {:termite, \"~> 0.4.0\"} and recompile."
    end
  end

  defp tty_available? do
    match?({:ok, _}, :io.columns()) and match?({:ok, _}, :io.rows())
  end

  defp charset_tuple(opts) do
    opts
    |> Keyword.get(:charset, @default_charset)
    |> to_string()
    |> String.graphemes()
    |> case do
      [] -> String.graphemes(@default_charset)
      chars -> chars
    end
    |> List.to_tuple()
  end

  defp cell_aspect(opts) do
    opts
    |> Keyword.get(:cell_aspect, @default_cell_aspect)
    |> normalize_positive_float(@default_cell_aspect)
  end

  defp normalize_positive_int(value, fallback) do
    cond do
      is_integer(value) and value > 0 ->
        value

      is_float(value) and value > 0 ->
        round(value)

      is_binary(value) ->
        case Integer.parse(value) do
          {n, ""} when n > 0 -> n
          _ -> fallback
        end

      true ->
        fallback
    end
  end

  defp normalize_positive_float(value, fallback) do
    cond do
      is_float(value) and value > 0 ->
        value

      is_integer(value) and value > 0 ->
        value * 1.0

      is_binary(value) ->
        case Float.parse(value) do
          {n, ""} when n > 0 -> n
          _ -> fallback
        end

      true ->
        fallback
    end
  end

  defp render_mode(opts) do
    case Keyword.fetch(opts, :mode) do
      {:ok, mode} when mode in [:luma, :silhouette, :braille, :halfblock] ->
        mode

      {:ok, mode} ->
        raise ArgumentError,
              "invalid terminal render mode #{inspect(mode)}. Expected one of :luma, :silhouette, :braille, :halfblock"

      :error ->
        if Keyword.has_key?(opts, :charset) do
          :luma
        else
          :silhouette
        end
    end
  end

  defp frame_from_rgb_luma(%{width: width, height: height, rgb: rgb}, columns, rows, opts) do
    chars = charset_tuple(opts)
    fit = Keyword.get(opts, :fit, :contain)
    invert? = Keyword.get(opts, :invert, false)
    color_mode = Keyword.get(opts, :color, :none)
    cell_aspect = cell_aspect(opts)
    samples = normalize_positive_int(Keyword.get(opts, :samples, 2), 2)
    contrast_profile = contrast_profile(opts, color_mode)

    geometry = fit_geometry(width, height, columns, rows, cell_aspect, fit)

    sample_maps = luma_sample_maps(geometry, width, height, samples)

    render_opts = %{
      columns: columns,
      src_w: width,
      rgb: rgb,
      chars: chars,
      invert?: invert?,
      color_mode: color_mode,
      draw_cols: geometry.draw_cols,
      draw_rows: geometry.draw_rows,
      off_x: geometry.off_x,
      off_y: geometry.off_y,
      contrast_profile: contrast_profile,
      sample_maps: sample_maps
    }

    lines = for row <- 0..(rows - 1), do: render_line(row, render_opts)

    lines
    |> Enum.intersperse("\n")
    |> IO.iodata_to_binary()
  end

  defp frame_from_rgb_braille(%{width: width, height: height, rgb: rgb}, columns, rows, opts) do
    fit = Keyword.get(opts, :fit, :contain)
    color_mode = Keyword.get(opts, :color, :none)
    cell_aspect = cell_aspect(opts)

    bg_threshold =
      opts
      |> Keyword.get(:background_threshold, @default_bg_threshold)
      |> normalize_ratio(@default_bg_threshold)

    contrast_profile = contrast_profile(opts, color_mode)

    geometry = fit_geometry(width, height, columns, rows, cell_aspect, fit)

    sample_maps = braille_sample_maps(geometry, width, height)

    render_opts = %{
      columns: columns,
      src_w: width,
      rgb: rgb,
      color_mode: color_mode,
      draw_cols: geometry.draw_cols,
      draw_rows: geometry.draw_rows,
      off_x: geometry.off_x,
      off_y: geometry.off_y,
      bg_threshold: bg_threshold,
      contrast_profile: contrast_profile,
      sample_maps: sample_maps
    }

    lines = for row <- 0..(rows - 1), do: render_braille_line(row, render_opts)

    lines
    |> Enum.intersperse("\n")
    |> IO.iodata_to_binary()
  end

  defp frame_from_rgb_halfblock(%{width: width, height: height, rgb: rgb}, columns, rows, opts) do
    fit = Keyword.get(opts, :fit, :contain)
    color_mode = Keyword.get(opts, :color, :none)
    cell_aspect = cell_aspect(opts)

    bg_threshold =
      opts
      |> Keyword.get(:background_threshold, @default_bg_threshold)
      |> normalize_ratio(@default_bg_threshold)

    contrast_profile = contrast_profile(opts, color_mode)
    geometry = fit_geometry(width, height, columns, rows, cell_aspect, fit)
    sample_maps = halfblock_sample_maps(geometry, width, height)

    render_opts = %{
      columns: columns,
      src_w: width,
      rgb: rgb,
      color_mode: color_mode,
      draw_cols: geometry.draw_cols,
      draw_rows: geometry.draw_rows,
      off_x: geometry.off_x,
      off_y: geometry.off_y,
      bg_threshold: bg_threshold,
      contrast_profile: contrast_profile,
      sample_maps: sample_maps
    }

    lines = for row <- 0..(rows - 1), do: render_halfblock_line(row, render_opts)

    lines
    |> Enum.intersperse("\n")
    |> IO.iodata_to_binary()
  end

  defp frame_from_rgb_silhouette(%{width: width, height: height, rgb: rgb}, columns, rows, opts) do
    fit = Keyword.get(opts, :fit, :contain)
    color_mode = Keyword.get(opts, :color, :none)
    cell_aspect = cell_aspect(opts)

    bg_threshold =
      opts
      |> Keyword.get(:background_threshold, @default_bg_threshold)
      |> normalize_ratio(@default_bg_threshold)

    glyph_w = normalize_positive_int(Keyword.get(opts, :glyph_width, @default_glyph_width), 9)
    glyph_h = normalize_positive_int(Keyword.get(opts, :glyph_height, @default_glyph_height), 19)

    glyph_profile = glyph_profile(glyph_w, glyph_h, opts)
    mask_cache = silhouette_mask_cache(opts, glyph_profile)
    contrast_profile = contrast_profile(opts, color_mode)

    geometry = fit_geometry(width, height, columns, rows, cell_aspect, fit)

    sample_maps = silhouette_sample_maps(geometry, width, height, glyph_w, glyph_h)

    render_opts = %{
      columns: columns,
      src_w: width,
      rgb: rgb,
      color_mode: color_mode,
      draw_cols: geometry.draw_cols,
      draw_rows: geometry.draw_rows,
      off_x: geometry.off_x,
      off_y: geometry.off_y,
      glyph_w: glyph_w,
      glyph_h: glyph_h,
      bg_threshold: bg_threshold,
      glyph_profile: glyph_profile,
      mask_cache: mask_cache,
      contrast_profile: contrast_profile,
      sample_maps: sample_maps
    }

    lines = for row <- 0..(rows - 1), do: render_silhouette_line(row, render_opts)

    lines
    |> Enum.intersperse("\n")
    |> IO.iodata_to_binary()
  end

  defp silhouette_mask_cache(opts, glyph_profile) do
    if Keyword.get(opts, :char_cache, true) do
      limit = normalize_positive_int(Keyword.get(opts, :char_cache_size, 8192), 8192)
      %{table: ensure_char_mask_cache_table(), profile_key: glyph_profile.cache_key, limit: limit}
    else
      nil
    end
  end

  defp ensure_char_mask_cache_table do
    key = {__MODULE__, :char_mask_cache_table}

    case Process.get(key) do
      tid when is_reference(tid) ->
        tid

      _ ->
        tid = :ets.new(:easel_terminal_char_mask_cache, [:set, :private, read_concurrency: true])
        Process.put(key, tid)
        tid
    end
  end

  defp ensure_sample_map_cache_table do
    key = {__MODULE__, :sample_map_cache_table}

    case Process.get(key) do
      tid when is_reference(tid) ->
        tid

      _ ->
        tid = :ets.new(:easel_terminal_sample_map_cache, [:set, :private, read_concurrency: true])
        Process.put(key, tid)
        tid
    end
  end

  defp maybe_trim_sample_map_cache(table) do
    if :ets.info(table, :size) > @sample_map_cache_limit do
      prune_ets_table(table, trunc(@sample_map_cache_limit / 4))
    end

    :ok
  end

  defp luma_sample_maps(geometry, src_w, src_h, samples) do
    x_map = sample_axis_map(geometry.src_x0, geometry.src_x1, src_w, geometry.draw_cols, samples)
    y_map = sample_axis_map(geometry.src_y0, geometry.src_y1, src_h, geometry.draw_rows, samples)
    %{x: x_map, y: y_map}
  end

  defp braille_sample_maps(geometry, src_w, src_h) do
    %{
      x: sample_axis_map(geometry.src_x0, geometry.src_x1, src_w, geometry.draw_cols, 2),
      y: sample_axis_map(geometry.src_y0, geometry.src_y1, src_h, geometry.draw_rows, 4)
    }
  end

  defp halfblock_sample_maps(geometry, src_w, src_h) do
    %{
      x: sample_axis_map(geometry.src_x0, geometry.src_x1, src_w, geometry.draw_cols, 1),
      y: sample_axis_map(geometry.src_y0, geometry.src_y1, src_h, geometry.draw_rows, 2)
    }
  end

  defp silhouette_sample_maps(geometry, src_w, src_h, glyph_w, glyph_h) do
    key =
      {geometry.src_x0, geometry.src_x1, geometry.src_y0, geometry.src_y1, geometry.draw_cols,
       geometry.draw_rows, glyph_w, glyph_h}

    table = ensure_sample_map_cache_table()

    case :ets.lookup(table, key) do
      [{^key, sample_maps}] ->
        sample_maps

      [] ->
        sample_maps = %{
          x:
            sample_axis_map(geometry.src_x0, geometry.src_x1, src_w, geometry.draw_cols, glyph_w),
          y: sample_axis_map(geometry.src_y0, geometry.src_y1, src_h, geometry.draw_rows, glyph_h)
        }

        true = :ets.insert(table, {key, sample_maps})
        maybe_trim_sample_map_cache(table)
        sample_maps
    end
  end

  defp sample_axis_map(src_start, src_end, src_limit, draw_size, sample_count) do
    for idx <- 0..(draw_size - 1) do
      start_pos = src_start + idx / draw_size * (src_end - src_start)
      end_pos = src_start + (idx + 1) / draw_size * (src_end - src_start)

      for sample_idx <- 0..(sample_count - 1) do
        pos = start_pos + (sample_idx + 0.5) / sample_count * (end_pos - start_pos)
        pos |> trunc() |> max(0) |> min(src_limit - 1)
      end
      |> List.to_tuple()
    end
    |> List.to_tuple()
  end

  defp fit_geometry(src_w, src_h, cols, rows, cell_aspect, :fill) do
    src_aspect = src_w / src_h
    out_aspect = cols / max(rows * cell_aspect, 0.0001)

    if src_aspect >= out_aspect do
      crop_w = src_h * out_aspect
      src_x0 = (src_w - crop_w) / 2

      %{
        draw_cols: cols,
        draw_rows: rows,
        off_x: 0,
        off_y: 0,
        src_x0: src_x0,
        src_x1: src_x0 + crop_w,
        src_y0: 0.0,
        src_y1: src_h * 1.0
      }
    else
      crop_h = src_w / out_aspect
      src_y0 = (src_h - crop_h) / 2

      %{
        draw_cols: cols,
        draw_rows: rows,
        off_x: 0,
        off_y: 0,
        src_x0: 0.0,
        src_x1: src_w * 1.0,
        src_y0: src_y0,
        src_y1: src_y0 + crop_h
      }
    end
  end

  defp fit_geometry(src_w, src_h, cols, rows, cell_aspect, _fit) do
    src_aspect = src_w / src_h
    out_aspect = cols / max(rows * cell_aspect, 0.0001)

    {draw_cols, draw_rows} =
      if src_aspect >= out_aspect do
        draw_cols = cols
        draw_rows = max(round(cols / (src_aspect * cell_aspect)), 1)
        {draw_cols, min(draw_rows, rows)}
      else
        draw_rows = rows
        draw_cols = max(round(rows * cell_aspect * src_aspect), 1)
        {min(draw_cols, cols), draw_rows}
      end

    %{
      draw_cols: draw_cols,
      draw_rows: draw_rows,
      off_x: div(cols - draw_cols, 2),
      off_y: div(rows - draw_rows, 2),
      src_x0: 0.0,
      src_x1: src_w * 1.0,
      src_y0: 0.0,
      src_y1: src_h * 1.0
    }
  end

  defp render_line(row, opts) do
    %{
      columns: columns,
      src_w: src_w,
      rgb: rgb,
      chars: chars,
      invert?: invert?,
      color_mode: color_mode,
      draw_cols: draw_cols,
      draw_rows: draw_rows,
      off_x: off_x,
      off_y: off_y,
      contrast_profile: contrast_profile,
      sample_maps: sample_maps
    } = opts

    char_count = tuple_size(chars)

    {line, current_color} =
      Enum.map_reduce(0..(columns - 1), nil, fn col, current_color ->
        inside? =
          col >= off_x and col < off_x + draw_cols and
            row >= off_y and row < off_y + draw_rows

        if inside? do
          rel_col = col - off_x
          rel_row = row - off_y

          x_samples = elem(sample_maps.x, rel_col)
          y_samples = elem(sample_maps.y, rel_row)

          {r, g, b} =
            sample_rgb(rgb, src_w, x_samples, y_samples)
            |> adjust_rgb_for_theme(contrast_profile)

          luma = luma(r, g, b)
          idx = luma_to_index(luma, char_count, invert?)
          ch = elem(chars, idx)

          render_cell(ch, r, g, b, color_mode, current_color)
        else
          render_cell_with_ansi(" ", nil, current_color, color_mode)
        end
      end)

    case {color_mode, current_color} do
      {:ansi256, code} when is_integer(code) ->
        [line, "\e[0m"]

      _ ->
        line
    end
  end

  defp render_halfblock_line(row, opts) do
    %{
      columns: columns,
      src_w: src_w,
      rgb: rgb,
      color_mode: color_mode,
      draw_cols: draw_cols,
      draw_rows: draw_rows,
      off_x: off_x,
      off_y: off_y,
      bg_threshold: bg_threshold,
      contrast_profile: contrast_profile,
      sample_maps: sample_maps
    } = opts

    {line, current_colors} =
      Enum.map_reduce(0..(columns - 1), nil, fn col, current_colors ->
        inside? =
          col >= off_x and col < off_x + draw_cols and
            row >= off_y and row < off_y + draw_rows

        if inside? do
          rel_col = col - off_x
          rel_row = row - off_y

          x_samples = elem(sample_maps.x, rel_col)
          y_samples = elem(sample_maps.y, rel_row)

          {ch, fg_code, bg_code} =
            halfblock_cell(
              rgb,
              src_w,
              x_samples,
              y_samples,
              bg_threshold,
              color_mode,
              contrast_profile
            )

          render_dual_color_cell(ch, fg_code, bg_code, current_colors, color_mode)
        else
          render_dual_color_cell(" ", nil, nil, current_colors, color_mode)
        end
      end)

    case {color_mode, current_colors} do
      {:ansi256, {_fg, _bg}} ->
        [line, "\e[0m"]

      _ ->
        line
    end
  end

  defp render_braille_line(row, opts) do
    %{
      columns: columns,
      src_w: src_w,
      rgb: rgb,
      color_mode: color_mode,
      draw_cols: draw_cols,
      draw_rows: draw_rows,
      off_x: off_x,
      off_y: off_y,
      bg_threshold: bg_threshold,
      contrast_profile: contrast_profile,
      sample_maps: sample_maps
    } = opts

    {line, current_color} =
      Enum.map_reduce(0..(columns - 1), nil, fn col, current_color ->
        inside? =
          col >= off_x and col < off_x + draw_cols and
            row >= off_y and row < off_y + draw_rows

        if inside? do
          rel_col = col - off_x
          rel_row = row - off_y

          x_samples = elem(sample_maps.x, rel_col)
          y_samples = elem(sample_maps.y, rel_row)

          {ch, color_value} =
            braille_cell(
              rgb,
              src_w,
              x_samples,
              y_samples,
              bg_threshold,
              color_mode,
              contrast_profile
            )

          render_cell_with_ansi(ch, color_value, current_color, color_mode)
        else
          render_cell_with_ansi(" ", nil, current_color, color_mode)
        end
      end)

    case {color_mode, current_color} do
      {:ansi256, code} when is_integer(code) ->
        [line, "\e[0m"]

      _ ->
        line
    end
  end

  defp render_silhouette_line(row, opts) do
    %{
      columns: columns,
      src_w: src_w,
      rgb: rgb,
      color_mode: color_mode,
      draw_cols: draw_cols,
      draw_rows: draw_rows,
      off_x: off_x,
      off_y: off_y,
      glyph_w: glyph_w,
      glyph_h: glyph_h,
      bg_threshold: bg_threshold,
      glyph_profile: glyph_profile,
      mask_cache: mask_cache,
      contrast_profile: contrast_profile,
      sample_maps: sample_maps
    } = opts

    {line, current_color} =
      Enum.map_reduce(0..(columns - 1), nil, fn col, current_color ->
        inside? =
          col >= off_x and col < off_x + draw_cols and
            row >= off_y and row < off_y + draw_rows

        if inside? do
          rel_col = col - off_x
          rel_row = row - off_y

          x_samples = elem(sample_maps.x, rel_col)
          y_samples = elem(sample_maps.y, rel_row)

          plane_masks =
            cell_plane_masks(
              rgb,
              src_w,
              x_samples,
              y_samples,
              glyph_w,
              glyph_h,
              bg_threshold,
              color_mode,
              contrast_profile
            )

          {ch, plane_key} = select_best_plane_char(plane_masks, glyph_profile, mask_cache)
          color_value = if color_mode == :ansi256, do: plane_key, else: nil
          render_cell_with_ansi(ch, color_value, current_color, color_mode)
        else
          render_cell_with_ansi(" ", nil, current_color, color_mode)
        end
      end)

    case {color_mode, current_color} do
      {:ansi256, code} when is_integer(code) ->
        [line, "\e[0m"]

      _ ->
        line
    end
  end

  defp halfblock_cell(
         rgb,
         src_w,
         x_samples,
         y_samples,
         bg_threshold,
         color_mode,
         contrast_profile
       ) do
    top =
      halfblock_region_color(
        rgb,
        src_w,
        x_samples,
        elem(y_samples, 0),
        bg_threshold,
        contrast_profile
      )

    bottom =
      halfblock_region_color(
        rgb,
        src_w,
        x_samples,
        elem(y_samples, 1),
        bg_threshold,
        contrast_profile
      )

    case {top, bottom, color_mode} do
      {nil, nil, _} ->
        {" ", nil, nil}

      {{r, g, b}, nil, :ansi256} ->
        {"▀", rgb_to_ansi256(r, g, b), nil}

      {nil, {r, g, b}, :ansi256} ->
        {"▄", rgb_to_ansi256(r, g, b), nil}

      {{rt, gt, bt}, {rb, gb, bb}, :ansi256} ->
        {"▀", rgb_to_ansi256(rt, gt, bt), rgb_to_ansi256(rb, gb, bb)}

      {_top, nil, _} ->
        {"▀", nil, nil}

      {nil, _bottom, _} ->
        {"▄", nil, nil}

      {_top, _bottom, _} ->
        {"█", nil, nil}
    end
  end

  defp halfblock_region_color(rgb, src_w, x_samples, py, bg_threshold, contrast_profile) do
    {r_sum, g_sum, b_sum, count} =
      Enum.reduce(0..(tuple_size(x_samples) - 1), {0, 0, 0, 0}, fn x_idx,
                                                                   {r_acc, g_acc, b_acc, n_acc} ->
        px = elem(x_samples, x_idx)

        {r, g, b} =
          pixel_rgb(rgb, src_w, px, py)
          |> adjust_rgb_for_theme(contrast_profile)

        if luma(r, g, b) / 255 <= bg_threshold do
          {r_acc, g_acc, b_acc, n_acc}
        else
          {r_acc + r, g_acc + g, b_acc + b, n_acc + 1}
        end
      end)

    if count == 0 do
      nil
    else
      {round(r_sum / count), round(g_sum / count), round(b_sum / count)}
    end
  end

  defp braille_cell(rgb, src_w, x_samples, y_samples, bg_threshold, color_mode, contrast_profile) do
    {mask, r_sum, g_sum, b_sum, count} =
      Enum.reduce(0..3, {0, 0, 0, 0, 0}, fn y_idx, {mask_acc, r_acc, g_acc, b_acc, n_acc} ->
        py = elem(y_samples, y_idx)

        Enum.reduce(0..1, {mask_acc, r_acc, g_acc, b_acc, n_acc}, fn x_idx,
                                                                     {mask_acc2, r_acc2, g_acc2,
                                                                      b_acc2, n_acc2} ->
          px = elem(x_samples, x_idx)

          {r, g, b} =
            pixel_rgb(rgb, src_w, px, py)
            |> adjust_rgb_for_theme(contrast_profile)

          if luma(r, g, b) / 255 <= bg_threshold do
            {mask_acc2, r_acc2, g_acc2, b_acc2, n_acc2}
          else
            {
              mask_acc2 ||| braille_dot_bit(x_idx, y_idx),
              r_acc2 + r,
              g_acc2 + g,
              b_acc2 + b,
              n_acc2 + 1
            }
          end
        end)
      end)

    if mask == 0 do
      {" ", nil}
    else
      ch = <<0x2800 + mask::utf8>>

      color_value =
        if color_mode == :ansi256 do
          rgb_to_ansi256(round(r_sum / count), round(g_sum / count), round(b_sum / count))
        else
          nil
        end

      {ch, color_value}
    end
  end

  defp braille_dot_bit(0, 0), do: 0x01
  defp braille_dot_bit(0, 1), do: 0x02
  defp braille_dot_bit(0, 2), do: 0x04
  defp braille_dot_bit(1, 0), do: 0x08
  defp braille_dot_bit(1, 1), do: 0x10
  defp braille_dot_bit(1, 2), do: 0x20
  defp braille_dot_bit(0, 3), do: 0x40
  defp braille_dot_bit(1, 3), do: 0x80

  defp cell_plane_masks(
         rgb,
         src_w,
         x_samples,
         y_samples,
         glyph_w,
         glyph_h,
         bg_threshold,
         color_mode,
         contrast_profile
       ) do
    Enum.reduce(0..(glyph_h - 1), [], fn gy, acc ->
      py = elem(y_samples, gy)

      Enum.reduce(0..(glyph_w - 1), acc, fn gx, acc2 ->
        px = elem(x_samples, gx)

        {r, g, b} =
          pixel_rgb(rgb, src_w, px, py)
          |> adjust_rgb_for_theme(contrast_profile)

        if luma(r, g, b) / 255 <= bg_threshold do
          acc2
        else
          bit_index = gy * glyph_w + gx
          plane_key = if color_mode == :ansi256, do: rgb_to_ansi256(r, g, b), else: :mono
          upsert_plane_mask(acc2, plane_key, 1 <<< bit_index)
        end
      end)
    end)
  end

  defp upsert_plane_mask(plane_masks, plane_key, bit) do
    case List.keytake(plane_masks, plane_key, 0) do
      {{^plane_key, mask}, rest} -> [{plane_key, mask ||| bit} | rest]
      nil -> [{plane_key, bit} | plane_masks]
    end
  end

  defp select_best_plane_char(plane_masks, glyph_profile, mask_cache) do
    Enum.reduce(plane_masks, {" ", nil, -1}, fn {plane_key, mask},
                                                {best_char, best_plane, best_score} ->
      {char, score} = best_char_for_mask(mask, glyph_profile, mask_cache)

      if score > best_score do
        {char, plane_key, score}
      else
        {best_char, best_plane, best_score}
      end
    end)
    |> then(fn {char, plane_key, _score} -> {char, plane_key} end)
  end

  defp best_char_for_mask(mask, _glyph_profile, _mask_cache) when mask == 0, do: {" ", 0}

  defp best_char_for_mask(mask, glyph_profile, nil) do
    compute_best_char_for_mask(mask, glyph_profile)
  end

  defp best_char_for_mask(mask, glyph_profile, %{
         table: table,
         profile_key: profile_key,
         limit: limit
       }) do
    key = {profile_key, mask}

    case :ets.lookup(table, key) do
      [{^key, value}] ->
        value

      [] ->
        value = compute_best_char_for_mask(mask, glyph_profile)
        true = :ets.insert(table, {key, value})

        if :ets.info(table, :size) > limit do
          prune_ets_table(table, max(div(limit, 4), 1))
          true = :ets.insert(table, {key, value})
        end

        value
    end
  end

  defp compute_best_char_for_mask(mask, glyph_profile) do
    region_black_mask = bxor(glyph_profile.full_cell_mask, mask)

    accumulator =
      reduce_set_bits(region_black_mask, glyph_profile.all_chars_mask, fn bit_index, acc ->
        acc &&& elem(glyph_profile.pixel_black_masks, bit_index)
      end)

    case highest_set_bit(accumulator) do
      nil ->
        {" ", 0}

      idx ->
        {elem(glyph_profile.chars, idx), elem(glyph_profile.white_counts, idx)}
    end
  end

  defp render_dual_color_cell(ch, fg_code, bg_code, current_colors, :ansi256) do
    new_colors = {fg_code, bg_code}

    cond do
      current_colors == new_colors ->
        {ch, current_colors}

      fg_code == nil and bg_code == nil ->
        {["\e[0m", ch], nil}

      true ->
        fg_ansi =
          if is_integer(fg_code), do: ["\e[38;5;", Integer.to_string(fg_code), "m"], else: []

        bg_ansi =
          if is_integer(bg_code), do: ["\e[48;5;", Integer.to_string(bg_code), "m"], else: []

        {["\e[0m", fg_ansi, bg_ansi, ch], new_colors}
    end
  end

  defp render_dual_color_cell(ch, _fg_code, _bg_code, current_colors, _color_mode) do
    {ch, current_colors}
  end

  defp render_cell_with_ansi(ch, code, current_color, :ansi256) do
    case {code, current_color} do
      {nil, nil} ->
        {ch, nil}

      {nil, _} ->
        {["\e[0m", ch], nil}

      {same, same} ->
        {ch, current_color}

      {new_code, _} when is_integer(new_code) ->
        {["\e[38;5;", Integer.to_string(new_code), "m", ch], new_code}
    end
  end

  defp render_cell_with_ansi(ch, _code, current_color, _color_mode) do
    {ch, current_color}
  end

  defp render_cell(ch, r, g, b, :ansi256, current_color) do
    code = rgb_to_ansi256(r, g, b)

    if code == current_color do
      {ch, current_color}
    else
      {["\e[38;5;", Integer.to_string(code), "m", ch], code}
    end
  end

  defp render_cell(ch, _r, _g, _b, _color_mode, current_color) do
    {ch, current_color}
  end

  defp sample_rgb(rgb, src_w, x_samples, y_samples) do
    {r_sum, g_sum, b_sum, count} =
      Enum.reduce(0..(tuple_size(y_samples) - 1), {0, 0, 0, 0}, fn y_idx,
                                                                   {r_acc, g_acc, b_acc, n_acc} ->
        py = elem(y_samples, y_idx)

        Enum.reduce(0..(tuple_size(x_samples) - 1), {r_acc, g_acc, b_acc, n_acc}, fn x_idx,
                                                                                     {r_acc2,
                                                                                      g_acc2,
                                                                                      b_acc2,
                                                                                      n_acc2} ->
          px = elem(x_samples, x_idx)
          {r, g, b} = pixel_rgb(rgb, src_w, px, py)
          {r_acc2 + r, g_acc2 + g, b_acc2 + b, n_acc2 + 1}
        end)
      end)

    {round(r_sum / count), round(g_sum / count), round(b_sum / count)}
  end

  defp pixel_rgb(rgb, width, x, y) do
    offset = (y * width + x) * 3
    {:binary.at(rgb, offset), :binary.at(rgb, offset + 1), :binary.at(rgb, offset + 2)}
  end

  defp luma(r, g, b) do
    round(0.2126 * r + 0.7152 * g + 0.0722 * b)
  end

  defp luma_to_index(luma, char_count, invert?) do
    idx = round(luma / 255 * (char_count - 1))

    if invert? do
      char_count - 1 - idx
    else
      idx
    end
  end

  defp rgb_to_ansi256(r, g, b) do
    if abs(r - g) <= 3 and abs(g - b) <= 3 and abs(r - b) <= 3 do
      if r < 8 do
        16
      else
        232 + round((r - 8) / 247 * 23)
      end
    else
      r6 = round(r / 255 * 5)
      g6 = round(g / 255 * 5)
      b6 = round(b / 255 * 5)
      16 + 36 * r6 + 6 * g6 + b6
    end
  end

  defp normalize_ratio(value, fallback) do
    cond do
      value == 0 or value == 0.0 ->
        0.0

      true ->
        value = normalize_positive_float(value, fallback)

        cond do
          value < 0 -> 0.0
          value > 1 -> 1.0
          true -> value
        end
    end
  end

  defp contrast_profile(_opts, :none), do: nil

  defp contrast_profile(opts, _color_mode) do
    if Keyword.get(opts, :auto_contrast, false) do
      dark_min_luma =
        opts
        |> Keyword.get(:dark_min_luma, @default_dark_min_luma)
        |> normalize_ratio(@default_dark_min_luma)

      light_max_luma =
        opts
        |> Keyword.get(:light_max_luma, @default_light_max_luma)
        |> normalize_ratio(@default_light_max_luma)

      %{theme: terminal_theme(opts), dark_min_luma: dark_min_luma, light_max_luma: light_max_luma}
    else
      nil
    end
  end

  defp terminal_theme(opts) do
    case Keyword.get(opts, :theme, :auto) do
      :dark -> :dark
      :light -> :light
      _ -> detect_terminal_theme()
    end
  end

  defp detect_terminal_theme do
    case System.get_env("COLORFGBG") do
      nil ->
        :dark

      value ->
        value
        |> String.split(";")
        |> List.last()
        |> case do
          nil ->
            :dark

          bg ->
            case Integer.parse(bg) do
              {idx, _rest} when idx in 7..15 -> :light
              {idx, _rest} when idx in 0..6 -> :dark
              {idx, _rest} when idx > 15 -> :light
              _ -> :dark
            end
        end
    end
  end

  defp adjust_rgb_for_theme({r, g, b}, nil), do: {r, g, b}

  defp adjust_rgb_for_theme({r, g, b}, %{theme: :dark, dark_min_luma: min_luma}) do
    lift_rgb_luma(r, g, b, min_luma)
  end

  defp adjust_rgb_for_theme({r, g, b}, %{theme: :light, light_max_luma: max_luma}) do
    lower_rgb_luma(r, g, b, max_luma)
  end

  defp adjust_rgb_for_theme({r, g, b}, _), do: {r, g, b}

  defp lift_rgb_luma(r, g, b, min_luma) do
    l = luma(r, g, b) / 255

    cond do
      l >= min_luma ->
        {r, g, b}

      l <= 0.0001 ->
        v = clamp_byte(round(min_luma * 255))
        {v, v, v}

      true ->
        scale = min_luma / l
        {clamp_byte(round(r * scale)), clamp_byte(round(g * scale)), clamp_byte(round(b * scale))}
    end
  end

  defp lower_rgb_luma(r, g, b, max_luma) do
    l = luma(r, g, b) / 255

    if l <= max_luma do
      {r, g, b}
    else
      scale = max_luma / l
      {clamp_byte(round(r * scale)), clamp_byte(round(g * scale)), clamp_byte(round(b * scale))}
    end
  end

  defp clamp_byte(v) when v < 0, do: 0
  defp clamp_byte(v) when v > 255, do: 255
  defp clamp_byte(v), do: v

  defp glyph_profile(glyph_w, glyph_h, opts) do
    glyph_threshold =
      opts
      |> Keyword.get(:glyph_threshold, @default_glyph_threshold)
      |> normalize_ratio(@default_glyph_threshold)

    font_size_default = max(round(glyph_h * 0.9), 1)

    font_size =
      normalize_positive_int(
        Keyword.get(opts, :glyph_font_size, font_size_default),
        font_size_default
      )

    key = {glyph_w, glyph_h, glyph_threshold, font_size}
    table = ensure_glyph_profile_cache_table()

    case :ets.lookup(table, key) do
      [{^key, profile}] ->
        profile

      [] ->
        profile =
          with_local_wx_env(fn ->
            build_glyph_profile(glyph_w, glyph_h, glyph_threshold, font_size)
          end)

        # Avoid duplicate writes under contention.
        _ = :ets.insert_new(table, {key, profile})
        maybe_trim_glyph_profile_cache(table, key, profile)

        case :ets.lookup(table, key) do
          [{^key, cached}] -> cached
          [] -> profile
        end
    end
  end

  defp ensure_glyph_profile_cache_table do
    case :ets.whereis(@glyph_profile_cache_table) do
      :undefined ->
        try do
          :ets.new(@glyph_profile_cache_table, [
            :named_table,
            :set,
            :public,
            read_concurrency: true,
            write_concurrency: true
          ])
        rescue
          ArgumentError -> @glyph_profile_cache_table
        end

      tid ->
        tid
    end
  end

  defp maybe_trim_glyph_profile_cache(table, key, profile) do
    if :ets.info(table, :size) > @glyph_profile_cache_limit do
      prune_ets_table(table, max(div(@glyph_profile_cache_limit, 4), 1))
      true = :ets.insert(table, {key, profile})
    end

    :ok
  end

  defp with_local_wx_env(fun) do
    created_wx_env? =
      try do
        _ = :wx.get_env()
        false
      rescue
        _ ->
          :wx.new(silent_start: true)
          true
      end

    try do
      fun.()
    after
      if created_wx_env?, do: :wx.destroy()
    end
  end

  defp build_glyph_profile(glyph_w, glyph_h, glyph_threshold, font_size) do
    chars = for cp <- 32..126, do: <<cp::utf8>>
    pixel_count = glyph_w * glyph_h
    full_cell_mask = (1 <<< pixel_count) - 1

    sorted_chars =
      chars
      |> Enum.map(fn ch ->
        white_mask = rasterize_glyph_mask(ch, glyph_w, glyph_h, glyph_threshold, font_size)
        %{char: ch, white_mask: white_mask, white_count: popcount(white_mask)}
      end)
      |> Enum.sort_by(fn %{char: ch, white_count: count} -> {count, ch} end)

    chars_tuple = sorted_chars |> Enum.map(& &1.char) |> List.to_tuple()
    white_counts_tuple = sorted_chars |> Enum.map(& &1.white_count) |> List.to_tuple()
    char_count = tuple_size(chars_tuple)
    all_chars_mask = (1 <<< char_count) - 1

    pixel_black_masks =
      sorted_chars
      |> Enum.with_index()
      |> Enum.reduce(:array.new(pixel_count, default: 0), fn {%{white_mask: white_mask}, idx},
                                                             arr ->
        bit = 1 <<< idx
        black_mask = bxor(full_cell_mask, white_mask)

        reduce_set_bits(black_mask, arr, fn pixel_index, acc ->
          current = :array.get(pixel_index, acc)
          :array.set(pixel_index, current ||| bit, acc)
        end)
      end)
      |> :array.to_list()
      |> List.to_tuple()

    %{
      cache_key: {glyph_w, glyph_h, glyph_threshold, font_size},
      chars: chars_tuple,
      white_counts: white_counts_tuple,
      pixel_black_masks: pixel_black_masks,
      full_cell_mask: full_cell_mask,
      all_chars_mask: all_chars_mask
    }
  end

  defp rasterize_glyph_mask(ch, glyph_w, glyph_h, glyph_threshold, font_size) do
    bitmap = :wxBitmap.new(glyph_w, glyph_h)
    dc = :wxMemoryDC.new(bitmap)
    brush = :wxBrush.new({0, 0, 0, 255})

    try do
      :wxMemoryDC.setBackground(dc, brush)
      :wxMemoryDC.clear(dc)
      glyph_mask_from_dc(dc, bitmap, ch, glyph_w, glyph_h, glyph_threshold, font_size)
    after
      :wxBrush.destroy(brush)
      :wxMemoryDC.destroy(dc)
      :wxBitmap.destroy(bitmap)
    end
  end

  defp glyph_mask_from_dc(dc, bitmap, ch, glyph_w, glyph_h, glyph_threshold, font_size) do
    font =
      :wxFont.new(
        font_size,
        wx_const(:wxFONTFAMILY_TELETYPE),
        wx_const(:wxFONTSTYLE_NORMAL),
        wx_const(:wxFONTWEIGHT_NORMAL)
      )

    try do
      :wxMemoryDC.setFont(dc, font)
      :wxMemoryDC.setTextForeground(dc, {255, 255, 255})

      charlist = String.to_charlist(ch)
      {tw, th} = :wxMemoryDC.getTextExtent(dc, charlist)

      x = max(div(glyph_w - tw, 2), 0)
      y = max(div(glyph_h - th, 2), 0)

      :wxMemoryDC.drawText(dc, charlist, {x, y})
      extract_glyph_mask(bitmap, glyph_w, glyph_h, glyph_threshold)
    after
      :wxFont.destroy(font)
    end
  end

  defp extract_glyph_mask(bitmap, glyph_w, glyph_h, glyph_threshold) do
    image = :wxBitmap.convertToImage(bitmap)

    try do
      data = :wxImage.getData(image)
      glyph_threshold_byte = round(glyph_threshold * 255)

      Enum.reduce(0..(glyph_w * glyph_h - 1), 0, fn idx, acc ->
        offset = idx * 3
        <<r, g, b>> = :binary.part(data, offset, 3)

        if luma(r, g, b) >= glyph_threshold_byte do
          acc ||| 1 <<< idx
        else
          acc
        end
      end)
    after
      :wxImage.destroy(image)
    end
  end

  defp wx_const(atom), do: :wxe_util.get_const(atom)

  defp prune_ets_table(_table, count) when count <= 0, do: :ok

  defp prune_ets_table(table, count) do
    prune_ets_table(table, :ets.first(table), count)
  end

  defp prune_ets_table(_table, :"$end_of_table", _count), do: :ok
  defp prune_ets_table(_table, _key, count) when count <= 0, do: :ok

  defp prune_ets_table(table, key, count) do
    next_key = :ets.next(table, key)
    true = :ets.delete(table, key)
    prune_ets_table(table, next_key, count - 1)
  end

  defp reduce_set_bits(mask, acc, fun), do: reduce_set_bits(mask, 0, acc, fun)

  defp reduce_set_bits(0, _idx, acc, _fun), do: acc

  defp reduce_set_bits(mask, idx, acc, fun) do
    acc = if (mask &&& 1) == 1, do: fun.(idx, acc), else: acc
    reduce_set_bits(mask >>> 1, idx + 1, acc, fun)
  end

  defp highest_set_bit(0), do: nil
  defp highest_set_bit(mask), do: highest_set_bit(mask, 0, nil)

  defp highest_set_bit(0, _idx, best), do: best

  defp highest_set_bit(mask, idx, best) do
    best = if (mask &&& 1) == 1, do: idx, else: best
    highest_set_bit(mask >>> 1, idx + 1, best)
  end

  defp popcount(mask), do: popcount(mask, 0)
  defp popcount(0, acc), do: acc
  defp popcount(mask, acc), do: popcount(band(mask, mask - 1), acc + 1)
end
