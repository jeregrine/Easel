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

    ## Events

    Enable mouse and keyboard events by setting the corresponding attributes.
    Events are sent as LiveView events with the canvas id as a prefix:

        <Easel.LiveView.canvas
          id="my-canvas"
          width={300}
          height={300}
          on_click
          on_mouse_move
          on_key_down
        />

    Then handle them in your LiveView:

        def handle_event("my-canvas:click", %{"x" => x, "y" => y}, socket) do
          # ...
          {:noreply, socket}
        end

        def handle_event("my-canvas:mousemove", %{"x" => x, "y" => y}, socket) do
          # ...
          {:noreply, socket}
        end

        def handle_event("my-canvas:keydown", %{"key" => key}, socket) do
          # ...
          {:noreply, socket}
        end

    Available event attributes: `on_click`, `on_mouse_down`, `on_mouse_up`,
    `on_mouse_move`, `on_key_down`.
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
      * `on_click` - enable click events (pushes `"\#{id}:click"`)
      * `on_mouse_down` - enable mousedown events (pushes `"\#{id}:mousedown"`)
      * `on_mouse_up` - enable mouseup events (pushes `"\#{id}:mouseup"`)
      * `on_mouse_move` - enable mousemove events (pushes `"\#{id}:mousemove"`)
      * `on_key_down` - enable keydown events (pushes `"\#{id}:keydown"`)

    Any additional attributes are passed through to the `<canvas>` element.
    """
    attr :id, :string, required: true
    attr :width, :integer, default: nil
    attr :height, :integer, default: nil
    attr :ops, :list, default: []
    attr :class, :string, default: nil
    attr :on_click, :boolean, default: false
    attr :on_mouse_down, :boolean, default: false
    attr :on_mouse_up, :boolean, default: false
    attr :on_mouse_move, :boolean, default: false
    attr :on_key_down, :boolean, default: false
    attr :rest, :global

    def canvas(assigns) do
      events =
        []
        |> then(fn e -> if assigns.on_click, do: ["click" | e], else: e end)
        |> then(fn e -> if assigns.on_mouse_down, do: ["mousedown" | e], else: e end)
        |> then(fn e -> if assigns.on_mouse_up, do: ["mouseup" | e], else: e end)
        |> then(fn e -> if assigns.on_mouse_move, do: ["mousemove" | e], else: e end)
        |> then(fn e -> if assigns.on_key_down, do: ["keydown" | e], else: e end)

      assigns = assign(assigns, :events, Phoenix.json_library().encode!(events))

      ~H"""
      <canvas
        id={@id}
        phx-hook=".Easel"
        width={@width}
        height={@height}
        class={@class}
        tabindex={if @on_key_down, do: "0"}
        data-ops={Phoenix.json_library().encode!(@ops)}
        data-events={@events}
        {@rest}
      />
      <script :type={ColocatedHook} name=".Easel" runtime>
        {
          canvasXY(e) {
            const rect = this.el.getBoundingClientRect();
            return {
              x: Math.round(e.clientX - rect.left),
              y: Math.round(e.clientY - rect.top)
            };
          },
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

            const events = JSON.parse(this.el.dataset.events || "[]");
            const id = this.el.id;

            for (const eventType of events) {
              if (eventType === "keydown") {
                this.el.addEventListener("keydown", (e) => {
                  this.pushEvent(`${id}:keydown`, {
                    key: e.key,
                    code: e.code,
                    ctrl: e.ctrlKey,
                    shift: e.shiftKey,
                    alt: e.altKey,
                    meta: e.metaKey
                  });
                });
              } else {
                this.el.addEventListener(eventType, (e) => {
                  this.pushEvent(`${id}:${eventType}`, this.canvasXY(e));
                });
              }
            }
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

    @doc """
    Starts a server-side animation loop that redraws a canvas at a fixed interval.

    The `tick_fn` receives the current state and must return `{%Easel{}, new_state}`.
    Each frame is pushed to the client as a clear+draw sequence.

    Returns the socket with the animation state stored in assigns.

    ## Options

      * `:interval` - milliseconds between frames (default `16`, ~60fps)
      * `:clear` - if `true`, clears before each frame (default `true`)

    ## Example

    In your LiveView `mount/3`:

        def mount(_params, _session, socket) do
          socket =
            socket
            |> assign(:balls, initial_balls())
            |> Easel.LiveView.animate("my-canvas", :balls, fn balls ->
              new_balls = tick(balls)
              canvas = render_balls(new_balls)
              {canvas, new_balls}
            end)

          {:ok, socket}
        end

    The animation is identified by the canvas id. To stop it:

        Easel.LiveView.stop_animation(socket, "my-canvas")

    Your LiveView must include a `handle_info` clause to receive ticks:

        def handle_info({:easel_tick, id}, socket) do
          {:noreply, Easel.LiveView.tick(socket, id)}
        end
    """
    def animate(socket, id, state_key, tick_fn, opts \\ []) do
      interval = Keyword.get(opts, :interval, 16)
      clear = Keyword.get(opts, :clear, true)

      anim_key = animation_key(id)

      Process.send_after(self(), {:easel_tick, id}, interval)

      Phoenix.Component.assign(socket, anim_key, %{
        tick_fn: tick_fn,
        state_key: state_key,
        interval: interval,
        clear: clear,
        running: true
      })
    end

    @doc """
    Processes an animation tick. Call this from your `handle_info`:

        def handle_info({:easel_tick, id}, socket) do
          {:noreply, Easel.LiveView.tick(socket, id)}
        end
    """
    def tick(socket, id) do
      anim_key = animation_key(id)
      anim = socket.assigns[anim_key]

      if anim && anim.running do
        state = socket.assigns[anim.state_key]
        {canvas, new_state} = anim.tick_fn.(state)

        # Schedule next tick
        Process.send_after(self(), {:easel_tick, id}, anim.interval)

        socket
        |> Phoenix.Component.assign(anim.state_key, new_state)
        |> draw(id, canvas, clear: anim.clear)
      else
        socket
      end
    end

    @doc """
    Stops a running animation.
    """
    def stop_animation(socket, id) do
      anim_key = animation_key(id)
      anim = socket.assigns[anim_key]

      if anim do
        Phoenix.Component.assign(socket, anim_key, %{anim | running: false})
      else
        socket
      end
    end

    defp animation_key(id), do: String.to_atom("easel_anim_#{id}")
  end
end
