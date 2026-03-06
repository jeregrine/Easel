defmodule TermExampleOpts do
  @valid_modes ~w(auto luma silhouette braille halfblock)

  def merge_terminal_mode(opts) do
    case terminal_mode() do
      nil -> opts
      mode -> Keyword.put(opts, :mode, mode)
    end
  end

  def terminal_mode do
    {parsed, _argv, invalid} = OptionParser.parse(System.argv(), strict: [mode: :string])

    case {Keyword.get(parsed, :mode), invalid} do
      {nil, []} ->
        nil

      {mode, []} when mode in @valid_modes ->
        parse_mode(mode)

      {mode, []} ->
        raise ArgumentError,
              "invalid --mode #{inspect(mode)}. Expected one of: #{Enum.join(@valid_modes, ", ")}"

      {_mode, invalid} ->
        raise ArgumentError, "invalid options: #{inspect(invalid)}"
    end
  end

  defp parse_mode("auto"), do: nil
  defp parse_mode("luma"), do: :luma
  defp parse_mode("silhouette"), do: :silhouette
  defp parse_mode("braille"), do: :braille
  defp parse_mode("halfblock"), do: :halfblock
end
