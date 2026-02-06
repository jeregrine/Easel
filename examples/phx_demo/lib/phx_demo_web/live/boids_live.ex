defmodule PhxDemoWeb.BoidsLive do
  use PhxDemoWeb, :live_view


  @width PhxDemo.Examples.boids_width()
  @height PhxDemo.Examples.boids_height()

  def mount(_params, _session, socket) do
    boids = PhxDemo.Examples.boids_init()
    canvas = render_boids(boids)

    # Static background — sent once, never changes
    background =
      Easel.new(@width, @height)
      |> Easel.set_fill_style("#0a0a2e")
      |> Easel.fill_rect(0, 0, @width, @height)
      |> Easel.render()

    socket =
      socket
      |> assign(:boids, boids)
      |> assign(:canvas, canvas)
      |> assign(:background, background)
      |> assign(:width, @width)
      |> assign(:height, @height)
      |> Easel.LiveView.animate("fg", :boids, fn boids ->
        new_boids = PhxDemo.Examples.boids_tick(boids)
        canvas = render_boids(new_boids)
        {canvas, new_boids}
      end, interval: 33, canvas_assign: :canvas)

    {:ok, socket}
  end

  def handle_info({:easel_tick, id}, socket) do
    {:noreply, Easel.LiveView.tick(socket, id)}
  end

  def handle_event("fg:click", %{"x" => x, "y" => y}, socket) do
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

  # Render boids using templates + instances.
  # Template defines the boid shape once; instances carry only position/angle/color.
  defp render_boids(boids) do
    instances =
      Enum.map(boids, fn boid ->
        angle = :math.atan2(boid.vy, boid.vx)
        hue = round(angle / :math.pi() * 180 + 180)

        %{x: boid.x, y: boid.y, rotate: angle, fill: "hsl(#{hue}, 70%, 60%)"}
      end)

    Easel.new(@width, @height)
    |> Easel.template(:boid, fn c ->
      c
      |> Easel.begin_path()
      |> Easel.move_to(12, 0)
      |> Easel.line_to(-4, -5)
      |> Easel.line_to(-4, 5)
      |> Easel.close_path()
      |> Easel.fill()
    end)
    |> Easel.instances(:boid, instances)
    |> Easel.render()
  end

  def render(assigns) do
    ~H"""
    <.demo title="Boids — click to add">
      <Easel.LiveView.canvas_stack id="boids" width={@width} height={@height}>
        <:layer id="bg" ops={@background.ops} />
        <:layer id="fg" ops={@canvas.ops} templates={@canvas.templates} on_click />
      </Easel.LiveView.canvas_stack>
      <p class="text-sm text-gray-500 mt-2">
        <%= length(@boids) %> boids
      </p>
    </.demo>
    """
  end
end
