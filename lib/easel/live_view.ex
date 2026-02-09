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
            |> Easel.set_fill_style("blue")
            |> Easel.fill_rect(0, 0, 100, 100)
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

    ## Layers

    Use `canvas_stack/1` to layer multiple canvases. Each layer is an
    independent `<canvas>` element stacked via CSS. Only layers whose
    assigns change get re-patched — static layers like backgrounds are
    sent once:

        <Easel.LiveView.canvas_stack id="game" width={800} height={600}>
          <:layer id="background" ops={@background.ops} />
          <:layer id="sprites" ops={@sprites.ops} templates={@sprites.templates} />
          <:layer id="ui" ops={@ui.ops} />
        </Easel.LiveView.canvas_stack>

    ## Templates and Instances

    For scenes with many similar shapes, define a template once and stamp
    out instances. The template ops are cached client-side; only the
    per-instance data (position, rotation, color) is sent each frame:

        canvas =
          Easel.new(800, 600)
          |> Easel.template(:boid, fn c ->
            c
            |> Easel.begin_path()
            |> Easel.move_to(12, 0)
            |> Easel.line_to(-4, -5)
            |> Easel.line_to(-4, 5)
            |> Easel.close_path()
            |> Easel.fill()
          end)
          |> Easel.instances(:boid, instances)
          |> Easel.render()

    Pass templates alongside ops in your template:

        <Easel.LiveView.canvas id="c" ops={@canvas.ops} templates={@canvas.templates} ... />

    ## Animation

    Start a server-side animation loop:

        def mount(_params, _session, socket) do
          socket =
            socket
            |> assign(:state, initial_state())
            |> assign(:canvas, Easel.new(600, 400) |> Easel.render())
            |> Easel.LiveView.animate("my-canvas", :state, fn state ->
              new_state = tick(state)
              canvas = render(new_state)
              {canvas, new_state}
            end, interval: 16, canvas_assign: :canvas)

          {:ok, socket}
        end

        def handle_info({:easel_tick, id}, socket) do
          {:noreply, Easel.LiveView.tick(socket, id)}
        end

    The canvas is redrawn each tick via LiveView's normal rendering cycle.
    The hook uses `requestAnimationFrame` to sync draws with the browser's
    refresh rate — multiple server updates between frames are coalesced.
    """

    use Phoenix.Component

    alias Phoenix.LiveView.ColocatedHook

    @doc """
    Renders a `<canvas>` element wired to a colocated LiveView hook.

    ## Attributes

      * `id` (required) - unique DOM id, also used to target draw commands
      * `width` - canvas width in pixels
      * `height` - canvas height in pixels
      * `ops` - list of ops to draw (default `[]`). When this changes, the
        hook automatically clears and redraws.
      * `class` - CSS class for the canvas element
      * `on_click` - enable click events (pushes `"\#{id}:click"`)
      * `on_mouse_down` - enable mousedown events (pushes `"\#{id}:mousedown"`)
      * `on_mouse_up` - enable mouseup events (pushes `"\#{id}:mouseup"`)
      * `on_mouse_move` - enable mousemove events (pushes `"\#{id}:mousemove"`)
      * `on_key_down` - enable keydown events (pushes `"\#{id}:keydown"`)

    Any additional attributes are passed through to the `<canvas>` element.
    """
    attr(:id, :string, required: true)
    attr(:width, :integer, default: nil)
    attr(:height, :integer, default: nil)
    attr(:ops, :list, default: [])
    attr(:templates, :map, default: %{})
    attr(:class, :string, default: nil)
    attr(:on_click, :boolean, default: false)
    attr(:on_mouse_down, :boolean, default: false)
    attr(:on_mouse_up, :boolean, default: false)
    attr(:on_mouse_move, :boolean, default: false)
    attr(:on_key_down, :boolean, default: false)
    attr(:rest, :global)

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
        data-templates={Phoenix.json_library().encode!(@templates)}
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
                if (op === "__instances") {
                  this.drawInstances(args[0], args[1], args[2] || []);
                } else if (op === "set") {
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
          drawInstances(name, rows, palette) {
            const tpl = this.templates[name];
            if (!tpl) { console.warn("[Easel] Unknown template:", name); return; }
            const ctx = this.context;
            for (const row of rows) {
              ctx.save();
              ctx.translate(row[0] ?? 0, row[1] ?? 0);
              if (row[2] != null) ctx.rotate(row[2]);
              if (row[3] != null || row[4] != null)
                ctx.scale(row[3] ?? 1, row[4] ?? 1);
              if (row[5] != null && palette[row[5]] != null) ctx.fillStyle = palette[row[5]];
              if (row[6] != null && palette[row[6]] != null) ctx.strokeStyle = palette[row[6]];
              if (row[7] != null) ctx.globalAlpha = row[7];
              this.executeOps(tpl);
              ctx.restore();
            }
          },
          loadTemplates() {
            const raw = this.el.dataset.templates || "{}";
            const parsed = JSON.parse(raw);
            this.templates = Object.assign(this.templates || {}, parsed);
          },
          drawFromData() {
            this.ensureDpr();
            this.loadTemplates();
            const ops = JSON.parse(this.el.dataset.ops || "[]");
            if (ops.length > 0) {
              const ctx = this.context;
              const dpr = this.dpr || 1;
              ctx.setTransform(1, 0, 0, 1, 0, 0);
              ctx.clearRect(0, 0, this.el.width, this.el.height);
              ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
              this.executeOps(ops);
            }
          },
          scheduleFrame() {
            if (this._rafId) return;
            this._rafId = requestAnimationFrame(() => {
              this._rafId = null;
              if (this._dirty) {
                this._dirty = false;
                this.drawFromData();
              }
            });
          },
          ensureDpr() {
            const dpr = window.devicePixelRatio || 1;
            this.dpr = dpr;
            const w = this._logicalW || parseInt(this.el.getAttribute("width")) || this.el.width;
            const h = this._logicalH || parseInt(this.el.getAttribute("height")) || this.el.height;
            this._logicalW = w;
            this._logicalH = h;
            if (this.el.width !== w * dpr || this.el.height !== h * dpr) {
              this.el.width = w * dpr;
              this.el.height = h * dpr;
              this.el.style.width = w + "px";
              this.el.style.height = h + "px";
            }
          },
          mounted() {
            this.ensureDpr();
            this.context = this.el.getContext("2d");
            this.templates = {};
            this._dirty = false;
            this._rafId = null;
            this.drawFromData();

            this.handleEvent(`easel:${this.el.id}:draw`, ({ ops, templates }) => {
              if (templates) Object.assign(this.templates, templates);
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
          },
          updated() {
            this._dirty = true;
            this.scheduleFrame();
          },
          destroyed() {
            if (this._rafId) cancelAnimationFrame(this._rafId);
          }
        }
      </script>
      """
    end

    @doc """
    Renders an export button that downloads the canvas as a PNG image.

    When clicked, converts the target canvas to a PNG and triggers a
    browser file download.

    ## Attributes

      * `for` (required) — the DOM id of the canvas to export
      * `filename` — download filename (default `"canvas.png"`)
      * `class` — CSS class for the button

    Any additional attributes are passed through to the `<button>` element.

    ## Example

        <Easel.LiveView.canvas id="my-canvas" width={300} height={300} ops={@ops} />
        <Easel.LiveView.export_button for="my-canvas" filename="drawing.png">
          Export PNG
        </Easel.LiveView.export_button>
    """
    attr(:for, :string, required: true)
    attr(:filename, :string, default: "canvas.png")
    attr(:class, :string, default: nil)
    attr(:rest, :global)
    slot(:inner_block, required: true)

    def export_button(assigns) do
      ~H"""
      <button
        class={@class}
        phx-hook=".EaselExport"
        id={"easel-export-#{@for}"}
        data-canvas-id={@for}
        data-filename={@filename}
        {@rest}
      >
        {render_slot(@inner_block)}
      </button>
      <script :type={ColocatedHook} name=".EaselExport" runtime>
        {
          mounted() {
            this.el.addEventListener("click", (e) => {
              e.preventDefault();
              const canvasId = this.el.dataset.canvasId;
              const filename = this.el.dataset.filename || "canvas.png";

              // Find the canvas - check for canvas_stack (multiple layers)
              const stack = document.getElementById(canvasId);
              let srcCanvas;
              if (stack && stack.tagName !== "CANVAS") {
                // canvas_stack — composite all layers onto a temp canvas
                const layers = stack.querySelectorAll("canvas");
                if (layers.length === 0) return;
                srcCanvas = layers[0];
                if (layers.length > 1) {
                  const tmp = document.createElement("canvas");
                  tmp.width = srcCanvas.width;
                  tmp.height = srcCanvas.height;
                  const ctx = tmp.getContext("2d");
                  for (const layer of layers) ctx.drawImage(layer, 0, 0);
                  srcCanvas = tmp;
                }
              } else {
                srcCanvas = stack;
              }
              if (!srcCanvas) return;

              // Export at logical (1x) resolution to avoid DPR scaling
              const logicalW = parseInt(srcCanvas.getAttribute("width")) || srcCanvas.width;
              const logicalH = parseInt(srcCanvas.getAttribute("height")) || srcCanvas.height;
              const out = document.createElement("canvas");
              out.width = logicalW;
              out.height = logicalH;
              out.getContext("2d").drawImage(srcCanvas, 0, 0, logicalW, logicalH);

              const link = document.createElement("a");
              link.download = filename;
              link.href = out.toDataURL("image/png");
              link.click();
            });
          }
        }
      </script>
      """
    end

    @doc """
    Renders a stack of layered canvases. Each layer is an independent
    `<canvas>` element, stacked via CSS `position: absolute`. Only layers
    whose ops change get redrawn — LiveView's normal diffing handles this.

    ## Example

        <Easel.LiveView.canvas_stack id="game" width={800} height={600}>
          <:layer id="background" ops={@background.ops} />
          <:layer id="sprites" ops={@sprites.ops} templates={@sprites.templates} />
          <:layer id="ui" ops={@ui.ops} />
        </Easel.LiveView.canvas_stack>

    ## Slots

    Each `:layer` slot accepts:

      * `id` (required) — unique DOM id for this layer's canvas
      * `ops` — list of drawing operations
      * `templates` — map of template definitions (for instance rendering)
      * `on_click`, `on_mouse_down`, `on_mouse_up`, `on_mouse_move`, `on_key_down` — event flags

    Only the topmost layer with event flags will receive pointer events.
    Lower layers have `pointer-events: none` by default.
    """
    attr(:id, :string, required: true)
    attr(:width, :integer, required: true)
    attr(:height, :integer, required: true)
    attr(:class, :string, default: nil)
    attr(:rest, :global)

    slot :layer, required: true do
      attr(:id, :string, required: true)
      attr(:ops, :list)
      attr(:templates, :map)
      attr(:on_click, :boolean)
      attr(:on_mouse_down, :boolean)
      attr(:on_mouse_up, :boolean)
      attr(:on_mouse_move, :boolean)
      attr(:on_key_down, :boolean)
    end

    def canvas_stack(assigns) do
      ~H"""
      <div id={@id} class={@class} style={"position: relative; width: #{@width}px; height: #{@height}px;"} {@rest}>
        <.canvas
          :for={layer <- @layer}
          id={layer.id}
          width={@width}
          height={@height}
          ops={Map.get(layer, :ops, [])}
          templates={Map.get(layer, :templates, %{})}
          style="position: absolute; top: 0; left: 0;"
          on_click={Map.get(layer, :on_click, false)}
          on_mouse_down={Map.get(layer, :on_mouse_down, false)}
          on_mouse_up={Map.get(layer, :on_mouse_up, false)}
          on_mouse_move={Map.get(layer, :on_mouse_move, false)}
          on_key_down={Map.get(layer, :on_key_down, false)}
        />
      </div>
      """
    end

    @doc """
    Pushes draw operations to a canvas element on the client.

    This uses `push_event` to send ops directly to the hook without
    going through the normal render cycle. Useful for one-off draws
    from event handlers.

    ## Options

      * `:clear` - if `true`, clears the canvas before drawing (default `false`)
    """
    def draw(socket, id, %Easel{} = canvas, opts \\ []) do
      canvas = Easel.render(canvas)

      payload =
        if map_size(canvas.templates) > 0 do
          %{ops: canvas.ops, templates: canvas.templates}
        else
          %{ops: canvas.ops}
        end

      if opts[:clear] do
        socket
        |> Phoenix.LiveView.push_event("easel:#{id}:clear", %{})
        |> Phoenix.LiveView.push_event("easel:#{id}:draw", payload)
      else
        Phoenix.LiveView.push_event(socket, "easel:#{id}:draw", payload)
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
    Each frame, the rendered ops are stored in a canvas assign so the template
    re-renders and the hook redraws automatically.

    Returns the socket with the animation state stored in assigns.

    ## Options

      * `:interval` - milliseconds between frames (default `16`, ~60fps)
      * `:canvas_assign` - assign key to store the rendered canvas
        (default: same as `state_key`). Your template should bind
        `ops={@canvas_assign_key.ops}` (or wherever you read ops from).

    ## Example

    In your LiveView `mount/3`:

        def mount(_params, _session, socket) do
          initial = %{balls: [...], canvas: Easel.new(600, 400)}

          socket =
            socket
            |> assign(:state, initial)
            |> Easel.LiveView.animate("my-canvas", :state, fn state ->
              new_balls = tick(state.balls)
              canvas = render_balls(new_balls)
              {canvas, %{state | balls: new_balls, canvas: canvas}}
            end)

          {:ok, socket}
        end

    Your LiveView must include a `handle_info` clause to receive ticks:

        def handle_info({:easel_tick, id}, socket) do
          {:noreply, Easel.LiveView.tick(socket, id)}
        end

    To stop the animation:

        Easel.LiveView.stop_animation(socket, "my-canvas")
    """
    def animate(socket, id, state_key, tick_fn, opts \\ []) do
      interval = Keyword.get(opts, :interval, 16)
      canvas_assign = Keyword.get(opts, :canvas_assign, nil)

      anim_key = animation_key(id)

      if Phoenix.LiveView.connected?(socket) do
        Process.send_after(self(), {:easel_tick, id}, interval)
      end

      Phoenix.Component.assign(socket, anim_key, %{
        tick_fn: tick_fn,
        state_key: state_key,
        canvas_assign: canvas_assign,
        interval: interval,
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
        canvas = Easel.render(canvas)

        # Schedule next tick
        Process.send_after(self(), {:easel_tick, id}, anim.interval)

        socket = Phoenix.Component.assign(socket, anim.state_key, new_state)

        # Update canvas assign so the template re-renders with new ops
        if anim.canvas_assign do
          Phoenix.Component.assign(socket, anim.canvas_assign, canvas)
        else
          socket
        end
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

    defp animation_key(id) do
      safe = String.replace(id, ~r/[^a-zA-Z0-9_]/, "_")
      String.to_atom("easel_anim_#{safe}")
    end
  end
end
