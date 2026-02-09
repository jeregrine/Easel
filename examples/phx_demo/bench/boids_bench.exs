Mix.Task.run("app.start")

render_templates = fn boids ->
  instances =
    Enum.map(boids, fn boid ->
      angle = :math.atan2(boid.vy, boid.vx)
      hue = round(angle / :math.pi() * 180 + 180)

      %{x: boid.x, y: boid.y, rotate: angle, fill: "hsl(#{hue}, 70%, 60%)"}
    end)

  Easel.new(PhxDemo.Examples.boids_width(), PhxDemo.Examples.boids_height())
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

inputs = %{
  "100 boids" => PhxDemo.Examples.boids_init(100),
  "500 boids" => PhxDemo.Examples.boids_init(500),
  "1000 boids" => PhxDemo.Examples.boids_init(1000)
}

Benchee.run(
  %{
    "tick" => fn boids ->
      PhxDemo.Examples.boids_tick(boids)
    end,
    "render bucketed ops" => fn boids ->
      PhxDemo.Examples.boids_render(boids)
    end,
    "render templates+instances" => fn boids ->
      render_templates.(boids)
    end
  },
  inputs: inputs,
  memory_time: 1,
  time: 3,
  warmup: 1,
  formatters: [Benchee.Formatters.Console]
)
