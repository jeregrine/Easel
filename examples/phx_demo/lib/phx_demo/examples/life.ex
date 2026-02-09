defmodule PhxDemo.Examples.Life do
  @cols 120
  @rows 80
  @cell 8

  def width, do: @cols * @cell
  def height, do: @rows * @cell
  def cell, do: @cell

  def init(density \\ 0.22) do
    alive =
      for y <- 0..(@rows - 1),
          x <- 0..(@cols - 1),
          :rand.uniform() < density,
          into: MapSet.new() do
        {x, y}
      end

    %{alive: alive}
  end

  def tick(%{alive: alive} = state) do
    counts =
      Enum.reduce(alive, %{}, fn {x, y}, acc ->
        Enum.reduce(-1..1, acc, fn dx, acc2 ->
          Enum.reduce(-1..1, acc2, fn dy, acc3 ->
            if dx == 0 and dy == 0 do
              acc3
            else
              nx = x + dx
              ny = y + dy

              if nx >= 0 and nx < @cols and ny >= 0 and ny < @rows do
                Map.update(acc3, {nx, ny}, 1, &(&1 + 1))
              else
                acc3
              end
            end
          end)
        end)
      end)

    next_alive =
      Enum.reduce(counts, MapSet.new(), fn {cell, n}, acc ->
        alive_now = MapSet.member?(alive, cell)

        if (alive_now and (n == 2 or n == 3)) or (!alive_now and n == 3) do
          MapSet.put(acc, cell)
        else
          acc
        end
      end)

    %{state | alive: next_alive}
  end

  def toggle(%{alive: alive} = state, x, y) do
    if x >= 0 and x < @cols and y >= 0 and y < @rows do
      alive =
        if MapSet.member?(alive, {x, y}),
          do: MapSet.delete(alive, {x, y}),
          else: MapSet.put(alive, {x, y})

      %{state | alive: alive}
    else
      state
    end
  end

  def render_background do
    Easel.new(width(), height())
    |> Easel.set_fill_style("#0b1020")
    |> Easel.fill_rect(0, 0, width(), height())
    |> Easel.render()
  end

  def render(%{alive: alive}) do
    instances = Enum.map(alive, fn {x, y} -> %{x: x * @cell, y: y * @cell} end)

    Easel.new(width(), height())
    |> Easel.template(:cell, fn c ->
      c
      |> Easel.set_fill_style("#7dd3fc")
      |> Easel.fill_rect(0, 0, @cell - 1, @cell - 1)
    end)
    |> Easel.instances(:cell, instances)
    |> Easel.render()
  end
end
