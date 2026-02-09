defmodule PhxDemoWeb.LifeLive do
  use PhxDemoWeb, :live_view

  @interval 80

  def mount(_params, _session, socket) do
    life = PhxDemo.Examples.life_init() |> Map.put(:running, true)

    socket =
      socket
      |> assign(:life, life)
      |> assign(:canvas, PhxDemo.Examples.life_render(life))
      |> assign(:background, PhxDemo.Examples.life_render_background())
      |> assign(:cell, PhxDemo.Examples.life_cell())
      |> Easel.LiveView.animate(
        "fg",
        :life,
        fn life ->
          next = if life.running, do: PhxDemo.Examples.life_tick(life), else: life
          {PhxDemo.Examples.life_render(next), next}
        end, interval: @interval, canvas_assign: :canvas)

    {:ok, socket}
  end

  def handle_info({:easel_tick, id}, socket) do
    {:noreply, Easel.LiveView.tick(socket, id)}
  end

  def handle_event("fg:click", %{"x" => x, "y" => y}, socket) do
    cx = div(round(x), socket.assigns.cell)
    cy = div(round(y), socket.assigns.cell)
    life = PhxDemo.Examples.life_toggle(socket.assigns.life, cx, cy)

    {:noreply,
     socket
     |> assign(:life, life)
     |> assign(:canvas, PhxDemo.Examples.life_render(life))}
  end

  def handle_event("toggle", _, socket) do
    {:noreply, update(socket, :life, &Map.update!(&1, :running, fn r -> !r end))}
  end

  def handle_event("randomize", _, socket) do
    running = socket.assigns.life.running
    life = PhxDemo.Examples.life_init() |> Map.put(:running, running)

    {:noreply,
     socket |> assign(:life, life) |> assign(:canvas, PhxDemo.Examples.life_render(life))}
  end

  def handle_event("clear", _, socket) do
    life = %{socket.assigns.life | alive: MapSet.new()}

    {:noreply,
     socket |> assign(:life, life) |> assign(:canvas, PhxDemo.Examples.life_render(life))}
  end

  def render(assigns) do
    ~H"""
    <.demo title="Game of Life">
      <div class="flex gap-2 mb-3">
        <button phx-click="toggle" class="px-3 py-1 border rounded text-sm">
          {if @life.running, do: "Pause", else: "Run"}
        </button>
        <button phx-click="randomize" class="px-3 py-1 border rounded text-sm">Randomize</button>
        <button phx-click="clear" class="px-3 py-1 border rounded text-sm">Clear</button>
      </div>

      <Easel.LiveView.canvas_stack id="life" width={@background.width} height={@background.height}>
        <:layer id="bg" ops={@background.ops} />
        <:layer id="fg" ops={@canvas.ops} templates={@canvas.templates} on_click />
      </Easel.LiveView.canvas_stack>

      <p class="text-sm text-gray-500 mt-2">
        {MapSet.size(@life.alive)} live cells · {if @life.running, do: "running", else: "paused"}
      </p>
    </.demo>
    """
  end
end
