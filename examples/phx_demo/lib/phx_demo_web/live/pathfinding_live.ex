defmodule PhxDemoWeb.PathfindingLive do
  use PhxDemoWeb, :live_view

  def mount(_params, _session, socket) do
    state = PhxDemo.Examples.Pathfinding.init()

    socket =
      socket
      |> assign(:state, state)
      |> assign(:background, PhxDemo.Examples.Pathfinding.render_background())
      |> assign(:canvas, PhxDemo.Examples.Pathfinding.render(state))
      |> Easel.LiveView.animate(
        "fg",
        :state,
        fn state ->
          next = PhxDemo.Examples.Pathfinding.tick(state)
          {PhxDemo.Examples.Pathfinding.render(next), next}
        end,
        interval: 33,
        canvas_assign: :canvas
      )

    {:ok, socket}
  end

  def handle_info({:easel_tick, id}, socket), do: {:noreply, Easel.LiveView.tick(socket, id)}

  def handle_event("fg:click", %{"x" => x, "y" => y}, socket) do
    cx = div(round(x), PhxDemo.Examples.Pathfinding.cell())
    cy = div(round(y), PhxDemo.Examples.Pathfinding.cell())
    state = PhxDemo.Examples.Pathfinding.toggle_wall(socket.assigns.state, cx, cy)
    {:noreply, assign(socket, :state, state)}
  end

  def handle_event("start", _, socket),
    do: {:noreply, update(socket, :state, &PhxDemo.Examples.Pathfinding.start_search/1)}

  def handle_event("stop", _, socket),
    do: {:noreply, update(socket, :state, &PhxDemo.Examples.Pathfinding.stop_search/1)}

  def handle_event("clear", _, socket),
    do: {:noreply, update(socket, :state, &PhxDemo.Examples.Pathfinding.clear_walls/1)}

  def handle_event("random", _, socket),
    do: {:noreply, update(socket, :state, &PhxDemo.Examples.Pathfinding.random_walls/1)}

  def handle_event("mode", %{"mode" => mode}, socket) do
    mode =
      case mode do
        "bfs" -> :bfs
        "dfs" -> :dfs
        "astar" -> :astar
        "greedy" -> :greedy
        _ -> :bfs
      end

    {:noreply, update(socket, :state, &PhxDemo.Examples.Pathfinding.set_mode(&1, mode))}
  end

  def render(assigns) do
    ~H"""
    <.demo title="Pathfinding — click to draw walls" code_id="pathfinding">
      <div class="flex flex-wrap gap-2 mb-3">
        <button phx-click="start" class="px-3 py-1 border rounded text-sm">Start</button>
        <button phx-click="stop" class="px-3 py-1 border rounded text-sm">Stop</button>
        <button phx-click="random" class="px-3 py-1 border rounded text-sm">Random walls</button>
        <button phx-click="clear" class="px-3 py-1 border rounded text-sm">Clear</button>

        <button
          phx-click="mode"
          phx-value-mode="bfs"
          class={[
            "px-3 py-1 border rounded text-sm",
            @state.mode == :bfs && "bg-blue-100 border-blue-400"
          ]}
        >
          BFS
        </button>
        <button
          phx-click="mode"
          phx-value-mode="dfs"
          class={[
            "px-3 py-1 border rounded text-sm",
            @state.mode == :dfs && "bg-blue-100 border-blue-400"
          ]}
        >
          DFS
        </button>
        <button
          phx-click="mode"
          phx-value-mode="astar"
          class={[
            "px-3 py-1 border rounded text-sm",
            @state.mode == :astar && "bg-blue-100 border-blue-400"
          ]}
        >
          A*
        </button>
        <button
          phx-click="mode"
          phx-value-mode="greedy"
          class={[
            "px-3 py-1 border rounded text-sm",
            @state.mode == :greedy && "bg-blue-100 border-blue-400"
          ]}
        >
          Greedy
        </button>
      </div>

      <Easel.LiveView.canvas_stack id="path" width={@background.width} height={@background.height}>
        <:layer id="bg" ops={@background.ops} />
        <:layer id="fg" ops={@canvas.ops} templates={@canvas.templates} on_click />
      </Easel.LiveView.canvas_stack>

      <p class="text-sm text-gray-500 mt-2">
        {String.upcase(to_string(@state.mode))} · {MapSet.size(@state.walls)} walls · {MapSet.size(
          @state.visited
        )} visited · {if @state.found,
          do: "path found",
          else: if(@state.running, do: "searching", else: "idle")}
      </p>
    </.demo>
    """
  end
end
