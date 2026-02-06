defmodule Canvas.API do
  @moduledoc """
  Represents the Canvas API, in elixir!

  Generated from WebIDL and MDN browser compatibility data for
  [CanvasRenderingContext2D](https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D).
  """

  dir = :code.priv_dir(:canvas)

  idl =
    File.read!("#{dir}/canvas.webidl")
    |> Canvas.WebIDL.members_by_name()

  %{"data" => bcd} =
    File.read!("#{dir}/compat.json")
    |> JSON.decode!()

  # Pre-compute a flat list of {type, elixir_name, js_name, arg_vars, doc_url | nil}
  # All overload expansion and dedup happens here, once.
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

              {required, optional} =
                Enum.split_while(args, fn a -> !a["optional"] end)

              for i <- 0..length(optional) do
                (required ++ Enum.take(optional, i))
                |> Enum.map(fn a ->
                  Macro.var(String.to_atom(Macro.underscore(a["name"])), __MODULE__)
                end)
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

  def set(ctx, key, val) do
    Canvas.push_op(ctx, ["set", [key, val]])
  end

  def call(ctx, op, arguments) do
    Canvas.push_op(ctx, [op, arguments])
  end

  for d <- defs do
    case d do
      {:set, name, js_name, doc_url} ->
        @doc doc_url
        def unquote(name)(ctx, value) do
          set(ctx, unquote(js_name), value)
        end

      {:call, name, js_name, arg_vars, doc_url} ->
        if doc_url do
          @doc doc_url
        end

        def unquote(name)(ctx, unquote_splicing(arg_vars)) do
          call(ctx, unquote(js_name), unquote(arg_vars))
        end
    end
  end
end
