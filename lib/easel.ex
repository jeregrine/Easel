defmodule Easel do
  @moduledoc """
  Easel lets you build Canvas 2D drawing operations as data.

  Create a canvas, pipe it through drawing functions to build up
  a list of operations, then render to a backend (browser via LiveView,
  native window via wx, or consume the ops list directly).

  All Canvas 2D API functions are available directly on this module as
  `snake_cased` versions of their JavaScript counterparts. Use `set/3`
  and `call/3` for properties or methods not yet generated.

  ## Example

      canvas =
        Easel.new(300, 300)
        |> Easel.set_fill_style("blue")
        |> Easel.fill_rect(0, 0, 100, 100)
        |> Easel.set_line_width(10)
        |> Easel.stroke_rect(100, 100, 100, 100)
        |> Easel.render()

  The resulting `%Easel{}` struct contains an `ops` list that maps
  directly to Canvas 2D API calls:

      canvas.ops
      #=> [["set", ["fillStyle", "blue"]], ["fillRect", [0, 0, 100, 100]], ...]

  ## Templates and Instances

  For scenes with many similar shapes, define a template once and stamp
  out instances with per-instance transforms:

      canvas =
        Easel.new(800, 600)
        |> Easel.template(:particle, fn c ->
          c |> Easel.begin_path() |> Easel.arc(0, 0, 3, 0, 6.28) |> Easel.fill()
        end)
        |> Easel.instances(:particle, [
          %{x: 100, y: 200, fill: "red"},
          %{x: 300, y: 400, fill: "blue", alpha: 0.5}
        ])
        |> Easel.render()

  The LiveView hook renders instances client-side (template ops cached,
  only instance data sent per frame). For other backends, call `expand/1`
  to flatten into plain ops.

  ## Backends

    * `Easel.LiveView` — Phoenix LiveView component with colocated JS hook
    * `Easel.WX` — Native desktop window via Erlang's `:wx` (wxWidgets)
    * Custom — consume `canvas.ops` directly in your own renderer
  """

  defstruct width: nil, height: nil, ops: [], rendered: false, templates: %{}

  @doc "Creates a new canvas with no dimensions set."
  def new do
    %Easel{}
  end

  @doc "Creates a new canvas with the given `width` and `height`."
  def new(width, height) do
    %Easel{width: width, height: height}
  end

  @doc """
  Pushes a raw operation onto the canvas.

  Operations are stored in reverse order for efficient prepend.
  Call `render/1` to finalize the ops list into correct order.
  """
  def push_op(%Easel{} = ctx, op) do
    %{ctx | ops: [op | ctx.ops], rendered: false}
  end

  @doc """
  Sets a Canvas 2D context property.

      Easel.set(canvas, "fillStyle", "blue")
  """
  def set(ctx, key, val) do
    push_op(ctx, ["set", [key, val]])
  end

  @doc """
  Calls a Canvas 2D context method with the given arguments.

      Easel.call(canvas, "fillRect", [0, 0, 100, 100])
  """
  def call(ctx, op, arguments) do
    push_op(ctx, [op, arguments])
  end

  # ── Generated Canvas 2D API ──────────────────────────────────────

  dir = :code.priv_dir(:easel)

  idl =
    File.read!("#{dir}/easel.webidl")
    |> Easel.WebIDL.members_by_name()

  %{"data" => bcd} =
    File.read!("#{dir}/compat.json")
    |> JSON.decode!()

  @defs bcd
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

  for d <- @defs do
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

  # ── Templates and Instances ──────────────────────────────────────

  @doc """
  Defines a reusable drawing template.

  A template is a named set of ops that can be instantiated many times
  with different transforms. The template function receives a fresh
  `%Easel{}` and should return one with ops added (don't call `render/1`).

  ## Example

      canvas =
        Easel.new(800, 600)
        |> Easel.template(:boid, fn c ->
          c
          |> Easel.begin_path()
          |> Easel.move_to(12, 0)
          |> Easel.line_to(-4, -5)
          |> Easel.line_to(-4, 5)
          |> Easel.close_path()
          |> Easel.fill()
        end)
  """
  def template(%Easel{} = ctx, name, draw_fn) when is_atom(name) and is_function(draw_fn, 1) do
    tpl = draw_fn.(%Easel{}) |> render()
    %{ctx | templates: Map.put(ctx.templates, name, tpl.ops)}
  end

  @doc """
  Draws instances of a previously defined template.

  Each instance is a map that may contain:

    * `:x`, `:y` — translation (default `0`, `0`)
    * `:rotate` — rotation in radians (default `0`)
    * `:scale_x`, `:scale_y` — scale factors (default `1`, `1`)
    * `:fill` — fill style override (applied before template ops)
    * `:stroke` — stroke style override
    * `:alpha` — global alpha override

  The hook renders each instance via `save → translate → rotate → scale →
  [style overrides] → [template ops] → restore`.

  ## Example

      canvas
      |> Easel.instances(:boid, Enum.map(boids, fn b ->
        %{x: b.x, y: b.y, rotate: :math.atan2(b.vy, b.vx),
          fill: "hsl(\#{hue}, 70%, 60%)"}
      end))
  """
  def instances(%Easel{} = ctx, name, instance_data)
      when is_atom(name) and is_list(instance_data) do
    push_op(ctx, ["__instances", [Atom.to_string(name), instance_data]])
  end

  @doc """
  Draws instances using a compact positional row format.

  Row order is:
  `[x, y, rotate, scale_x, scale_y, fill, stroke, alpha]`.

  Trailing `nil` values are trimmed to reduce payload size.
  """
  def instances_compact(%Easel{} = ctx, name, instance_data)
      when is_atom(name) and is_list(instance_data) do
    rows = Enum.map(instance_data, &instance_to_row/1)
    push_op(ctx, ["__instances_compact", [Atom.to_string(name), rows]])
  end

  defp instance_to_row(inst) when is_map(inst) do
    [
      Map.get(inst, :x),
      Map.get(inst, :y),
      Map.get(inst, :rotate),
      Map.get(inst, :scale_x),
      Map.get(inst, :scale_y),
      Map.get(inst, :fill),
      Map.get(inst, :stroke),
      Map.get(inst, :alpha)
    ]
    |> Enum.reverse()
    |> Enum.drop_while(&is_nil/1)
    |> Enum.reverse()
  end

  defp instance_to_row(inst) when is_list(inst), do: inst

  @doc """
  Expands `__instances` ops into plain Canvas 2D ops.

  The LiveView hook handles instances natively on the client (more efficient),
  but other backends (wx, custom) can call this to get a flat ops list that
  any Canvas 2D renderer can execute.

  Automatically calls `render/1` first if needed.

  ## Example

      canvas
      |> Easel.template(:dot, fn c -> ... end)
      |> Easel.instances(:dot, [%{x: 10, y: 20}])
      |> Easel.expand()
      # ops now contain save/translate/rotate/.../restore sequences
  """
  def expand(%Easel{rendered: false} = ctx), do: ctx |> render() |> expand()

  def expand(%Easel{} = ctx) do
    expanded =
      Enum.flat_map(ctx.ops, fn
        ["__instances", [name, instances]] ->
          expand_instances(name, instances, ctx.templates)

        ["__instances_compact", [name, rows]] ->
          instances =
            Enum.map(rows, fn row ->
              %{
                x: Enum.at(row, 0),
                y: Enum.at(row, 1),
                rotate: Enum.at(row, 2),
                scale_x: Enum.at(row, 3),
                scale_y: Enum.at(row, 4),
                fill: Enum.at(row, 5),
                stroke: Enum.at(row, 6),
                alpha: Enum.at(row, 7)
              }
            end)

          expand_instances(name, instances, ctx.templates)

        op ->
          [op]
      end)

    %{ctx | ops: expanded}
  end

  defp expand_instances(name, instances, templates) do
    tpl_ops = Map.get(templates, String.to_existing_atom(name), [])

    Enum.flat_map(instances, fn inst ->
      style_ops =
        []
        |> then(fn ops ->
          if inst[:fill], do: [["set", ["fillStyle", inst.fill]] | ops], else: ops
        end)
        |> then(fn ops ->
          if inst[:stroke], do: [["set", ["strokeStyle", inst.stroke]] | ops], else: ops
        end)
        |> then(fn ops ->
          if inst[:alpha], do: [["set", ["globalAlpha", inst.alpha]] | ops], else: ops
        end)
        |> Enum.reverse()

      transform_ops =
        [["translate", [inst[:x] || 0, inst[:y] || 0]]]
        |> then(fn ops -> if inst[:rotate], do: ops ++ [["rotate", [inst.rotate]]], else: ops end)
        |> then(fn ops ->
          if inst[:scale_x] || inst[:scale_y] do
            ops ++ [["scale", [inst[:scale_x] || 1, inst[:scale_y] || 1]]]
          else
            ops
          end
        end)

      [["save", []]] ++ transform_ops ++ style_ops ++ tpl_ops ++ [["restore", []]]
    end)
  end

  @doc """
  Finalizes the canvas by reversing the ops list into execution order.

  Must be called before passing the canvas to a backend for rendering.
  Safe to call multiple times — subsequent calls are no-ops.
  """
  def render(%Easel{rendered: true} = ctx), do: ctx

  def render(%Easel{} = ctx) do
    %{ctx | ops: Enum.reverse(ctx.ops), rendered: true}
  end
end
