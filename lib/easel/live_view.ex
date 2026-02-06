if Code.ensure_loaded?(Phoenix.LiveView) do
  defmodule Easel.LiveView do
    @moduledoc """
    A Phoenix LiveView component for rendering and drawing on an HTML canvas.

    ## Setup

    No JavaScript build step is required. The hook is colocated and injected
    at runtime automatically.

    If you use colocated hooks elsewhere in your app, ensure your LiveSocket
    merges them:

        import {hooks as colocatedHooks} from "phoenix-colocated/my_app"

        const liveSocket = new LiveSocket("/live", Socket, {
          hooks: {...colocatedHooks},
          // ...
        })

    ## Usage

    Render a canvas element in your LiveView template:

        <Easel.LiveView.canvas id="my-canvas" width={300} height={300} />

    Then draw to it from any event handler:

        def handle_event("draw", _, socket) do
          canvas =
            Easel.new(300, 300)
            |> Easel.API.set_fill_style("blue")
            |> Easel.API.fill_rect(0, 0, 100, 100)
            |> Easel.render()

          {:noreply, Easel.LiveView.draw(socket, "my-canvas", canvas)}
        end

    You can also pass initial ops to draw on mount:

        <Easel.LiveView.canvas id="my-canvas" width={300} height={300} ops={@canvas.ops} />

    ## Clearing

    To clear the canvas before drawing:

        {:noreply, Easel.LiveView.clear(socket, "my-canvas")}

    Or clear and draw in one step:

        {:noreply, Easel.LiveView.draw(socket, "my-canvas", canvas, clear: true)}
    """

    use Phoenix.Component

    alias Phoenix.LiveView.ColocatedHook

    @doc """
    Renders a `<canvas>` element wired to a colocated LiveView hook.

    ## Attributes

      * `id` (required) - unique DOM id, also used to target draw commands
      * `width` - canvas width in pixels
      * `height` - canvas height in pixels
      * `ops` - initial list of ops to draw on mount (default `[]`)
      * `class` - CSS class for the canvas element

    Any additional attributes are passed through to the `<canvas>` element.
    """
    attr :id, :string, required: true
    attr :width, :integer, default: nil
    attr :height, :integer, default: nil
    attr :ops, :list, default: []
    attr :class, :string, default: nil
    attr :rest, :global

    def canvas(assigns) do
      ~H"""
      <canvas
        id={@id}
        phx-hook=".Canvas"
        width={@width}
        height={@height}
        class={@class}
        data-ops={Phoenix.json_library().encode!(@ops)}
        {@rest}
      />
      <script :type={ColocatedHook} name=".Canvas" runtime>
        {
          executeOps(ops) {
            const ctx = this.context;
            for (const [op, args] of ops) {
              try {
                if (op === "set") {
                  ctx[args[0]] = args[1];
                } else if (typeof ctx[op] === "function") {
                  ctx[op](...args);
                } else {
                  console.warn("[Easel] Unknown operation:", op);
                }
              } catch (e) {
                console.error("[Easel] Error executing op:", op, args, e);
              }
            }
          },
          mounted() {
            this.context = this.el.getContext("2d");

            const initialOps = JSON.parse(this.el.dataset.ops || "[]");
            if (initialOps.length > 0) {
              this.executeOps(initialOps);
            }

            this.handleEvent(`easel:${this.el.id}:draw`, ({ ops }) => {
              this.executeOps(ops);
            });

            this.handleEvent(`easel:${this.el.id}:clear`, () => {
              this.context.clearRect(0, 0, this.el.width, this.el.height);
            });
          }
        }
      </script>
      """
    end

    @doc """
    Pushes draw operations to a canvas element on the client.

    ## Options

      * `:clear` - if `true`, clears the canvas before drawing (default `false`)
    """
    def draw(socket, id, %Easel{} = canvas, opts \\ []) do
      canvas = Easel.render(canvas)

      if opts[:clear] do
        socket
        |> Phoenix.LiveView.push_event("easel:#{id}:clear", %{})
        |> Phoenix.LiveView.push_event("easel:#{id}:draw", %{ops: canvas.ops})
      else
        Phoenix.LiveView.push_event(socket, "easel:#{id}:draw", %{ops: canvas.ops})
      end
    end

    @doc """
    Clears the entire canvas.
    """
    def clear(socket, id) do
      Phoenix.LiveView.push_event(socket, "easel:#{id}:clear", %{})
    end
  end
end
