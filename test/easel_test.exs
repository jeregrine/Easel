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

      # Double render is a no-op — safe to call multiple times
      double = Easel.render(canvas)
      assert double.ops == [["a", []], ["b", []]]
      assert double.rendered == true
    end

    test "push_op after render resets rendered flag" do
      canvas =
        Easel.new(100, 100)
        |> Easel.push_op(["a", []])
        |> Easel.render()

      assert canvas.rendered == true

      canvas = Easel.push_op(canvas, ["c", []])
      assert canvas.rendered == false

      canvas = Easel.render(canvas)
      assert canvas.ops == [["a", []], ["c", []]]
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

  describe "templates and instances" do
    test "template defines reusable ops" do
      canvas =
        Easel.new(100, 100)
        |> Easel.template(:dot, fn c ->
          c
          |> Easel.API.begin_path()
          |> Easel.API.arc(0, 0, 5, 0, :math.pi() * 2)
          |> Easel.API.fill()
        end)

      assert Map.has_key?(canvas.templates, :dot)
      assert [["beginPath", []], ["arc", _], ["fill", []]] = canvas.templates[:dot]
    end

    test "instances emits __instances op" do
      canvas =
        Easel.new(100, 100)
        |> Easel.template(:dot, fn c ->
          c |> Easel.API.begin_path() |> Easel.API.arc(0, 0, 5, 0, 6.28) |> Easel.API.fill()
        end)
        |> Easel.instances(:dot, [%{x: 10, y: 20}, %{x: 30, y: 40}])
        |> Easel.render()

      assert [["__instances", ["dot", instances]]] = canvas.ops
      assert length(instances) == 2
      assert hd(instances) == %{x: 10, y: 20}
    end

    test "templates + ops are JSON-serializable" do
      canvas =
        Easel.new(100, 100)
        |> Easel.template(:tri, fn c ->
          c
          |> Easel.API.begin_path()
          |> Easel.API.move_to(0, -5)
          |> Easel.API.line_to(-5, 5)
          |> Easel.API.line_to(5, 5)
          |> Easel.API.close_path()
          |> Easel.API.fill()
        end)
        |> Easel.API.set_fill_style("#000")
        |> Easel.API.fill_rect(0, 0, 100, 100)
        |> Easel.instances(:tri, [%{x: 50, y: 50, rotate: 1.0, fill: "red"}])
        |> Easel.render()

      # ops serialize
      json = JSON.encode!(canvas.ops)
      assert is_binary(json)

      # templates serialize
      tjson = JSON.encode!(canvas.templates)
      assert is_binary(tjson)

      # round-trip
      decoded = JSON.decode!(tjson)
      assert Map.has_key?(decoded, "tri")
    end

    test "multiple templates on one canvas" do
      canvas =
        Easel.new(100, 100)
        |> Easel.template(:a, fn c -> Easel.API.fill(c) end)
        |> Easel.template(:b, fn c -> Easel.API.stroke(c) end)

      assert map_size(canvas.templates) == 2
      assert canvas.templates[:a] == [["fill", []]]
      assert canvas.templates[:b] == [["stroke", []]]
    end

    test "instances with transform options" do
      canvas =
        Easel.new(100, 100)
        |> Easel.template(:t, fn c -> Easel.API.fill(c) end)
        |> Easel.instances(:t, [
          %{x: 10, y: 20, rotate: 1.5, scale_x: 2.0, scale_y: 0.5, fill: "red", stroke: "blue", alpha: 0.5}
        ])
        |> Easel.render()

      [["__instances", ["t", [inst]]]] = canvas.ops
      assert inst.x == 10
      assert inst.y == 20
      assert inst.rotate == 1.5
      assert inst.scale_x == 2.0
      assert inst.fill == "red"
      assert inst.alpha == 0.5
    end
  end

  describe "expand/1" do
    test "expands instances into plain ops" do
      canvas =
        Easel.new(100, 100)
        |> Easel.template(:dot, fn c ->
          c |> Easel.API.begin_path() |> Easel.API.fill()
        end)
        |> Easel.instances(:dot, [%{x: 10, y: 20}, %{x: 30, y: 40}])
        |> Easel.expand()

      # No __instances ops remain
      refute Enum.any?(canvas.ops, fn [op | _] -> op == "__instances" end)

      # Each instance: save, translate, beginPath, fill, restore = 5 ops
      assert length(canvas.ops) == 10

      assert [
        ["save", []], ["translate", [10, 20]], ["beginPath", []], ["fill", []], ["restore", []],
        ["save", []], ["translate", [30, 40]], ["beginPath", []], ["fill", []], ["restore", []]
      ] = canvas.ops
    end

    test "expand includes style and transform ops" do
      canvas =
        Easel.new(100, 100)
        |> Easel.template(:t, fn c -> Easel.API.fill(c) end)
        |> Easel.instances(:t, [
          %{x: 5, y: 10, rotate: 1.0, scale_x: 2.0, scale_y: 0.5, fill: "red", alpha: 0.8}
        ])
        |> Easel.expand()

      assert [
        ["save", []],
        ["translate", [5, 10]],
        ["rotate", [1.0]],
        ["scale", [2.0, 0.5]],
        ["set", ["fillStyle", "red"]],
        ["set", ["globalAlpha", 0.8]],
        ["fill", []],
        ["restore", []]
      ] = canvas.ops
    end

    test "expand preserves non-instance ops" do
      canvas =
        Easel.new(100, 100)
        |> Easel.template(:t, fn c -> Easel.API.fill(c) end)
        |> Easel.API.set_fill_style("blue")
        |> Easel.API.fill_rect(0, 0, 100, 100)
        |> Easel.instances(:t, [%{x: 50, y: 50}])
        |> Easel.expand()

      assert [
        ["set", ["fillStyle", "blue"]],
        ["fillRect", [0, 0, 100, 100]],
        ["save", []], ["translate", [50, 50]], ["fill", []], ["restore", []]
      ] = canvas.ops
    end

    test "expand on canvas with no instances is a no-op" do
      canvas =
        Easel.new(100, 100)
        |> Easel.API.fill_rect(0, 0, 100, 100)
        |> Easel.expand()

      assert [["fillRect", [0, 0, 100, 100]]] = canvas.ops
    end

    test "expand auto-renders if needed" do
      canvas =
        Easel.new(100, 100)
        |> Easel.template(:t, fn c -> Easel.API.fill(c) end)
        |> Easel.instances(:t, [%{x: 1, y: 2}])
        |> Easel.expand()

      assert canvas.rendered == true
      assert hd(canvas.ops) == ["save", []]
    end
  end
end
