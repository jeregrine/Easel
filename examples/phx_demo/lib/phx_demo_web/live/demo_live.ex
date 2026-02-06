defmodule PhxDemoWeb.DemoLive do
  use PhxDemoWeb, :live_view

  @examples [
    {:smiley, "Smiley", 300, 300},
    {:chart, "Chart", 600, 400},
    {:starfield, "Starfield", 600, 400},
    {:spiral, "Spiral", 500, 500},
    {:tree, "Fractal Tree", 600, 500},
    {:mondrian, "Mondrian", 500, 500},
    {:sierpinski, "Sierpinski Triangle", 600, 520},
    {:mandelbrot, "Mandelbrot Set", 200, 200}
  ]

  def mount(_params, _session, socket) do
    socket =
      Enum.reduce(@examples, socket, fn {key, _title, _w, _h}, socket ->
        assign_async(socket, key, fn ->
          {:ok, %{key => apply(PhxDemo.Examples, key, [])}}
        end)
      end)

    {:ok, assign(socket, :examples, @examples)}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-screen-xl mx-auto py-8 px-4">
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
          <.link navigate="/matrix" class="block p-4 border rounded-lg hover:bg-gray-50 transition-colors">
            <h3 class="font-semibold">🟢 Matrix</h3>
            <p class="text-sm text-gray-500">Matrix rain animation</p>
          </.link>
        </div>
      </div>

      <h2 class="text-xl font-semibold mb-4">Static</h2>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-10 items-start">
        <.async_example
          :for={{key, title, width, height} <- @examples}
          key={key}
          title={title}
          width={width}
          height={height}
          result={Map.get(assigns, key)}
        />
      </div>
    </div>
    """
  end

  attr :key, :atom, required: true
  attr :title, :string, required: true
  attr :width, :integer, required: true
  attr :height, :integer, required: true
  attr :result, :any, required: true

  defp async_example(%{result: %{ok?: true}} = assigns) do
    ~H"""
    <div class="min-w-0">
      <div class="flex items-center gap-2 mb-2">
        <h3 class="font-semibold text-lg">{@title}</h3>
        <Easel.LiveView.export_button for={@key} filename={"#{@key}.png"} class="text-xs text-gray-400 hover:text-gray-700 cursor-pointer">
          📥
        </Easel.LiveView.export_button>
      </div>
      <Easel.LiveView.canvas id={@key} width={@width} height={@height} ops={@result.result.ops} />
    </div>
    """
  end

  defp async_example(%{result: %{failed: reason}} = assigns) do
    assigns = assign(assigns, :reason, inspect(reason))

    ~H"""
    <div class="min-w-0">
      <div class="flex items-center gap-2 mb-2">
        <h3 class="font-semibold text-lg">{@title}</h3>
      </div>
      <div class="flex items-center justify-center bg-red-50 text-red-500 text-sm rounded"
           style={"width: #{@width}px; height: #{@height}px"}>
        Failed: {@reason}
      </div>
    </div>
    """
  end

  defp async_example(assigns) do
    ~H"""
    <div class="min-w-0">
      <div class="flex items-center gap-2 mb-2">
        <h3 class="font-semibold text-lg">{@title}</h3>
      </div>
      <div class="flex items-center justify-center bg-gray-100 rounded animate-pulse"
           style={"width: #{@width}px; height: #{@height}px"}>
        <span class="text-gray-400 text-sm">Rendering…</span>
      </div>
    </div>
    """
  end
end
