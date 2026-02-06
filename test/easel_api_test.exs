defmodule Easel.APITest do
  use ExUnit.Case

  defp ops(canvas), do: Easel.render(canvas).ops

  describe "set/3 and call/3 escape hatches" do
    test "set pushes a set op" do
      result =
        Easel.new(100, 100)
        |> Easel.set("customProp", 42)
        |> ops()

      assert [["set", ["customProp", 42]]] = result
    end

    test "call pushes an arbitrary op" do
      result =
        Easel.new(100, 100)
        |> Easel.call("someMethod", [1, 2, 3])
        |> ops()

      assert [["someMethod", [1, 2, 3]]] = result
    end
  end

  describe "attribute setters" do
    test "set_fill_style" do
      assert [["set", ["fillStyle", "red"]]] =
               Easel.new() |> Easel.set_fill_style("red") |> ops()
    end

    test "set_stroke_style" do
      assert [["set", ["strokeStyle", "#00ff00"]]] =
               Easel.new() |> Easel.set_stroke_style("#00ff00") |> ops()
    end

    test "set_line_width" do
      assert [["set", ["lineWidth", 5]]] =
               Easel.new() |> Easel.set_line_width(5) |> ops()
    end

    test "set_font" do
      assert [["set", ["font", "16px Arial"]]] =
               Easel.new() |> Easel.set_font("16px Arial") |> ops()
    end

    test "set_global_alpha" do
      assert [["set", ["globalAlpha", 0.5]]] =
               Easel.new() |> Easel.set_global_alpha(0.5) |> ops()
    end

    test "set_shadow_color" do
      assert [["set", ["shadowColor", "rgba(0,0,0,0.5)"]]] =
               Easel.new() |> Easel.set_shadow_color("rgba(0,0,0,0.5)") |> ops()
    end

    test "set_text_align" do
      assert [["set", ["textAlign", "center"]]] =
               Easel.new() |> Easel.set_text_align("center") |> ops()
    end

    test "set_text_baseline" do
      assert [["set", ["textBaseline", "middle"]]] =
               Easel.new() |> Easel.set_text_baseline("middle") |> ops()
    end
  end

  describe "rect operations" do
    test "fill_rect" do
      assert [["fillRect", [10, 20, 100, 50]]] =
               Easel.new() |> Easel.fill_rect(10, 20, 100, 50) |> ops()
    end

    test "stroke_rect" do
      assert [["strokeRect", [0, 0, 200, 200]]] =
               Easel.new() |> Easel.stroke_rect(0, 0, 200, 200) |> ops()
    end

    test "clear_rect" do
      assert [["clearRect", [0, 0, 300, 300]]] =
               Easel.new() |> Easel.clear_rect(0, 0, 300, 300) |> ops()
    end
  end

  describe "path operations" do
    test "begin_path" do
      assert [["beginPath", []]] = Easel.new() |> Easel.begin_path() |> ops()
    end

    test "close_path" do
      assert [["closePath", []]] = Easel.new() |> Easel.close_path() |> ops()
    end

    test "move_to" do
      assert [["moveTo", [10, 20]]] = Easel.new() |> Easel.move_to(10, 20) |> ops()
    end

    test "line_to" do
      assert [["lineTo", [30, 40]]] = Easel.new() |> Easel.line_to(30, 40) |> ops()
    end

    test "arc with required args only" do
      assert [["arc", [50, 50, 25, 0, 3.14]]] =
               Easel.new() |> Easel.arc(50, 50, 25, 0, 3.14) |> ops()
    end

    test "arc with anticlockwise" do
      assert [["arc", [50, 50, 25, 0, 3.14, true]]] =
               Easel.new() |> Easel.arc(50, 50, 25, 0, 3.14, true) |> ops()
    end

    test "arc_to" do
      assert [["arcTo", [10, 10, 50, 50, 20]]] =
               Easel.new() |> Easel.arc_to(10, 10, 50, 50, 20) |> ops()
    end

    test "bezier_curve_to" do
      assert [["bezierCurveTo", [10, 20, 30, 40, 50, 60]]] =
               Easel.new() |> Easel.bezier_curve_to(10, 20, 30, 40, 50, 60) |> ops()
    end

    test "quadratic_curve_to" do
      assert [["quadraticCurveTo", [10, 20, 30, 40]]] =
               Easel.new() |> Easel.quadratic_curve_to(10, 20, 30, 40) |> ops()
    end

    test "ellipse with required args" do
      assert [["ellipse", [100, 100, 50, 30, 0, 0, 6.28]]] =
               Easel.new() |> Easel.ellipse(100, 100, 50, 30, 0, 0, 6.28) |> ops()
    end

    test "rect" do
      assert [["rect", [10, 10, 80, 80]]] =
               Easel.new() |> Easel.rect(10, 10, 80, 80) |> ops()
    end
  end

  describe "fill/stroke/clip overloads" do
    test "fill with no args" do
      assert [["fill", []]] = Easel.new() |> Easel.fill() |> ops()
    end

    test "fill with winding rule" do
      assert [["fill", ["evenodd"]]] = Easel.new() |> Easel.fill("evenodd") |> ops()
    end

    test "fill with path and winding rule" do
      assert [["fill", ["p", "nonzero"]]] =
               Easel.new() |> Easel.fill("p", "nonzero") |> ops()
    end

    test "stroke with no args" do
      assert [["stroke", []]] = Easel.new() |> Easel.stroke() |> ops()
    end

    test "stroke with path" do
      assert [["stroke", ["p"]]] = Easel.new() |> Easel.stroke("p") |> ops()
    end

    test "clip with no args" do
      assert [["clip", []]] = Easel.new() |> Easel.clip() |> ops()
    end

    test "clip with winding rule" do
      assert [["clip", ["evenodd"]]] = Easel.new() |> Easel.clip("evenodd") |> ops()
    end

    test "clip with path and winding rule" do
      assert [["clip", ["p", "nonzero"]]] =
               Easel.new() |> Easel.clip("p", "nonzero") |> ops()
    end
  end

  describe "draw_image overloads" do
    test "draw_image 3-arg (image, dx, dy)" do
      assert [["drawImage", ["img", 10, 20]]] =
               Easel.new() |> Easel.draw_image("img", 10, 20) |> ops()
    end

    test "draw_image 5-arg (image, dx, dy, dw, dh)" do
      assert [["drawImage", ["img", 10, 20, 100, 100]]] =
               Easel.new() |> Easel.draw_image("img", 10, 20, 100, 100) |> ops()
    end

    test "draw_image 9-arg (image, sx, sy, sw, sh, dx, dy, dw, dh)" do
      assert [["drawImage", ["img", 0, 0, 50, 50, 10, 20, 100, 100]]] =
               Easel.new()
               |> Easel.draw_image("img", 0, 0, 50, 50, 10, 20, 100, 100)
               |> ops()
    end
  end

  describe "set_transform overloads" do
    test "set_transform with no args (reset)" do
      assert [["setTransform", []]] = Easel.new() |> Easel.set_transform() |> ops()
    end

    test "set_transform with matrix arg" do
      assert [["setTransform", ["m"]]] =
               Easel.new() |> Easel.set_transform("m") |> ops()
    end

    test "set_transform with 6 args (a, b, c, d, e, f)" do
      assert [["setTransform", [1, 0, 0, 1, 0, 0]]] =
               Easel.new() |> Easel.set_transform(1, 0, 0, 1, 0, 0) |> ops()
    end
  end

  describe "put_image_data overloads" do
    test "put_image_data 3-arg" do
      assert [["putImageData", ["data", 0, 0]]] =
               Easel.new() |> Easel.put_image_data("data", 0, 0) |> ops()
    end

    test "put_image_data 7-arg with dirty rect" do
      assert [["putImageData", ["data", 0, 0, 10, 10, 50, 50]]] =
               Easel.new() |> Easel.put_image_data("data", 0, 0, 10, 10, 50, 50) |> ops()
    end
  end

  describe "text operations" do
    test "fill_text without maxWidth" do
      assert [["fillText", ["hello", 10, 20]]] =
               Easel.new() |> Easel.fill_text("hello", 10, 20) |> ops()
    end

    test "fill_text with maxWidth" do
      assert [["fillText", ["hello", 10, 20, 200]]] =
               Easel.new() |> Easel.fill_text("hello", 10, 20, 200) |> ops()
    end

    test "stroke_text without maxWidth" do
      assert [["strokeText", ["hello", 10, 20]]] =
               Easel.new() |> Easel.stroke_text("hello", 10, 20) |> ops()
    end

    test "stroke_text with maxWidth" do
      assert [["strokeText", ["hello", 10, 20, 200]]] =
               Easel.new() |> Easel.stroke_text("hello", 10, 20, 200) |> ops()
    end

    test "measure_text" do
      assert [["measureText", ["hello"]]] =
               Easel.new() |> Easel.measure_text("hello") |> ops()
    end
  end

  describe "state and transform operations" do
    test "save and restore" do
      assert [["save", []], ["restore", []]] =
               Easel.new() |> Easel.save() |> Easel.restore() |> ops()
    end

    test "scale" do
      assert [["scale", [2, 3]]] = Easel.new() |> Easel.scale(2, 3) |> ops()
    end

    test "rotate" do
      assert [["rotate", [1.57]]] = Easel.new() |> Easel.rotate(1.57) |> ops()
    end

    test "translate" do
      assert [["translate", [50, 100]]] =
               Easel.new() |> Easel.translate(50, 100) |> ops()
    end

    test "transform" do
      assert [["transform", [1, 0, 0, 1, 10, 20]]] =
               Easel.new() |> Easel.transform(1, 0, 0, 1, 10, 20) |> ops()
    end

    test "reset_transform" do
      assert [["resetTransform", []]] = Easel.new() |> Easel.reset_transform() |> ops()
    end
  end

  describe "gradient and pattern" do
    test "create_linear_gradient" do
      assert [["createLinearGradient", [0, 0, 100, 100]]] =
               Easel.new() |> Easel.create_linear_gradient(0, 0, 100, 100) |> ops()
    end

    test "create_radial_gradient" do
      assert [["createRadialGradient", [50, 50, 10, 50, 50, 100]]] =
               Easel.new()
               |> Easel.create_radial_gradient(50, 50, 10, 50, 50, 100)
               |> ops()
    end
  end

  describe "op chaining preserves order" do
    test "multiple operations render in correct order" do
      result =
        Easel.new(300, 300)
        |> Easel.set_fill_style("blue")
        |> Easel.fill_rect(0, 0, 100, 100)
        |> Easel.set_stroke_style("red")
        |> Easel.set_line_width(3)
        |> Easel.stroke_rect(10, 10, 80, 80)
        |> Easel.render()

      assert [
               ["set", ["fillStyle", "blue"]],
               ["fillRect", [0, 0, 100, 100]],
               ["set", ["strokeStyle", "red"]],
               ["set", ["lineWidth", 3]],
               ["strokeRect", [10, 10, 80, 80]]
             ] = result.ops
    end
  end
end
