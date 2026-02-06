defmodule Easel.WebIDL do
  @moduledoc """
  A WebIDL parser for Canvas2D using NimbleParsec.

  Parses interface/mixin declarations, extracting attributes and operations
  with their arguments, types, optionality, and default values.
  """

  import NimbleParsec

  # ── Whitespace & comments ──────────────────────────────────────────

  whitespace_char = ascii_char([?\s, ?\t, ?\n, ?\r])

  line_comment =
    string("//")
    |> repeat(ascii_char(not: ?\n))

  block_comment =
    string("/*")
    |> repeat(
      lookahead_not(string("*/"))
      |> ascii_char([])
    )
    |> string("*/")

  skip =
    choice([whitespace_char, line_comment, block_comment])
    |> times(min: 1)
    |> ignore()

  optional_skip = optional(skip)

  # ── Identifiers & basic tokens ─────────────────────────────────────

  identifier =
    ascii_char([?a..?z, ?A..?Z, ?_])
    |> repeat(ascii_char([?a..?z, ?A..?Z, ?0..?9, ?_]))
    |> reduce({List, :to_string, []})

  # ── Types (we capture as a flat string, don't need to deeply parse) ──

  # A type can be complex: `(A or B)`, `sequence<T>`, `unrestricted double`, `Type?`
  # We just capture everything as a string token for our purposes.

  # Balanced content inside parens or angle brackets
  paren_content =
    repeat(
      choice([
        string("(")
        |> concat(parsec(:paren_inner))
        |> string(")"),
        string("<")
        |> concat(parsec(:angle_inner))
        |> string(">"),
        ascii_char([{:not, ?\)}, {:not, ?\(}, {:not, ?>}, {:not, ?<}])
      ])
    )

  angle_content =
    repeat(
      choice([
        string("(")
        |> concat(parsec(:paren_inner))
        |> string(")"),
        string("<")
        |> concat(parsec(:angle_inner))
        |> string(">"),
        ascii_char([{:not, ?>}, {:not, ?<}, {:not, ?\(}, {:not, ?\)}])
      ])
    )

  defcombinatorp(:paren_inner, paren_content)
  defcombinatorp(:angle_inner, angle_content)

  # A type expression — reads tokens until we hit an identifier that would be an arg name
  # We'll handle this differently: parse type as part of argument/attribute parsing

  # Type: sequence of type keywords. We'll collect chars up to a boundary.
  # For arguments: type ends at the argument name (last identifier before , or = or ))
  # For attributes: type ends at the attribute name (last identifier before ;)
  # Simplest approach: capture a "type token" which is one or more of:
  #   - identifiers (including `unrestricted`, `unsigned`, `long`, etc.)
  #   - `?` suffix
  #   - `<...>` generic
  #   - `(... or ...)` union

  type_union =
    ignore(string("("))
    |> concat(optional_skip)
    |> concat(parsec(:type_expr))
    |> repeat(
      optional_skip
      |> ignore(string("or"))
      |> concat(optional_skip)
      |> concat(parsec(:type_expr))
    )
    |> concat(optional_skip)
    |> ignore(string(")"))
    |> reduce(:join_type)

  type_sequence =
    string("sequence")
    |> ignore(string("<"))
    |> concat(optional_skip)
    |> concat(parsec(:type_expr))
    |> concat(optional_skip)
    |> ignore(string(">"))
    |> reduce(:join_type)

  type_simple =
    optional(string("unrestricted") |> concat(skip))
    |> optional(string("unsigned") |> concat(skip))
    |> concat(identifier)
    |> optional(string("?"))
    |> reduce(:join_type)

  type_expr =
    choice([
      type_union,
      type_sequence,
      type_simple
    ])

  defcombinatorp(:type_expr, type_expr)

  defp join_type(parts) do
    parts
    |> List.flatten()
    |> Enum.map(fn
      i when is_integer(i) -> <<i>>
      s -> s
    end)
    |> Enum.join(" ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  # ── Default values ─────────────────────────────────────────────────

  string_default =
    ignore(ascii_char([?"]))
    |> repeat(ascii_char(not: ?"))
    |> ignore(ascii_char([?"]))
    |> reduce({List, :to_string, []})
    |> unwrap_and_tag(:string)

  number_default =
    optional(string("-"))
    |> choice([
      string("0x")
      |> repeat(ascii_char([?0..?9, ?a..?f, ?A..?F]))
      |> reduce({List, :to_string, []}),
      repeat(ascii_char([?0..?9, ?.]))
      |> reduce({List, :to_string, []})
    ])
    |> reduce(:parse_number)
    |> unwrap_and_tag(:number)

  bool_default =
    choice([
      string("true") |> replace(true),
      string("false") |> replace(false)
    ])
    |> unwrap_and_tag(:boolean)

  null_default = string("null") |> replace(nil) |> unwrap_and_tag(:null)
  dict_default = string("{}") |> replace(%{}) |> unwrap_and_tag(:dictionary)

  default_value =
    choice([
      string_default,
      bool_default,
      null_default,
      dict_default,
      number_default
    ])

  defp parse_number(parts) do
    str =
      parts
      |> List.flatten()
      |> Enum.map(fn
        i when is_integer(i) -> <<i>>
        s -> s
      end)
      |> Enum.join()

    cond do
      String.starts_with?(str, "0x") or String.starts_with?(str, "-0x") ->
        {n, ""} = Integer.parse(str, 16)
        n

      String.contains?(str, ".") ->
        {f, ""} = Float.parse(str)
        f

      true ->
        {n, ""} = Integer.parse(str)
        n
    end
  end

  # ── Extended attributes (we skip them) ─────────────────────────────

  ext_attrs =
    ignore(
      string("[")
      |> concat(parsec(:paren_inner_bracket))
      |> string("]")
    )

  bracket_content =
    repeat(
      choice([
        string("[")
        |> concat(parsec(:paren_inner_bracket))
        |> string("]"),
        string("\"")
        |> repeat(ascii_char([{:not, ?"}]))
        |> string("\""),
        ascii_char([{:not, ?\]}, {:not, ?\[}, {:not, ?"}])
      ])
    )

  defcombinatorp(:paren_inner_bracket, bracket_content)

  # ── Arguments ──────────────────────────────────────────────────────

  single_argument =
    optional(ext_attrs |> concat(optional_skip))
    |> optional(
      string("optional")
      |> concat(skip)
      |> replace(true)
      |> unwrap_and_tag(:optional)
    )
    |> concat(type_expr |> unwrap_and_tag(:type))
    |> concat(skip)
    |> concat(identifier |> unwrap_and_tag(:name))
    |> optional(
      optional_skip
      |> ignore(string("="))
      |> concat(optional_skip)
      |> concat(default_value)
      |> unwrap_and_tag(:default)
    )
    |> reduce(:build_argument)

  argument_list =
    optional(
      single_argument
      |> repeat(
        optional_skip
        |> ignore(string(","))
        |> concat(optional_skip)
        |> concat(single_argument)
      )
    )

  defp build_argument(parts) do
    parts = Map.new(parts)

    %{
      "name" => parts[:name],
      "optional" => Map.get(parts, :optional, false),
      "idlType" => %{"idlType" => parts[:type]},
      "default" => build_default(parts[:default])
    }
  end

  defp build_default(nil), do: nil
  defp build_default({:string, v}), do: %{"type" => "string", "value" => v}
  defp build_default({:boolean, v}), do: %{"type" => "boolean", "value" => v}
  defp build_default({:null, _}), do: %{"type" => "null"}
  defp build_default({:dictionary, _}), do: %{"type" => "dictionary"}
  defp build_default({:number, v}), do: %{"type" => "number", "value" => v}

  # ── Members ────────────────────────────────────────────────────────

  const_member =
    optional(ext_attrs |> concat(optional_skip))
    |> ignore(string("const"))
    |> repeat(ascii_char(not: ?;))
    |> ignore(string(";"))
    |> replace(:skip)

  readonly_attribute =
    optional(ext_attrs |> concat(optional_skip))
    |> ignore(string("readonly"))
    |> concat(skip)
    |> ignore(string("attribute"))
    |> concat(skip)
    |> concat(type_expr |> unwrap_and_tag(:type))
    |> concat(skip)
    |> concat(identifier |> unwrap_and_tag(:name))
    |> concat(optional_skip)
    |> ignore(string(";"))
    |> reduce(:build_readonly_attribute)

  writable_attribute =
    optional(ext_attrs |> concat(optional_skip))
    |> ignore(string("attribute"))
    |> concat(skip)
    |> concat(type_expr |> unwrap_and_tag(:type))
    |> concat(skip)
    |> concat(identifier |> unwrap_and_tag(:name))
    |> concat(optional_skip)
    |> ignore(string(";"))
    |> reduce(:build_writable_attribute)

  operation =
    optional(ext_attrs |> concat(optional_skip))
    |> concat(type_expr |> unwrap_and_tag(:return_type))
    |> concat(optional_skip)
    |> concat(identifier |> unwrap_and_tag(:name))
    |> concat(optional_skip)
    |> ignore(string("("))
    |> concat(optional_skip)
    |> tag(argument_list, :arguments)
    |> concat(optional_skip)
    |> ignore(string(")"))
    |> concat(optional_skip)
    |> ignore(string(";"))
    |> reduce(:build_operation)

  defp build_readonly_attribute(parts) do
    parts = Map.new(parts)

    %{
      "type" => "attribute",
      "name" => parts[:name],
      "readonly" => true,
      "idlType" => %{"idlType" => parts[:type]}
    }
  end

  defp build_writable_attribute(parts) do
    parts = Map.new(parts)

    %{
      "type" => "attribute",
      "name" => parts[:name],
      "readonly" => false,
      "idlType" => %{"idlType" => parts[:type]}
    }
  end

  defp build_operation(parts) do
    parts = Map.new(parts)

    %{
      "type" => "operation",
      "name" => parts[:name],
      "returnType" => %{"idlType" => parts[:return_type]},
      "arguments" => parts[:arguments]
    }
  end

  member =
    choice([
      const_member,
      readonly_attribute,
      writable_attribute,
      operation
    ])

  members =
    repeat(
      optional_skip
      |> concat(member)
    )

  # ── Interface / interface mixin ────────────────────────────────────

  interface_mixin =
    optional(ext_attrs |> concat(optional_skip))
    |> ignore(string("interface"))
    |> concat(skip)
    |> ignore(string("mixin"))
    |> concat(skip)
    |> concat(identifier |> unwrap_and_tag(:name))
    |> concat(optional_skip)
    |> ignore(string("{"))
    |> tag(members, :members)
    |> concat(optional_skip)
    |> ignore(string("};"))
    |> reduce(:build_interface_mixin)

  interface_def =
    optional(ext_attrs |> concat(optional_skip))
    |> ignore(string("interface"))
    |> concat(skip)
    |> concat(identifier |> unwrap_and_tag(:name))
    |> concat(optional_skip)
    |> ignore(string("{"))
    |> tag(members, :members)
    |> concat(optional_skip)
    |> ignore(string("};"))
    |> reduce(:build_interface)

  defp build_interface_mixin(parts) do
    parts = Map.new(parts)

    %{
      "type" => "interface mixin",
      "name" => parts[:name],
      "members" => Enum.reject(parts[:members], &(&1 == :skip))
    }
  end

  defp build_interface(parts) do
    parts = Map.new(parts)

    %{
      "type" => "interface",
      "name" => parts[:name],
      "members" => Enum.reject(parts[:members], &(&1 == :skip))
    }
  end

  # ── Skip non-interface top-level constructs ────────────────────────

  # enum Name { ... };
  skip_enum =
    ignore(
      string("enum")
      |> repeat(ascii_char(not: ?;))
      |> string(";")
    )

  # typedef ... Name;
  skip_typedef =
    ignore(
      string("typedef")
      |> repeat(ascii_char(not: ?;))
      |> string(";")
    )

  # dictionary Name { ... };
  skip_dictionary =
    ignore(
      string("dictionary")
      |> repeat(
        choice([
          string("{")
          |> repeat(ascii_char(not: ?}))
          |> string("}"),
          ascii_char(not: ?;)
        ])
      )
      |> string(";")
    )

  # Name includes Name;
  skip_includes =
    ignore(
      identifier
      |> concat(skip)
      |> string("includes")
      |> repeat(ascii_char(not: ?;))
      |> string(";")
    )

  # ── Top-level document ─────────────────────────────────────────────

  top_level =
    choice([
      interface_mixin,
      interface_def,
      skip_enum,
      skip_typedef,
      skip_dictionary,
      skip_includes
    ])

  document =
    repeat(
      optional_skip
      |> concat(top_level)
    )
    |> concat(optional_skip)
    |> eos()

  defparsec(:parse_document, document)

  # ── Public API ─────────────────────────────────────────────────────

  @doc """
  Parses a WebIDL string and returns a list of interface/mixin definitions.
  """
  def parse(source) do
    case parse_document(source) do
      {:ok, results, "", _, _, _} ->
        results

      {:ok, _results, rest, _, _, _} ->
        raise "WebIDL parse error: unparsed input starting at: #{String.slice(rest, 0, 100)}"

      {:error, reason, rest, _, _, _} ->
        raise "WebIDL parse error: #{reason} at: #{String.slice(rest, 0, 100)}"
    end
  end

  @doc """
  Parses a WebIDL file and returns a flat map of non-const, non-readonly
  members grouped by name (preserving overloads).
  """
  def members_by_name(source) do
    source
    |> parse()
    |> Enum.filter(fn d -> d["type"] in ["interface", "interface mixin"] end)
    |> Enum.flat_map(fn d -> d["members"] end)
    |> Enum.reject(fn m ->
      m["type"] == "const" ||
        (m["type"] == "attribute" && m["readonly"] == true)
    end)
    |> Enum.group_by(fn m -> m["name"] end)
  end
end
