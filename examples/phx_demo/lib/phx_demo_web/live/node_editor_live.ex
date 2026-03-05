defmodule PhxDemoWeb.NodeEditorLive do
  use PhxDemoWeb, :live_view

  alias PhxDemo.Examples.NodeEditor

  def mount(_params, _session, socket) do
    state = NodeEditor.init()
    template_canvas = NodeEditor.template_canvas()

    {:ok,
     socket
     |> assign(:background, NodeEditor.render_background())
     |> assign(:templates, template_canvas.templates)
     |> assign(:template_opts, template_canvas.template_opts)
     |> assign_state(state)}
  end

  def handle_event("fg:mousedown", %{"x" => x, "y" => y}, socket) do
    state = NodeEditor.mouse_down(socket.assigns.state, x * 1.0, y * 1.0)
    {:noreply, draw_state(socket, state, snapshot?: true)}
  end

  def handle_event("fg:mousemove", %{"x" => x, "y" => y}, socket) do
    state = NodeEditor.drag(socket.assigns.state, x * 1.0, y * 1.0)

    if state == socket.assigns.state do
      {:noreply, socket}
    else
      {:noreply, draw_state(socket, state)}
    end
  end

  def handle_event("fg:mouseup", params, socket), do: handle_event("stop-drag", params, socket)

  def handle_event("stop-drag", _params, socket) do
    state = NodeEditor.stop_drag(socket.assigns.state)

    if state == socket.assigns.state do
      {:noreply, socket}
    else
      {:noreply, assign_state(socket, state)}
    end
  end

  def handle_event("reset", _, socket) do
    state = NodeEditor.init()
    {:noreply, draw_state(socket, state, snapshot?: true)}
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
          <:layer
            id="fg"
            ops={@canvas.ops}
            templates={@templates}
            on_mouse_down
            on_mouse_move
            mouse_move_fps={30}
            on_mouse_up
          />
        </Easel.LiveView.canvas_stack>
      </div>

      <p class="text-sm text-gray-500 mt-2">
        Drag nodes around like a tiny Blueprint graph. Click an output pin, then an input pin to connect.
        Selected: {@selected_title || "none"}
        <span :if={@pending_output}> · connecting from  {@pending_output}</span>
      </p>
    </.demo>
    """
  end

  defp draw_state(socket, state, opts \\ []) do
    canvas = NodeEditor.render(state, socket.assigns.template_opts)

    socket
    |> assign_editor_state(state)
    |> maybe_snapshot_canvas(canvas, opts)
    |> Easel.LiveView.draw("fg", canvas, clear: true)
  end

  defp assign_state(socket, state) do
    canvas = NodeEditor.render(state, socket.assigns.template_opts)

    socket
    |> assign_editor_state(state)
    |> assign(:canvas, canvas)
  end

  defp maybe_snapshot_canvas(socket, canvas, opts) do
    if opts[:snapshot?], do: assign(socket, :canvas, canvas), else: socket
  end

  defp assign_editor_state(socket, state) do
    socket
    |> assign(:state, state)
    |> assign(:selected_title, NodeEditor.selected_title(state))
    |> assign(:pending_output, NodeEditor.pending_output_label(state))
  end
end
