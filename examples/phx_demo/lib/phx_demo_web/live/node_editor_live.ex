defmodule PhxDemoWeb.NodeEditorLive do
  use PhxDemoWeb, :live_view

  alias PhxDemo.Examples.NodeEditor

  def mount(_params, _session, socket) do
    state = NodeEditor.init()

    {:ok,
     socket
     |> assign(:background, NodeEditor.render_background())
     |> assign_state(state)}
  end

  def handle_event("fg:mousedown", %{"x" => x, "y" => y}, socket) do
    state = NodeEditor.start_drag(socket.assigns.state, x * 1.0, y * 1.0)
    {:noreply, assign_state(socket, state)}
  end

  def handle_event("fg:mousemove", %{"x" => x, "y" => y}, socket) do
    state = NodeEditor.drag(socket.assigns.state, x * 1.0, y * 1.0)

    if state == socket.assigns.state do
      {:noreply, socket}
    else
      {:noreply, assign_state(socket, state)}
    end
  end

  def handle_event("fg:mouseup", params, socket), do: handle_event("stop-drag", params, socket)

  def handle_event("stop-drag", _params, socket) do
    state = NodeEditor.stop_drag(socket.assigns.state)

    if state == socket.assigns.state do
      {:noreply, socket}
    else
      {:noreply, assign(socket, :state, state)}
    end
  end

  def handle_event("reset", _, socket) do
    state = NodeEditor.init()
    {:noreply, assign_state(socket, state)}
  end

  def render(assigns) do
    ~H"""
    <.demo title="Node Editor — drag nodes" code_id="node_editor">
      <div class="flex gap-2 mb-3">
        <button phx-click="reset" class="px-3 py-1 border rounded text-sm">Reset layout</button>
      </div>

      <div phx-window-mouseup="stop-drag">
        <Easel.LiveView.canvas_stack
          id="node-editor"
          width={@background.width}
          height={@background.height}
          class="select-none"
        >
          <:layer id="bg" ops={@background.ops} />
          <:layer id="fg" ops={@canvas.ops} on_mouse_down on_mouse_move on_mouse_up />
        </Easel.LiveView.canvas_stack>
      </div>

      <p class="text-sm text-gray-500 mt-2">
        Drag nodes around like a tiny Blueprint graph.
        Selected: {NodeEditor.selected_title(@state) || "none"}
      </p>
    </.demo>
    """
  end

  defp assign_state(socket, state) do
    socket
    |> assign(:state, state)
    |> assign(:canvas, NodeEditor.render(state))
  end
end
