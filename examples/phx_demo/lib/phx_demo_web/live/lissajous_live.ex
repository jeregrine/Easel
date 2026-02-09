defmodule PhxDemoWeb.LissajousLive do
  use PhxDemoWeb, :live_view

  def mount(_params, _session, socket) do
    t = 0

    socket =
      socket
      |> assign(:t, t)
      |> assign(:background, PhxDemo.Examples.Lissajous.background())
      |> assign(:canvas, PhxDemo.Examples.Lissajous.render(t))
      |> Easel.LiveView.animate(
        "fg",
        :t,
        fn t ->
          t2 = t + 2
          {PhxDemo.Examples.Lissajous.render(t2), t2}
        end,
        interval: 33,
        canvas_assign: :canvas
      )

    {:ok, socket}
  end

  def handle_info({:easel_tick, id}, socket) do
    {:noreply, Easel.LiveView.tick(socket, id)}
  end

  def render(assigns) do
    ~H"""
    <.demo title="Lissajous Curves">
      <Easel.LiveView.canvas_stack
        id="lissajous"
        width={@background.width}
        height={@background.height}
      >
        <:layer id="bg" ops={@background.ops} />
        <:layer id="fg" ops={@canvas.ops} />
      </Easel.LiveView.canvas_stack>
    </.demo>
    """
  end
end
