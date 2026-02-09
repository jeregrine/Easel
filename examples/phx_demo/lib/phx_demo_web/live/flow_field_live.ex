defmodule PhxDemoWeb.FlowFieldLive do
  use PhxDemoWeb, :live_view

  def mount(_params, _session, socket) do
    state = PhxDemo.Examples.FlowField.init()
    first = PhxDemo.Examples.FlowField.render(state)

    socket =
      socket
      |> assign(:state, state)
      |> assign(:background, PhxDemo.Examples.FlowField.background())
      |> assign(:canvas, %{ops: first.ops})
      |> assign(:templates, first.templates)
      |> Easel.LiveView.animate(
        "fg",
        :state,
        fn state ->
          {Easel.new(), PhxDemo.Examples.FlowField.tick(state)}
        end,
        interval: 16
      )

    {:ok, socket}
  end

  def handle_info({:easel_tick, id}, socket) do
    socket = Easel.LiveView.tick(socket, id)
    frame = PhxDemo.Examples.FlowField.render(socket.assigns.state)
    {:noreply, Easel.LiveView.draw(socket, "fg", frame, clear: true)}
  end

  def handle_event("fg:mousedown", %{"x" => x, "y" => y}, socket) do
    state = PhxDemo.Examples.FlowField.add_burst(socket.assigns.state, x * 1.0, y * 1.0)
    {:noreply, assign(socket, :state, state)}
  end

  def handle_event("fg:click", params, socket), do: handle_event("fg:mousedown", params, socket)

  def render(assigns) do
    ~H"""
    <.demo title="Flow Field Particles — click to burst">
      <Easel.LiveView.canvas_stack id="flow" width={@background.width} height={@background.height}>
        <:layer id="bg" ops={@background.ops} />
        <:layer id="fg" ops={@canvas.ops} templates={@templates} on_click on_mouse_down />
      </Easel.LiveView.canvas_stack>
    </.demo>
    """
  end
end
