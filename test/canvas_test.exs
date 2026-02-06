defmodule CanvasTest do
  use ExUnit.Case

  describe "Canvas struct" do
    test "new/0 creates a canvas with nil dimensions" do
      canvas = Canvas.new()
      assert %Canvas{width: nil, height: nil, ops: []} = canvas
    end

    test "new/2 creates a canvas with given dimensions" do
      canvas = Canvas.new(800, 600)
      assert %Canvas{width: 800, height: 600, ops: []} = canvas
    end

    test "push_op prepends to ops list" do
      canvas =
        Canvas.new(100, 100)
        |> Canvas.push_op(["fillRect", [0, 0, 50, 50]])
        |> Canvas.push_op(["strokeRect", [10, 10, 30, 30]])

      # ops are in reverse order before render
      assert [["strokeRect", _], ["fillRect", _]] = canvas.ops
    end

    test "render reverses ops to correct order" do
      canvas =
        Canvas.new(100, 100)
        |> Canvas.push_op(["fillRect", [0, 0, 50, 50]])
        |> Canvas.push_op(["strokeRect", [10, 10, 30, 30]])
        |> Canvas.render()

      assert [["fillRect", [0, 0, 50, 50]], ["strokeRect", [10, 10, 30, 30]]] = canvas.ops
    end


  end
end
