defmodule PhxDemoWeb.BoidsLive do
  use PhxDemoWeb, :live_view

  def mount(_params, _session, socket) do
    boids = PhxDemo.Examples.boids_init()
    canvas = PhxDemo.Examples.boids_render(boids)

    socket =
      socket
      |> assign(:boids, boids)
      |> assign(:canvas, canvas)
      |> Easel.LiveView.animate("boids", :boids, fn boids ->
        new_boids = PhxDemo.Examples.boids_tick(boids)
        canvas = PhxDemo.Examples.boids_render(new_boids)
        {canvas, new_boids}
      end, interval: 33, canvas_assign: :canvas)

    {:ok, socket}
  end

  def handle_info({:easel_tick, id}, socket) do
    {:noreply, Easel.LiveView.tick(socket, id)}
  end

  def handle_event("boids:click", %{"x" => x, "y" => y}, socket) do
    new_boids =
      for _ <- 1..10 do
        angle = :rand.uniform() * 2 * :math.pi()
        speed = 2.0 + :rand.uniform() * 2.0

        %{
          x: x * 1.0,
          y: y * 1.0,
          vx: :math.cos(angle) * speed,
          vy: :math.sin(angle) * speed
        }
      end

    {:noreply, assign(socket, :boids, new_boids ++ socket.assigns.boids)}
  end

  def render(assigns) do
    ~H"""
    <.demo title="Boids — click to add">
      <Easel.LiveView.canvas
        id="boids"
        width={PhxDemo.Examples.boids_width()}
        height={PhxDemo.Examples.boids_height()}
        ops={@canvas.ops}
        on_click
      />
      <p class="text-sm text-gray-500 mt-2">
        <%= length(@boids) %> boids
      </p>
    </.demo>
    """
  end
end
