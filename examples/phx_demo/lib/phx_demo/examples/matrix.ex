defmodule PhxDemo.Examples.Matrix do
  @width 800
  @height 600
  @font_size 14
  @cols div(@width, @font_size)
  @chars ~c"abcdefghijklmnopqrstuvwxyz0123456789@#$%^&*(){}[]|;:<>?ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ"

  def init do
    columns =
      for col <- 0..(@cols - 1), into: %{} do
        drops = for _ <- 1..Enum.random(1..3), do: new_drop(col)
        {col, drops}
      end

    %{columns: columns, tick: 0}
  end

  def tick(%{columns: columns, tick: tick} = state) do
    max_rows = div(@height, @font_size)

    columns =
      Map.new(columns, fn {col, drops} ->
        drops = Enum.map(drops, &%{&1 | row: &1.row + &1.speed})

        drops =
          Enum.map(drops, fn drop ->
            if drop.row - drop.length > max_rows, do: new_drop(col), else: drop
          end)

        drops =
          if :rand.uniform() < 0.3 do
            Enum.map(drops, fn drop ->
              idx = :rand.uniform(length(drop.chars)) - 1
              %{drop | chars: List.replace_at(drop.chars, idx, random_char())}
            end)
          else
            drops
          end

        {col, drops}
      end)

    %{state | columns: columns, tick: tick + 1}
  end

  def render(%{columns: columns}) do
    max_rows = div(@height, @font_size)

    canvas =
      Easel.new(@width, @height)
      |> Easel.set_fill_style("rgba(0, 0, 0, 0.85)")
      |> Easel.fill_rect(0, 0, @width, @height)
      |> Easel.set_font("#{@font_size}px monospace")
      |> Easel.set_text_baseline("top")
      |> Easel.set_text_align("center")

    Enum.reduce(columns, canvas, fn {col, drops}, c0 ->
      x = col * @font_size + @font_size / 2

      Enum.reduce(drops, c0, fn drop, c1 ->
        head_row = trunc(drop.row)

        Enum.reduce(0..(drop.length - 1), c1, fn i, c2 ->
          row = head_row - i

          if row >= 0 and row < max_rows do
            y = row * @font_size
            char_idx = rem(abs(row), length(drop.chars))
            char = Enum.at(drop.chars, char_idx)

            {color, alpha} =
              if i == 0 do
                {"#ffffff", 1.0}
              else
                brightness = 1.0 - i / drop.length
                g = round(255 * brightness)
                {"rgb(0, #{g}, 0)", max(0.1, brightness)}
              end

            c2
            |> Easel.save()
            |> Easel.set_global_alpha(alpha)
            |> Easel.set_fill_style(color)
            |> Easel.fill_text(char, x, y)
            |> Easel.restore()
          else
            c2
          end
        end)
      end)
    end)
    |> Easel.render()
  end

  defp new_drop(_col) do
    %{
      row: -Enum.random(0..30),
      speed: Enum.random(1..3) / 1.0,
      length: Enum.random(8..25),
      chars: for(_ <- 1..40, do: random_char())
    }
  end

  defp random_char do
    idx = :rand.uniform(length(@chars)) - 1
    @chars |> Enum.at(idx) |> List.wrap() |> List.to_string()
  end
end
