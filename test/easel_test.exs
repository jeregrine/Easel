defmodule EaselTest do
  use ExUnit.Case

  describe "Easel struct" do
    test "new/0 creates a canvas with nil dimensions" do
      canvas = Easel.new()
      assert %Easel{width: nil, height: nil, ops: []} = canvas
    end

    test "new/2 creates a canvas with given dimensions" do
      canvas = Easel.new(800, 600)
      assert %Easel{width: 800, height: 600, ops: []} = canvas
    end

    test "push_op prepends to ops list" do
      canvas =
        Easel.new(100, 100)
        |> Easel.push_op(["fillRect", [0, 0, 50, 50]])
        |> Easel.push_op(["strokeRect", [10, 10, 30, 30]])

      # ops are in reverse order before render
      assert [["strokeRect", _], ["fillRect", _]] = canvas.ops
    end

    test "render reverses ops to correct order" do
      canvas =
        Easel.new(100, 100)
        |> Easel.push_op(["fillRect", [0, 0, 50, 50]])
        |> Easel.push_op(["strokeRect", [10, 10, 30, 30]])
        |> Easel.render()

      assert [["fillRect", [0, 0, 50, 50]], ["strokeRect", [10, 10, 30, 30]]] = canvas.ops
    end


  end
end
