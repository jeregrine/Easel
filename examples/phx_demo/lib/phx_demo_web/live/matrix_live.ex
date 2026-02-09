defmodule PhxDemoWeb.MatrixLive do
  use PhxDemoWeb, :live_view

  @width 800
  @height 600

  def mount(_params, _session, socket) do
    state = PhxDemo.Examples.matrix_init()
    canvas = PhxDemo.Examples.matrix_render(state)

    background =
      Easel.new(@width, @height)
      |> Easel.set_fill_style("#000000")
      |> Easel.fill_rect(0, 0, @width, @height)
      |> Easel.render()

    socket =
      socket
      |> assign(:state, state)
      |> assign(:canvas, canvas)
      |> assign(:background, background)
      |> Easel.LiveView.animate(
        "fg",
        :state,
        fn state ->
          new_state = PhxDemo.Examples.matrix_tick(state)
          canvas = PhxDemo.Examples.matrix_render(new_state)
          {canvas, new_state}
        end,
        interval: 50,
        canvas_assign: :canvas
      )

    {:ok, socket}
  end

  def handle_info({:easel_tick, id}, socket) do
    {:noreply, Easel.LiveView.tick(socket, id)}
  end

  def render(assigns) do
    ~H"""
    <.demo title="Matrix Rain">
      <Easel.LiveView.canvas_stack id="matrix" width={@background.width} height={@background.height}>
        <:layer id="bg" ops={@background.ops} />
        <:layer id="fg" ops={@canvas.ops} />
      </Easel.LiveView.canvas_stack>
    </.demo>
    """
  end
end
