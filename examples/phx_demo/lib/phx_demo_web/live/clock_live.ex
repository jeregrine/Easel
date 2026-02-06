defmodule PhxDemoWeb.ClockLive do
  use PhxDemoWeb, :live_view

  def mount(_params, _session, socket) do
    canvas = PhxDemo.Examples.clock()

    socket =
      socket
      |> assign(:time, Time.utc_now())
      |> assign(:canvas, canvas)
      |> Easel.LiveView.animate("clock", :time, fn _time ->
        now = Time.utc_now()
        canvas = PhxDemo.Examples.clock(now)
        {canvas, now}
      end, interval: 1000, canvas_assign: :canvas)

    {:ok, socket}
  end

  def handle_info({:easel_tick, id}, socket) do
    {:noreply, Easel.LiveView.tick(socket, id)}
  end

  def render(assigns) do
    ~H"""
    <.demo title="Clock">
      <Easel.LiveView.canvas id="clock" width={400} height={400} ops={@canvas.ops} />
    </.demo>
    """
  end
end
