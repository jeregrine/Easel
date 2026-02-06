defmodule Easel.WebIDLTest do
  use ExUnit.Case

  describe "parse/1" do
    test "parses an empty interface" do
      idl = "interface Foo {};"

      assert [%{"type" => "interface", "name" => "Foo", "members" => []}] =
               Easel.WebIDL.parse(idl)
    end

    test "parses an interface mixin" do
      idl = "interface mixin Bar {};"

      assert [%{"type" => "interface mixin", "name" => "Bar", "members" => []}] =
               Easel.WebIDL.parse(idl)
    end

    test "parses a readonly attribute" do
      idl = """
      interface Ctx {
        readonly attribute double width;
      };
      """

      [%{"members" => [member]}] = Easel.WebIDL.parse(idl)
      assert member["type"] == "attribute"
      assert member["name"] == "width"
      assert member["readonly"] == true
    end

    test "parses a writable attribute" do
      idl = """
      interface mixin Styles {
        attribute DOMString font;
      };
      """

      [%{"members" => [member]}] = Easel.WebIDL.parse(idl)
      assert member["type"] == "attribute"
      assert member["name"] == "font"
      assert member["readonly"] == false
    end

    test "parses an operation with no arguments" do
      idl = """
      interface mixin State {
        undefined save();
      };
      """

      [%{"members" => [member]}] = Easel.WebIDL.parse(idl)
      assert member["type"] == "operation"
      assert member["name"] == "save"
      assert member["arguments"] == []
    end

    test "parses an operation with required arguments" do
      idl = """
      interface mixin Rect {
        undefined fillRect(double x, double y, double w, double h);
      };
      """

      [%{"members" => [member]}] = Easel.WebIDL.parse(idl)
      assert member["name"] == "fillRect"
      assert length(member["arguments"]) == 4

      [x, y, w, h] = member["arguments"]
      assert x["name"] == "x"
      assert x["optional"] == false
      assert y["name"] == "y"
      assert w["name"] == "w"
      assert h["name"] == "h"
    end

    test "parses an operation with optional argument and string default" do
      idl = """
      interface mixin Draw {
        undefined fill(optional CanvasWindingRule winding = "nonzero");
      };
      """

      [%{"members" => [member]}] = Easel.WebIDL.parse(idl)
      [arg] = member["arguments"]
      assert arg["name"] == "winding"
      assert arg["optional"] == true
      assert arg["default"] == %{"type" => "string", "value" => "nonzero"}
    end

    test "parses an operation with optional argument and boolean default" do
      idl = """
      interface mixin Path {
        undefined arc(double x, double y, double r, double s, double e, optional boolean ccw = false);
      };
      """

      [%{"members" => [member]}] = Easel.WebIDL.parse(idl)
      ccw = List.last(member["arguments"])
      assert ccw["name"] == "ccw"
      assert ccw["optional"] == true
      assert ccw["default"] == %{"type" => "boolean", "value" => false}
    end

    test "parses an operation with optional argument and numeric default" do
      idl = """
      interface Ctx {
        undefined drawWindow(double x, optional unsigned long flags = 0);
      };
      """

      [%{"members" => [member]}] = Easel.WebIDL.parse(idl)
      flags = List.last(member["arguments"])
      assert flags["name"] == "flags"
      assert flags["optional"] == true
      assert flags["default"] == %{"type" => "number", "value" => 0}
    end

    test "preserves overloaded operations" do
      idl = """
      interface mixin Draw {
        undefined stroke();
        undefined stroke(Path2D path);
      };
      """

      [%{"members" => members}] = Easel.WebIDL.parse(idl)
      assert length(members) == 2
      [no_args, with_path] = members
      assert no_args["name"] == "stroke"
      assert no_args["arguments"] == []
      assert with_path["name"] == "stroke"
      assert length(with_path["arguments"]) == 1
    end

    test "parses unrestricted type modifier" do
      idl = """
      interface mixin Path {
        undefined moveTo(unrestricted double x, unrestricted double y);
      };
      """

      [%{"members" => [member]}] = Easel.WebIDL.parse(idl)
      [x, _y] = member["arguments"]
      assert x["idlType"]["idlType"] =~ "unrestricted"
      assert x["idlType"]["idlType"] =~ "double"
    end

    test "parses nullable type" do
      idl = """
      interface Ctx {
        readonly attribute HTMLCanvasElement? canvas;
      };
      """

      [%{"members" => [member]}] = Easel.WebIDL.parse(idl)
      assert member["idlType"]["idlType"] =~ "HTMLCanvasElement"
      assert member["idlType"]["idlType"] =~ "?"
    end

    test "parses union type in attribute" do
      idl = """
      interface mixin Styles {
        attribute (DOMString or CanvasGradient or CanvasPattern) fillStyle;
      };
      """

      [%{"members" => [member]}] = Easel.WebIDL.parse(idl)
      assert member["name"] == "fillStyle"
      assert member["idlType"]["idlType"] =~ "DOMString"
      assert member["idlType"]["idlType"] =~ "CanvasGradient"
    end

    test "parses sequence type" do
      idl = """
      interface mixin LineStyles {
        undefined setLineDash(sequence<double> segments);
      };
      """

      [%{"members" => [member]}] = Easel.WebIDL.parse(idl)
      [arg] = member["arguments"]
      assert arg["name"] == "segments"
      assert arg["idlType"]["idlType"] =~ "sequence"
      assert arg["idlType"]["idlType"] =~ "double"
    end

    test "skips const members" do
      idl = """
      interface Ctx {
        const unsigned long SOME_FLAG = 0x01;
        undefined save();
      };
      """

      [%{"members" => members}] = Easel.WebIDL.parse(idl)
      assert length(members) == 1
      assert hd(members)["name"] == "save"
    end

    test "skips extended attributes" do
      idl = """
      interface mixin Transform {
        [Throws, LenientFloat]
        undefined scale(double x, double y);
      };
      """

      [%{"members" => [member]}] = Easel.WebIDL.parse(idl)
      assert member["name"] == "scale"
    end

    test "skips enum, typedef, dictionary, and includes" do
      idl = """
      enum WindingRule { "nonzero", "evenodd" };
      typedef (HTMLImageElement or SVGImageElement) ImageSource;
      dictionary Options { boolean alpha = true; };
      interface Ctx { undefined save(); };
      Ctx includes SomeMixin;
      """

      result = Easel.WebIDL.parse(idl)
      assert length(result) == 1
      assert hd(result)["name"] == "Ctx"
    end

    test "handles block comments" do
      idl = """
      /* This is a comment */
      interface Ctx {
        /* another comment */
        undefined save();
      };
      """

      [%{"members" => [member]}] = Easel.WebIDL.parse(idl)
      assert member["name"] == "save"
    end

    test "handles line comments" do
      idl = """
      interface mixin State {
        // save the state
        undefined save();
        undefined restore(); // pop state
      };
      """

      [%{"members" => members}] = Easel.WebIDL.parse(idl)
      assert length(members) == 2
    end

    test "parses the actual canvas WebIDL file" do
      result =
        File.read!(Path.join(:code.priv_dir(:easel), "easel.webidl"))
        |> Easel.WebIDL.parse()

      interfaces = Enum.map(result, & &1["name"])
      assert "CanvasRenderingContext2D" in interfaces
      assert "CanvasDrawPath" in interfaces
      assert "CanvasPath" in interfaces
      assert "CanvasRect" in interfaces
    end
  end

  describe "members_by_name/1" do
    test "groups overloaded operations by name" do
      idl = """
      interface mixin Draw {
        undefined fill(optional DOMString winding = "nonzero");
        undefined fill(Path2D path, optional DOMString winding = "nonzero");
        undefined stroke();
        undefined stroke(Path2D path);
      };
      """

      members = Easel.WebIDL.members_by_name(idl)
      assert length(members["fill"]) == 2
      assert length(members["stroke"]) == 2
    end

    test "excludes readonly attributes" do
      idl = """
      interface Ctx {
        readonly attribute double width;
        attribute DOMString font;
      };
      """

      members = Easel.WebIDL.members_by_name(idl)
      refute Map.has_key?(members, "width")
      assert Map.has_key?(members, "font")
    end

    test "excludes const members" do
      idl = """
      interface Ctx {
        const unsigned long FLAG = 0x01;
        undefined save();
      };
      """

      members = Easel.WebIDL.members_by_name(idl)
      refute Map.has_key?(members, "FLAG")
      assert Map.has_key?(members, "save")
    end
  end
end
