defmodule Easel.TermShowreel do
  @moduledoc false

  @default_bpm 100

  def main(argv) do
    argv = normalize_argv(argv)

    {opts, _argv, invalid} =
      OptionParser.parse(argv,
        strict: [
          list: :boolean,
          bpm: :integer,
          no_ready: :boolean,
          audio_test: :boolean,
          mp3: :string,
          music: :string
        ]
      )

    if invalid != [] do
      raise ArgumentError, "invalid options: #{inspect(invalid)}"
    end

    bpm = max(opts[:bpm] || @default_bpm, 1)
    schedule = schedule()

    cond do
      opts[:list] ->
        print_schedule(schedule, bpm)

      opts[:audio_test] ->
        audio_test(opts)

      true ->
        run(schedule, bpm, opts)
    end
  end

  defp run(schedule, bpm, opts) do
    ensure_available!()
    {cols, rows} = terminal_size!()

    if rows < 8 do
      raise "terminal is too short for the showreel; need at least 8 rows"
    end

    wx_created? = ensure_wx_env()

    try do
      stage = %{
        cols: cols,
        rows: rows,
        demo_rows: rows - 2,
        canvas_w: min(max(cols * 6, 560), 800),
        canvas_h: min(max((rows - 2) * 12, 320), 520)
      }

      total_beats = total_beats(schedule)
      total_ms = total_duration_ms(schedule, bpm)
      audio = prepare_audio(opts)

      setup_terminal()
      keyboard = setup_quit_listener()

      try do
        draw_status_card(
          stage,
          "Loading showreel…",
          "Pre-rendering demos so playback stays on-beat"
        )

        {_states, playback} = preload_playback(schedule, stage, bpm)

        unless opts[:no_ready] do
          wait_for_start(stage, bpm, total_ms, audio)
        end

        maybe_quit!()
        audio_handle = start_audio(audio)

        try do
          show_start = now_ms()

          Enum.reduce_while(
            Enum.with_index(schedule, 1),
            %{beats_done: 0, elapsed_ms: 0},
            fn {segment, idx}, acc ->
              segment_ms = segment_duration_ms(segment, bpm)
              segment_start = show_start + acc.elapsed_ms
              segment_end = segment_start + segment_ms

              wait_until(segment_start)

              run_segment(
                segment,
                idx,
                length(schedule),
                playback,
                stage,
                segment_start,
                segment_end,
                acc.beats_done,
                total_beats,
                show_start,
                total_ms,
                bpm
              )

              {:cont,
               %{
                 acc
                 | beats_done: acc.beats_done + segment.beats,
                   elapsed_ms: acc.elapsed_ms + segment_ms
               }}
            end
          )

          unless quit_requested?() do
            draw_title_card(stage, "Showreel complete", "Recorded at #{bpm} BPM", 900)
          end
        catch
          :showreel_quit -> :ok
        after
          stop_audio(audio_handle)
        end
      after
        teardown_quit_listener(keyboard)
        restore_terminal()
      end
    after
      teardown_wx_env(wx_created?)
    end
  end

  defp normalize_argv(["--" | rest]), do: rest
  defp normalize_argv(argv), do: argv

  defp schedule do
    [
      static_segment(:mondrian_canvas, "Mondrian", :halfblock, 8, &__MODULE__.Demos.mondrian/1,
        color: :ansi256,
        fit: :contain,
        background_threshold: 0.05,
        halfblock_samples: 3,
        halfblock_color_merge_distance: 42
      )
      |> Map.put(:duration_ms, 2_800),
      static_segment(:mondrian_canvas, "Mondrian", :braille, 8, &__MODULE__.Demos.mondrian/1,
        color: :ansi256,
        fit: :contain,
        background_threshold: 0.03
      )
      |> Map.put(:duration_ms, 1_700),
      static_segment(:smiley_canvas, "Smiley", :silhouette, 8, &__MODULE__.Demos.smiley/1,
        color: :ansi256,
        fit: :contain,
        background_threshold: 0.08,
        glyph_width: 7,
        glyph_height: 15
      )
      |> Map.put(:duration_ms, 1_500),
      static_segment(:smiley_canvas, "Smiley", :halfblock, 8, &__MODULE__.Demos.smiley/1,
        color: :ansi256,
        fit: :contain,
        background_threshold: 0.05,
        halfblock_samples: 3,
        halfblock_color_merge_distance: 36
      )
      |> Map.put(:duration_ms, 1_300),
      static_segment(:smiley_canvas, "Smiley", :braille, 8, &__MODULE__.Demos.smiley/1,
        color: :ansi256,
        fit: :contain,
        background_threshold: 0.03
      )
      |> Map.put(:duration_ms, 2_000),
      static_segment(:spiral_canvas, "Spiral", :braille, 8, &__MODULE__.Demos.spiral/1,
        color: :ansi256,
        fit: :contain,
        background_threshold: 0.05
      )
      |> Map.put(:duration_ms, 1_400),
      static_segment(:spiral_canvas, "Spiral", :halfblock, 8, &__MODULE__.Demos.spiral/1,
        color: :ansi256,
        fit: :contain,
        background_threshold: 0.05,
        halfblock_samples: 3,
        halfblock_color_merge_distance: 40
      )
      |> Map.put(:duration_ms, 1_100),
      static_segment(:spiral_canvas, "Spiral", :silhouette, 8, &__MODULE__.Demos.spiral/1,
        color: :ansi256,
        fit: :contain,
        background_threshold: 0.08,
        glyph_width: 7,
        glyph_height: 15
      )
      |> Map.put(:duration_ms, 1_800),
      static_segment(
        :mandelbrot_canvas,
        "Mandelbrot",
        :halfblock,
        8,
        &__MODULE__.Demos.mandelbrot/1,
        color: :ansi256,
        fit: :contain,
        background_threshold: 0.03,
        halfblock_samples: 3,
        halfblock_color_merge_distance: 36
      )
      |> Map.put(:duration_ms, 2_800),
      static_segment(
        :mandelbrot_canvas,
        "Mandelbrot",
        :braille,
        8,
        &__MODULE__.Demos.mandelbrot/1,
        color: :ansi256,
        fit: :contain,
        background_threshold: 0.03
      )
      |> Map.put(:duration_ms, 1_400),
      animated_segment(
        :clock_tick,
        "Clock",
        :halfblock,
        2,
        16,
        &__MODULE__.Demos.clock_init/1,
        &__MODULE__.Demos.clock_frame/2,
        color: :ansi256,
        fit: :contain,
        background_threshold: 0.08,
        halfblock_samples: 3,
        halfblock_color_merge_distance: 32
      ),
      animated_segment(
        :clock_tick,
        "Clock",
        :braille,
        1,
        16,
        &__MODULE__.Demos.clock_init/1,
        &__MODULE__.Demos.clock_frame/2,
        color: :ansi256,
        fit: :contain,
        background_threshold: 0.08
      ),
      animated_segment(
        :clock_tick,
        "Clock",
        :silhouette,
        1,
        16,
        &__MODULE__.Demos.clock_init/1,
        &__MODULE__.Demos.clock_frame/2,
        color: :ansi256,
        fit: :contain,
        background_threshold: 0.08,
        glyph_width: 7,
        glyph_height: 15
      ),
      animated_segment(
        :clock_tick,
        "Clock",
        :luma,
        1,
        16,
        &__MODULE__.Demos.clock_init/1,
        &__MODULE__.Demos.clock_frame/2,
        color: :ansi256,
        fit: :contain,
        samples: 2
      ),
      animated_segment(
        :neon_t,
        "Neon",
        :halfblock,
        5,
        18,
        &__MODULE__.Demos.neon_init/1,
        &__MODULE__.Demos.neon_frame/2,
        color: :ansi256,
        fit: :contain,
        background_threshold: 0.05,
        halfblock_samples: 3,
        halfblock_color_merge_distance: 44
      ),
      animated_segment(
        :neon_t,
        "Neon",
        :braille,
        5,
        18,
        &__MODULE__.Demos.neon_init/1,
        &__MODULE__.Demos.neon_frame/2,
        color: :ansi256,
        fit: :contain,
        background_threshold: 0.03
      ),
      animated_segment(
        :wave_t,
        "Terminal Wave",
        :halfblock,
        5,
        18,
        &__MODULE__.Demos.wave_init/1,
        &__MODULE__.Demos.wave_frame/2,
        color: :ansi256,
        fit: :contain,
        background_threshold: 0.08,
        halfblock_samples: 3,
        halfblock_color_merge_distance: 32
      ),
      animated_segment(
        :braille_bloom_t,
        "Braille Bloom",
        :braille,
        5,
        18,
        &__MODULE__.Demos.bloom_init/1,
        &__MODULE__.Demos.bloom_frame/2,
        color: :ansi256,
        fit: :contain,
        background_threshold: 0.05
      ),
      animated_segment(
        :boids_state,
        "Boids",
        :braille,
        12,
        24,
        &__MODULE__.Demos.boids_init/1,
        &__MODULE__.Demos.boids_frame/2,
        color: :ansi256,
        fit: :contain,
        background_threshold: 0.1
      )
      |> Map.put(:burst_center, 20),
      animated_segment(
        :boids_state,
        "Boids",
        :silhouette,
        12,
        24,
        &__MODULE__.Demos.boids_init/1,
        &__MODULE__.Demos.boids_frame/2,
        color: :ansi256,
        fit: :contain,
        background_threshold: 0.1,
        glyph_width: 6,
        glyph_height: 12
      )
      |> Map.put(:burst_center, 20),
      animated_segment(
        :boids_state,
        "Boids",
        :halfblock,
        12,
        24,
        &__MODULE__.Demos.boids_init/1,
        &__MODULE__.Demos.boids_frame/2,
        color: :ansi256,
        fit: :contain,
        background_threshold: 0.1,
        halfblock_samples: 2,
        halfblock_color_merge_distance: 38
      )
      |> Map.put(:burst_center, 20),
      animated_segment(
        :boids_state,
        "Boids",
        :luma,
        16,
        24,
        &__MODULE__.Demos.boids_init/1,
        &__MODULE__.Demos.boids_frame/2,
        color: :ansi256,
        fit: :contain,
        samples: 2
      )
      |> Map.put(:burst_center, 20)
    ]
  end

  defp static_segment(state_key, name, mode, beats, init_fun, terminal_opts) do
    %{
      kind: :static,
      state_key: state_key,
      name: name,
      mode: mode,
      beats: beats,
      fps: 1,
      init_fun: init_fun,
      frame_fun: fn _stage, canvas -> {canvas, canvas} end,
      terminal_opts: Keyword.put(terminal_opts, :mode, mode),
      dpr: static_dpr(mode)
    }
  end

  defp animated_segment(state_key, name, mode, beats, fps, init_fun, frame_fun, terminal_opts) do
    %{
      kind: :animated,
      state_key: state_key,
      name: name,
      mode: mode,
      beats: beats,
      fps: fps,
      init_fun: init_fun,
      frame_fun: frame_fun,
      terminal_opts: Keyword.put(terminal_opts, :mode, mode),
      dpr: animated_dpr(mode, name)
    }
  end

  defp static_dpr(:braille), do: 2.6
  defp static_dpr(:halfblock), do: 2.0
  defp static_dpr(:luma), do: 2.0
  defp static_dpr(:silhouette), do: 2.0

  defp animated_dpr(:braille, "Braille Bloom"), do: 2.2
  defp animated_dpr(:halfblock, "Neon"), do: 1.7
  defp animated_dpr(:luma, "Boids"), do: 1.5
  defp animated_dpr(:silhouette, "Boids"), do: 1.5
  defp animated_dpr(:braille, "Boids"), do: 1.5
  defp animated_dpr(:halfblock, "Boids"), do: 1.5
  defp animated_dpr(_mode, _name), do: 2.0

  defp preload_playback(schedule, stage, bpm) do
    schedule
    |> Enum.with_index(1)
    |> Enum.reduce({%{}, %{}}, fn {segment, idx}, {states, playback} ->
      state = Map.get_lazy(states, segment.state_key, fn -> segment.init_fun.(stage) end)

      case segment.kind do
        :static ->
          frame = canvas_to_frame(state, stage, segment)
          {Map.put_new(states, segment.state_key, state), Map.put(playback, idx, %{frame: frame})}

        :animated ->
          state = maybe_apply_segment_start_effect(state, segment)
          interval = segment_interval_ms(segment)
          frame_count = max(trunc(Float.ceil(segment_duration_ms(segment, bpm) / interval)), 1)

          {frames, next_state} =
            Enum.map_reduce(1..frame_count, state, fn _, current_state ->
              {canvas, updated_state} = segment.frame_fun.(stage, current_state)
              {canvas_to_frame(canvas, stage, segment), updated_state}
            end)

          {Map.put(states, segment.state_key, next_state),
           Map.put(playback, idx, %{frames: frames, interval: interval})}
      end
    end)
  end

  defp run_segment(
         %{kind: :static} = segment,
         idx,
         total_segments,
         playback,
         stage,
         _segment_start,
         segment_end,
         beats_done,
         total_beats,
         show_start,
         total_ms,
         bpm
       ) do
    maybe_quit!()
    frame = playback |> Map.fetch!(idx) |> Map.fetch!(:frame)

    draw_frame(
      frame,
      footer(
        stage,
        segment,
        idx,
        total_segments,
        beats_done,
        total_beats,
        show_start,
        total_ms,
        bpm
      )
    )

    wait_until(segment_end)
  end

  defp run_segment(
         %{kind: :animated} = segment,
         idx,
         total_segments,
         playback,
         stage,
         segment_start,
         segment_end,
         beats_done,
         total_beats,
         show_start,
         total_ms,
         bpm
       ) do
    maybe_quit!()
    %{frames: frames, interval: interval} = Map.fetch!(playback, idx)

    frames
    |> Enum.with_index(1)
    |> Enum.each(fn {frame, frame_idx} ->
      maybe_quit!()

      draw_frame(
        frame,
        footer(
          stage,
          segment,
          idx,
          total_segments,
          beats_done,
          total_beats,
          show_start,
          total_ms,
          bpm
        )
      )

      target = min(segment_start + frame_idx * interval, segment_end)
      wait_until(target)
    end)
  end

  defp draw_frame(frame, [footer_1, footer_2]) do
    IO.write(["\e[H", frame, "\n", footer_1, "\n", footer_2])
  end

  defp footer(
         stage,
         segment,
         idx,
         total_segments,
         beats_done,
         total_beats,
         show_start,
         total_ms,
         bpm
       ) do
    elapsed_ms = min(max(now_ms() - show_start, 0), total_ms)
    beat_range = "beats #{beats_done + 1}-#{beats_done + segment.beats} / #{total_beats}"

    line_1 =
      " #{segment.name}  ·  mode: #{segment.mode}  ·  segment #{idx}/#{total_segments} "
      |> String.pad_trailing(stage.cols)
      |> String.slice(0, stage.cols)
      |> then(&[IO.ANSI.reverse(), &1, IO.ANSI.reset()])

    line_2 =
      " #{beat_range}  ·  #{format_ms(elapsed_ms)} / #{format_ms(total_ms)}  ·  #{bpm} BPM reggaetron cut  ·  (q) quit "
      |> String.pad_trailing(stage.cols)
      |> String.slice(0, stage.cols)
      |> then(
        &[
          IO.ANSI.format_fragment([:bright, :black, :white_background], true),
          &1,
          IO.ANSI.reset()
        ]
      )

    [line_1, line_2]
  end

  defp draw_title_card(stage, title, subtitle, duration_ms) do
    draw_status_card(stage, title, subtitle, footer_title: "Finished")
    Process.sleep(duration_ms)
  end

  defp draw_status_card(stage, title, subtitle, opts \\ []) do
    footer_title = Keyword.get(opts, :footer_title, "Easel Terminal Showreel")

    frame =
      [
        center_line("", stage.cols),
        center_line("Easel Terminal Showreel", stage.cols),
        center_line("", stage.cols),
        center_line(title, stage.cols),
        center_line(subtitle, stage.cols)
      ]
      |> Enum.map(&String.pad_trailing(&1, stage.cols))
      |> Enum.join("\n")

    filler =
      for _ <- 1..max(stage.demo_rows - 5, 1) do
        String.duplicate(" ", stage.cols)
      end
      |> Enum.join("\n")

    full_frame = frame <> "\n" <> filler

    draw_frame(
      full_frame,
      [
        [
          IO.ANSI.reverse(),
          String.pad_trailing(" #{footer_title} ", stage.cols),
          IO.ANSI.reset()
        ],
        [
          IO.ANSI.reverse(),
          String.pad_trailing(
            " Press q to quit · Ctrl+C if terminal gets weird ",
            stage.cols
          ),
          IO.ANSI.reset()
        ]
      ]
    )
  end

  defp wait_for_start(stage, bpm, total_ms, audio) do
    draw_status_card(
      stage,
      "Ready to roll",
      "Press Enter to start #{format_ms(total_ms)} at #{bpm} BPM#{audio_summary(audio)}",
      footer_title: "Cue"
    )

    _ = IO.gets("")
    :ok
  end

  defp center_line(text, cols) do
    pad = max(div(cols - String.length(text), 2), 0)
    String.duplicate(" ", pad) <> text
  end

  defp format_ms(ms) do
    total_seconds = div(ms, 1000)
    minutes = div(total_seconds, 60)
    seconds = rem(total_seconds, 60)
    :io_lib.format("~2..0B:~2..0B", [minutes, seconds]) |> IO.iodata_to_binary()
  end

  defp print_schedule(schedule, bpm) do
    schedule
    |> Enum.with_index(1)
    |> Enum.each(fn {segment, idx} ->
      duration_ms = segment_duration_ms(segment, bpm)

      IO.puts(
        :io_lib.format(
          "~2..0B. ~-20s  mode=~-10s  beats=~3B  duration=~s",
          [idx, segment.name, Atom.to_string(segment.mode), segment.beats, format_ms(duration_ms)]
        )
      )
    end)

    IO.puts("")
    IO.puts("Total beats: #{total_beats(schedule)}")
    IO.puts("Total time:  #{format_ms(total_duration_ms(schedule, bpm))}")
  end

  defp total_beats(schedule) do
    Enum.reduce(schedule, 0, fn segment, acc -> acc + segment.beats end)
  end

  defp total_duration_ms(schedule, bpm) do
    Enum.reduce(schedule, 0, fn segment, acc -> acc + segment_duration_ms(segment, bpm) end)
  end

  defp beats_to_ms(beats, bpm) do
    round(beats * 60_000 / bpm)
  end

  defp segment_duration_ms(%{duration_ms: duration_ms}, _bpm)
       when is_integer(duration_ms) and duration_ms > 0,
       do: duration_ms

  defp segment_duration_ms(segment, bpm), do: beats_to_ms(segment.beats, bpm)
  defp segment_interval_ms(segment), do: max(round(1000 / max(segment.fps, 1)), 1)

  defp maybe_apply_segment_start_effect(state, %{burst_center: count})
       when is_integer(count) and count > 0,
       do: __MODULE__.Demos.add_boids_center(state, count)

  defp maybe_apply_segment_start_effect(state, _segment), do: state

  defp canvas_to_frame(canvas, stage, segment) do
    image =
      Easel.WX.rasterize(canvas, width: canvas.width, height: canvas.height, dpr: segment.dpr)

    Easel.Terminal.frame_from_rgb(image, stage.cols, stage.demo_rows, segment.terminal_opts)
  end

  defp prepare_audio(opts) do
    path = opts[:mp3] || opts[:music]

    if is_nil(path) do
      nil
    else
      expanded = Path.expand(path)

      unless File.regular?(expanded) do
        raise "audio file not found: #{expanded}"
      end

      player = find_audio_player()

      unless player do
        raise "no supported audio player found for --mp3. Install one of: afplay, ffplay, mpv, mpg123, mplayer, or cvlc"
      end

      %{path: expanded, name: Path.basename(expanded), player: player}
    end
  end

  defp audio_test(opts) do
    audio =
      prepare_audio(opts) ||
        raise "audio test requires --mp3 /path/to/file.mp3"

    IO.puts("Audio test")
    IO.puts("player: #{audio.player.name}")
    IO.puts("file:   #{audio.path}")
    IO.puts("starting playback for 3 seconds...")

    audio_handle = start_audio(audio)
    Process.sleep(3_000)
    stop_audio(audio_handle)

    IO.puts("done")
  end

  defp start_audio(nil), do: nil

  defp start_audio(%{path: path, player: %{exe: exe, arg_fun: arg_fun, name: name}} = audio) do
    script = "\"$@\" >/dev/null 2>&1 & echo $!"

    {output, 0} =
      System.cmd("sh", ["-c", script, "showreel-audio", exe | arg_fun.(path)],
        stderr_to_stdout: true
      )

    case Integer.parse(String.trim(output)) do
      {pid, _} when pid > 0 ->
        Process.sleep(150)

        case System.cmd("kill", ["-0", Integer.to_string(pid)], stderr_to_stdout: true) do
          {_, 0} ->
            Map.put(audio, :os_pid, pid)

          {msg, code} ->
            raise "audio player #{name} exited immediately (code #{code}): #{String.trim(msg)}"
        end

      _ ->
        raise "audio player #{name} did not return a background pid"
    end
  rescue
    error ->
      raise "failed to start audio player #{name}: #{Exception.message(error)}"
  end

  defp stop_audio(nil), do: :ok

  defp stop_audio(%{os_pid: pid}) when is_integer(pid) and pid > 0 do
    _ = System.cmd("kill", ["-TERM", Integer.to_string(pid)], stderr_to_stdout: true)
    :ok
  rescue
    _ -> :ok
  end

  defp find_audio_player do
    [
      {"afplay", fn path -> [path] end},
      {"ffplay", fn path -> ["-nodisp", "-autoexit", "-loglevel", "quiet", path] end},
      {"mpv", fn path -> ["--no-video", "--really-quiet", path] end},
      {"mpg123", fn path -> ["-q", path] end},
      {"mplayer", fn path -> ["-really-quiet", path] end},
      {"cvlc", fn path -> ["--play-and-exit", "--quiet", path] end}
    ]
    |> Enum.find_value(fn {name, arg_fun} ->
      case System.find_executable(name) do
        nil -> nil
        exe -> %{name: name, exe: exe, arg_fun: arg_fun}
      end
    end)
  end

  defp audio_summary(nil), do: ""
  defp audio_summary(%{name: name, player: %{name: player}}), do: " · #{name} via #{player}"

  defp ensure_available! do
    unless Easel.WX.available?() do
      raise "Easel.Terminal showreel requires Erlang compiled with wx support."
    end

    unless match?({:ok, _}, :io.columns()) and match?({:ok, _}, :io.rows()) do
      raise "Easel.Terminal showreel requires an interactive TTY."
    end
  end

  defp terminal_size! do
    case {:io.columns(), :io.rows()} do
      {{:ok, cols}, {:ok, rows}} -> {cols, rows}
      _ -> raise "could not read terminal size"
    end
  end

  defp ensure_wx_env do
    try do
      _ = :wx.get_env()
      false
    rescue
      _ ->
        :wx.new(silent_start: true)
        true
    end
  end

  defp teardown_wx_env(true) do
    :wx.destroy()
  rescue
    _ -> :ok
  end

  defp teardown_wx_env(false), do: :ok

  defp setup_terminal do
    IO.write([
      "\e[?1049h",
      "\e[?25l",
      IO.ANSI.home(),
      IO.ANSI.clear(),
      IO.ANSI.home()
    ])
  end

  defp restore_terminal do
    IO.write([IO.ANSI.reset(), "\e[?25h", "\e[?1049l"])
  end

  defp wait_until(target_ms) do
    maybe_quit!()
    remaining = target_ms - now_ms()

    cond do
      remaining > 10 ->
        Process.sleep(min(remaining - 4, 25))
        wait_until(target_ms)

      remaining > 1 ->
        Process.sleep(remaining)
        maybe_quit!()

      true ->
        :ok
    end
  end

  defp setup_quit_listener do
    case System.find_executable("stty") do
      nil ->
        nil

      stty ->
        {state, 0} = System.cmd(stty, ["-g"], stderr_to_stdout: true)

        _ =
          System.cmd(stty, ["-echo", "-icanon", "min", "1", "time", "0"], stderr_to_stdout: true)

        parent = self()

        task =
          Task.async(fn ->
            quit_listener_loop(parent)
          end)

        %{stty: stty, state: String.trim(state), task: task}
    end
  rescue
    _ -> nil
  end

  defp teardown_quit_listener(nil), do: :ok

  defp teardown_quit_listener(%{stty: stty, state: state, task: %Task{pid: pid}}) do
    if is_pid(pid), do: Process.exit(pid, :kill)
    _ = System.cmd(stty, [state], stderr_to_stdout: true)
    :ok
  rescue
    _ -> :ok
  end

  defp quit_listener_loop(parent) do
    case IO.binread(:stdio, 1) do
      "q" -> send(parent, :showreel_quit)
      "Q" -> send(parent, :showreel_quit)
      :eof -> :ok
      {:error, _} -> :ok
      _ -> quit_listener_loop(parent)
    end
  end

  defp quit_requested? do
    receive do
      :showreel_quit -> true
    after
      0 -> false
    end
  end

  defp maybe_quit! do
    if quit_requested?(), do: throw(:showreel_quit)
  end

  defp now_ms, do: System.monotonic_time(:millisecond)

  defmodule Demos do
    @moduledoc false

    def smiley(stage) do
      size = trunc(min(stage.canvas_w, stage.canvas_h) * 0.9)
      c = size / 2
      face_r = size * 0.33

      Easel.new(size, size)
      |> Easel.set_fill_style("#111317")
      |> Easel.fill_rect(0, 0, size, size)
      |> Easel.begin_path()
      |> Easel.arc(c, c, face_r, 0, :math.pi() * 2)
      |> Easel.set_fill_style("#FFD700")
      |> Easel.fill()
      |> Easel.set_stroke_style("#222")
      |> Easel.set_line_width(size * 0.012)
      |> Easel.stroke()
      |> Easel.begin_path()
      |> Easel.arc(c - size * 0.12, c - size * 0.1, size * 0.05, 0, :math.pi() * 2)
      |> Easel.set_fill_style("#222")
      |> Easel.fill()
      |> Easel.begin_path()
      |> Easel.arc(c + size * 0.12, c - size * 0.1, size * 0.05, 0, :math.pi() * 2)
      |> Easel.fill()
      |> Easel.begin_path()
      |> Easel.arc(c, c + size * 0.02, size * 0.2, 0.2, :math.pi() - 0.2)
      |> Easel.set_stroke_style("#222")
      |> Easel.set_line_width(size * 0.016)
      |> Easel.set_line_cap("round")
      |> Easel.stroke()
      |> Easel.render()
    end

    def chart(stage) do
      width = max(round(stage.canvas_w * 0.9), 700)
      height = max(round(stage.canvas_h * 0.82), 420)
      padding = round(min(width, height) * 0.11)

      data = [
        {"2018", 45},
        {"2019", 62},
        {"2020", 78},
        {"2021", 95},
        {"2022", 120},
        {"2023", 155},
        {"2024", 190},
        {"2025", 230}
      ]

      max_val = data |> Enum.map(&elem(&1, 1)) |> Enum.max()
      bar_count = length(data)
      chart_w = width - padding * 2
      chart_h = height - padding * 2
      bar_w = chart_w / bar_count * 0.7
      gap = chart_w / bar_count * 0.3

      colors = [
        "#6366f1",
        "#8b5cf6",
        "#a78bfa",
        "#c084fc",
        "#d946ef",
        "#ec4899",
        "#f43f5e",
        "#ef4444"
      ]

      canvas =
        Easel.new(width, height)
        |> Easel.set_fill_style("#fafafa")
        |> Easel.fill_rect(0, 0, width, height)
        |> Easel.set_fill_style("#1f2937")
        |> Easel.set_font("bold 22px sans-serif")
        |> Easel.set_text_align("center")
        |> Easel.fill_text("Elixir Popularity Index", width / 2, 34)
        |> Easel.set_stroke_style("#9ca3af")
        |> Easel.set_line_width(1)
        |> Easel.begin_path()
        |> Easel.move_to(padding, padding)
        |> Easel.line_to(padding, height - padding)
        |> Easel.line_to(width - padding, height - padding)
        |> Easel.stroke()

      canvas =
        Enum.reduce(0..4, canvas, fn i, acc ->
          y = padding + chart_h * (1 - i / 4)
          val = round(max_val * i / 4)

          acc
          |> Easel.set_stroke_style("#e5e7eb")
          |> Easel.set_line_width(0.5)
          |> Easel.begin_path()
          |> Easel.move_to(padding, y)
          |> Easel.line_to(width - padding, y)
          |> Easel.stroke()
          |> Easel.set_fill_style("#6b7280")
          |> Easel.set_font("14px sans-serif")
          |> Easel.set_text_align("right")
          |> Easel.fill_text("#{val}", padding - 10, y + 4)
        end)

      data
      |> Enum.with_index()
      |> Enum.reduce(canvas, fn {{label, value}, i}, acc ->
        x = padding + i * (bar_w + gap) + gap / 2
        bar_h = value / max_val * chart_h
        y = height - padding - bar_h
        color = Enum.at(colors, i)

        acc
        |> Easel.set_fill_style(color)
        |> Easel.fill_rect(x, y, bar_w, bar_h)
        |> Easel.set_stroke_style("rgba(0,0,0,0.1)")
        |> Easel.set_line_width(1)
        |> Easel.stroke_rect(x, y, bar_w, bar_h)
        |> Easel.set_fill_style("#374151")
        |> Easel.set_font("bold 14px sans-serif")
        |> Easel.set_text_align("center")
        |> Easel.fill_text("#{value}", x + bar_w / 2, y - 10)
        |> Easel.set_fill_style("#6b7280")
        |> Easel.set_font("14px sans-serif")
        |> Easel.fill_text(label, x + bar_w / 2, height - padding + 24)
      end)
      |> Easel.render()
    end

    def clock_init(_stage), do: 0

    def clock_frame(stage, tick) do
      width = max(round(stage.canvas_w * 0.92), 720)
      height = max(round(stage.canvas_h * 0.56), 260)
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

      canvas =
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
        |> Easel.render()

      {canvas, tick + 1}
    end

    def starfield(stage) do
      :rand.seed(:exsss, {111, 222, 333})
      width = stage.canvas_w
      height = stage.canvas_h

      canvas =
        Easel.new(width, height)
        |> Easel.set_fill_style("#090b26")
        |> Easel.fill_rect(0, 0, width, height)

      canvas =
        Enum.reduce(1..240, canvas, fn _, acc ->
          x = :rand.uniform(width)
          y = :rand.uniform(height)
          radius = :rand.uniform() * 2.4 + 0.4
          brightness = :rand.uniform(155) + 100

          color =
            "rgba(#{brightness}, #{brightness}, #{min(255, brightness + 50)}, #{Float.round(:rand.uniform(), 2)})"

          acc
          |> Easel.begin_path()
          |> Easel.arc(x, y, radius, 0, :math.pi() * 2)
          |> Easel.set_fill_style(color)
          |> Easel.fill()
        end)

      Enum.reduce(1..10, canvas, fn _, acc ->
        x = :rand.uniform(width)
        y = :rand.uniform(height)

        acc
        |> Easel.save()
        |> Easel.set_global_alpha(0.28)
        |> Easel.begin_path()
        |> Easel.arc(x, y, 10, 0, :math.pi() * 2)
        |> Easel.set_fill_style("rgba(200, 200, 255, 0.3)")
        |> Easel.fill()
        |> Easel.set_global_alpha(1.0)
        |> Easel.begin_path()
        |> Easel.arc(x, y, 2.4, 0, :math.pi() * 2)
        |> Easel.set_fill_style("white")
        |> Easel.fill()
        |> Easel.restore()
      end)
      |> Easel.render()
    end

    def spiral(stage) do
      size = trunc(min(stage.canvas_w, stage.canvas_h) * 0.94)
      cx = size / 2
      cy = size / 2
      turns = 8
      points = turns * 100

      canvas =
        Easel.new(size, size)
        |> Easel.set_fill_style("#111")
        |> Easel.fill_rect(0, 0, size, size)
        |> Easel.set_line_width(2)
        |> Easel.set_line_cap("round")

      Enum.reduce(0..points, canvas, fn i, acc ->
        t = i / points
        angle = t * turns * 2 * :math.pi()
        radius = t * size * 0.4
        x = cx + radius * :math.cos(angle)
        y = cy + radius * :math.sin(angle)
        hue = rem(round(t * 360 * 3), 360)
        color = "hsl(#{hue}, 80%, 60%)"

        if i == 0 do
          acc
          |> Easel.begin_path()
          |> Easel.move_to(x, y)
        else
          prev_t = t - 1 / points
          prev_angle = prev_t * turns * 2 * :math.pi()
          prev_radius = prev_t * size * 0.4
          px = cx + prev_radius * :math.cos(prev_angle)
          py = cy + prev_radius * :math.sin(prev_angle)

          acc
          |> Easel.set_stroke_style(color)
          |> Easel.begin_path()
          |> Easel.move_to(px, py)
          |> Easel.line_to(x, y)
          |> Easel.stroke()
        end
      end)
      |> Easel.render()
    end

    def tree(stage) do
      :rand.seed(:exsss, {42, 42, 42})
      width = stage.canvas_w
      height = stage.canvas_h

      canvas =
        Easel.new(width, height)
        |> Easel.set_fill_style("#87CEEB")
        |> Easel.fill_rect(0, 0, width, height)
        |> Easel.set_fill_style("#3d5a1e")
        |> Easel.fill_rect(0, height - 40, width, 40)

      draw_tree(canvas, width / 2, height - 40, height * 0.22, -:math.pi() / 2, 0, 10)
      |> Easel.render()
    end

    defp draw_tree(canvas, _x, _y, _length, _angle, depth, max_depth) when depth >= max_depth,
      do: canvas

    defp draw_tree(canvas, x, y, length, angle, depth, max_depth) do
      end_x = x + length * :math.cos(angle)
      end_y = y + length * :math.sin(angle)
      t = depth / max_depth
      r = round(80 * (1 - t) + 34 * t)
      g = round(50 * (1 - t) + 139 * t)
      b = round(20 * (1 - t) + 34 * t)
      line_w = max(1, (max_depth - depth) * 1.5)

      canvas =
        canvas
        |> Easel.begin_path()
        |> Easel.move_to(x, y)
        |> Easel.line_to(end_x, end_y)
        |> Easel.set_stroke_style("rgb(#{r}, #{g}, #{b})")
        |> Easel.set_line_width(line_w)
        |> Easel.set_line_cap("round")
        |> Easel.stroke()

      canvas =
        if depth >= max_depth - 2 do
          size = 3 + :rand.uniform(4)

          canvas
          |> Easel.begin_path()
          |> Easel.arc(end_x, end_y, size, 0, :math.pi() * 2)
          |> Easel.set_fill_style("rgba(34, #{100 + :rand.uniform(100)}, 34, 0.6)")
          |> Easel.fill()
        else
          canvas
        end

      new_length = length * (0.65 + :rand.uniform() * 0.1)
      spread = 0.4 + :rand.uniform() * 0.2

      canvas
      |> draw_tree(end_x, end_y, new_length, angle - spread, depth + 1, max_depth)
      |> draw_tree(end_x, end_y, new_length, angle + spread, depth + 1, max_depth)
    end

    def mondrian(stage) do
      :rand.seed(:exsss, {123, 456, 789})
      size = trunc(min(stage.canvas_w, stage.canvas_h) * 0.96)

      Easel.new(size, size)
      |> Easel.set_fill_style("#ecf0f1")
      |> Easel.fill_rect(0, 0, size, size)
      |> mondrian_generate(0, 0, size, size, 0)
      |> Easel.render()
    end

    defp mondrian_generate(canvas, x, y, w, h, depth) when depth > 5 or w < 40 or h < 40 do
      colors = ["#c0392b", "#2980b9", "#f1c40f", "#ecf0f1", "#ecf0f1", "#ecf0f1"]
      color = Enum.random(colors)
      line_width = 6

      canvas
      |> Easel.set_fill_style(color)
      |> Easel.fill_rect(x + line_width / 2, y + line_width / 2, w - line_width, h - line_width)
      |> Easel.set_stroke_style("#2c3e50")
      |> Easel.set_line_width(line_width)
      |> Easel.stroke_rect(x, y, w, h)
    end

    defp mondrian_generate(canvas, x, y, w, h, depth) do
      if :rand.uniform() < 0.5 do
        split = round(w * (0.3 + :rand.uniform() * 0.4))

        canvas
        |> mondrian_generate(x, y, split, h, depth + 1)
        |> mondrian_generate(x + split, y, w - split, h, depth + 1)
      else
        split = round(h * (0.3 + :rand.uniform() * 0.4))

        canvas
        |> mondrian_generate(x, y, w, split, depth + 1)
        |> mondrian_generate(x, y + split, w, h - split, depth + 1)
      end
    end

    def sierpinski(stage) do
      width = stage.canvas_w
      height = stage.canvas_h
      depth = 8
      padding = 20
      side = width - padding * 2
      h = side * :math.sqrt(3) / 2
      ax = width / 2
      ay = padding
      bx = padding
      by = padding + h
      cx = width - padding
      cy = padding + h

      Easel.new(width, height)
      |> Easel.set_fill_style("#0d1117")
      |> Easel.fill_rect(0, 0, width, height)
      |> Easel.set_fill_style("#58a6ff")
      |> sierpinski_triangle(ax, ay, bx, by, cx, cy, depth)
      |> Easel.render()
    end

    defp sierpinski_triangle(canvas, _ax, _ay, _bx, _by, _cx, _cy, depth) when depth <= 0,
      do: canvas

    defp sierpinski_triangle(canvas, ax, ay, bx, by, cx, cy, 1) do
      canvas
      |> Easel.begin_path()
      |> Easel.move_to(ax, ay)
      |> Easel.line_to(bx, by)
      |> Easel.line_to(cx, cy)
      |> Easel.close_path()
      |> Easel.fill()
    end

    defp sierpinski_triangle(canvas, ax, ay, bx, by, cx, cy, depth) do
      mab_x = (ax + bx) / 2
      mab_y = (ay + by) / 2
      mbc_x = (bx + cx) / 2
      mbc_y = (by + cy) / 2
      mac_x = (ax + cx) / 2
      mac_y = (ay + cy) / 2

      canvas
      |> sierpinski_triangle(ax, ay, mab_x, mab_y, mac_x, mac_y, depth - 1)
      |> sierpinski_triangle(mab_x, mab_y, bx, by, mbc_x, mbc_y, depth - 1)
      |> sierpinski_triangle(mac_x, mac_y, mbc_x, mbc_y, cx, cy, depth - 1)
    end

    def mandelbrot(_stage) do
      width = 220
      height = 220
      max_iter = 50
      x_min = -2.0
      x_max = 0.7
      y_min = -1.35
      y_max = 1.35

      canvas = Easel.new(width, height)

      Enum.reduce(0..(height - 1), canvas, fn py, acc ->
        ci = y_min + py / height * (y_max - y_min)

        Enum.reduce(0..(width - 1), acc, fn px, acc2 ->
          cr = x_min + px / width * (x_max - x_min)
          n = mandelbrot_iterate(cr, ci, max_iter)
          color = mandelbrot_color(n, max_iter)

          acc2
          |> Easel.set_fill_style(color)
          |> Easel.fill_rect(px, py, 1, 1)
        end)
      end)
      |> Easel.render()
    end

    defp mandelbrot_iterate(cr, ci, max_iter),
      do: mandelbrot_iterate(0.0, 0.0, cr, ci, 0, max_iter)

    defp mandelbrot_iterate(_zr, _zi, _cr, _ci, n, max) when n >= max, do: max

    defp mandelbrot_iterate(zr, zi, cr, ci, n, max) do
      zr2 = zr * zr
      zi2 = zi * zi

      if zr2 + zi2 > 4.0 do
        n
      else
        mandelbrot_iterate(zr2 - zi2 + cr, 2.0 * zr * zi + ci, cr, ci, n + 1, max)
      end
    end

    defp mandelbrot_color(n, max) when n >= max, do: "#000000"

    defp mandelbrot_color(n, max) do
      t = n / max
      r = round(9 * (1 - t) * t * t * t * 255)
      g = round(15 * (1 - t) * (1 - t) * t * t * 255)
      b = round(8.5 * (1 - t) * (1 - t) * (1 - t) * t * 255)
      "rgb(#{min(r, 255)}, #{min(g, 255)}, #{min(b, 255)})"
    end

    def bloom_init(_stage), do: 0.0

    def bloom_frame(stage, t) do
      width = max(stage.canvas_w, 720)
      height = max(stage.canvas_h, 520)
      center_x = width / 2
      center_y = height / 2
      points = 800
      base_radius = min(width, height) * 0.33

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

            x =
              center_x +
                r * :math.sin(theta * a + phase * speed) * :math.cos(theta * twist + phase)

            y =
              center_y +
                r * :math.sin(theta * b - phase * speed * 0.8) *
                  :math.sin(theta * twist + phase * 0.6)

            if i == 0 do
              Easel.move_to(acc, x, y)
            else
              Easel.line_to(acc, x, y)
            end
          end)
        end)
        |> Easel.stroke()
      end

      canvas =
        Easel.new(width, height)
        |> Easel.set_fill_style("#02030a")
        |> Easel.fill_rect(0, 0, width, height)
        |> Easel.set_global_alpha(0.08)

      canvas =
        Enum.reduce(0..10, canvas, fn i, acc ->
          r = base_radius * (0.26 + i * 0.075)
          hue = 210 + i * 7 + round(:math.sin(t + i) * 8)

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
          alpha: 0.95,
          line_width: 2.4,
          phase: t,
          speed: 1.0,
          a: 3.0,
          b: 2.0,
          twist: 1.0
        },
        %{
          hue: 292 + round(:math.sin(t * 0.41) * 22),
          alpha: 0.82,
          line_width: 1.9,
          phase: t + 1.7,
          speed: 1.18,
          a: 5.0,
          b: 4.0,
          twist: 0.72
        },
        %{
          hue: 38 + round(:math.cos(t * 0.37) * 14),
          alpha: 0.7,
          line_width: 1.4,
          phase: t + 3.1,
          speed: 0.82,
          a: 7.0,
          b: 5.0,
          twist: 1.36
        },
        %{
          hue: 210 + round(:math.sin(t * 0.51) * 26),
          alpha: 0.52,
          line_width: 1.0,
          phase: t + 4.4,
          speed: 1.34,
          a: 9.0,
          b: 8.0,
          twist: 0.94
        }
      ]

      canvas = Enum.reduce(traces, canvas, fn opts, acc -> trace.(acc, opts) end)

      canvas =
        canvas
        |> Easel.set_fill_style("rgba(255,255,255,0.9)")
        |> Easel.begin_path()
        |> Easel.arc(center_x, center_y, 5, 0, 2 * :math.pi())
        |> Easel.fill()
        |> Easel.set_fill_style("rgba(255,255,255,0.08)")
        |> Easel.begin_path()
        |> Easel.arc(center_x, center_y, 18, 0, 2 * :math.pi())
        |> Easel.fill()
        |> Easel.render()

      {canvas, t + 0.038}
    end

    def neon_init(_stage), do: 0.0

    def neon_frame(stage, t) do
      width = max(stage.canvas_w, 640)
      height = max(stage.canvas_h, 420)
      center_y = height / 2

      band = fn canvas, opts ->
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
          Enum.reduce(Enum.reverse(bottom_points), c, fn {x, y}, acc ->
            Easel.line_to(acc, x, y)
          end)
        end)
        |> Easel.close_path()
        |> Easel.fill()
      end

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

      canvas = Enum.reduce(bands, canvas, fn opts, acc -> band.(acc, opts) end)

      canvas =
        canvas
        |> Easel.set_fill_style("rgba(255,255,255,0.05)")
        |> Easel.begin_path()
        |> Easel.arc(width * 0.18, height * 0.22, width * 0.06, 0, 2 * :math.pi())
        |> Easel.fill()
        |> Easel.set_fill_style("rgba(255,255,255,0.04)")
        |> Easel.begin_path()
        |> Easel.arc(width * 0.82, height * 0.72, width * 0.08, 0, 2 * :math.pi())
        |> Easel.fill()
        |> Easel.render()

      {canvas, t + 0.08}
    end

    def wave_init(_stage), do: 0.0

    def wave_frame(stage, t) do
      width = max(stage.canvas_w, 240)
      height = max(stage.canvas_h, 160)
      amp1 = height * 0.18
      amp2 = height * 0.08

      canvas =
        Easel.new(width, height)
        |> Easel.set_fill_style("black")
        |> Easel.fill_rect(0, 0, width, height)
        |> Easel.set_stroke_style("hsl(190, 80%, 65%)")
        |> Easel.set_line_width(2)
        |> Easel.begin_path()
        |> then(fn c ->
          Enum.reduce(0..(width - 1), c, fn x, acc ->
            y =
              height * 0.5 + :math.sin(x * 0.08 + t * 2.0) * amp1 + :math.sin(x * 0.03 - t) * amp2

            if x == 0 do
              Easel.move_to(acc, x, y)
            else
              Easel.line_to(acc, x, y)
            end
          end)
        end)
        |> Easel.stroke()
        |> Easel.render()

      {canvas, t + 0.08}
    end

    def boids_init(stage) do
      :rand.seed(:exsss, {77, 88, 99})
      width = max(stage.canvas_w, 800)
      height = max(stage.canvas_h, 600)
      num_boids = 100

      boids =
        for _ <- 1..num_boids do
          angle = :rand.uniform() * 2 * :math.pi()
          speed = 2.0 + :rand.uniform() * 2.0

          %{
            x: :rand.uniform(width) * 1.0,
            y: :rand.uniform(height) * 1.0,
            vx: :math.cos(angle) * speed,
            vy: :math.sin(angle) * speed
          }
        end

      %{width: width, height: height, boids: boids, tick: 0}
    end

    def boids_frame(_stage, state) do
      next = tick_boids(state) |> bump_tick()
      {render_boids(next), next}
    end

    def add_boids_center(%{width: width, height: height} = state, count \\ 10) do
      x = width / 2
      y = height / 2

      burst =
        for _ <- 1..count do
          angle = :rand.uniform() * 2 * :math.pi()
          speed = 2.0 + :rand.uniform() * 2.0

          %{
            x: x * 1.0,
            y: y * 1.0,
            vx: :math.cos(angle) * speed,
            vy: :math.sin(angle) * speed
          }
        end

      update_in(state.boids, fn boids -> Enum.take(burst ++ boids, 500) end)
    end

    defp tick_boids(%{width: width, height: height, boids: boids} = state) do
      perception = 50.0
      separation_dist = 25.0
      max_speed = 4.0
      max_force = 0.1
      cell_size = trunc(perception)

      grid =
        Enum.reduce(boids, %{}, fn boid, grid ->
          key = {trunc(boid.x / cell_size), trunc(boid.y / cell_size)}
          Map.update(grid, key, [boid], &[boid | &1])
        end)

      next_boids =
        Enum.map(boids, fn boid ->
          cx = trunc(boid.x / cell_size)
          cy = trunc(boid.y / cell_size)

          nearby =
            for dx <- -1..1, dy <- -1..1, reduce: [] do
              acc -> Map.get(grid, {cx + dx, cy + dy}, []) ++ acc
            end

          {sep_x, sep_y, ali_x, ali_y, coh_x, coh_y, count} =
            Enum.reduce(nearby, {0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0}, fn other,
                                                                      {sx, sy, ax, ay, cx2, cy2,
                                                                       n} ->
              dx = other.x - boid.x
              dy = other.y - boid.y
              dist_sq = dx * dx + dy * dy

              if dist_sq > 0 and dist_sq < perception * perception do
                dist = :math.sqrt(dist_sq)

                {sx2, sy2} =
                  if dist < separation_dist do
                    {sx - dx / dist, sy - dy / dist}
                  else
                    {sx, sy}
                  end

                {sx2, sy2, ax + other.vx, ay + other.vy, cx2 + other.x, cy2 + other.y, n + 1}
              else
                {sx, sy, ax, ay, cx2, cy2, n}
              end
            end)

          boid =
            if count > 0 do
              {avx, avy} = steer(boid, ali_x / count, ali_y / count, max_speed, max_force)

              {cvx, cvy} =
                steer(boid, coh_x / count - boid.x, coh_y / count - boid.y, max_speed, max_force)

              {svx, svy} = {sep_x * max_force * 1.5, sep_y * max_force * 1.5}
              %{boid | vx: boid.vx + svx + avx + cvx, vy: boid.vy + svy + avy + cvy}
            else
              boid
            end

          boid
          |> limit_speed(max_speed)
          |> move_boid()
          |> wrap_boid(width, height)
        end)

      %{state | boids: next_boids}
    end

    defp steer(boid, target_vx, target_vy, max_speed, max_force) do
      mag = :math.sqrt(target_vx * target_vx + target_vy * target_vy)

      if mag > 0 do
        dvx = target_vx / mag * max_speed - boid.vx
        dvy = target_vy / mag * max_speed - boid.vy
        limit_vec(dvx, dvy, max_force)
      else
        {0.0, 0.0}
      end
    end

    defp limit_vec(x, y, max) do
      mag = :math.sqrt(x * x + y * y)

      if mag > max do
        {x / mag * max, y / mag * max}
      else
        {x, y}
      end
    end

    defp limit_speed(boid, max_speed) do
      speed = :math.sqrt(boid.vx * boid.vx + boid.vy * boid.vy)

      if speed > max_speed do
        %{boid | vx: boid.vx / speed * max_speed, vy: boid.vy / speed * max_speed}
      else
        boid
      end
    end

    defp move_boid(boid), do: %{boid | x: boid.x + boid.vx, y: boid.y + boid.vy}

    defp wrap_boid(boid, width, height) do
      %{boid | x: wrap_val(boid.x, width), y: wrap_val(boid.y, height)}
    end

    defp wrap_val(v, max) do
      cond do
        v < 0 -> v + max
        v > max -> v - max
        true -> v
      end
    end

    defp bump_tick(state), do: Map.update(state, :tick, 1, &(&1 + 1))

    defp render_boids(%{width: width, height: height, boids: boids}) do
      canvas =
        Easel.new(width, height)
        |> Easel.set_fill_style("#0a0a2e")
        |> Easel.fill_rect(0, 0, width, height)

      buckets =
        Enum.group_by(boids, fn boid ->
          angle = :math.atan2(boid.vy, boid.vx)
          div(round(angle / :math.pi() * 180 + 180), 10) * 10
        end)

      Enum.reduce(buckets, canvas, fn {hue, group}, acc ->
        acc = Easel.set_fill_style(acc, "hsl(#{hue}, 70%, 60%)")
        acc = Easel.begin_path(acc)

        acc =
          Enum.reduce(group, acc, fn boid, acc2 ->
            angle = :math.atan2(boid.vy, boid.vx)
            size = 9
            x1 = boid.x + :math.cos(angle) * size * 2
            y1 = boid.y + :math.sin(angle) * size * 2
            x2 = boid.x + :math.cos(angle + 2.5) * size
            y2 = boid.y + :math.sin(angle + 2.5) * size
            x3 = boid.x + :math.cos(angle - 2.5) * size
            y3 = boid.y + :math.sin(angle - 2.5) * size

            acc2
            |> Easel.move_to(x1, y1)
            |> Easel.line_to(x2, y2)
            |> Easel.line_to(x3, y3)
            |> Easel.close_path()
          end)

        Easel.fill(acc)
      end)
      |> Easel.render()
    end
  end
end

if System.get_env("EASEL_SHOWREEL_NOAUTO") != "1" do
  Easel.TermShowreel.main(System.argv())
end
