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
      mode: :bfs,
      open: :queue.new(),
      visited: MapSet.new(),
      came: %{},
      g: %{},
      frontier: MapSet.new(),
      path: MapSet.new(),
      running: false,
      found: false
    }
    |> reset_search()
  end

  def set_mode(state, mode) when mode in [:bfs, :dfs, :astar, :greedy],
    do: %{state | mode: mode} |> reset_search()

  def toggle_wall(state, x, y) do
    cell = {x, y}

    cond do
      cell == state.start or cell == state.goal -> state
      MapSet.member?(state.walls, cell) -> %{state | walls: MapSet.delete(state.walls, cell)}
      true -> %{state | walls: MapSet.put(state.walls, cell)}
    end
  end

  def clear_walls(state) do
    mode = state[:mode] || :bfs
    %{state | walls: MapSet.new(), mode: mode} |> reset_search()
  end

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

    mode = state[:mode] || :bfs
    %{state | walls: walls, mode: mode} |> reset_search()
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
    case open_pop(state) do
      :empty ->
        %{state | running: false}

      {current, open2} ->
        frontier2 = MapSet.delete(state.frontier, current)

        cond do
          MapSet.member?(state.visited, current) ->
            %{state | open: open2, frontier: frontier2}

          current == state.goal ->
            %{
              state
              | open: open2,
                frontier: frontier2,
                running: false,
                found: true,
                path: build_path(state.came, state.goal)
            }

          true ->
            visited2 = MapSet.put(state.visited, current)
            current_g = Map.get(state.g, current, 0)

            {open3, came3, g3, frontier3} =
              neighbors(current)
              |> Enum.reject(&blocked?(state, &1))
              |> Enum.reduce({open2, state.came, state.g, frontier2}, fn n, {o, c, g, f} ->
                maybe_enqueue(state, n, current, current_g, visited2, o, c, g, f)
              end)

            %{state | open: open3, visited: visited2, came: came3, g: g3, frontier: frontier3}
        end
    end
  end

  defp maybe_enqueue(%{mode: mode}, n, current, current_g, visited, open, came, g, frontier)
       when mode in [:bfs, :dfs] do
    if MapSet.member?(visited, n) or MapSet.member?(frontier, n) do
      {open, came, g, frontier}
    else
      open2 = open_put(mode, open, n, 0)
      {open2, Map.put(came, n, current), Map.put(g, n, current_g + 1), MapSet.put(frontier, n)}
    end
  end

  defp maybe_enqueue(
         %{mode: :astar, goal: goal},
         n,
         current,
         current_g,
         visited,
         open,
         came,
         g,
         frontier
       ) do
    if MapSet.member?(visited, n) do
      {open, came, g, frontier}
    else
      tentative = current_g + 1

      if tentative < Map.get(g, n, 1_000_000) do
        f_score = tentative + heuristic(n, goal)

        {
          open_put(:astar, open, n, f_score),
          Map.put(came, n, current),
          Map.put(g, n, tentative),
          MapSet.put(frontier, n)
        }
      else
        {open, came, g, frontier}
      end
    end
  end

  defp maybe_enqueue(
         %{mode: :greedy, goal: goal},
         n,
         current,
         current_g,
         visited,
         open,
         came,
         g,
         frontier
       ) do
    if MapSet.member?(visited, n) or MapSet.member?(frontier, n) do
      {open, came, g, frontier}
    else
      {
        open_put(:greedy, open, n, heuristic(n, goal)),
        Map.put(came, n, current),
        Map.put(g, n, current_g + 1),
        MapSet.put(frontier, n)
      }
    end
  end

  defp reset_search(state) do
    start = state.start
    mode = state[:mode] || :bfs

    %{
      state
      | mode: mode,
        open: open_put(mode, open_empty(mode), start, 0),
        visited: MapSet.new(),
        came: %{},
        g: %{start => 0},
        frontier: MapSet.new([start]),
        path: MapSet.new(),
        found: false,
        running: false
    }
  end

  defp open_empty(:bfs), do: :queue.new()
  defp open_empty(:dfs), do: []
  defp open_empty(:astar), do: []
  defp open_empty(:greedy), do: []

  defp open_put(:bfs, open, node, _priority), do: :queue.in(node, open)
  defp open_put(:dfs, open, node, _priority), do: [node | open]
  defp open_put(:astar, open, node, priority), do: [{node, priority} | open]
  defp open_put(:greedy, open, node, priority), do: [{node, priority} | open]

  defp open_pop(%{mode: :bfs, open: open}) do
    case :queue.out(open) do
      {:empty, _} -> :empty
      {{:value, node}, open2} -> {node, open2}
    end
  end

  defp open_pop(%{mode: :dfs, open: []}), do: :empty
  defp open_pop(%{mode: :dfs, open: [node | rest]}), do: {node, rest}

  defp open_pop(%{mode: :astar, open: []}), do: :empty

  defp open_pop(%{mode: :astar, open: open}) do
    best = Enum.min_by(open, fn {_node, f} -> f end)
    {elem(best, 0), List.delete(open, best)}
  end

  defp open_pop(%{mode: :greedy, open: []}), do: :empty

  defp open_pop(%{mode: :greedy, open: open}) do
    best = Enum.min_by(open, fn {_node, h} -> h end)
    {elem(best, 0), List.delete(open, best)}
  end

  defp heuristic({x, y}, {gx, gy}), do: abs(x - gx) + abs(y - gy)

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
