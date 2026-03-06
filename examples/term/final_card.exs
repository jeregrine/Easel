# Final title card test with direct terminal text only.
# Run:
#   mix run examples/term/final_card.exs

defmodule FinalCard do
  def main do
    {term_cols, term_rows} =
      case {:io.columns(), :io.rows()} do
        {{:ok, cols}, {:ok, rows}} -> {cols, rows}
        _ -> {120, 40}
      end

    stty = System.find_executable("stty")

    stty_state =
      if stty,
        do: elem(System.cmd(stty, ["-g"], stderr_to_stdout: true), 0) |> String.trim(),
        else: nil

    if stty,
      do: System.cmd(stty, ["-echo", "-icanon", "min", "1", "time", "0"], stderr_to_stdout: true)

    try do
      draw_background(term_cols, term_rows)
      draw_centered_text(term_cols, max(div(term_rows * 50, 100), 3), "EASEL")
      draw_centered_text(term_cols, max(div(term_rows * 56, 100), 5), "Canvas in your terminal")
      draw_centered_text(term_cols, max(div(term_rows * 62, 100), 7), "NOW!")
      wait_for_q()
    after
      if stty && stty_state, do: System.cmd(stty, [stty_state], stderr_to_stdout: true)
      IO.write([IO.ANSI.reset(), "\e[?25h", "\e[?1049l"])
    end
  end

  defp draw_background(cols, rows) do
    line = IO.iodata_to_binary([ansi(["48;5;57"]), String.duplicate(" ", cols), IO.ANSI.reset()])
    body = Enum.map_join(1..rows, "", fn _ -> line end)
    IO.write(["\e[?1049h", "\e[?25l", IO.ANSI.home(), body, IO.ANSI.home()])
  end

  defp draw_centered_text(term_cols, row, text) do
    col = max(div(term_cols - String.length(text), 2), 0) + 1

    IO.write([
      cursor(col, row),
      ansi(["38;5;230", "1"]),
      text,
      IO.ANSI.reset()
    ])
  end

  defp cursor(col, row), do: "\e[#{row};#{col}H"
  defp ansi(codes), do: "\e[" <> Enum.join(codes, ";") <> "m"

  defp wait_for_q do
    case IO.binread(:stdio, 1) do
      "q" -> :ok
      "Q" -> :ok
      <<3>> -> :ok
      _ -> wait_for_q()
    end
  end
end

FinalCard.main()
