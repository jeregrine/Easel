defmodule PhxDemoWeb.BoidsLive do
  use PhxDemoWeb, :live_view

  @width PhxDemo.Examples.boids_width()
  @height PhxDemo.Examples.boids_height()
  @max_boids 1000
  @frame_ms 16
  @bucket_colors 0..35 |> Enum.map(&"hsl(#{&1 * 10}, 70%, 60%)") |> List.to_tuple()

  def mount(_params, _session, socket) do
    boids = PhxDemo.Examples.boids_init()
    canvas = render_boids(boids)

    background =
      Easel.new(@width, @height)
      |> Easel.set_fill_style("#0a0a2e")
      |> Easel.fill_rect(0, 0, @width, @height)
      |> Easel.render()

    templates =
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
      |> then(& &1.templates)

    now = System.monotonic_time(:millisecond)

    socket =
      socket
      |> assign(:boids, boids)
      |> assign(:canvas, canvas)
      |> assign(:templates, templates)
      |> assign(:background, background)
      |> assign(:width, @width)
      |> assign(:height, @height)
      |> assign(:max_boids, @max_boids)
      |> assign(:boid_count, length(boids))
      |> assign(:fps, 0)
      |> assign(:avg_tick_ms, 0.0)
      |> assign(:fps_frames, 0)
      |> assign(:fps_tick_acc_ms, 0.0)
      |> assign(:fps_window_start, now)
      |> Easel.LiveView.animate(
        "fg",
        :boids,
        fn boids ->
          {Easel.new(), PhxDemo.Examples.boids_tick(boids)}
        end,
        interval: @frame_ms
      )

    {:ok, socket}
  end

  def handle_info({:easel_tick, id}, socket) do
    t0 = System.monotonic_time(:microsecond)

    socket = Easel.LiveView.tick(socket, id)
    boids = socket.assigns.boids
    canvas = render_boids(boids)

    t1 = System.monotonic_time(:microsecond)
    tick_ms = (t1 - t0) / 1000.0

    socket =
      socket
      |> Easel.LiveView.draw("fg", canvas, clear: true)
      |> update_fps_stats(tick_ms, length(boids))

    {:noreply, socket}
  end

  def handle_event("fg:click", %{"x" => x, "y" => y}, socket) do
    current = socket.assigns.boids

    if length(current) >= @max_boids do
      {:noreply, socket}
    else
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

      boids = Enum.take(new_boids ++ current, @max_boids)

      {:noreply,
       socket
       |> assign(:boids, boids)
       |> assign(:boid_count, length(boids))}
    end
  end

  defp render_boids(boids) do
    instances =
      Enum.map(boids, fn boid ->
        angle = :math.atan2(boid.vy, boid.vx)
        bucket = rem(div(round(angle / :math.pi() * 180 + 180), 10), 36)

        %{x: boid.x, y: boid.y, rotate: angle, fill: elem(@bucket_colors, bucket)}
      end)

    Easel.new(@width, @height)
    |> Easel.instances(:boid, instances)
    |> Easel.render()
  end

  defp update_fps_stats(socket, tick_ms, boid_count) do
    now = System.monotonic_time(:millisecond)
    frames = socket.assigns.fps_frames + 1
    tick_acc_ms = socket.assigns.fps_tick_acc_ms + tick_ms
    window_start = socket.assigns.fps_window_start
    elapsed = now - window_start

    if elapsed >= 1000 do
      fps = round(frames * 1000 / elapsed)
      avg_tick_ms = tick_acc_ms / frames

      socket
      |> assign(:fps, fps)
      |> assign(:avg_tick_ms, avg_tick_ms)
      |> assign(:boid_count, boid_count)
      |> assign(:fps_frames, 0)
      |> assign(:fps_tick_acc_ms, 0.0)
      |> assign(:fps_window_start, now)
    else
      socket
      |> assign(:fps_frames, frames)
      |> assign(:fps_tick_acc_ms, tick_acc_ms)
    end
  end

  def render(assigns) do
    ~H"""
    <.demo title="Boids — click to add">
      <Easel.LiveView.canvas_stack id="boids" width={@width} height={@height}>
        <:layer id="bg" ops={@background.ops} />
        <:layer id="fg" ops={@canvas.ops} templates={@templates} on_click />
      </Easel.LiveView.canvas_stack>
      <p class="text-sm text-gray-500 mt-2">
        {@boid_count} / {@max_boids} boids · {@fps} FPS · {Float.round(@avg_tick_ms, 2)}ms tick
      </p>
    </.demo>
    """
  end
end
