if Code.ensure_loaded?(Phoenix.LiveView) do
  defmodule Canvas.LiveViewTest do
    use ExUnit.Case

    import Phoenix.Component
    import Phoenix.LiveViewTest

    describe "canvas/1 component" do
      test "renders a canvas element with id and hook" do
        assigns = %{}

        html = rendered_to_string(~H"""
          <Canvas.LiveView.canvas id="test-canvas" width={300} height={200} />
        """)

        assert html =~ ~s(id="test-canvas")
        assert html =~ ~s(phx-hook=")
        assert html =~ ~s(width="300")
        assert html =~ ~s(height="200")
      end

      test "renders with empty ops by default" do
        assigns = %{}

        html = rendered_to_string(~H"""
          <Canvas.LiveView.canvas id="test-canvas" width={100} height={100} />
        """)

        assert html =~ ~s(data-ops="[]")
      end

      test "renders with initial ops" do
        assigns = %{
          ops: [["fillRect", [0, 0, 100, 100]], ["set", ["fillStyle", "red"]]]
        }

        html = rendered_to_string(~H"""
          <Canvas.LiveView.canvas id="test-canvas" width={100} height={100} ops={@ops} />
        """)

        assert html =~ ~s(data-ops=")
        refute html =~ ~s(data-ops="[]")
      end

      test "passes through class attribute" do
        assigns = %{}

        html = rendered_to_string(~H"""
          <Canvas.LiveView.canvas id="test-canvas" width={100} height={100} class="my-canvas" />
        """)

        assert html =~ ~s(class="my-canvas")
      end

      test "passes through global attributes" do
        assigns = %{}

        html = rendered_to_string(~H"""
          <Canvas.LiveView.canvas id="test-canvas" width={100} height={100} style="border: 1px solid" />
        """)

        assert html =~ ~s(style="border: 1px solid")
      end

      test "includes the colocated runtime hook script" do
        assigns = %{}

        html = rendered_to_string(~H"""
          <Canvas.LiveView.canvas id="test-canvas" width={100} height={100} />
        """)

        assert html =~ "<script"
        assert html =~ "executeOps"
        assert html =~ "mounted()"
        assert html =~ "handleEvent"
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
          Canvas.new(300, 300)
          |> Canvas.API.set_fill_style("blue")
          |> Canvas.API.fill_rect(0, 0, 100, 100)

        socket = Canvas.LiveView.draw(socket, "my-canvas", canvas)
        events = socket.private.live_temp[:push_events]

        assert [["canvas:my-canvas:draw", %{ops: ops}]] = events

        assert [
                 ["set", ["fillStyle", "blue"]],
                 ["fillRect", [0, 0, 100, 100]]
               ] = ops
      end

      test "pushes clear then draw with clear: true", %{socket: socket} do
        canvas =
          Canvas.new(100, 100)
          |> Canvas.API.fill_rect(0, 0, 50, 50)

        socket = Canvas.LiveView.draw(socket, "c1", canvas, clear: true)
        events = socket.private.live_temp[:push_events]

        # push_event prepends, so order is reversed in the list
        assert [
                 ["canvas:c1:draw", %{ops: [["fillRect", [0, 0, 50, 50]]]}],
                 ["canvas:c1:clear", %{}]
               ] = events
      end

      test "renders ops from Canvas.render", %{socket: socket} do
        canvas =
          Canvas.new(100, 100)
          |> Canvas.API.begin_path()
          |> Canvas.API.arc(50, 50, 25, 0, 6.28)
          |> Canvas.API.fill()

        socket = Canvas.LiveView.draw(socket, "c1", canvas)
        [["canvas:c1:draw", %{ops: ops}]] = socket.private.live_temp[:push_events]

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

        socket = Canvas.LiveView.clear(socket, "my-canvas")
        events = socket.private.live_temp[:push_events]

        assert [["canvas:my-canvas:clear", %{}]] = events
      end
    end
  end
end
