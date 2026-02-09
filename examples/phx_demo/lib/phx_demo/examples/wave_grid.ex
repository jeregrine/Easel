defmodule PhxDemo.Examples.WaveGrid do
  @width 840
  @height 504
  @cell 12
  @cols div(@width, @cell)
  @rows div(@height, @cell)

  def width, do: @width
  def height, do: @height
  def cell, do: @cell

  def init do
    %{sources: [%{x: @width / 2, y: @height / 2, amp: 1.0, decay: 0.004, hue: 190}], t: 0}
  end

  def add(%{sources: sources} = state, x, y) do
    src = %{
      x: x,
      y: y,
      amp: 1.0,
      decay: 0.004 + :rand.uniform() * 0.003,
      hue: :rand.uniform(360) - 1
    }

    %{state | sources: Enum.take([src | sources], 8)}
  end

  def tick(%{sources: sources, t: t} = state) do
    sources =
      Enum.map(sources, fn s -> %{s | amp: s.amp * 0.995} end) |> Enum.filter(&(&1.amp > 0.2))

    %{state | sources: sources, t: t + 1}
  end

  def background do
    Easel.new(@width, @height)
    |> Easel.set_fill_style("#040712")
    |> Easel.fill_rect(0, 0, @width, @height)
    |> Easel.render()
  end

  def render(%{sources: sources, t: t}) do
    instances =
      for gy <- 0..(@rows - 1), gx <- 0..(@cols - 1) do
        x = gx * @cell + @cell / 2
        y = gy * @cell + @cell / 2
        h = height_at(x, y, t, sources)
        b = max(8, min(85, round((h + 1.0) * 42)))
        hue = hue_at(x, y, sources)
        %{x: gx * @cell, y: gy * @cell, fill: "hsl(#{hue}, 80%, #{b}%)"}
      end

    Easel.new(@width, @height)
    |> Easel.template(:cell, fn c ->
      c
      |> Easel.fill_rect(0, 0, @cell - 1, @cell - 1)
    end)
    |> Easel.instances(:cell, instances)
    |> Easel.render()
  end

  defp height_at(x, y, t, sources) do
    phase = t * 0.18

    Enum.reduce(sources, 0.0, fn s, acc ->
      dx = x - s.x
      dy = y - s.y
      d = :math.sqrt(dx * dx + dy * dy)
      acc + :math.sin(d * 0.08 - phase) * s.amp * :math.exp(-d * s.decay)
    end)
  end

  defp hue_at(x, y, []), do: rem(round((x + y) * 0.05), 360)

  defp hue_at(x, y, sources) do
    {h, _w} =
      Enum.reduce(sources, {0.0, 0.0}, fn s, {h_acc, w_acc} ->
        dx = x - s.x
        dy = y - s.y
        d2 = max(1.0, dx * dx + dy * dy)
        w = 1.0 / d2
        {h_acc + s.hue * w, w_acc + w}
      end)

    rem(round(h), 360)
  end
end
