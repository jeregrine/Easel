defmodule Easel do
  @moduledoc """
  Easel lets you build Canvas 2D drawing operations as data.

  Create a canvas, pipe it through `Easel.API` functions to build up
  a list of operations, then render to a backend (browser via LiveView,
  native window via wx, or consume the ops list directly).

  ## Example

      canvas =
        Easel.new(300, 300)
        |> Easel.API.set_fill_style("blue")
        |> Easel.API.fill_rect(0, 0, 100, 100)
        |> Easel.API.set_line_width(10)
        |> Easel.API.stroke_rect(100, 100, 100, 100)
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
          c |> Easel.API.begin_path() |> Easel.API.arc(0, 0, 3, 0, 6.28) |> Easel.API.fill()
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

  Most users should use `Easel.API` functions instead of this directly.
  """
  def push_op(%Easel{} = ctx, op) do
    %{ctx | ops: [op | ctx.ops], rendered: false}
  end

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
          |> Easel.API.begin_path()
          |> Easel.API.move_to(12, 0)
          |> Easel.API.line_to(-4, -5)
          |> Easel.API.line_to(-4, 5)
          |> Easel.API.close_path()
          |> Easel.API.fill()
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
  def instances(%Easel{} = ctx, name, instance_data) when is_atom(name) and is_list(instance_data) do
    push_op(ctx, ["__instances", [Atom.to_string(name), instance_data]])
  end

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
          tpl_ops = Map.get(ctx.templates, String.to_existing_atom(name), [])
          Enum.flat_map(instances, fn inst ->
            style_ops =
              []
              |> then(fn ops -> if inst[:fill], do: [["set", ["fillStyle", inst.fill]] | ops], else: ops end)
              |> then(fn ops -> if inst[:stroke], do: [["set", ["strokeStyle", inst.stroke]] | ops], else: ops end)
              |> then(fn ops -> if inst[:alpha], do: [["set", ["globalAlpha", inst.alpha]] | ops], else: ops end)
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

        op ->
          [op]
      end)

    %{ctx | ops: expanded}
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
