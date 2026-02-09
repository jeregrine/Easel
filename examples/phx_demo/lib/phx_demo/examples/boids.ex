defmodule PhxDemo.Examples.Boids do
  @width 800
  @height 600
  @max_speed 4.0
  @max_force 0.1
  @perception 50.0
  @separation_dist 25.0
  @cell_size trunc(@perception)

  def width, do: @width
  def height, do: @height

  def init(count \\ 100) do
    for _ <- 1..count do
      angle = :rand.uniform() * 2 * :math.pi()
      speed = 2.0 + :rand.uniform() * 2.0

      %{
        x: :rand.uniform(@width) * 1.0,
        y: :rand.uniform(@height) * 1.0,
        vx: :math.cos(angle) * speed,
        vy: :math.sin(angle) * speed
      }
    end
  end

  def tick(boids) do
    grid = build_grid(boids)

    Enum.map(boids, fn boid ->
      boid
      |> apply_rules(grid)
      |> limit_speed()
      |> move()
      |> wrap()
    end)
  end

  defp build_grid(boids) do
    Enum.reduce(boids, %{}, fn boid, grid ->
      key = {trunc(boid.x / @cell_size), trunc(boid.y / @cell_size)}
      Map.update(grid, key, [boid], &[boid | &1])
    end)
  end

  defp neighbors(boid, grid) do
    cx = trunc(boid.x / @cell_size)
    cy = trunc(boid.y / @cell_size)

    for dx <- -1..1, dy <- -1..1, reduce: [] do
      acc -> Map.get(grid, {cx + dx, cy + dy}, []) ++ acc
    end
  end

  defp apply_rules(boid, grid) do
    neighbors = neighbors(boid, grid)

    {sep_x, sep_y, ali_x, ali_y, coh_x, coh_y, count} =
      Enum.reduce(neighbors, {0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0}, fn other,
                                                                   {sx, sy, ax, ay, cx, cy, n} ->
        dx = other.x - boid.x
        dy = other.y - boid.y
        dist_sq = dx * dx + dy * dy

        if dist_sq > 0 and dist_sq < @perception * @perception do
          dist = :math.sqrt(dist_sq)

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
      {avx, avy} = steer(boid, ali_x / count, ali_y / count)
      {cvx, cvy} = steer(boid, coh_x / count - boid.x, coh_y / count - boid.y)
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

  defp limit_vec(x, y, max) do
    mag = :math.sqrt(x * x + y * y)
    if mag > max, do: {x / mag * max, y / mag * max}, else: {x, y}
  end

  defp limit_speed(boid) do
    speed = :math.sqrt(boid.vx * boid.vx + boid.vy * boid.vy)

    if speed > @max_speed do
      %{boid | vx: boid.vx / speed * @max_speed, vy: boid.vy / speed * @max_speed}
    else
      boid
    end
  end

  defp move(boid), do: %{boid | x: boid.x + boid.vx, y: boid.y + boid.vy}

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
      |> Easel.set_fill_style("#0a0a2e")
      |> Easel.fill_rect(0, 0, @width, @height)

    buckets =
      Enum.group_by(boids, fn boid ->
        angle = :math.atan2(boid.vy, boid.vx)
        div(round(angle / :math.pi() * 180 + 180), 10) * 10
      end)

    Enum.reduce(buckets, canvas, fn {hue, group}, acc ->
      acc = Easel.set_fill_style(acc, "hsl(#{hue}, 70%, 60%)")
      acc = Easel.begin_path(acc)

      acc =
        Enum.reduce(group, acc, fn boid, acc2 ->
          angle = :math.atan2(boid.vy, boid.vx)
          size = 6
          x1 = boid.x + :math.cos(angle) * size * 2
          y1 = boid.y + :math.sin(angle) * size * 2
          x2 = boid.x + :math.cos(angle + 2.5) * size
          y2 = boid.y + :math.sin(angle + 2.5) * size
          x3 = boid.x + :math.cos(angle - 2.5) * size
          y3 = boid.y + :math.sin(angle - 2.5) * size

          acc2
          |> Easel.move_to(x1, y1)
          |> Easel.line_to(x2, y2)
          |> Easel.line_to(x3, y3)
          |> Easel.close_path()
        end)

      Easel.fill(acc)
    end)
    |> Easel.render()
  end
end
