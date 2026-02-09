if Code.ensure_loaded?(Phoenix.LiveView) do
  defmodule Easel.LiveViewTest do
    use ExUnit.Case

    import Phoenix.Component
    import Phoenix.LiveViewTest

    describe "canvas/1 component" do
      test "renders a canvas element with id and hook" do
        assigns = %{}

        html =
          rendered_to_string(~H"""
            <Easel.LiveView.canvas id="test-canvas" width={300} height={200} />
          """)

        assert html =~ ~s(id="test-canvas")
        assert html =~ ~s(phx-hook=")
        assert html =~ ~s(width="300")
        assert html =~ ~s(height="200")
      end

      test "renders with empty ops by default" do
        assigns = %{}

        html =
          rendered_to_string(~H"""
            <Easel.LiveView.canvas id="test-canvas" width={100} height={100} />
          """)

        assert html =~ ~s(data-ops="[]")
      end

      test "renders with initial ops" do
        assigns = %{
          ops: [["fillRect", [0, 0, 100, 100]], ["set", ["fillStyle", "red"]]]
        }

        html =
          rendered_to_string(~H"""
            <Easel.LiveView.canvas id="test-canvas" width={100} height={100} ops={@ops} />
          """)

        assert html =~ ~s(data-ops=")
        refute html =~ ~s(data-ops="[]")
      end

      test "passes through class attribute" do
        assigns = %{}

        html =
          rendered_to_string(~H"""
            <Easel.LiveView.canvas id="test-canvas" width={100} height={100} class="my-canvas" />
          """)

        assert html =~ ~s(class="my-canvas")
      end

      test "passes through global attributes" do
        assigns = %{}

        html =
          rendered_to_string(~H"""
            <Easel.LiveView.canvas id="test-canvas" width={100} height={100} style="border: 1px solid" />
          """)

        assert html =~ ~s(style="border: 1px solid")
      end

      test "includes the colocated runtime hook script" do
        assigns = %{}

        html =
          rendered_to_string(~H"""
            <Easel.LiveView.canvas id="test-canvas" width={100} height={100} />
          """)

        assert html =~ "<script"
        assert html =~ "executeOps"
        assert html =~ "mounted()"
        assert html =~ "handleEvent"
      end

      test "no events by default" do
        assigns = %{}

        html =
          rendered_to_string(~H"""
            <Easel.LiveView.canvas id="test-canvas" width={100} height={100} />
          """)

        assert html =~ ~s(data-events="[]")
        refute html =~ ~s(tabindex)
      end

      test "on_click enables click event" do
        assigns = %{}

        html =
          rendered_to_string(~H"""
            <Easel.LiveView.canvas id="test-canvas" width={100} height={100} on_click />
          """)

        assert html =~ ~s(click)
        assert html =~ ~s(data-events=")
        assert html =~ ~s(pushEvent)
      end

      test "on_mouse_move enables mousemove event" do
        assigns = %{}

        html =
          rendered_to_string(~H"""
            <Easel.LiveView.canvas id="test-canvas" width={100} height={100} on_mouse_move />
          """)

        assert html =~ ~s(mousemove)
      end

      test "on_key_down adds tabindex for focus" do
        assigns = %{}

        html =
          rendered_to_string(~H"""
            <Easel.LiveView.canvas id="test-canvas" width={100} height={100} on_key_down />
          """)

        assert html =~ ~s(tabindex="0")
        assert html =~ ~s(keydown)
      end

      test "multiple events" do
        assigns = %{}

        html =
          rendered_to_string(~H"""
            <Easel.LiveView.canvas id="test-canvas" width={100} height={100} on_click on_mouse_down on_mouse_up />
          """)

        assert html =~ ~s(click)
        assert html =~ ~s(mousedown)
        assert html =~ ~s(mouseup)
      end
    end

    describe "draw/3" do
      setup do
        socket = %Phoenix.LiveView.Socket{
          private: %{live_temp: %{}},
          endpoint: nil
        }

        {:ok, socket: socket}
      end

      test "pushes a draw event with ops", %{socket: socket} do
        canvas =
          Easel.new(300, 300)
          |> Easel.set_fill_style("blue")
          |> Easel.fill_rect(0, 0, 100, 100)

        socket = Easel.LiveView.draw(socket, "my-canvas", canvas)
        events = socket.private.live_temp[:push_events]

        assert [["easel:my-canvas:draw", %{ops: ops}]] = events

        assert [
                 ["set", ["fillStyle", "blue"]],
                 ["fillRect", [0, 0, 100, 100]]
               ] = ops
      end

      test "pushes clear then draw with clear: true", %{socket: socket} do
        canvas =
          Easel.new(100, 100)
          |> Easel.fill_rect(0, 0, 50, 50)

        socket = Easel.LiveView.draw(socket, "c1", canvas, clear: true)
        events = socket.private.live_temp[:push_events]

        # push_event prepends, so order is reversed in the list
        assert [
                 ["easel:c1:draw", %{ops: [["fillRect", [0, 0, 50, 50]]]}],
                 ["easel:c1:clear", %{}]
               ] = events
      end

      test "renders ops from Easel.render", %{socket: socket} do
        canvas =
          Easel.new(100, 100)
          |> Easel.begin_path()
          |> Easel.arc(50, 50, 25, 0, 6.28)
          |> Easel.fill()

        socket = Easel.LiveView.draw(socket, "c1", canvas)
        [["easel:c1:draw", %{ops: ops}]] = socket.private.live_temp[:push_events]

        assert [
                 ["beginPath", []],
                 ["arc", [50, 50, 25, 0, 6.28]],
                 ["fill", []]
               ] = ops
      end
    end

    describe "clear/2" do
      test "pushes a clear event" do
        socket = %Phoenix.LiveView.Socket{
          private: %{live_temp: %{}},
          endpoint: nil
        }

        socket = Easel.LiveView.clear(socket, "my-canvas")
        events = socket.private.live_temp[:push_events]

        assert [["easel:my-canvas:clear", %{}]] = events
      end
    end

    describe "animate/5" do
      setup do
        socket = %Phoenix.LiveView.Socket{
          private: %{live_temp: %{}},
          endpoint: nil,
          assigns: %{__changed__: %{}, counter: 0}
        }

        {:ok, socket: socket}
      end

      test "stores animation state in assigns", %{socket: socket} do
        tick_fn = fn count ->
          canvas = Easel.new(100, 100) |> Easel.fill_rect(0, 0, count, count)
          {canvas, count + 1}
        end

        socket = Easel.LiveView.animate(socket, "anim-canvas", :counter, tick_fn)

        anim = socket.assigns[:easel_anim_anim_canvas]
        assert anim.running == true
        assert anim.state_key == :counter
        assert anim.interval == 16
        assert is_function(anim.tick_fn, 1)
      end

      test "animate with custom interval", %{socket: socket} do
        tick_fn = fn s -> {Easel.new(10, 10), s} end

        socket = Easel.LiveView.animate(socket, "c1", :counter, tick_fn, interval: 1000)

        anim = socket.assigns[:easel_anim_c1]
        assert anim.interval == 1000
      end

      test "animate with canvas_assign", %{socket: socket} do
        socket = assign(socket, :canvas, nil)

        tick_fn = fn count ->
          canvas = Easel.new(100, 100) |> Easel.fill_rect(0, 0, count, count)
          {canvas, count + 1}
        end

        socket = Easel.LiveView.animate(socket, "c1", :counter, tick_fn, canvas_assign: :canvas)

        anim = socket.assigns[:easel_anim_c1]
        assert anim.canvas_assign == :canvas
      end

      test "tick calls tick_fn and updates state", %{socket: socket} do
        tick_fn = fn count ->
          canvas = Easel.new(100, 100) |> Easel.fill_rect(0, 0, count, count)
          {canvas, count + 1}
        end

        socket = Easel.LiveView.animate(socket, "anim-canvas", :counter, tick_fn)
        socket = Easel.LiveView.tick(socket, "anim-canvas")

        # Counter should have advanced
        assert socket.assigns.counter == 1
      end

      test "tick updates canvas_assign when set", %{socket: socket} do
        socket = assign(socket, :canvas, nil)

        tick_fn = fn count ->
          canvas = Easel.new(100, 100) |> Easel.fill_rect(0, 0, count, count)
          {canvas, count + 1}
        end

        socket = Easel.LiveView.animate(socket, "c1", :counter, tick_fn, canvas_assign: :canvas)
        socket = Easel.LiveView.tick(socket, "c1")

        assert %Easel{ops: [_ | _]} = socket.assigns.canvas
      end

      test "stop_animation sets running to false", %{socket: socket} do
        tick_fn = fn s -> {Easel.new(10, 10), s} end

        socket = Easel.LiveView.animate(socket, "c1", :counter, tick_fn)
        socket = Easel.LiveView.stop_animation(socket, "c1")

        anim = socket.assigns[:easel_anim_c1]
        assert anim.running == false
      end

      test "tick does nothing when stopped", %{socket: socket} do
        tick_fn = fn count ->
          {Easel.new(10, 10) |> Easel.fill_rect(0, 0, 10, 10), count + 1}
        end

        socket = Easel.LiveView.animate(socket, "c1", :counter, tick_fn)
        socket = Easel.LiveView.stop_animation(socket, "c1")
        socket = Easel.LiveView.tick(socket, "c1")

        # Counter should not have advanced
        assert socket.assigns.counter == 0
      end

      test "stop_animation is safe when no animation exists", %{socket: socket} do
        socket = Easel.LiveView.stop_animation(socket, "nonexistent")
        assert socket == socket
      end
    end

    describe "canvas_stack/1 component" do
      test "renders a container div with layers" do
        assigns = %{
          bg_ops: [["fillRect", [0, 0, 100, 100]]],
          fg_ops: [["strokeRect", [10, 10, 50, 50]]]
        }

        html =
          rendered_to_string(~H"""
            <Easel.LiveView.canvas_stack id="game" width={800} height={600}>
              <:layer id="bg" ops={@bg_ops} />
              <:layer id="fg" ops={@fg_ops} />
            </Easel.LiveView.canvas_stack>
          """)

        assert html =~ ~s(id="game")
        assert html =~ ~s(position: relative)
        assert html =~ ~s(width: 800px)
        assert html =~ ~s(height: 600px)
        assert html =~ ~s(id="bg")
        assert html =~ ~s(id="fg")
        assert html =~ ~s(position: absolute)
      end

      test "each layer is an independent canvas with hook" do
        assigns = %{}

        html =
          rendered_to_string(~H"""
            <Easel.LiveView.canvas_stack id="stack" width={100} height={100}>
              <:layer id="l1" ops={[]} />
              <:layer id="l2" ops={[]} />
            </Easel.LiveView.canvas_stack>
          """)

        # Both layers get phx-hook
        # 2 hooks + 1 = 3 parts
        assert length(String.split(html, "phx-hook")) == 3
      end

      test "layers pass through event flags" do
        assigns = %{}

        html =
          rendered_to_string(~H"""
            <Easel.LiveView.canvas_stack id="stack" width={100} height={100}>
              <:layer id="bg" ops={[]} />
              <:layer id="fg" ops={[]} on_click />
            </Easel.LiveView.canvas_stack>
          """)

        assert html =~ ~s(click)
      end
    end

    describe "templates in draw/3" do
      setup do
        socket = %Phoenix.LiveView.Socket{
          private: %{live_temp: %{}},
          endpoint: nil
        }

        {:ok, socket: socket}
      end

      test "includes templates in draw payload when present", %{socket: socket} do
        canvas =
          Easel.new(100, 100)
          |> Easel.template(:dot, fn c ->
            c |> Easel.begin_path() |> Easel.fill()
          end)
          |> Easel.instances(:dot, [%{x: 10, y: 20}])

        socket = Easel.LiveView.draw(socket, "c1", canvas)
        [["easel:c1:draw", payload]] = socket.private.live_temp[:push_events]

        assert Map.has_key?(payload, :templates)
        assert Map.has_key?(payload.templates, :dot)
      end

      test "omits templates when none defined", %{socket: socket} do
        canvas =
          Easel.new(100, 100)
          |> Easel.fill_rect(0, 0, 100, 100)

        socket = Easel.LiveView.draw(socket, "c1", canvas)
        [["easel:c1:draw", payload]] = socket.private.live_temp[:push_events]

        refute Map.has_key?(payload, :templates)
      end
    end
  end
end
