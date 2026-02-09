defmodule PhxDemoWeb.StaticExampleLive do
  use PhxDemoWeb, :live_view

  @examples %{
    "smiley" => {"Smiley", 300, 300, :smiley},
    "chart" => {"Chart", 600, 400, :chart},
    "starfield" => {"Starfield", 600, 400, :starfield},
    "spiral" => {"Spiral", 500, 500, :spiral},
    "tree" => {"Fractal Tree", 600, 500, :tree},
    "mondrian" => {"Mondrian", 500, 500, :mondrian},
    "sierpinski" => {"Sierpinski Triangle", 600, 520, :sierpinski},
    "mandelbrot" => {"Mandelbrot Set", 200, 200, :mandelbrot}
  }

  def mount(%{"id" => id}, _session, socket) do
    case Map.get(@examples, id) do
      nil ->
        {:ok, push_navigate(socket, to: "/")}

      {title, width, height, fun} ->
        canvas = apply(PhxDemo.Examples, fun, [])

        {:ok,
         socket
         |> assign(:id, id)
         |> assign(:title, title)
         |> assign(:width, width)
         |> assign(:height, height)
         |> assign(:canvas, canvas)}
    end
  end

  def render(assigns) do
    ~H"""
    <.demo title={@title} code_id={@id}>
      <Easel.LiveView.canvas id={"static-#{@id}"} width={@width} height={@height} ops={@canvas.ops} />
    </.demo>
    """
  end
end
