if Code.ensure_loaded?(Phoenix.LiveView) do
  defmodule Easel.LiveViewTest do
    use ExUnit.Case

    import Phoenix.Component
    import Phoenix.LiveViewTest

    describe "canvas/1 component" do
      test "renders a canvas element with id and hook" do
        assigns = %{}

        html = rendered_to_string(~H"""
          <Easel.LiveView.canvas id="test-canvas" width={300} height={200} />
        """)

        assert html =~ ~s(id="test-canvas")
        assert html =~ ~s(phx-hook=")
        assert html =~ ~s(width="300")
        assert html =~ ~s(height="200")
      end

      test "renders with empty ops by default" do
        assigns = %{}

        html = rendered_to_string(~H"""
          <Easel.LiveView.canvas id="test-canvas" width={100} height={100} />
        """)

        assert html =~ ~s(data-ops="[]")
      end

      test "renders with initial ops" do
        assigns = %{
          ops: [["fillRect", [0, 0, 100, 100]], ["set", ["fillStyle", "red"]]]
        }

        html = rendered_to_string(~H"""
          <Easel.LiveView.canvas id="test-canvas" width={100} height={100} ops={@ops} />
        """)

        assert html =~ ~s(data-ops=")
        refute html =~ ~s(data-ops="[]")
      end

      test "passes through class attribute" do
        assigns = %{}

        html = rendered_to_string(~H"""
          <Easel.LiveView.canvas id="test-canvas" width={100} height={100} class="my-canvas" />
        """)

        assert html =~ ~s(class="my-canvas")
      end

      test "passes through global attributes" do
        assigns = %{}

        html = rendered_to_string(~H"""
          <Easel.LiveView.canvas id="test-canvas" width={100} height={100} style="border: 1px solid" />
        """)

        assert html =~ ~s(style="border: 1px solid")
      end

      test "includes the colocated runtime hook script" do
        assigns = %{}

        html = rendered_to_string(~H"""
          <Easel.LiveView.canvas id="test-canvas" width={100} height={100} />
        """)

        assert html =~ "<script"
        assert html =~ "executeOps"
        assert html =~ "mounted()"
        assert html =~ "handleEvent"
      end

      test "no events by default" do
        assigns = %{}

        html = rendered_to_string(~H"""
          <Easel.LiveView.canvas id="test-canvas" width={100} height={100} />
        """)

        assert html =~ ~s(data-events="[]")
        refute html =~ ~s(tabindex)
      end

      test "on_click enables click event" do
        assigns = %{}

        html = rendered_to_string(~H"""
          <Easel.LiveView.canvas id="test-canvas" width={100} height={100} on_click />
        """)

        assert html =~ ~s(click)
        assert html =~ ~s(data-events=")
        assert html =~ ~s(pushEvent)
      end

      test "on_mouse_move enables mousemove event" do
        assigns = %{}

        html = rendered_to_string(~H"""
          <Easel.LiveView.canvas id="test-canvas" width={100} height={100} on_mouse_move />
        """)

        assert html =~ ~s(mousemove)
      end

      test "on_key_down adds tabindex for focus" do
        assigns = %{}

        html = rendered_to_string(~H"""
          <Easel.LiveView.canvas id="test-canvas" width={100} height={100} on_key_down />
        """)

        assert html =~ ~s(tabindex="0")
        assert html =~ ~s(keydown)
      end

      test "multiple events" do
        assigns = %{}

        html = rendered_to_string(~H"""
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
          |> Easel.API.set_fill_style("blue")
          |> Easel.API.fill_rect(0, 0, 100, 100)

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
          |> Easel.API.fill_rect(0, 0, 50, 50)

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
          |> Easel.API.begin_path()
          |> Easel.API.arc(50, 50, 25, 0, 6.28)
          |> Easel.API.fill()

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
  end
end
