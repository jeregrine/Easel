defmodule PhxDemo.Examples.FlowField do
  @width 900
  @height 560
  @count 1300

  def width, do: @width
  def height, do: @height

  def init do
    particles = for _ <- 1..@count, do: new_particle()
    %{particles: particles, t: 0}
  end

  def tick(%{particles: particles, t: t}) do
    t2 = t + 1

    particles =
      Enum.map(particles, fn p ->
        a = angle(p.x, p.y, t2)
        vx = p.vx * 0.85 + :math.cos(a) * 1.4
        vy = p.vy * 0.85 + :math.sin(a) * 1.4
        x = wrap(p.x + vx, @width)
        y = wrap(p.y + vy, @height)
        life = p.life - 1

        if life <= 0 do
          new_particle()
        else
          %{p | x: x, y: y, vx: vx, vy: vy, life: life}
        end
      end)

    %{particles: particles, t: t2}
  end

  def add_burst(%{particles: particles} = state, x, y) do
    burst =
      for _ <- 1..260 do
        a = :rand.uniform() * 2 * :math.pi()
        s = 1.0 + :rand.uniform() * 4.0
        d = :rand.uniform() * 18.0

        %{
          x: x + :math.cos(a) * d,
          y: y + :math.sin(a) * d,
          vx: :math.cos(a) * s,
          vy: :math.sin(a) * s,
          life: 100 + :rand.uniform(160)
        }
      end

    %{state | particles: Enum.take(burst ++ particles, @count)}
  end

  def background do
    Easel.new(@width, @height)
    |> Easel.set_fill_style("#050914")
    |> Easel.fill_rect(0, 0, @width, @height)
    |> Easel.render()
  end

  def render(%{particles: particles, t: t}) do
    boid_instances =
      Enum.map(particles, fn p ->
        speed = :math.sqrt(p.vx * p.vx + p.vy * p.vy)
        hue = rem(round(p.x / @width * 220 + t), 360)

        %{
          x: p.x,
          y: p.y,
          rotate: :math.atan2(p.vy, p.vx),
          scale_x: 0.7 + speed * 0.25,
          scale_y: 0.7 + speed * 0.25,
          fill: "hsl(#{hue}, 95%, 68%)",
          alpha: 0.9
        }
      end)

    vector_instances =
      for gy <- 0..12, gx <- 0..20 do
        x = gx * 45 + 22
        y = gy * 45 + 22
        a = angle(x, y, t)

        %{x: x, y: y, rotate: a, stroke: "rgba(125, 211, 252, 0.25)", fill: "rgba(125, 211, 252, 0.25)"}
      end

    Easel.new(@width, @height)
    |> Easel.template(:boid, fn c ->
      c
      |> Easel.begin_path()
      |> Easel.move_to(3.2, 0)
      |> Easel.line_to(-2.0, -1.25)
      |> Easel.line_to(-1.2, 0)
      |> Easel.line_to(-2.0, 1.25)
      |> Easel.close_path()
      |> Easel.fill()
    end)
    |> Easel.template(:vec, fn c ->
      c
      |> Easel.begin_path()
      |> Easel.move_to(-6, 0)
      |> Easel.line_to(4, 0)
      |> Easel.set_line_width(1)
      |> Easel.stroke()
      |> Easel.begin_path()
      |> Easel.move_to(4, 0)
      |> Easel.line_to(0, -2)
      |> Easel.line_to(0, 2)
      |> Easel.close_path()
      |> Easel.fill()
    end)
    |> Easel.instances(:vec, vector_instances)
    |> Easel.instances(:boid, boid_instances)
    |> Easel.render()
  end

  defp angle(x, y, t) do
    :math.sin(x * 0.012 + t * 0.02) * 2.1 + :math.cos(y * 0.01 - t * 0.015) * 1.7
  end

  defp wrap(v, max) when v < 0, do: v + max
  defp wrap(v, max) when v > max, do: v - max
  defp wrap(v, _max), do: v

  defp new_particle do
    %{
      x: :rand.uniform() * @width,
      y: :rand.uniform() * @height,
      vx: 0.0,
      vy: 0.0,
      life: 80 + :rand.uniform(200)
    }
  end
end
