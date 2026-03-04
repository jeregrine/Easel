#!/usr/bin/env elixir

Mix.install([{:nimble_parsec, "~> 1.0"}])

project_root = Path.expand("..", __DIR__)
parser_template_path = Path.join(project_root, "lib/web_idl.ex.exs")
web_idl_path = Path.join(project_root, "priv/easel.webidl")
compat_path = Path.join(project_root, "priv/compat.json")
easel_path = Path.join(project_root, "lib/easel.ex")

Code.compiler_options(ignore_module_conflict: true)
Code.require_file(parser_template_path)

idl =
  web_idl_path
  |> File.read!()
  |> Easel.WebIDL.members_by_name()

%{"data" => bcd} = compat_path |> File.read!() |> JSON.decode!()

defs =
  bcd
  |> Enum.reject(fn {func, stuff} ->
    func == "__compat" ||
      stuff["__compat"]["status"]["deprecated"] != false ||
      !Map.has_key?(idl, func)
  end)
  |> Enum.flat_map(fn {func, stuff} ->
    variants = Map.fetch!(idl, func)
    doc_url = "https://developer.mozilla.org#{stuff["__compat"]["mdn_url"]}"

    case hd(variants)["type"] do
      "attribute" ->
        name = String.to_atom("set_" <> Macro.underscore(func))
        [{:set, name, func, doc_url}]

      "operation" ->
        name = String.to_atom(Macro.underscore(func))

        clauses =
          variants
          |> Enum.flat_map(fn variant ->
            args = variant["arguments"]
            {required, optional} = Enum.split_while(args, fn a -> !a["optional"] end)

            for i <- 0..length(optional) do
              (required ++ Enum.take(optional, i))
              |> Enum.map(fn a -> String.to_atom(Macro.underscore(a["name"])) end)
            end
          end)
          |> Enum.uniq_by(&length/1)
          |> Enum.sort_by(&length/1)

        clauses
        |> Enum.with_index()
        |> Enum.map(fn {arg_vars, idx} ->
          url = if idx == 0, do: doc_url, else: nil
          {:call, name, func, arg_vars, url}
        end)

      _ ->
        []
    end
  end)
  |> Enum.sort_by(fn
    {:set, name, _js_name, _doc_url} ->
      {Atom.to_string(name), 1}

    {:call, name, _js_name, arg_vars, _doc_url} ->
      {Atom.to_string(name), length(arg_vars)}
  end)

render_def = fn
  {:set, name, js_name, doc_url} ->
    """
      @doc \"#{doc_url}\"
      def #{name}(ctx, value) do
        set(ctx, \"#{js_name}\", value)
      end
    """

  {:call, name, js_name, arg_vars, doc_url} ->
    args_sig = Enum.join(["ctx" | Enum.map(arg_vars, &Atom.to_string/1)], ", ")
    args_call = Enum.join(Enum.map(arg_vars, &Atom.to_string/1), ", ")

    doc =
      if doc_url do
        "  @doc \"#{doc_url}\"\n"
      else
        ""
      end

    doc <>
      "  def #{name}(#{args_sig}) do\n" <>
      "    call(ctx, \"#{js_name}\", [#{args_call}])\n" <>
      "  end\n"
end

generated_block =
  defs
  |> Enum.map(render_def)
  |> Enum.join("\n")
  |> String.trim_trailing()

begin_marker = "  # --- BEGIN GENERATED CANVAS API ---"
end_marker = "  # --- END GENERATED CANVAS API ---"

source = File.read!(easel_path)

new_source =
  case String.split(source, begin_marker, parts: 2) do
    [before, rest] ->
      case String.split(rest, end_marker, parts: 2) do
        [_old_generated, after_block] ->
          before <> begin_marker <> "\n" <> generated_block <> "\n\n" <> end_marker <> after_block

        _ ->
          raise "Could not find end marker in #{Path.relative_to(easel_path, project_root)}"
      end

    _ ->
      raise "Could not find begin marker in #{Path.relative_to(easel_path, project_root)}"
  end

File.write!(easel_path, new_source)

IO.puts(
  "Updated #{Path.relative_to(easel_path, project_root)} with #{length(defs)} generated Canvas API clauses"
)
