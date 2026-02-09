defmodule PhxDemo.Examples do
  @moduledoc """
  Drawing functions for each Easel example, returning rendered canvases.
  """

  # ── Smiley ──────────────────────────────────────────────────────

  def smiley do
    Easel.new(300, 300)
    |> Easel.begin_path()
    |> Easel.arc(150, 150, 100, 0, :math.pi() * 2)
    |> Easel.set_fill_style("#FFD700")
    |> Easel.fill()
    |> Easel.set_stroke_style("#333")
    |> Easel.set_line_width(3)
    |> Easel.stroke()
    |> Easel.begin_path()
    |> Easel.arc(115, 120, 15, 0, :math.pi() * 2)
    |> Easel.set_fill_style("#333")
    |> Easel.fill()
    |> Easel.begin_path()
    |> Easel.arc(185, 120, 15, 0, :math.pi() * 2)
    |> Easel.fill()
    |> Easel.begin_path()
    |> Easel.arc(150, 155, 60, 0.2, :math.pi() - 0.2)
    |> Easel.set_stroke_style("#333")
    |> Easel.set_line_width(4)
    |> Easel.set_line_cap("round")
    |> Easel.stroke()
    |> Easel.render()
  end

  # ── Chart ───────────────────────────────────────────────────────

  def chart do
    width = 600
    height = 400
    padding = 60

    data = [
      {"2018", 45},
      {"2019", 62},
      {"2020", 78},
      {"2021", 95},
      {"2022", 120},
      {"2023", 155},
      {"2024", 190},
      {"2025", 230}
    ]

    max_val = data |> Enum.map(&elem(&1, 1)) |> Enum.max()
    bar_count = length(data)
    chart_w = width - padding * 2
    chart_h = height - padding * 2
    bar_w = chart_w / bar_count * 0.7
    gap = chart_w / bar_count * 0.3

    colors = [
      "#6366f1",
      "#8b5cf6",
      "#a78bfa",
      "#c084fc",
      "#d946ef",
      "#ec4899",
      "#f43f5e",
      "#ef4444"
    ]

    canvas =
      Easel.new(width, height)
      |> Easel.set_fill_style("#fafafa")
      |> Easel.fill_rect(0, 0, width, height)
      |> Easel.set_fill_style("#1f2937")
      |> Easel.set_font("bold 18px sans-serif")
      |> Easel.set_text_align("center")
      |> Easel.fill_text("Elixir Popularity Index", width / 2, 30)
      |> Easel.set_stroke_style("#9ca3af")
      |> Easel.set_line_width(1)
      |> Easel.begin_path()
      |> Easel.move_to(padding, padding)
      |> Easel.line_to(padding, height - padding)
      |> Easel.line_to(width - padding, height - padding)
      |> Easel.stroke()

    canvas =
      Enum.reduce(0..4, canvas, fn i, acc ->
        y = padding + chart_h * (1 - i / 4)
        val = round(max_val * i / 4)

        acc
        |> Easel.set_stroke_style("#e5e7eb")
        |> Easel.set_line_width(0.5)
        |> Easel.begin_path()
        |> Easel.move_to(padding, y)
        |> Easel.line_to(width - padding, y)
        |> Easel.stroke()
        |> Easel.set_fill_style("#6b7280")
        |> Easel.set_font("12px sans-serif")
        |> Easel.set_text_align("right")
        |> Easel.fill_text("#{val}", padding - 8, y + 4)
      end)

    data
    |> Enum.with_index()
    |> Enum.reduce(canvas, fn {{label, value}, i}, acc ->
      x = padding + i * (bar_w + gap) + gap / 2
      bar_h = value / max_val * chart_h
      y = height - padding - bar_h
      color = Enum.at(colors, i)

      acc
      |> Easel.set_fill_style(color)
      |> Easel.fill_rect(x, y, bar_w, bar_h)
      |> Easel.set_stroke_style("rgba(0,0,0,0.1)")
      |> Easel.set_line_width(1)
      |> Easel.stroke_rect(x, y, bar_w, bar_h)
      |> Easel.set_fill_style("#374151")
      |> Easel.set_font("bold 12px sans-serif")
      |> Easel.set_text_align("center")
      |> Easel.fill_text("#{value}", x + bar_w / 2, y - 8)
      |> Easel.set_fill_style("#6b7280")
      |> Easel.set_font("12px sans-serif")
      |> Easel.fill_text(label, x + bar_w / 2, height - padding + 20)
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
      |> Easel.set_fill_style("#0a0a2e")
      |> Easel.fill_rect(0, 0, width, height)

    canvas =
      Enum.reduce(1..200, canvas, fn _, acc ->
        x = :rand.uniform(width)
        y = :rand.uniform(height)
        radius = :rand.uniform() * 2.5 + 0.5
        brightness = :rand.uniform(155) + 100

        color =
          "rgba(#{brightness}, #{brightness}, #{min(255, brightness + 50)}, #{Float.round(:rand.uniform(), 2)})"

        acc
        |> Easel.begin_path()
        |> Easel.arc(x, y, radius, 0, :math.pi() * 2)
        |> Easel.set_fill_style(color)
        |> Easel.fill()
      end)

    Enum.reduce(1..8, canvas, fn _, acc ->
      x = :rand.uniform(width)
      y = :rand.uniform(height)

      acc
      |> Easel.save()
      |> Easel.set_global_alpha(0.3)
      |> Easel.begin_path()
      |> Easel.arc(x, y, 8, 0, :math.pi() * 2)
      |> Easel.set_fill_style("rgba(200, 200, 255, 0.3)")
      |> Easel.fill()
      |> Easel.set_global_alpha(1.0)
      |> Easel.begin_path()
      |> Easel.arc(x, y, 2, 0, :math.pi() * 2)
      |> Easel.set_fill_style("white")
      |> Easel.fill()
      |> Easel.restore()
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
      |> Easel.set_fill_style("#111")
      |> Easel.fill_rect(0, 0, width, height)
      |> Easel.set_line_width(2)
      |> Easel.set_line_cap("round")

    Enum.reduce(0..points, canvas, fn i, acc ->
      t = i / points
      angle = t * turns * 2 * :math.pi()
      radius = t * 200
      x = cx + radius * :math.cos(angle)
      y = cy + radius * :math.sin(angle)
      hue = rem(round(t * 360 * 3), 360)
      color = "hsl(#{hue}, 80%, 60%)"

      if i == 0 do
        acc |> Easel.begin_path() |> Easel.move_to(x, y)
      else
        acc
        |> Easel.set_stroke_style(color)
        |> Easel.begin_path()
        |> Easel.move_to(
          cx + (t - 1 / points) * 200 * :math.cos(angle - turns * 2 * :math.pi() / points),
          cy + (t - 1 / points) * 200 * :math.sin(angle - turns * 2 * :math.pi() / points)
        )
        |> Easel.line_to(x, y)
        |> Easel.stroke()
      end
    end)
    |> Easel.render()
  end

  defp random_seed do
    a = :erlang.unique_integer([:positive])
    b = :erlang.phash2({System.system_time(), self()})
    c = :erlang.phash2({System.monotonic_time(), make_ref()})
    :rand.seed(:exsss, {a, b, c})
  end

  # ── Tree ────────────────────────────────────────────────────────

  def tree do
    random_seed()
    width = 600
    height = 500

    canvas =
      Easel.new(width, height)
      |> Easel.set_fill_style("#87CEEB")
      |> Easel.fill_rect(0, 0, width, height)
      |> Easel.set_fill_style("#3d5a1e")
      |> Easel.fill_rect(0, height - 40, width, 40)

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
      |> Easel.begin_path()
      |> Easel.move_to(x, y)
      |> Easel.line_to(end_x, end_y)
      |> Easel.set_stroke_style("rgb(#{r}, #{g}, #{b})")
      |> Easel.set_line_width(line_w)
      |> Easel.set_line_cap("round")
      |> Easel.stroke()

    canvas =
      if depth >= max_depth - 2 do
        size = 3 + :rand.uniform(4)

        canvas
        |> Easel.begin_path()
        |> Easel.arc(end_x, end_y, size, 0, :math.pi() * 2)
        |> Easel.set_fill_style("rgba(34, #{100 + :rand.uniform(100)}, 34, 0.6)")
        |> Easel.fill()
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
    random_seed()
    width = 500
    height = 500

    canvas =
      Easel.new(width, height)
      |> Easel.set_fill_style("#ecf0f1")
      |> Easel.fill_rect(0, 0, width, height)

    mondrian_split(canvas, 0, 0, width, height, 0)
    |> Easel.render()
  end

  @mondrian_colors ["#c0392b", "#2980b9", "#f1c40f", "#ecf0f1", "#ecf0f1", "#ecf0f1"]
  @line_width 6

  defp mondrian_split(canvas, x, y, w, h, depth) when depth > 5 or w < 40 or h < 40 do
    color = Enum.random(@mondrian_colors)

    canvas
    |> Easel.set_fill_style(color)
    |> Easel.fill_rect(x + @line_width / 2, y + @line_width / 2, w - @line_width, h - @line_width)
    |> Easel.set_stroke_style("#2c3e50")
    |> Easel.set_line_width(@line_width)
    |> Easel.stroke_rect(x, y, w, h)
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
      |> Easel.set_fill_style("#0d1117")
      |> Easel.fill_rect(0, 0, width, height)
      |> Easel.set_fill_style("#58a6ff")

    sierpinski_tri(
      canvas,
      width / 2,
      padding,
      padding,
      padding + h,
      width - padding,
      padding + h,
      depth
    )
    |> Easel.render()
  end

  defp sierpinski_tri(canvas, _ax, _ay, _bx, _by, _cx, _cy, depth) when depth <= 0, do: canvas

  defp sierpinski_tri(canvas, ax, ay, bx, by, cx, cy, 1) do
    canvas
    |> Easel.begin_path()
    |> Easel.move_to(ax, ay)
    |> Easel.line_to(bx, by)
    |> Easel.line_to(cx, cy)
    |> Easel.close_path()
    |> Easel.fill()
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
    case :persistent_term.get({__MODULE__, :mandelbrot}, :missing) do
      :missing ->
        canvas = mandelbrot_build()
        :persistent_term.put({__MODULE__, :mandelbrot}, canvas)
        canvas

      canvas ->
        canvas
    end
  end

  defp mandelbrot_build do
    width = 200
    height = 200
    max_iter = 50
    x_min = -2.0
    x_max = 0.7
    y_min = -1.35
    y_max = 1.35

    palette = for n <- 0..max_iter, do: mandelbrot_color(n, max_iter)

    Enum.reduce(0..(height - 1), Easel.new(width, height), fn py, acc ->
      ci = y_min + py / height * (y_max - y_min)

      {runs, start_x, last_n} =
        Enum.reduce(0..(width - 1), {[], 0, nil}, fn px, {runs, start_x, last_n} ->
          cr = x_min + px / width * (x_max - x_min)
          n = mandelbrot_iterate(0.0, 0.0, cr, ci, 0, max_iter)

          cond do
            is_nil(last_n) ->
              {runs, px, n}

            n == last_n ->
              {runs, start_x, last_n}

            true ->
              {[{start_x, px - start_x, last_n} | runs], px, n}
          end
        end)

      runs = [{start_x, width - start_x, last_n} | runs] |> Enum.reverse()

      Enum.reduce(runs, acc, fn {x, run_w, n}, c ->
        c
        |> Easel.set_fill_style(Enum.at(palette, n))
        |> Easel.fill_rect(x, py, run_w, 1)
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
    |> Easel.set_fill_style("#1a1a2e")
    |> Easel.fill_rect(0, 0, cx * 2, cy * 2)
    |> Easel.begin_path()
    |> Easel.arc(cx, cy, radius, 0, :math.pi() * 2)
    |> Easel.set_fill_style("#16213e")
    |> Easel.fill()
    |> Easel.set_stroke_style("#e94560")
    |> Easel.set_line_width(4)
    |> Easel.stroke()
    |> Easel.begin_path()
    |> Easel.arc(cx, cy, radius - 10, 0, :math.pi() * 2)
    |> Easel.set_stroke_style("rgba(233, 69, 96, 0.3)")
    |> Easel.set_line_width(1)
    |> Easel.stroke()
  end

  defp clock_markers(canvas, cx, cy, radius) do
    Enum.reduce(1..12, canvas, fn i, acc ->
      angle = i * :math.pi() / 6 - :math.pi() / 2
      is_quarter = rem(i, 3) == 0
      inner_r = if is_quarter, do: radius - 30, else: radius - 20
      outer_r = radius - 12
      width = if is_quarter, do: 3, else: 1.5

      acc
      |> Easel.begin_path()
      |> Easel.move_to(cx + inner_r * :math.cos(angle), cy + inner_r * :math.sin(angle))
      |> Easel.line_to(cx + outer_r * :math.cos(angle), cy + outer_r * :math.sin(angle))
      |> Easel.set_stroke_style(if(is_quarter, do: "#e94560", else: "#a0a0b0"))
      |> Easel.set_line_width(width)
      |> Easel.set_line_cap("round")
      |> Easel.stroke()
    end)
  end

  defp clock_numbers(canvas, cx, cy, radius) do
    Enum.reduce(1..12, canvas, fn i, acc ->
      angle = i * :math.pi() / 6 - :math.pi() / 2
      text_r = radius - 45

      acc
      |> Easel.set_fill_style("#e0e0e0")
      |> Easel.set_font("bold 20px sans-serif")
      |> Easel.set_text_align("center")
      |> Easel.set_text_baseline("middle")
      |> Easel.fill_text("#{i}", cx + text_r * :math.cos(angle), cy + text_r * :math.sin(angle))
    end)
  end

  defp clock_hands(canvas, cx, cy, _radius, hours, minutes, seconds) do
    hour_angle = (hours + minutes / 60) * :math.pi() / 6 - :math.pi() / 2
    minute_angle = (minutes + seconds / 60) * :math.pi() / 30 - :math.pi() / 2
    second_angle = seconds * :math.pi() / 30 - :math.pi() / 2

    canvas
    # Hour
    |> Easel.begin_path()
    |> Easel.move_to(cx - 15 * :math.cos(hour_angle), cy - 15 * :math.sin(hour_angle))
    |> Easel.line_to(cx + 95 * :math.cos(hour_angle), cy + 95 * :math.sin(hour_angle))
    |> Easel.set_stroke_style("#e0e0e0")
    |> Easel.set_line_width(6)
    |> Easel.set_line_cap("round")
    |> Easel.stroke()
    # Minute
    |> Easel.begin_path()
    |> Easel.move_to(cx - 20 * :math.cos(minute_angle), cy - 20 * :math.sin(minute_angle))
    |> Easel.line_to(cx + 130 * :math.cos(minute_angle), cy + 130 * :math.sin(minute_angle))
    |> Easel.set_stroke_style("#e0e0e0")
    |> Easel.set_line_width(3)
    |> Easel.set_line_cap("round")
    |> Easel.stroke()
    # Second
    |> Easel.begin_path()
    |> Easel.move_to(cx - 25 * :math.cos(second_angle), cy - 25 * :math.sin(second_angle))
    |> Easel.line_to(cx + 140 * :math.cos(second_angle), cy + 140 * :math.sin(second_angle))
    |> Easel.set_stroke_style("#e94560")
    |> Easel.set_line_width(1.5)
    |> Easel.set_line_cap("round")
    |> Easel.stroke()
  end

  defp clock_center(canvas, cx, cy, hours, minutes, seconds) do
    canvas
    |> Easel.begin_path()
    |> Easel.arc(cx, cy, 6, 0, :math.pi() * 2)
    |> Easel.set_fill_style("#e94560")
    |> Easel.fill()
    |> Easel.begin_path()
    |> Easel.arc(cx, cy, 3, 0, :math.pi() * 2)
    |> Easel.set_fill_style("#1a1a2e")
    |> Easel.fill()
    |> Easel.set_fill_style("rgba(233, 69, 96, 0.8)")
    |> Easel.set_font("14px monospace")
    |> Easel.set_text_align("center")
    |> Easel.fill_text(
      "#{String.pad_leading("#{hours}", 2, "0")}:#{String.pad_leading("#{minutes}", 2, "0")}:#{String.pad_leading("#{seconds}", 2, "0")} UTC",
      cx,
      cy + 55
    )
  end

  # ── Matrix Rain ──────────────────────────────────────────────────

  @matrix_width 800
  @matrix_height 600
  @matrix_font_size 14
  @matrix_cols div(@matrix_width, @matrix_font_size)
  @matrix_chars ~c"abcdefghijklmnopqrstuvwxyz0123456789@#$%^&*(){}[]|;:<>?ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ"

  def matrix_init do
    # Each column has a list of drops. Each drop is {row, speed, length, trail}
    columns =
      for col <- 0..(@matrix_cols - 1) do
        drops = for _ <- 1..Enum.random(1..3), do: new_matrix_drop(col)
        {col, drops}
      end
      |> Map.new()

    %{columns: columns, tick: 0}
  end

  defp new_matrix_drop(_col) do
    %{
      row: -Enum.random(0..30),
      speed: Enum.random(1..3) / 1.0,
      length: Enum.random(8..25),
      chars: for(_ <- 1..40, do: random_matrix_char())
    }
  end

  defp random_matrix_char do
    idx = :rand.uniform(length(@matrix_chars)) - 1
    @matrix_chars |> Enum.at(idx) |> List.wrap() |> List.to_string()
  end

  def matrix_tick(%{columns: columns, tick: tick} = state) do
    max_rows = div(@matrix_height, @matrix_font_size)

    columns =
      Map.new(columns, fn {col, drops} ->
        drops =
          Enum.map(drops, fn drop ->
            %{drop | row: drop.row + drop.speed}
          end)

        # Respawn drops that have fully left the screen
        drops =
          Enum.map(drops, fn drop ->
            if drop.row - drop.length > max_rows do
              new_matrix_drop(col)
            else
              drop
            end
          end)

        # Randomly glitch some characters
        drops =
          if :rand.uniform() < 0.3 do
            Enum.map(drops, fn drop ->
              idx = :rand.uniform(length(drop.chars)) - 1
              chars = List.replace_at(drop.chars, idx, random_matrix_char())
              %{drop | chars: chars}
            end)
          else
            drops
          end

        {col, drops}
      end)

    %{state | columns: columns, tick: tick + 1}
  end

  def matrix_render(%{columns: columns}) do
    max_rows = div(@matrix_height, @matrix_font_size)

    canvas =
      Easel.new(@matrix_width, @matrix_height)
      # Semi-transparent black to create fade trail effect
      |> Easel.set_fill_style("rgba(0, 0, 0, 0.85)")
      |> Easel.fill_rect(0, 0, @matrix_width, @matrix_height)
      |> Easel.set_font("#{@matrix_font_size}px monospace")
      |> Easel.set_text_baseline("top")
      |> Easel.set_text_align("center")

    Enum.reduce(columns, canvas, fn {col, drops}, canvas ->
      x = col * @matrix_font_size + @matrix_font_size / 2

      Enum.reduce(drops, canvas, fn drop, canvas ->
        head_row = trunc(drop.row)

        Enum.reduce(0..(drop.length - 1), canvas, fn i, canvas ->
          row = head_row - i

          if row >= 0 and row < max_rows do
            y = row * @matrix_font_size
            char_idx = rem(abs(row), length(drop.chars))
            char = Enum.at(drop.chars, char_idx)

            {color, alpha} =
              if i == 0 do
                # Head of the stream — bright white/green
                {"#ffffff", 1.0}
              else
                # Fade from bright green to dark green
                brightness = 1.0 - i / drop.length
                g = round(255 * brightness)
                {"rgb(0, #{g}, 0)", max(0.1, brightness)}
              end

            canvas
            |> Easel.save()
            |> Easel.set_global_alpha(alpha)
            |> Easel.set_fill_style(color)
            |> Easel.fill_text(char, x, y)
            |> Easel.restore()
          else
            canvas
          end
        end)
      end)
    end)
    |> Easel.render()
  end

  # ── Game of Life ────────────────────────────────────────────────

  @life_cols 120
  @life_rows 80
  @life_cell 8

  def life_width, do: @life_cols * @life_cell
  def life_height, do: @life_rows * @life_cell
  def life_cell, do: @life_cell

  def life_init(density \\ 0.22) do
    alive =
      for y <- 0..(@life_rows - 1), x <- 0..(@life_cols - 1), :rand.uniform() < density, into: MapSet.new() do
        {x, y}
      end

    %{alive: alive}
  end

  def life_tick(%{alive: alive} = state) do
    counts =
      Enum.reduce(alive, %{}, fn {x, y}, acc ->
        Enum.reduce(-1..1, acc, fn dx, acc2 ->
          Enum.reduce(-1..1, acc2, fn dy, acc3 ->
            if dx == 0 and dy == 0 do
              acc3
            else
              nx = x + dx
              ny = y + dy

              if nx >= 0 and nx < @life_cols and ny >= 0 and ny < @life_rows do
                Map.update(acc3, {nx, ny}, 1, &(&1 + 1))
              else
                acc3
              end
            end
          end)
        end)
      end)

    next_alive =
      Enum.reduce(counts, MapSet.new(), fn {cell, n}, acc ->
        alive_now = MapSet.member?(alive, cell)

        if (alive_now and (n == 2 or n == 3)) or (!alive_now and n == 3) do
          MapSet.put(acc, cell)
        else
          acc
        end
      end)

    %{state | alive: next_alive}
  end

  def life_toggle(%{alive: alive} = state, x, y) do
    if x >= 0 and x < @life_cols and y >= 0 and y < @life_rows do
      alive = if MapSet.member?(alive, {x, y}), do: MapSet.delete(alive, {x, y}), else: MapSet.put(alive, {x, y})
      %{state | alive: alive}
    else
      state
    end
  end

  def life_render_background do
    width = life_width()
    height = life_height()

    Easel.new(width, height)
    |> Easel.set_fill_style("#0b1020")
    |> Easel.fill_rect(0, 0, width, height)
    |> Easel.render()
  end

  def life_render(%{alive: alive}) do
    instances = Enum.map(alive, fn {x, y} -> %{x: x * @life_cell, y: y * @life_cell} end)

    Easel.new(life_width(), life_height())
    |> Easel.template(:cell, fn c ->
      c
      |> Easel.set_fill_style("#7dd3fc")
      |> Easel.fill_rect(0, 0, @life_cell - 1, @life_cell - 1)
    end)
    |> Easel.instances(:cell, instances)
    |> Easel.render()
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

  @cell_size trunc(@perception)

  def boids_tick(boids) do
    grid = boids_build_grid(boids)

    Enum.map(boids, fn boid ->
      boid
      |> boids_apply_rules(grid)
      |> boids_limit_speed()
      |> boids_move()
      |> boids_wrap()
    end)
  end

  # Spatial hash grid — only check neighbors in adjacent cells
  defp boids_build_grid(boids) do
    Enum.reduce(boids, %{}, fn boid, grid ->
      key = {trunc(boid.x / @cell_size), trunc(boid.y / @cell_size)}
      Map.update(grid, key, [boid], &[boid | &1])
    end)
  end

  defp boids_neighbors(boid, grid) do
    cx = trunc(boid.x / @cell_size)
    cy = trunc(boid.y / @cell_size)

    for dx <- -1..1, dy <- -1..1, reduce: [] do
      acc -> Map.get(grid, {cx + dx, cy + dy}, []) ++ acc
    end
  end

  defp boids_apply_rules(boid, grid) do
    neighbors = boids_neighbors(boid, grid)

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
      {avx, avy} = boids_steer(boid, ali_x / count, ali_y / count)
      {cvx, cvy} = boids_steer(boid, coh_x / count - boid.x, coh_y / count - boid.y)
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
    %{boid | x: boids_wrap_val(boid.x, @boids_width), y: boids_wrap_val(boid.y, @boids_height)}
  end

  defp boids_wrap_val(v, max) do
    cond do
      v < 0 -> v + max
      v > max -> v - max
      true -> v
    end
  end

  # Batch render: group boids by hue bucket, one path + fill per bucket.
  # Reduces ops from ~7 per boid to ~4 per bucket (much fewer buckets than boids).
  def boids_render(boids) do
    canvas =
      Easel.new(@boids_width, @boids_height)
      |> Easel.set_fill_style("#0a0a2e")
      |> Easel.fill_rect(0, 0, @boids_width, @boids_height)

    # Group boids into 36 hue buckets (10° each)
    buckets =
      Enum.group_by(boids, fn boid ->
        angle = :math.atan2(boid.vy, boid.vx)
        div(round(angle / :math.pi() * 180 + 180), 10) * 10
      end)

    Enum.reduce(buckets, canvas, fn {hue, group}, acc ->
      acc = Easel.set_fill_style(acc, "hsl(#{hue}, 70%, 60%)")
      acc = Easel.begin_path(acc)

      acc =
        Enum.reduce(group, acc, fn boid, acc ->
          angle = :math.atan2(boid.vy, boid.vx)
          size = 6
          x1 = boid.x + :math.cos(angle) * size * 2
          y1 = boid.y + :math.sin(angle) * size * 2
          x2 = boid.x + :math.cos(angle + 2.5) * size
          y2 = boid.y + :math.sin(angle + 2.5) * size
          x3 = boid.x + :math.cos(angle - 2.5) * size
          y3 = boid.y + :math.sin(angle - 2.5) * size

          acc
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
