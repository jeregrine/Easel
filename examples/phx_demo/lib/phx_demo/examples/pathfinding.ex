defmodule PhxDemo.Examples.Pathfinding do
  @cols 56
  @rows 34
  @cell 16

  def cols, do: @cols
  def rows, do: @rows
  def cell, do: @cell
  def width, do: @cols * @cell
  def height, do: @rows * @cell

  def init do
    start = {2, 2}
    goal = {@cols - 3, @rows - 3}

    %{
      walls: MapSet.new(),
      start: start,
      goal: goal,
      queue: :queue.in(start, :queue.new()),
      visited: MapSet.new([start]),
      came: %{},
      frontier: MapSet.new([start]),
      path: MapSet.new(),
      running: false,
      found: false
    }
  end

  def toggle_wall(state, x, y) do
    cell = {x, y}

    cond do
      cell == state.start or cell == state.goal -> state
      MapSet.member?(state.walls, cell) -> %{state | walls: MapSet.delete(state.walls, cell)}
      true -> %{state | walls: MapSet.put(state.walls, cell)}
    end
  end

  def clear_walls(state), do: %{state | walls: MapSet.new()} |> reset_search()

  def random_walls(state) do
    walls =
      for y <- 0..(@rows - 1),
          x <- 0..(@cols - 1),
          :rand.uniform() < 0.23,
          {x, y} != state.start,
          {x, y} != state.goal,
          into: MapSet.new() do
        {x, y}
      end

    %{state | walls: walls} |> reset_search()
  end

  def start_search(state), do: %{reset_search(state) | running: true}

  def stop_search(state), do: %{state | running: false}

  def tick(%{running: false} = state), do: state

  def tick(%{found: true} = state), do: %{state | running: false}

  def tick(state) do
    Enum.reduce_while(1..40, state, fn _, acc ->
      step(acc)
      |> case do
        %{running: true} = next -> {:cont, next}
        next -> {:halt, next}
      end
    end)
  end

  def render_background do
    Easel.new(width(), height())
    |> Easel.set_fill_style("#0b1020")
    |> Easel.fill_rect(0, 0, width(), height())
    |> Easel.render()
  end

  def render(state) do
    wall_instances = Enum.map(state.walls, &to_inst(&1, "#334155"))
    visited_instances = Enum.map(state.visited, &to_inst(&1, "rgba(59,130,246,0.35)"))
    frontier_instances = Enum.map(state.frontier, &to_inst(&1, "#f59e0b"))
    path_instances = Enum.map(state.path, &to_inst(&1, "#22c55e"))

    points = [to_inst(state.start, "#22d3ee"), to_inst(state.goal, "#ef4444")]

    Easel.new(width(), height())
    |> Easel.template(:cell, fn c -> c |> Easel.fill_rect(0, 0, @cell - 1, @cell - 1) end)
    |> Easel.instances(:cell, visited_instances)
    |> Easel.instances(:cell, wall_instances)
    |> Easel.instances(:cell, frontier_instances)
    |> Easel.instances(:cell, path_instances)
    |> Easel.instances(:cell, points)
    |> Easel.render()
  end

  defp step(state) do
    case :queue.out(state.queue) do
      {:empty, _} ->
        %{state | running: false}

      {{:value, current}, queue} ->
        if current == state.goal do
          %{state | running: false, found: true, path: build_path(state.came, state.goal)}
        else
          {queue2, visited2, came2, frontier2} =
            neighbors(current)
            |> Enum.reject(fn n -> blocked?(state, n) or MapSet.member?(state.visited, n) end)
            |> Enum.reduce(
              {queue, state.visited, state.came, MapSet.delete(state.frontier, current)},
              fn n, {q, v, c, f} ->
                {:queue.in(n, q), MapSet.put(v, n), Map.put(c, n, current), MapSet.put(f, n)}
              end
            )

          %{state | queue: queue2, visited: visited2, came: came2, frontier: frontier2}
        end
    end
  end

  defp reset_search(state) do
    start = state.start

    %{
      state
      | queue: :queue.in(start, :queue.new()),
        visited: MapSet.new([start]),
        came: %{},
        frontier: MapSet.new([start]),
        path: MapSet.new(),
        found: false,
        running: false
    }
  end

  defp build_path(came, goal) do
    Stream.unfold(goal, fn
      nil -> nil
      node -> {node, Map.get(came, node)}
    end)
    |> MapSet.new()
  end

  defp blocked?(state, {x, y}) do
    x < 0 or x >= @cols or y < 0 or y >= @rows or MapSet.member?(state.walls, {x, y})
  end

  defp neighbors({x, y}), do: [{x + 1, y}, {x - 1, y}, {x, y + 1}, {x, y - 1}]

  defp to_inst({x, y}, fill), do: %{x: x * @cell, y: y * @cell, fill: fill}
end
