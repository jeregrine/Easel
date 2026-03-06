# Simple audio-only test.
# Run:
#   mix run examples/term/audio_test.exs
#   mix run examples/term/audio_test.exs -- --mp3 ~/Downloads/100bpm___reggaeton-aus-der-regenbogentonne___isrsrsrr.mp3

defmodule Easel.AudioTest do
  @default_mp3 "~/Downloads/100bpm___reggaeton-aus-der-regenbogentonne___isrsrsrr.mp3"

  def main(argv) do
    argv = normalize_argv(argv)

    {opts, args, invalid} =
      OptionParser.parse(argv,
        strict: [mp3: :string, music: :string]
      )

    if invalid != [] do
      raise ArgumentError, "invalid options: #{inspect(invalid)}"
    end

    path = opts[:mp3] || opts[:music] || List.first(args) || @default_mp3
    expanded = Path.expand(path)

    unless File.regular?(expanded) do
      raise "audio file not found: #{expanded}"
    end

    player =
      find_player() ||
        raise "no audio player found (tried afplay, ffplay, mpv, mpg123, mplayer, cvlc)"

    IO.puts("Audio-only test")
    IO.puts("player: #{player.name}")
    IO.puts("file:   #{expanded}")
    IO.puts("")
    IO.puts("If you hear audio, this works. Press Ctrl+C to stop if needed.")
    IO.puts("")

    {_, status} = System.cmd(player.exe, player.args.(expanded), stderr_to_stdout: true)

    if status != 0 do
      raise "player exited with status #{status}"
    end
  end

  defp normalize_argv(["--" | rest]), do: rest
  defp normalize_argv(argv), do: argv

  defp find_player do
    [
      {"afplay", fn path -> [path] end},
      {"ffplay", fn path -> ["-nodisp", "-autoexit", "-loglevel", "quiet", path] end},
      {"mpv", fn path -> ["--no-video", "--really-quiet", path] end},
      {"mpg123", fn path -> ["-q", path] end},
      {"mplayer", fn path -> ["-really-quiet", path] end},
      {"cvlc", fn path -> ["--play-and-exit", "--quiet", path] end}
    ]
    |> Enum.find_value(fn {name, args_fun} ->
      case System.find_executable(name) do
        nil -> nil
        exe -> %{name: name, exe: exe, args: args_fun}
      end
    end)
  end
end

Easel.AudioTest.main(System.argv())
