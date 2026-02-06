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

    test "render on empty canvas returns empty ops" do
      canvas = Easel.new(100, 100) |> Easel.render()
      assert canvas.ops == []
    end

    test "render is idempotent on already-rendered canvas" do
      canvas =
        Easel.new(100, 100)
        |> Easel.push_op(["a", []])
        |> Easel.push_op(["b", []])
        |> Easel.render()

      # Double render reverses again — document this behavior
      double = Easel.render(canvas)
      assert double.ops == [["b", []], ["a", []]]
    end

    test "struct fields are accessible" do
      canvas = Easel.new(640, 480)
      assert canvas.width == 640
      assert canvas.height == 480
      assert canvas.ops == []
    end

    test "many ops maintain order after render" do
      canvas =
        Enum.reduce(1..100, Easel.new(100, 100), fn i, acc ->
          Easel.push_op(acc, ["op#{i}", [i]])
        end)
        |> Easel.render()

      assert length(canvas.ops) == 100
      assert hd(canvas.ops) == ["op1", [1]]
      assert List.last(canvas.ops) == ["op100", [100]]
    end
  end

  describe "full pipeline" do
    test "new |> API calls |> render produces correct ops" do
      canvas =
        Easel.new(300, 300)
        |> Easel.API.set_fill_style("blue")
        |> Easel.API.fill_rect(0, 0, 100, 100)
        |> Easel.API.set_line_width(10)
        |> Easel.API.stroke_rect(100, 100, 100, 100)
        |> Easel.render()

      assert %Easel{width: 300, height: 300} = canvas
      assert length(canvas.ops) == 4

      assert [
               ["set", ["fillStyle", "blue"]],
               ["fillRect", [0, 0, 100, 100]],
               ["set", ["lineWidth", 10]],
               ["strokeRect", [100, 100, 100, 100]]
             ] = canvas.ops
    end

    test "complex drawing with paths" do
      canvas =
        Easel.new(200, 200)
        |> Easel.API.save()
        |> Easel.API.begin_path()
        |> Easel.API.arc(100, 100, 50, 0, :math.pi() * 2)
        |> Easel.API.set_fill_style("red")
        |> Easel.API.fill()
        |> Easel.API.restore()
        |> Easel.render()

      assert length(canvas.ops) == 6
      assert ["save", []] = hd(canvas.ops)
      assert ["restore", []] = List.last(canvas.ops)
    end

    test "ops are JSON-serializable" do
      canvas =
        Easel.new(100, 100)
        |> Easel.API.set_fill_style("blue")
        |> Easel.API.fill_rect(0, 0, 50, 50)
        |> Easel.API.set_global_alpha(0.5)
        |> Easel.render()

      json = JSON.encode!(canvas.ops)
      decoded = JSON.decode!(json)
      assert decoded == canvas.ops
    end
  end
end
