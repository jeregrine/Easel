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
    * `Easel.Terminal` - Experimental terminal renderer (wx off-screen raster + ASCII)
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
  def push_op(%Easel{rendered: true} = ctx, op) do
    # ops is in forward order when rendered; un-reverse before prepending
    %{ctx | ops: [op | Enum.reverse(ctx.ops)], rendered: false}
  end

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

  # Generated once from priv/easel.webidl + priv/compat.json.
  # To regenerate this section, run: mix easel.regen_canvas_api

  # --- BEGIN GENERATED CANVAS API ---
  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/arc"
  def arc(ctx, x, y, radius, start_angle, end_angle) do
    call(ctx, "arc", [x, y, radius, start_angle, end_angle])
  end

  def arc(ctx, x, y, radius, start_angle, end_angle, anticlockwise) do
    call(ctx, "arc", [x, y, radius, start_angle, end_angle, anticlockwise])
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/arcTo"
  def arc_to(ctx, x1, y1, x2, y2, radius) do
    call(ctx, "arcTo", [x1, y1, x2, y2, radius])
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/beginPath"
  def begin_path(ctx) do
    call(ctx, "beginPath", [])
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/bezierCurveTo"
  def bezier_curve_to(ctx, cp1x, cp1y, cp2x, cp2y, x, y) do
    call(ctx, "bezierCurveTo", [cp1x, cp1y, cp2x, cp2y, x, y])
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/clearRect"
  def clear_rect(ctx, x, y, w, h) do
    call(ctx, "clearRect", [x, y, w, h])
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/clip"
  def clip(ctx) do
    call(ctx, "clip", [])
  end

  def clip(ctx, winding) do
    call(ctx, "clip", [winding])
  end

  def clip(ctx, path, winding) do
    call(ctx, "clip", [path, winding])
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/closePath"
  def close_path(ctx) do
    call(ctx, "closePath", [])
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/createImageData"
  def create_image_data(ctx, imagedata) do
    call(ctx, "createImageData", [imagedata])
  end

  def create_image_data(ctx, sw, sh) do
    call(ctx, "createImageData", [sw, sh])
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/createLinearGradient"
  def create_linear_gradient(ctx, x0, y0, x1, y1) do
    call(ctx, "createLinearGradient", [x0, y0, x1, y1])
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/createPattern"
  def create_pattern(ctx, image, repetition) do
    call(ctx, "createPattern", [image, repetition])
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/createRadialGradient"
  def create_radial_gradient(ctx, x0, y0, r0, x1, y1, r1) do
    call(ctx, "createRadialGradient", [x0, y0, r0, x1, y1, r1])
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/drawFocusIfNeeded"
  def draw_focus_if_needed(ctx, element) do
    call(ctx, "drawFocusIfNeeded", [element])
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/drawImage"
  def draw_image(ctx, image, dx, dy) do
    call(ctx, "drawImage", [image, dx, dy])
  end

  def draw_image(ctx, image, dx, dy, dw, dh) do
    call(ctx, "drawImage", [image, dx, dy, dw, dh])
  end

  def draw_image(ctx, image, sx, sy, sw, sh, dx, dy, dw, dh) do
    call(ctx, "drawImage", [image, sx, sy, sw, sh, dx, dy, dw, dh])
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/ellipse"
  def ellipse(ctx, x, y, radius_x, radius_y, rotation, start_angle, end_angle) do
    call(ctx, "ellipse", [x, y, radius_x, radius_y, rotation, start_angle, end_angle])
  end

  def ellipse(ctx, x, y, radius_x, radius_y, rotation, start_angle, end_angle, anticlockwise) do
    call(ctx, "ellipse", [
      x,
      y,
      radius_x,
      radius_y,
      rotation,
      start_angle,
      end_angle,
      anticlockwise
    ])
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/fill"
  def fill(ctx) do
    call(ctx, "fill", [])
  end

  def fill(ctx, winding) do
    call(ctx, "fill", [winding])
  end

  def fill(ctx, path, winding) do
    call(ctx, "fill", [path, winding])
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/fillRect"
  def fill_rect(ctx, x, y, w, h) do
    call(ctx, "fillRect", [x, y, w, h])
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/fillText"
  def fill_text(ctx, text, x, y) do
    call(ctx, "fillText", [text, x, y])
  end

  def fill_text(ctx, text, x, y, max_width) do
    call(ctx, "fillText", [text, x, y, max_width])
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/getImageData"
  def get_image_data(ctx, sx, sy, sw, sh) do
    call(ctx, "getImageData", [sx, sy, sw, sh])
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/getLineDash"
  def get_line_dash(ctx) do
    call(ctx, "getLineDash", [])
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/getTransform"
  def get_transform(ctx) do
    call(ctx, "getTransform", [])
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/isPointInPath"
  def is_point_in_path(ctx, x, y) do
    call(ctx, "isPointInPath", [x, y])
  end

  def is_point_in_path(ctx, x, y, winding) do
    call(ctx, "isPointInPath", [x, y, winding])
  end

  def is_point_in_path(ctx, path, x, y, winding) do
    call(ctx, "isPointInPath", [path, x, y, winding])
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/isPointInStroke"
  def is_point_in_stroke(ctx, x, y) do
    call(ctx, "isPointInStroke", [x, y])
  end

  def is_point_in_stroke(ctx, path, x, y) do
    call(ctx, "isPointInStroke", [path, x, y])
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/lineTo"
  def line_to(ctx, x, y) do
    call(ctx, "lineTo", [x, y])
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/measureText"
  def measure_text(ctx, text) do
    call(ctx, "measureText", [text])
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/moveTo"
  def move_to(ctx, x, y) do
    call(ctx, "moveTo", [x, y])
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/putImageData"
  def put_image_data(ctx, imagedata, dx, dy) do
    call(ctx, "putImageData", [imagedata, dx, dy])
  end

  def put_image_data(ctx, imagedata, dx, dy, dirty_x, dirty_y, dirty_width, dirty_height) do
    call(ctx, "putImageData", [imagedata, dx, dy, dirty_x, dirty_y, dirty_width, dirty_height])
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/quadraticCurveTo"
  def quadratic_curve_to(ctx, cpx, cpy, x, y) do
    call(ctx, "quadraticCurveTo", [cpx, cpy, x, y])
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/rect"
  def rect(ctx, x, y, w, h) do
    call(ctx, "rect", [x, y, w, h])
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/resetTransform"
  def reset_transform(ctx) do
    call(ctx, "resetTransform", [])
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/restore"
  def restore(ctx) do
    call(ctx, "restore", [])
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/rotate"
  def rotate(ctx, angle) do
    call(ctx, "rotate", [angle])
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/save"
  def save(ctx) do
    call(ctx, "save", [])
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/scale"
  def scale(ctx, x, y) do
    call(ctx, "scale", [x, y])
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/fillStyle"
  def set_fill_style(ctx, value) do
    set(ctx, "fillStyle", value)
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/filter"
  def set_filter(ctx, value) do
    set(ctx, "filter", value)
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/font"
  def set_font(ctx, value) do
    set(ctx, "font", value)
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/globalAlpha"
  def set_global_alpha(ctx, value) do
    set(ctx, "globalAlpha", value)
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/globalCompositeOperation"
  def set_global_composite_operation(ctx, value) do
    set(ctx, "globalCompositeOperation", value)
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/imageSmoothingEnabled"
  def set_image_smoothing_enabled(ctx, value) do
    set(ctx, "imageSmoothingEnabled", value)
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/lineCap"
  def set_line_cap(ctx, value) do
    set(ctx, "lineCap", value)
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/setLineDash"
  def set_line_dash(ctx, segments) do
    call(ctx, "setLineDash", [segments])
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/lineDashOffset"
  def set_line_dash_offset(ctx, value) do
    set(ctx, "lineDashOffset", value)
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/lineJoin"
  def set_line_join(ctx, value) do
    set(ctx, "lineJoin", value)
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/lineWidth"
  def set_line_width(ctx, value) do
    set(ctx, "lineWidth", value)
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/miterLimit"
  def set_miter_limit(ctx, value) do
    set(ctx, "miterLimit", value)
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/shadowBlur"
  def set_shadow_blur(ctx, value) do
    set(ctx, "shadowBlur", value)
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/shadowColor"
  def set_shadow_color(ctx, value) do
    set(ctx, "shadowColor", value)
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/shadowOffsetX"
  def set_shadow_offset_x(ctx, value) do
    set(ctx, "shadowOffsetX", value)
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/shadowOffsetY"
  def set_shadow_offset_y(ctx, value) do
    set(ctx, "shadowOffsetY", value)
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/strokeStyle"
  def set_stroke_style(ctx, value) do
    set(ctx, "strokeStyle", value)
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/textAlign"
  def set_text_align(ctx, value) do
    set(ctx, "textAlign", value)
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/textBaseline"
  def set_text_baseline(ctx, value) do
    set(ctx, "textBaseline", value)
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/setTransform"
  def set_transform(ctx) do
    call(ctx, "setTransform", [])
  end

  def set_transform(ctx, transform) do
    call(ctx, "setTransform", [transform])
  end

  def set_transform(ctx, a, b, c, d, e, f) do
    call(ctx, "setTransform", [a, b, c, d, e, f])
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/stroke"
  def stroke(ctx) do
    call(ctx, "stroke", [])
  end

  def stroke(ctx, path) do
    call(ctx, "stroke", [path])
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/strokeRect"
  def stroke_rect(ctx, x, y, w, h) do
    call(ctx, "strokeRect", [x, y, w, h])
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/strokeText"
  def stroke_text(ctx, text, x, y) do
    call(ctx, "strokeText", [text, x, y])
  end

  def stroke_text(ctx, text, x, y, max_width) do
    call(ctx, "strokeText", [text, x, y, max_width])
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/transform"
  def transform(ctx, a, b, c, d, e, f) do
    call(ctx, "transform", [a, b, c, d, e, f])
  end

  @doc "https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/translate"
  def translate(ctx, x, y) do
    call(ctx, "translate", [x, y])
  end

  # --- END GENERATED CANVAS API ---

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
      0 -> round(v)
      places when is_integer(places) and places > 0 -> Float.round(v, places)
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
          col_pos = col_positions(cols || [])
          instances = Enum.map(rows, &row_to_instance(&1, palette, col_pos))
          expand_instances(name, instances, ctx.templates)

        ["__instances", [name, rows, palette]] ->
          col_pos = col_positions([0, 1, 2, 3, 4, 5, 6, 7])
          instances = Enum.map(rows, &row_to_instance(&1, palette, col_pos))
          expand_instances(name, instances, ctx.templates)

        ["__instances", [name, instances]] ->
          expand_instances(name, instances, ctx.templates)

        op ->
          [op]
      end)

    %{ctx | ops: expanded}
  end

  defp col_positions(cols) do
    cols |> Enum.with_index() |> Map.new()
  end

  defp row_to_instance(row, palette, col_pos) do
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
    tpl_ops =
      try do
        Map.get(templates, String.to_existing_atom(name), [])
      rescue
        ArgumentError -> []
      end

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
        |> then(fn ops ->
          if not is_nil(inst[:rotate]), do: ops ++ [["rotate", [inst.rotate]]], else: ops
        end)
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
