defmodule Canvas.API do
  @moduledoc """
  Represents the Canvas API, in elixir!
  """
  dir = :code.priv_dir(:canvas)

  idl =
    File.read!("#{dir}/web_idl.json")
    |> JSON.decode!()
    |> Enum.filter(fn val ->
      val["type"] in ["interface", "interface mixin"]
    end)
    |> get_in([Access.all(), "members"])
    |> List.flatten()
    |> Enum.reject(fn val ->
      val["type"] == "const" ||
        (val["type"] == "attribute" && val["readonly"] == true)
    end)
    |> Enum.map(fn val ->
      {val["name"], val}
    end)
    |> Enum.into(%{})

  %{"data" => bcd} =
    File.read!("#{dir}/compat.json")
    |> JSON.decode!()

  canvas_ops =
    for {func, stuff} <- bcd, stuff["__compat"]["status"]["deprecated"] == false do
      i = idl[func]

      case i["type"] do
        "attribute" ->
          attr_atom = String.to_atom("set_" <> Macro.underscore(func))

          {:setter, attr_atom, func, stuff["__compat"], i}

        "operation" ->
          arguments =
            idl[func]["arguments"]
            |> Enum.map(fn a ->
              name = Macro.var(String.to_atom(Macro.underscore(a["name"])), __MODULE__)

              if a["optional"] do
                {:optional, a["idlType"]["idlType"], name, a["default"]}
              else
                {:required, a["idlType"]["idlType"], name}
              end
            end)

          fun_atom = String.to_atom(Macro.underscore(func))

          {:op, fun_atom, func, arguments, stuff["__compat"], i}

        _ ->
          nil
      end
    end
    |> Enum.reject(&is_nil/1)

  def set(ctx, key, val) do
    Canvas.push_op(ctx, ["set", [key, val]])
  end

  def call(ctx, op, arguments) do
    Canvas.push_op(ctx, [op, arguments])
  end

  for op <- canvas_ops do
    case op do
      {:op, fun_atom, func, arguments, stuff, _i} ->
        def_map =
          arguments
          |> Enum.map(fn
            {:required, _, name} -> name
            {:optional, _, name, nil} -> {:\\, [], [name, Macro.escape(:unset)]}
            {:optional, _, name, %{"value" => value}} -> {:\\, [], [name, Macro.escape(value)]}
          end)
          |> Enum.reject(&is_nil/1)

        arg_map =
          arguments
          |> Enum.map(fn
            {:required, _, name} -> name
            {:optional, _, name, _} -> name
          end)

        @doc "https://developer.mozilla.org#{stuff["mdn_url"]}"
        def unquote(fun_atom)(ctx, unquote_splicing(def_map)) do
          call(ctx, unquote(func), unquote(arg_map))
        end

      {:setter, attr_atom, func, _stuff, _i} ->
        def unquote(attr_atom)(ctx, args) do
          set(ctx, unquote(func), args)
        end
    end
  end
end
