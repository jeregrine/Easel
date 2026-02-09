defmodule PhxDemoWeb.WaveGridLive do
  use PhxDemoWeb, :live_view

  def mount(_params, _session, socket) do
    state = PhxDemo.Examples.WaveGrid.init()

    socket =
      socket
      |> assign(:state, state)
      |> assign(:background, PhxDemo.Examples.WaveGrid.background())
      |> assign(:canvas, PhxDemo.Examples.WaveGrid.render(state))
      |> Easel.LiveView.animate(
        "fg",
        :state,
        fn state ->
          next = PhxDemo.Examples.WaveGrid.tick(state)
          {PhxDemo.Examples.WaveGrid.render(next), next}
        end,
        interval: 33,
        canvas_assign: :canvas
      )

    {:ok, socket}
  end

  def handle_info({:easel_tick, id}, socket), do: {:noreply, Easel.LiveView.tick(socket, id)}

  def handle_event("fg:click", %{"x" => x, "y" => y}, socket) do
    state = PhxDemo.Examples.WaveGrid.add(socket.assigns.state, x * 1.0, y * 1.0)
    {:noreply, assign(socket, :state, state)}
  end

  def render(assigns) do
    ~H"""
    <.demo title="Wave Grid — click to disturb" code_id="wave">
      <Easel.LiveView.canvas_stack id="wave" width={@background.width} height={@background.height}>
        <:layer id="bg" ops={@background.ops} />
        <:layer id="fg" ops={@canvas.ops} templates={@canvas.templates} on_click />
      </Easel.LiveView.canvas_stack>
    </.demo>
    """
  end
end
