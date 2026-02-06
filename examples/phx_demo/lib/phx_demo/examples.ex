defmodule PhxDemo.Examples do
  @moduledoc """
  Drawing functions for each Easel example, returning rendered canvases.
  """
  alias Easel.API

  # ── Smiley ──────────────────────────────────────────────────────

  def smiley do
    Easel.new(300, 300)
    |> API.begin_path()
    |> API.arc(150, 150, 100, 0, :math.pi() * 2)
    |> API.set_fill_style("#FFD700")
    |> API.fill()
    |> API.set_stroke_style("#333")
    |> API.set_line_width(3)
    |> API.stroke()
    |> API.begin_path()
    |> API.arc(115, 120, 15, 0, :math.pi() * 2)
    |> API.set_fill_style("#333")
    |> API.fill()
    |> API.begin_path()
    |> API.arc(185, 120, 15, 0, :math.pi() * 2)
    |> API.fill()
    |> API.begin_path()
    |> API.arc(150, 155, 60, 0.2, :math.pi() - 0.2)
    |> API.set_stroke_style("#333")
    |> API.set_line_width(4)
    |> API.set_line_cap("round")
    |> API.stroke()
    |> Easel.render()
  end

  # ── Chart ───────────────────────────────────────────────────────

  def chart do
    width = 600
    height = 400
    padding = 60

    data = [
      {"2018", 45}, {"2019", 62}, {"2020", 78}, {"2021", 95},
      {"2022", 120}, {"2023", 155}, {"2024", 190}, {"2025", 230}
    ]

    max_val = data |> Enum.map(&elem(&1, 1)) |> Enum.max()
    bar_count = length(data)
    chart_w = width - padding * 2
    chart_h = height - padding * 2
    bar_w = chart_w / bar_count * 0.7
    gap = chart_w / bar_count * 0.3
    colors = ["#6366f1", "#8b5cf6", "#a78bfa", "#c084fc", "#d946ef", "#ec4899", "#f43f5e", "#ef4444"]

    canvas =
      Easel.new(width, height)
      |> API.set_fill_style("#fafafa")
      |> API.fill_rect(0, 0, width, height)
      |> API.set_fill_style("#1f2937")
      |> API.set_font("bold 18px sans-serif")
      |> API.set_text_align("center")
      |> API.fill_text("Elixir Popularity Index", width / 2, 30)
      |> API.set_stroke_style("#9ca3af")
      |> API.set_line_width(1)
      |> API.begin_path()
      |> API.move_to(padding, padding)
      |> API.line_to(padding, height - padding)
      |> API.line_to(width - padding, height - padding)
      |> API.stroke()

    canvas =
      Enum.reduce(0..4, canvas, fn i, acc ->
        y = padding + chart_h * (1 - i / 4)
        val = round(max_val * i / 4)

        acc
        |> API.set_stroke_style("#e5e7eb")
        |> API.set_line_width(0.5)
        |> API.begin_path()
        |> API.move_to(padding, y)
        |> API.line_to(width - padding, y)
        |> API.stroke()
        |> API.set_fill_style("#6b7280")
        |> API.set_font("12px sans-serif")
        |> API.set_text_align("right")
        |> API.fill_text("#{val}", padding - 8, y + 4)
      end)

    data
    |> Enum.with_index()
    |> Enum.reduce(canvas, fn {{label, value}, i}, acc ->
      x = padding + i * (bar_w + gap) + gap / 2
      bar_h = value / max_val * chart_h
      y = height - padding - bar_h
      color = Enum.at(colors, i)

      acc
      |> API.set_fill_style(color)
      |> API.fill_rect(x, y, bar_w, bar_h)
      |> API.set_stroke_style("rgba(0,0,0,0.1)")
      |> API.set_line_width(1)
      |> API.stroke_rect(x, y, bar_w, bar_h)
      |> API.set_fill_style("#374151")
      |> API.set_font("bold 12px sans-serif")
      |> API.set_text_align("center")
      |> API.fill_text("#{value}", x + bar_w / 2, y - 8)
      |> API.set_fill_style("#6b7280")
      |> API.set_font("12px sans-serif")
      |> API.fill_text(label, x + bar_w / 2, height - padding + 20)
    end)
    |> Easel.render()
  end

  # ── Starfield ───────────────────────────────────────────────────

  def starfield do
    :rand.seed(:exsss, {100, 200, 300})
    width = 600
    height = 400

    canvas =
      Easel.new(width, height)
      |> API.set_fill_style("#0a0a2e")
      |> API.fill_rect(0, 0, width, height)

    canvas =
      Enum.reduce(1..200, canvas, fn _, acc ->
        x = :rand.uniform(width)
        y = :rand.uniform(height)
        radius = :rand.uniform() * 2.5 + 0.5
        brightness = :rand.uniform(155) + 100
        color = "rgba(#{brightness}, #{brightness}, #{min(255, brightness + 50)}, #{Float.round(:rand.uniform(), 2)})"

        acc
        |> API.begin_path()
        |> API.arc(x, y, radius, 0, :math.pi() * 2)
        |> API.set_fill_style(color)
        |> API.fill()
      end)

    Enum.reduce(1..8, canvas, fn _, acc ->
      x = :rand.uniform(width)
      y = :rand.uniform(height)

      acc
      |> API.save()
      |> API.set_global_alpha(0.3)
      |> API.begin_path()
      |> API.arc(x, y, 8, 0, :math.pi() * 2)
      |> API.set_fill_style("rgba(200, 200, 255, 0.3)")
      |> API.fill()
      |> API.set_global_alpha(1.0)
      |> API.begin_path()
      |> API.arc(x, y, 2, 0, :math.pi() * 2)
      |> API.set_fill_style("white")
      |> API.fill()
      |> API.restore()
    end)
    |> Easel.render()
  end

  # ── Spiral ──────────────────────────────────────────────────────

  def spiral do
    width = 500
    height = 500
    cx = width / 2
    cy = height / 2
    turns = 8
    points = turns * 100

    canvas =
      Easel.new(width, height)
      |> API.set_fill_style("#111")
      |> API.fill_rect(0, 0, width, height)
      |> API.set_line_width(2)
      |> API.set_line_cap("round")

    Enum.reduce(0..points, canvas, fn i, acc ->
      t = i / points
      angle = t * turns * 2 * :math.pi()
      radius = t * 200
      x = cx + radius * :math.cos(angle)
      y = cy + radius * :math.sin(angle)
      hue = rem(round(t * 360 * 3), 360)
      color = "hsl(#{hue}, 80%, 60%)"

      if i == 0 do
        acc |> API.begin_path() |> API.move_to(x, y)
      else
        acc
        |> API.set_stroke_style(color)
        |> API.begin_path()
        |> API.move_to(
          cx + (t - 1 / points) * 200 * :math.cos(angle - turns * 2 * :math.pi() / points),
          cy + (t - 1 / points) * 200 * :math.sin(angle - turns * 2 * :math.pi() / points)
        )
        |> API.line_to(x, y)
        |> API.stroke()
      end
    end)
    |> Easel.render()
  end

  # ── Tree ────────────────────────────────────────────────────────

  def tree do
    :rand.seed(:exsss, {42, 42, 42})
    width = 600
    height = 500

    canvas =
      Easel.new(width, height)
      |> API.set_fill_style("#87CEEB")
      |> API.fill_rect(0, 0, width, height)
      |> API.set_fill_style("#3d5a1e")
      |> API.fill_rect(0, height - 40, width, 40)

    draw_tree(canvas, width / 2, height - 40, 100, -:math.pi() / 2, 0, 10)
    |> Easel.render()
  end

  defp draw_tree(canvas, _x, _y, _length, _angle, depth, max) when depth >= max, do: canvas

  defp draw_tree(canvas, x, y, length, angle, depth, max_depth) do
    end_x = x + length * :math.cos(angle)
    end_y = y + length * :math.sin(angle)

    t = depth / max_depth
    r = round(80 * (1 - t) + 34 * t)
    g = round(50 * (1 - t) + 139 * t)
    b = round(20 * (1 - t) + 34 * t)
    line_w = max(1, (max_depth - depth) * 1.5)

    canvas =
      canvas
      |> API.begin_path()
      |> API.move_to(x, y)
      |> API.line_to(end_x, end_y)
      |> API.set_stroke_style("rgb(#{r}, #{g}, #{b})")
      |> API.set_line_width(line_w)
      |> API.set_line_cap("round")
      |> API.stroke()

    canvas =
      if depth >= max_depth - 2 do
        size = 3 + :rand.uniform(4)

        canvas
        |> API.begin_path()
        |> API.arc(end_x, end_y, size, 0, :math.pi() * 2)
        |> API.set_fill_style("rgba(34, #{100 + :rand.uniform(100)}, 34, 0.6)")
        |> API.fill()
      else
        canvas
      end

    new_length = length * (0.65 + :rand.uniform() * 0.1)
    spread = 0.4 + :rand.uniform() * 0.2

    canvas
    |> draw_tree(end_x, end_y, new_length, angle - spread, depth + 1, max_depth)
    |> draw_tree(end_x, end_y, new_length, angle + spread, depth + 1, max_depth)
  end

  # ── Mondrian ────────────────────────────────────────────────────

  def mondrian do
    :rand.seed(:exsss, {123, 456, 789})
    width = 500
    height = 500

    canvas =
      Easel.new(width, height)
      |> API.set_fill_style("#ecf0f1")
      |> API.fill_rect(0, 0, width, height)

    mondrian_split(canvas, 0, 0, width, height, 0)
    |> Easel.render()
  end

  @mondrian_colors ["#c0392b", "#2980b9", "#f1c40f", "#ecf0f1", "#ecf0f1", "#ecf0f1"]
  @line_width 6

  defp mondrian_split(canvas, x, y, w, h, depth) when depth > 5 or w < 40 or h < 40 do
    color = Enum.random(@mondrian_colors)

    canvas
    |> API.set_fill_style(color)
    |> API.fill_rect(x + @line_width / 2, y + @line_width / 2, w - @line_width, h - @line_width)
    |> API.set_stroke_style("#2c3e50")
    |> API.set_line_width(@line_width)
    |> API.stroke_rect(x, y, w, h)
  end

  defp mondrian_split(canvas, x, y, w, h, depth) do
    if :rand.uniform() < 0.5 do
      split = round(w * (0.3 + :rand.uniform() * 0.4))
      canvas
      |> mondrian_split(x, y, split, h, depth + 1)
      |> mondrian_split(x + split, y, w - split, h, depth + 1)
    else
      split = round(h * (0.3 + :rand.uniform() * 0.4))
      canvas
      |> mondrian_split(x, y, w, split, depth + 1)
      |> mondrian_split(x, y + split, w, h - split, depth + 1)
    end
  end

  # ── Sierpinski ──────────────────────────────────────────────────

  def sierpinski do
    width = 600
    height = 520
    depth = 8
    padding = 20
    side = width - padding * 2
    h = side * :math.sqrt(3) / 2

    canvas =
      Easel.new(width, height)
      |> API.set_fill_style("#0d1117")
      |> API.fill_rect(0, 0, width, height)
      |> API.set_fill_style("#58a6ff")

    sierpinski_tri(canvas, width / 2, padding, padding, padding + h, width - padding, padding + h, depth)
    |> Easel.render()
  end

  defp sierpinski_tri(canvas, _ax, _ay, _bx, _by, _cx, _cy, depth) when depth <= 0, do: canvas

  defp sierpinski_tri(canvas, ax, ay, bx, by, cx, cy, 1) do
    canvas
    |> API.begin_path()
    |> API.move_to(ax, ay)
    |> API.line_to(bx, by)
    |> API.line_to(cx, cy)
    |> API.close_path()
    |> API.fill()
  end

  defp sierpinski_tri(canvas, ax, ay, bx, by, cx, cy, depth) do
    mab_x = (ax + bx) / 2
    mab_y = (ay + by) / 2
    mbc_x = (bx + cx) / 2
    mbc_y = (by + cy) / 2
    mac_x = (ax + cx) / 2
    mac_y = (ay + cy) / 2

    canvas
    |> sierpinski_tri(ax, ay, mab_x, mab_y, mac_x, mac_y, depth - 1)
    |> sierpinski_tri(mab_x, mab_y, bx, by, mbc_x, mbc_y, depth - 1)
    |> sierpinski_tri(mac_x, mac_y, mbc_x, mbc_y, cx, cy, depth - 1)
  end

  # ── Mandelbrot ──────────────────────────────────────────────────

  def mandelbrot do
    width = 200
    height = 200
    max_iter = 50
    x_min = -2.0
    x_max = 0.7
    y_min = -1.35
    y_max = 1.35

    canvas = Easel.new(width, height)

    Enum.reduce(0..(height - 1), canvas, fn py, acc ->
      ci = y_min + py / height * (y_max - y_min)

      Enum.reduce(0..(width - 1), acc, fn px, acc2 ->
        cr = x_min + px / width * (x_max - x_min)
        n = mandelbrot_iterate(0.0, 0.0, cr, ci, 0, max_iter)
        color = mandelbrot_color(n, max_iter)

        acc2
        |> API.set_fill_style(color)
        |> API.fill_rect(px, py, 1, 1)
      end)
    end)
    |> Easel.render()
  end

  defp mandelbrot_iterate(_zr, _zi, _cr, _ci, n, max) when n >= max, do: max

  defp mandelbrot_iterate(zr, zi, cr, ci, n, max) do
    zr2 = zr * zr
    zi2 = zi * zi

    if zr2 + zi2 > 4.0 do
      n
    else
      mandelbrot_iterate(zr2 - zi2 + cr, 2.0 * zr * zi + ci, cr, ci, n + 1, max)
    end
  end

  defp mandelbrot_color(n, max) when n >= max, do: "#000000"

  defp mandelbrot_color(n, max) do
    t = n / max
    r = round(9 * (1 - t) * t * t * t * 255)
    g = round(15 * (1 - t) * (1 - t) * t * t * 255)
    b = round(8.5 * (1 - t) * (1 - t) * (1 - t) * t * 255)
    "rgb(#{min(r, 255)}, #{min(g, 255)}, #{min(b, 255)})"
  end

  # ── Clock ───────────────────────────────────────────────────────

  def clock do
    clock(Time.utc_now())
  end

  def clock(%Time{} = now) do
    size = 400
    cx = size / 2
    cy = size / 2
    radius = 170
    hours = rem(now.hour, 12)
    minutes = now.minute
    seconds = now.second

    Easel.new(size, size)
    |> clock_face(cx, cy, radius)
    |> clock_markers(cx, cy, radius)
    |> clock_numbers(cx, cy, radius)
    |> clock_hands(cx, cy, radius, hours, minutes, seconds)
    |> clock_center(cx, cy, hours, minutes, seconds)
    |> Easel.render()
  end

  defp clock_face(canvas, cx, cy, radius) do
    canvas
    |> API.set_fill_style("#1a1a2e")
    |> API.fill_rect(0, 0, cx * 2, cy * 2)
    |> API.begin_path()
    |> API.arc(cx, cy, radius, 0, :math.pi() * 2)
    |> API.set_fill_style("#16213e")
    |> API.fill()
    |> API.set_stroke_style("#e94560")
    |> API.set_line_width(4)
    |> API.stroke()
    |> API.begin_path()
    |> API.arc(cx, cy, radius - 10, 0, :math.pi() * 2)
    |> API.set_stroke_style("rgba(233, 69, 96, 0.3)")
    |> API.set_line_width(1)
    |> API.stroke()
  end

  defp clock_markers(canvas, cx, cy, radius) do
    Enum.reduce(1..12, canvas, fn i, acc ->
      angle = i * :math.pi() / 6 - :math.pi() / 2
      is_quarter = rem(i, 3) == 0
      inner_r = if is_quarter, do: radius - 30, else: radius - 20
      outer_r = radius - 12
      width = if is_quarter, do: 3, else: 1.5

      acc
      |> API.begin_path()
      |> API.move_to(cx + inner_r * :math.cos(angle), cy + inner_r * :math.sin(angle))
      |> API.line_to(cx + outer_r * :math.cos(angle), cy + outer_r * :math.sin(angle))
      |> API.set_stroke_style(if(is_quarter, do: "#e94560", else: "#a0a0b0"))
      |> API.set_line_width(width)
      |> API.set_line_cap("round")
      |> API.stroke()
    end)
  end

  defp clock_numbers(canvas, cx, cy, radius) do
    Enum.reduce(1..12, canvas, fn i, acc ->
      angle = i * :math.pi() / 6 - :math.pi() / 2
      text_r = radius - 45

      acc
      |> API.set_fill_style("#e0e0e0")
      |> API.set_font("bold 20px sans-serif")
      |> API.set_text_align("center")
      |> API.set_text_baseline("middle")
      |> API.fill_text("#{i}", cx + text_r * :math.cos(angle), cy + text_r * :math.sin(angle))
    end)
  end

  defp clock_hands(canvas, cx, cy, _radius, hours, minutes, seconds) do
    hour_angle = (hours + minutes / 60) * :math.pi() / 6 - :math.pi() / 2
    minute_angle = (minutes + seconds / 60) * :math.pi() / 30 - :math.pi() / 2
    second_angle = seconds * :math.pi() / 30 - :math.pi() / 2

    canvas
    # Hour
    |> API.begin_path()
    |> API.move_to(cx - 15 * :math.cos(hour_angle), cy - 15 * :math.sin(hour_angle))
    |> API.line_to(cx + 95 * :math.cos(hour_angle), cy + 95 * :math.sin(hour_angle))
    |> API.set_stroke_style("#e0e0e0")
    |> API.set_line_width(6)
    |> API.set_line_cap("round")
    |> API.stroke()
    # Minute
    |> API.begin_path()
    |> API.move_to(cx - 20 * :math.cos(minute_angle), cy - 20 * :math.sin(minute_angle))
    |> API.line_to(cx + 130 * :math.cos(minute_angle), cy + 130 * :math.sin(minute_angle))
    |> API.set_stroke_style("#e0e0e0")
    |> API.set_line_width(3)
    |> API.set_line_cap("round")
    |> API.stroke()
    # Second
    |> API.begin_path()
    |> API.move_to(cx - 25 * :math.cos(second_angle), cy - 25 * :math.sin(second_angle))
    |> API.line_to(cx + 140 * :math.cos(second_angle), cy + 140 * :math.sin(second_angle))
    |> API.set_stroke_style("#e94560")
    |> API.set_line_width(1.5)
    |> API.set_line_cap("round")
    |> API.stroke()
  end

  defp clock_center(canvas, cx, cy, hours, minutes, seconds) do
    canvas
    |> API.begin_path()
    |> API.arc(cx, cy, 6, 0, :math.pi() * 2)
    |> API.set_fill_style("#e94560")
    |> API.fill()
    |> API.begin_path()
    |> API.arc(cx, cy, 3, 0, :math.pi() * 2)
    |> API.set_fill_style("#1a1a2e")
    |> API.fill()
    |> API.set_fill_style("rgba(233, 69, 96, 0.8)")
    |> API.set_font("14px monospace")
    |> API.set_text_align("center")
    |> API.fill_text(
      "#{String.pad_leading("#{hours}", 2, "0")}:#{String.pad_leading("#{minutes}", 2, "0")}:#{String.pad_leading("#{seconds}", 2, "0")} UTC",
      cx, cy + 55
    )
  end

  # ── Boids ───────────────────────────────────────────────────────

  @boids_width 800
  @boids_height 600
  @max_speed 4.0
  @max_force 0.1
  @perception 50.0
  @separation_dist 25.0

  def boids_width, do: @boids_width
  def boids_height, do: @boids_height

  def boids_init(count \\ 100) do
    for _ <- 1..count do
      angle = :rand.uniform() * 2 * :math.pi()
      speed = 2.0 + :rand.uniform() * 2.0

      %{
        x: :rand.uniform(@boids_width) * 1.0,
        y: :rand.uniform(@boids_height) * 1.0,
        vx: :math.cos(angle) * speed,
        vy: :math.sin(angle) * speed
      }
    end
  end

  def boids_tick(boids) do
    Enum.map(boids, fn boid ->
      boid
      |> boids_apply_rules(boids)
      |> boids_limit_speed()
      |> boids_move()
      |> boids_wrap()
    end)
  end

  defp boids_apply_rules(boid, boids) do
    {sep_x, sep_y, ali_x, ali_y, coh_x, coh_y, count} =
      Enum.reduce(boids, {0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0}, fn other, {sx, sy, ax, ay, cx, cy, n} ->
        dx = other.x - boid.x
        dy = other.y - boid.y
        dist = :math.sqrt(dx * dx + dy * dy)

        if dist > 0 and dist < @perception do
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
      {avx, avy} = boids_steer(boid, ali_x / count, ali_y / count)
      # Cohesion — steer toward average position
      {cvx, cvy} = boids_steer(boid, coh_x / count - boid.x, coh_y / count - boid.y)
      # Separation
      {svx, svy} = {sep_x * @max_force * 1.5, sep_y * @max_force * 1.5}

      %{boid | vx: boid.vx + svx + avx + cvx, vy: boid.vy + svy + avy + cvy}
    else
      boid
    end
  end

  defp boids_steer(boid, target_vx, target_vy) do
    mag = :math.sqrt(target_vx * target_vx + target_vy * target_vy)

    if mag > 0 do
      dvx = target_vx / mag * @max_speed - boid.vx
      dvy = target_vy / mag * @max_speed - boid.vy
      boids_limit_vec(dvx, dvy, @max_force)
    else
      {0.0, 0.0}
    end
  end

  defp boids_limit_vec(x, y, max) do
    mag = :math.sqrt(x * x + y * y)
    if mag > max, do: {x / mag * max, y / mag * max}, else: {x, y}
  end

  defp boids_limit_speed(boid) do
    speed = :math.sqrt(boid.vx * boid.vx + boid.vy * boid.vy)

    if speed > @max_speed do
      %{boid | vx: boid.vx / speed * @max_speed, vy: boid.vy / speed * @max_speed}
    else
      boid
    end
  end

  defp boids_move(boid) do
    %{boid | x: boid.x + boid.vx, y: boid.y + boid.vy}
  end

  defp boids_wrap(boid) do
    %{boid |
      x: boids_wrap_val(boid.x, @boids_width),
      y: boids_wrap_val(boid.y, @boids_height)
    }
  end

  defp boids_wrap_val(v, max) do
    cond do
      v < 0 -> v + max
      v > max -> v - max
      true -> v
    end
  end

  def boids_render(boids) do
    canvas =
      Easel.new(@boids_width, @boids_height)
      |> API.set_fill_style("#0a0a2e")
      |> API.fill_rect(0, 0, @boids_width, @boids_height)

    Enum.reduce(boids, canvas, fn boid, acc ->
      angle = :math.atan2(boid.vy, boid.vx)
      size = 6
      x1 = boid.x + :math.cos(angle) * size * 2
      y1 = boid.y + :math.sin(angle) * size * 2
      x2 = boid.x + :math.cos(angle + 2.5) * size
      y2 = boid.y + :math.sin(angle + 2.5) * size
      x3 = boid.x + :math.cos(angle - 2.5) * size
      y3 = boid.y + :math.sin(angle - 2.5) * size
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
    |> Easel.render()
  end
end
