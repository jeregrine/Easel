defmodule Easel.WXTest do
  use ExUnit.Case

  describe "UnsupportedOpError" do
    test "raises for unsupported operations" do
      assert_raise Easel.WX.UnsupportedOpError, ~r/shadowBlur/, fn ->
        raise Easel.WX.UnsupportedOpError, op: "shadowBlur"
      end
    end

    test "error message includes the op name" do
      error = %Easel.WX.UnsupportedOpError{op: "createPattern"}
      assert Exception.message(error) =~ "createPattern"
      assert Exception.message(error) =~ "not supported"
    end
  end

  describe "parse_color/1" do
    test "parses named colors" do
      assert Easel.WX.parse_color("black") == {0, 0, 0, 255}
      assert Easel.WX.parse_color("white") == {255, 255, 255, 255}
      assert Easel.WX.parse_color("red") == {255, 0, 0, 255}
      assert Easel.WX.parse_color("blue") == {0, 0, 255, 255}
      assert Easel.WX.parse_color("transparent") == {0, 0, 0, 0}
    end

    test "parses 3-digit hex" do
      assert Easel.WX.parse_color("#f00") == {255, 0, 0, 255}
      assert Easel.WX.parse_color("#0f0") == {0, 255, 0, 255}
      assert Easel.WX.parse_color("#00f") == {0, 0, 255, 255}
      assert Easel.WX.parse_color("#fff") == {255, 255, 255, 255}
    end

    test "parses 6-digit hex" do
      assert Easel.WX.parse_color("#ff0000") == {255, 0, 0, 255}
      assert Easel.WX.parse_color("#00ff00") == {0, 255, 0, 255}
      assert Easel.WX.parse_color("#0000ff") == {0, 0, 255, 255}
      assert Easel.WX.parse_color("#abcdef") == {171, 205, 239, 255}
    end

    test "parses 8-digit hex with alpha" do
      assert Easel.WX.parse_color("#ff000080") == {255, 0, 0, 128}
      assert Easel.WX.parse_color("#00ff00ff") == {0, 255, 0, 255}
    end

    test "parses rgb()" do
      assert Easel.WX.parse_color("rgb(255, 0, 0)") == {255, 0, 0, 255}
      assert Easel.WX.parse_color("rgb(0, 128, 255)") == {0, 128, 255, 255}
    end

    test "parses rgba()" do
      assert Easel.WX.parse_color("rgba(255, 0, 0, 1.0)") == {255, 0, 0, 255}
      assert Easel.WX.parse_color("rgba(255, 0, 0, 0.5)") == {255, 0, 0, 128}
      assert Easel.WX.parse_color("rgba(0, 0, 0, 0.0)") == {0, 0, 0, 0}
    end

    test "is case insensitive" do
      assert Easel.WX.parse_color("RED") == {255, 0, 0, 255}
      assert Easel.WX.parse_color("#FF0000") == {255, 0, 0, 255}
    end

    test "defaults to black for unknown values" do
      assert Easel.WX.parse_color("not-a-color") == {0, 0, 0, 255}
    end

    test "defaults to black for non-binary values" do
      assert Easel.WX.parse_color(123) == {0, 0, 0, 255}
    end
  end

  describe "parse_font/1" do
    test "parses simple font" do
      assert Easel.WX.parse_font("16px Arial") ==
               {16, ~c"Arial", :wxFONTSTYLE_NORMAL, :wxFONTWEIGHT_NORMAL}
    end

    test "parses bold font" do
      assert Easel.WX.parse_font("bold 20px Helvetica") ==
               {20, ~c"Helvetica", :wxFONTSTYLE_NORMAL, :wxFONTWEIGHT_BOLD}
    end

    test "parses italic font" do
      assert Easel.WX.parse_font("italic 14px serif") ==
               {14, ~c"serif", :wxFONTSTYLE_ITALIC, :wxFONTWEIGHT_NORMAL}
    end

    test "parses italic bold font" do
      assert Easel.WX.parse_font("italic bold 12px monospace") ==
               {12, ~c"monospace", :wxFONTSTYLE_ITALIC, :wxFONTWEIGHT_BOLD}
    end

    test "parses font with multi-word family" do
      assert Easel.WX.parse_font("16px Times New Roman") ==
               {16, ~c"Times New Roman", :wxFONTSTYLE_NORMAL, :wxFONTWEIGHT_NORMAL}
    end

    test "parses size-only font" do
      {size, _face, style, weight} = Easel.WX.parse_font("24px")
      assert size == 24
      assert style == :wxFONTSTYLE_NORMAL
      assert weight == :wxFONTWEIGHT_NORMAL
    end

    test "parses oblique font" do
      assert Easel.WX.parse_font("oblique 10px mono") ==
               {10, ~c"mono", :wxFONTSTYLE_SLANT, :wxFONTWEIGHT_NORMAL}
    end

    test "parses lighter weight" do
      assert Easel.WX.parse_font("lighter 10px mono") ==
               {10, ~c"mono", :wxFONTSTYLE_NORMAL, :wxFONTWEIGHT_LIGHT}
    end
  end
end
