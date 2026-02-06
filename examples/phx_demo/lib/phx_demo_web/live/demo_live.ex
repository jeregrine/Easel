defmodule PhxDemoWeb.DemoLive do
  use PhxDemoWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       smiley: PhxDemo.Examples.smiley(),
       chart: PhxDemo.Examples.chart(),
       starfield: PhxDemo.Examples.starfield(),
       spiral: PhxDemo.Examples.spiral(),
       tree: PhxDemo.Examples.tree(),
       mondrian: PhxDemo.Examples.mondrian(),
       sierpinski: PhxDemo.Examples.sierpinski(),
       mandelbrot: PhxDemo.Examples.mandelbrot()
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-6xl mx-auto py-8 px-4">
      <h1 class="text-3xl font-bold mb-2">Easel LiveView Demos</h1>
      <p class="text-gray-600 mb-8">Canvas 2D rendering powered by Easel + Phoenix LiveView</p>

      <div class="mb-8">
        <h2 class="text-xl font-semibold mb-4">Animated</h2>
        <div class="flex gap-4">
          <.link navigate="/clock" class="block p-4 border rounded-lg hover:bg-gray-50 transition-colors">
            <h3 class="font-semibold">⏰ Clock</h3>
            <p class="text-sm text-gray-500">Animated analog clock</p>
          </.link>
          <.link navigate="/boids" class="block p-4 border rounded-lg hover:bg-gray-50 transition-colors">
            <h3 class="font-semibold">🐦 Boids</h3>
            <p class="text-sm text-gray-500">Flocking simulation</p>
          </.link>
        </div>
      </div>

      <h2 class="text-xl font-semibold mb-4">Static</h2>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
        <.example title="Smiley">
          <Easel.LiveView.canvas id="smiley" width={300} height={300} ops={@smiley.ops} />
        </.example>

        <.example title="Chart">
          <Easel.LiveView.canvas id="chart" width={600} height={400} ops={@chart.ops} />
        </.example>

        <.example title="Starfield">
          <Easel.LiveView.canvas id="starfield" width={600} height={400} ops={@starfield.ops} />
        </.example>

        <.example title="Spiral">
          <Easel.LiveView.canvas id="spiral" width={500} height={500} ops={@spiral.ops} />
        </.example>

        <.example title="Fractal Tree">
          <Easel.LiveView.canvas id="tree" width={600} height={500} ops={@tree.ops} />
        </.example>

        <.example title="Mondrian">
          <Easel.LiveView.canvas id="mondrian" width={500} height={500} ops={@mondrian.ops} />
        </.example>

        <.example title="Sierpinski Triangle">
          <Easel.LiveView.canvas id="sierpinski" width={600} height={520} ops={@sierpinski.ops} />
        </.example>

        <.example title="Mandelbrot Set">
          <Easel.LiveView.canvas id="mandelbrot" width={200} height={200} ops={@mandelbrot.ops} />
        </.example>
      </div>
    </div>
    """
  end

  defp example(assigns) do
    ~H"""
    <div>
      <h3 class="font-semibold text-lg mb-2"><%= @title %></h3>
      <%= render_slot(@inner_block) %>
    </div>
    """
  end
end
