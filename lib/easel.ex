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

    * `Easel.LiveView` - Phoenix LiveView component with colocated JS hook
    * `Easel.WX` - Native desktop window via Erlang's `:wx` (wxWidgets)
    * Custom - consume `canvas.ops` directly in your own renderer
  """

  defstruct width: nil, height: nil, ops: [], rendered: false, templates: %{}, template_opts: %{}

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
  def template(%Easel{} = ctx, name, draw_fn, opts \\ [])
      when is_atom(name) and is_function(draw_fn, 1) do
    tpl = draw_fn.(%Easel{}) |> render()
    t_opts = template_instance_opts(opts)

    template_opts =
      if t_opts == [], do: ctx.template_opts, else: Map.put(ctx.template_opts, name, t_opts)

    %{ctx | templates: Map.put(ctx.templates, name, tpl.ops), template_opts: template_opts}
  end

  @doc """
  Sets template-level instance options for this canvas.

  Useful when templates are prepared in one canvas and instances are emitted
  from another (for example, static templates cached in assigns).
  """
  def with_template_opts(%Easel{} = ctx, opts_map) when is_map(opts_map) do
    %{ctx | template_opts: Map.merge(ctx.template_opts, opts_map)}
  end

  @doc """
  Draws instances of a previously defined template.

  Each instance is a map that may contain:

    * `:x`, `:y` - translation (default `0`, `0`)
    * `:rotate` - rotation in radians (default `0`)
    * `:scale_x`, `:scale_y` - scale factors (default `1`, `1`)
    * `:fill` - fill style override (applied before template ops)
    * `:stroke` - stroke style override
    * `:alpha` - global alpha override

  The hook renders each instance via `save → translate → rotate → scale →
  [style overrides] → [template ops] → restore`.

  You can optionally quantize float values before serialization by passing
  `precision` globally or per field:

      Easel.instances(canvas, :boid, instances, precision: 2)
      Easel.instances(canvas, :boid, instances, x: 1, y: 1, rotate: 3)

  ## Example

      canvas
      |> Easel.instances(:boid, Enum.map(boids, fn b ->
        %{x: b.x, y: b.y, rotate: :math.atan2(b.vy, b.vx),
          fill: "hsl(\#{hue}, 70%, 60%)"}
      end))
  """
  def instances(%Easel{} = ctx, name, instance_data, opts \\ [])
      when is_atom(name) and is_list(instance_data) do
    merged_opts = merge_instance_opts(Map.get(ctx.template_opts, name, []), opts)
    {rows, palette, cols} = encode_instances(instance_data, merged_opts)
    push_op(ctx, ["__instances", [Atom.to_string(name), rows, palette, cols]])
  end

  defp encode_instances(instance_data, opts) do
    {rows_full, _palette_map, palette_rev} =
      Enum.reduce(instance_data, {[], %{}, []}, fn inst, {rows, pal, rev} ->
        {fill_id, pal, rev} = palette_id(Map.get(inst, :fill), pal, rev)
        {stroke_id, pal, rev} = palette_id(Map.get(inst, :stroke), pal, rev)

        row = [
          quantize(Map.get(inst, :x), :x, opts),
          quantize(Map.get(inst, :y), :y, opts),
          quantize(Map.get(inst, :rotate), :rotate, opts),
          quantize(Map.get(inst, :scale_x), :scale_x, opts),
          quantize(Map.get(inst, :scale_y), :scale_y, opts),
          fill_id,
          stroke_id,
          quantize(Map.get(inst, :alpha), :alpha, opts)
        ]

        {[row | rows], pal, rev}
      end)

    rows_full = Enum.reverse(rows_full)
    cols = active_cols(rows_full)

    rows =
      Enum.map(rows_full, fn row ->
        Enum.map(cols, &Enum.at(row, &1))
      end)

    {rows, Enum.reverse(palette_rev), cols}
  end

  defp quantize(v, _key, _opts) when is_nil(v) or is_integer(v), do: v

  defp quantize(v, key, opts) when is_float(v) do
    case quantize_places(opts, key) do
      nil -> v
      places when is_integer(places) and places >= 0 -> Float.round(v, places)
      _ -> v
    end
  end

  defp quantize(v, _key, _opts), do: v

  defp quantize_places(opts, key) do
    cond do
      is_list(opts) -> Keyword.get(opts, key) || Keyword.get(opts, :precision)
      is_map(opts) -> Map.get(opts, key) || Map.get(opts, :precision)
      true -> nil
    end
  end

  defp template_instance_opts(opts) when is_list(opts) do
    opts |> Keyword.take([:precision, :x, :y, :rotate, :scale_x, :scale_y, :alpha])
  end

  defp template_instance_opts(_), do: []

  defp merge_instance_opts(base, override) when is_list(base) and is_list(override),
    do: Keyword.merge(base, override)

  defp merge_instance_opts(_base, override) when is_list(override), do: override
  defp merge_instance_opts(base, _override) when is_list(base), do: base
  defp merge_instance_opts(_base, _override), do: []

  defp active_cols(rows) do
    # Always include x/y; include other columns only if any non-nil appears.
    base = [0, 1]

    dynamic =
      2..7
      |> Enum.filter(fn idx -> Enum.any?(rows, &(Enum.at(&1, idx) != nil)) end)

    base ++ dynamic
  end

  defp palette_id(nil, pal, rev), do: {nil, pal, rev}

  defp palette_id(style, pal, rev) when is_binary(style) do
    case pal do
      %{^style => idx} ->
        {idx, pal, rev}

      _ ->
        idx = map_size(pal)
        {idx, Map.put(pal, style, idx), [style | rev]}
    end
  end

  defp palette_id(_other, pal, rev), do: {nil, pal, rev}

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
        ["__instances", [name, rows, palette, cols]] ->
          instances = Enum.map(rows, &row_to_instance(&1, palette, cols || []))
          expand_instances(name, instances, ctx.templates)

        ["__instances", [name, rows, palette]] ->
          instances = Enum.map(rows, &row_to_instance(&1, palette, [0, 1, 2, 3, 4, 5, 6, 7]))
          expand_instances(name, instances, ctx.templates)

        ["__instances", [name, instances]] ->
          expand_instances(name, instances, ctx.templates)

        op ->
          [op]
      end)

    %{ctx | ops: expanded}
  end

  defp row_to_instance(row, palette, cols) do
    col_pos = cols |> Enum.with_index() |> Map.new()

    get = fn col_idx ->
      case Map.get(col_pos, col_idx) do
        nil -> nil
        pos -> Enum.at(row, pos)
      end
    end

    %{
      x: get.(0),
      y: get.(1),
      rotate: get.(2),
      scale_x: get.(3),
      scale_y: get.(4),
      fill: palette_lookup(palette, get.(5)),
      stroke: palette_lookup(palette, get.(6)),
      alpha: get.(7)
    }
  end

  defp palette_lookup(_palette, nil), do: nil
  defp palette_lookup(palette, idx) when is_integer(idx), do: Enum.at(palette || [], idx)
  defp palette_lookup(_palette, _), do: nil

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
  Safe to call multiple times - subsequent calls are no-ops.
  """
  def render(%Easel{rendered: true} = ctx), do: ctx

  def render(%Easel{} = ctx) do
    %{ctx | ops: Enum.reverse(ctx.ops), rendered: true}
  end
end
