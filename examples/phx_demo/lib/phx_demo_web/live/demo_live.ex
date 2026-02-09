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

  @animated [
    {"/clock", "⏰ Clock", "Animated analog clock"},
    {"/boids", "🐦 Boids", "Flocking simulation"},
    {"/matrix", "🟢 Matrix", "Matrix rain animation"},
    {"/life", "🧬 Life", "Conway's Game of Life"},
    {"/lissajous", "〰️ Lissajous", "Colorful harmonic curves"},
    {"/flow", "🌪️ Flow Field", "Particle flow + vectors"},
    {"/wave", "🌊 Wave Grid", "Interference pattern playground"},
    {"/pathfinding", "🧭 Pathfinding", "Draw walls and watch BFS solve"}
  ]

  def mount(_params, _session, socket) do
    aurora_state = PhxDemo.Examples.Aurora.init()

    socket =
      Enum.reduce(@examples, socket, fn {key, _title, _w, _h}, socket ->
        assign_async(socket, key, fn ->
          {:ok, %{key => apply(PhxDemo.Examples, key, [])}}
        end)
      end)

    socket =
      socket
      |> assign(:examples, @examples)
      |> assign(:animated, @animated)
      |> assign(:aurora, PhxDemo.Examples.Aurora.render(aurora_state))
      |> assign(:aurora_state, aurora_state)
      |> assign(:aurora_running, true)
      |> Easel.LiveView.animate(
        "aurora",
        :aurora_state,
        &aurora_tick/1,
        interval: 40,
        canvas_assign: :aurora
      )

    {:ok, socket}
  end

  def handle_info({:easel_tick, id}, socket), do: {:noreply, Easel.LiveView.tick(socket, id)}

  def handle_event("toggle-aurora", _, %{assigns: %{aurora_running: true}} = socket) do
    {:noreply,
     socket |> Easel.LiveView.stop_animation("aurora") |> assign(:aurora_running, false)}
  end

  def handle_event("toggle-aurora", _, socket) do
    socket =
      socket
      |> assign(:aurora_running, true)
      |> Easel.LiveView.animate("aurora", :aurora_state, &aurora_tick/1,
        interval: 40,
        canvas_assign: :aurora
      )

    {:noreply, socket}
  end

  defp aurora_tick(state) do
    next = PhxDemo.Examples.Aurora.tick(state)
    {PhxDemo.Examples.Aurora.render(next), next}
  end

  def render(assigns) do
    ~H"""
    <div class="relative">
      <div class="pointer-events-none fixed inset-0 opacity-70 -z-10 overflow-hidden">
        <Easel.LiveView.canvas
          id="aurora"
          width={@aurora.width}
          height={@aurora.height}
          ops={@aurora.ops}
          class="w-screen h-screen"
        />
      </div>

      <div class="max-w-screen-xl mx-auto py-8 px-4">
        <div class="flex items-center justify-between mb-2">
          <h1 class="text-3xl font-bold">Easel LiveView Demos</h1>
          <a
            href="https://github.com/jeregrine/Easel"
            target="_blank"
            class="text-gray-400 hover:text-gray-700 transition-colors"
          >
            <svg viewBox="0 0 16 16" width="24" height="24" fill="currentColor">
              <path d="M8 0c4.42 0 8 3.58 8 8a8.013 8.013 0 0 1-5.45 7.59c-.4.08-.55-.17-.55-.38 0-.27.01-1.13.01-2.2 0-.75-.25-1.23-.54-1.48 1.78-.2 3.65-.88 3.65-3.95 0-.88-.31-1.59-.82-2.15.08-.2.36-1.02-.08-2.12 0 0-.67-.22-2.2.82-.64-.18-1.32-.27-2-.27-.68 0-1.36.09-2 .27-1.53-1.03-2.2-.82-2.2-.82-.44 1.1-.16 1.92-.08 2.12-.51.56-.82 1.28-.82 2.15 0 3.06 1.86 3.75 3.64 3.95-.23.2-.44.55-.51 1.07-.46.21-1.61.55-2.33-.66-.15-.24-.6-.83-1.23-.82-.67.01-.27.38.01.53.34.19.73.9.82 1.13.16.45.68 1.31 2.69.94 0 .67.01 1.3.01 1.49 0 .21-.15.45-.55.38A7.995 7.995 0 0 1 0 8c0-4.42 3.58-8 8-8Z">
              </path>
            </svg>
          </a>
        </div>
        <p class="text-gray-600 mb-4">Canvas 2D rendering powered by Easel + Phoenix LiveView</p>

        <div class="mb-8 rounded-lg border bg-gray-50 p-4 text-sm text-gray-700">
          <p>
            Pure Elixir drawing and animation with Phoenix LiveView or Wx backends. Data transfer and draw calls are optimized with compact payloads, templating, and instancing, so complex scenes stay responsive without writing manual JavaScript drawing code.
          </p>
          <p class="pt-4">
            No new drawing DSL to learn: Easel uses the familiar Canvas 2D API across targets.
          </p>
        </div>

        <div class="mb-8">
          <h2 class="text-xl font-semibold mb-4">Animated</h2>
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            <div :for={{path, title, desc} <- @animated} class="p-4 border rounded-lg bg-white">
              <h3 class="font-semibold">{title}</h3>
              <p class="text-sm text-gray-500 mb-3">{desc}</p>
              <div class="flex items-center gap-3 text-sm">
                <.link navigate={path} class="text-blue-600 hover:underline">Open demo</.link>
              </div>
            </div>
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

        <div class="mt-8 flex justify-end">
          <button phx-click="toggle-aurora" class="btn btn-sm btn-soft bg-white/90">
            {if @aurora_running, do: "Stop background animation", else: "Start background animation"}
          </button>
        </div>
      </div>
    </div>
    """
  end

  attr(:key, :atom, required: true)
  attr(:title, :string, required: true)
  attr(:width, :integer, required: true)
  attr(:height, :integer, required: true)
  attr(:result, :any, required: true)

  defp async_example(%{result: %{ok?: true}} = assigns) do
    ~H"""
    <div class="min-w-0">
      <div class="flex items-center gap-2 mb-2">
        <h3 class="font-semibold text-lg">{@title}</h3>
        <.link navigate={"/examples/#{@key}"} class="text-xs text-blue-600 hover:underline">
          open
        </.link>
        <Easel.LiveView.export_button
          for={@key}
          filename={"#{@key}.png"}
          class="text-xs text-gray-400 hover:text-gray-700 cursor-pointer"
        >
          📥
        </Easel.LiveView.export_button>
      </div>
      <Easel.LiveView.canvas id={@key} width={@width} height={@height} ops={@result.result.ops} />
    </div>
    """
  end

  defp async_example(%{result: %{failed: reason}} = assigns) when not is_nil(reason) do
    assigns = assign(assigns, :reason, inspect(reason))

    ~H"""
    <div class="min-w-0">
      <div class="flex items-center gap-2 mb-2">
        <h3 class="font-semibold text-lg">{@title}</h3>
        <.link navigate={"/examples/#{@key}"} class="text-xs text-blue-600 hover:underline">
          open
        </.link>
      </div>
      <div
        class="flex items-center justify-center bg-red-50 text-red-500 text-sm rounded"
        style={"width: #{@width}px; height: #{@height}px"}
      >
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
        <.link navigate={"/examples/#{@key}"} class="text-xs text-blue-600 hover:underline">
          open
        </.link>
      </div>
      <div
        class="flex items-center justify-center bg-gray-100 rounded animate-pulse"
        style={"width: #{@width}px; height: #{@height}px"}
      >
        <span class="text-gray-400 text-sm">Rendering…</span>
      </div>
    </div>
    """
  end
end
