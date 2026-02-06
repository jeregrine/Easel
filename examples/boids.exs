# Boids flocking simulation
# Run: mix run examples/boids.exs
#
# Uses Easel.WX.animate/5 to run at ~60fps in a native window.
# Requires Erlang compiled with wx support.
#
# Rules:
#   1. Separation — steer away from nearby boids
#   2. Alignment  — steer toward average heading of nearby boids
#   3. Cohesion   — steer toward average position of nearby boids

alias Easel.API

defmodule Boids do
  @width 800
  @height 600
  @num_boids 100
  @max_speed 4.0
  @max_force 0.1
  @perception 50.0
  @separation_dist 25.0

  defstruct [:x, :y, :vx, :vy]

  def width, do: @width
  def height, do: @height

  def init do
    for _ <- 1..@num_boids do
      angle = :rand.uniform() * 2 * :math.pi()
      speed = 2.0 + :rand.uniform() * 2.0

      %Boids{
        x: :rand.uniform(@width) * 1.0,
        y: :rand.uniform(@height) * 1.0,
        vx: :math.cos(angle) * speed,
        vy: :math.sin(angle) * speed
      }
    end
  end

  def tick(boids) do
    Enum.map(boids, fn boid ->
      boid
      |> apply_rules(boids)
      |> limit_speed()
      |> move()
      |> wrap()
    end)
  end

  defp apply_rules(boid, boids) do
    {sep_x, sep_y, ali_x, ali_y, coh_x, coh_y, count} =
      Enum.reduce(boids, {0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0}, fn other,
                                                               {sx, sy, ax, ay, cx, cy, n} ->
        dx = other.x - boid.x
        dy = other.y - boid.y
        dist = :math.sqrt(dx * dx + dy * dy)

        if dist > 0 and dist < @perception do
          # Separation
          {sx2, sy2} =
            if dist < @separation_dist do
              {sx - dx / dist, sy - dy / dist}
            else
              {sx, sy}
            end

          {sx2, sy2, ax + other.vx, ay + other.vy, cx + other.x, cy + other.y, n + 1}
        else
          {sx, sy, ax, ay, cx, cy, n}
        end
      end)

    if count > 0 do
      # Alignment — steer toward average velocity
      {avx, avy} = steer(boid, ali_x / count, ali_y / count)
      # Cohesion — steer toward average position
      {cvx, cvy} = steer_to(boid, coh_x / count, coh_y / count)
      # Separation
      {svx, svy} = {sep_x * @max_force * 1.5, sep_y * @max_force * 1.5}

      %{boid | vx: boid.vx + svx + avx + cvx, vy: boid.vy + svy + avy + cvy}
    else
      boid
    end
  end

  defp steer(boid, target_vx, target_vy) do
    mag = :math.sqrt(target_vx * target_vx + target_vy * target_vy)

    if mag > 0 do
      dvx = target_vx / mag * @max_speed - boid.vx
      dvy = target_vy / mag * @max_speed - boid.vy
      limit_vec(dvx, dvy, @max_force)
    else
      {0.0, 0.0}
    end
  end

  defp steer_to(boid, tx, ty) do
    steer(boid, tx - boid.x, ty - boid.y)
  end

  defp limit_vec(x, y, max) do
    mag = :math.sqrt(x * x + y * y)

    if mag > max do
      {x / mag * max, y / mag * max}
    else
      {x, y}
    end
  end

  defp limit_speed(boid) do
    speed = :math.sqrt(boid.vx * boid.vx + boid.vy * boid.vy)

    if speed > @max_speed do
      %{boid | vx: boid.vx / speed * @max_speed, vy: boid.vy / speed * @max_speed}
    else
      boid
    end
  end

  defp move(boid) do
    %{boid | x: boid.x + boid.vx, y: boid.y + boid.vy}
  end

  defp wrap(boid) do
    %{boid | x: wrap_val(boid.x, @width), y: wrap_val(boid.y, @height)}
  end

  defp wrap_val(v, max) do
    cond do
      v < 0 -> v + max
      v > max -> v - max
      true -> v
    end
  end

  def render(boids) do
    canvas =
      Easel.new(@width, @height)
      |> API.set_fill_style("#0a0a2e")
      |> API.fill_rect(0, 0, @width, @height)

    Enum.reduce(boids, canvas, fn boid, acc ->
      angle = :math.atan2(boid.vy, boid.vx)
      size = 6

      # Triangle pointing in direction of travel
      x1 = boid.x + :math.cos(angle) * size * 2
      y1 = boid.y + :math.sin(angle) * size * 2
      x2 = boid.x + :math.cos(angle + 2.5) * size
      y2 = boid.y + :math.sin(angle + 2.5) * size
      x3 = boid.x + :math.cos(angle - 2.5) * size
      y3 = boid.y + :math.sin(angle - 2.5) * size

      # Color based on heading
      hue = round(angle / :math.pi() * 180 + 180)

      acc
      |> API.begin_path()
      |> API.move_to(x1, y1)
      |> API.line_to(x2, y2)
      |> API.line_to(x3, y3)
      |> API.close_path()
      |> API.set_fill_style("hsl(#{hue}, 70%, 60%)")
      |> API.fill()
    end)
  end
end

:rand.seed(:exsss, {42, 42, 42})
boids = Boids.init()

# If wx is available, run the animation in a native window.
# Click to add a burst of new boids at the cursor position.
# Otherwise, just simulate a few frames and print stats.
if Code.ensure_loaded?(Easel.WX) and Easel.WX.available?() do
  Easel.WX.animate(
    Boids.width(),
    Boids.height(),
    boids,
    fn boids ->
      new_boids = Boids.tick(boids)
      canvas = Boids.render(new_boids)
      {canvas, new_boids}
    end,
    title: "Boids — click to add",
    interval: 16,
    on_click: fn x, y, boids ->
      # Spawn 10 new boids at click position
      new =
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

      new ++ boids
    end
  )
else
  IO.puts("wx not available — simulating 60 frames...")

  Enum.reduce(1..60, boids, fn frame, boids ->
    new_boids = Boids.tick(boids)
    canvas = Boids.render(new_boids) |> Easel.render()

    if rem(frame, 10) == 0 do
      IO.puts("Frame #{frame}: #{length(canvas.ops)} ops")
    end

    new_boids
  end)

  IO.puts("Done. Pipe to Easel.WX.animate/5 when wx is available.")
end
