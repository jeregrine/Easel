defmodule PhxDemo.Examples do
  @moduledoc """
  Drawing functions for each Easel example, returning rendered canvases.
  """

  # Static
  def smiley, do: PhxDemo.Examples.Smiley.render()
  def chart, do: PhxDemo.Examples.Chart.render()
  def starfield, do: PhxDemo.Examples.Starfield.render()
  def spiral, do: PhxDemo.Examples.Spiral.render()
  def tree, do: PhxDemo.Examples.Tree.render()
  def mondrian, do: PhxDemo.Examples.Mondrian.render()
  def sierpinski, do: PhxDemo.Examples.Sierpinski.render()
  def mandelbrot, do: PhxDemo.Examples.Mandelbrot.render()

  # Clock
  def clock, do: PhxDemo.Examples.Clock.render()
  def clock(%Time{} = now), do: PhxDemo.Examples.Clock.render(now)

  # Matrix
  def matrix_init, do: PhxDemo.Examples.Matrix.init()
  def matrix_tick(state), do: PhxDemo.Examples.Matrix.tick(state)
  def matrix_render(state), do: PhxDemo.Examples.Matrix.render(state)

  # Game of Life
  def life_width, do: PhxDemo.Examples.Life.width()
  def life_height, do: PhxDemo.Examples.Life.height()
  def life_cell, do: PhxDemo.Examples.Life.cell()
  def life_init(density \\ 0.22), do: PhxDemo.Examples.Life.init(density)
  def life_tick(state), do: PhxDemo.Examples.Life.tick(state)
  def life_toggle(state, x, y), do: PhxDemo.Examples.Life.toggle(state, x, y)
  def life_render_background, do: PhxDemo.Examples.Life.render_background()
  def life_render(state), do: PhxDemo.Examples.Life.render(state)

  # Boids
  def boids_width, do: PhxDemo.Examples.Boids.width()
  def boids_height, do: PhxDemo.Examples.Boids.height()
  def boids_init(count \\ 100), do: PhxDemo.Examples.Boids.init(count)
  def boids_tick(boids), do: PhxDemo.Examples.Boids.tick(boids)
  def boids_render(boids), do: PhxDemo.Examples.Boids.render(boids)
end
