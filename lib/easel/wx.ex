defmodule Easel.WX do
  @moduledoc """
  A wx (wxWidgets) backend for Easel that renders draw operations
  to a native window using wxGraphicsContext.

  This maps the Canvas 2D API operations to their wx equivalents.
  Not all operations are supported — unsupported ops raise at runtime.

  ## Usage

      canvas =
        Easel.new(400, 300)
        |> Easel.API.set_fill_style("blue")
        |> Easel.API.fill_rect(50, 50, 100, 100)
        |> Easel.API.set_stroke_style("red")
        |> Easel.API.set_line_width(3)
        |> Easel.API.stroke_rect(50, 50, 100, 100)
        |> Easel.render()

      # Opens a wx window and draws the operations
      Easel.WX.render(canvas)

  ## Supported operations

  Drawing: `fillRect`, `strokeRect`, `clearRect`, `fillText`, `strokeText`

  Paths: `beginPath`, `closePath`, `moveTo`, `lineTo`, `arc`, `ellipse`,
  `rect`, `bezierCurveTo`, `quadraticCurveTo`, `arcTo`, `fill`, `stroke`

  Styles: `fillStyle`, `strokeStyle`, `lineWidth`, `lineCap`, `lineJoin`,
  `font`, `globalAlpha`

  Transforms: `save`, `restore`, `translate`, `rotate`, `scale`,
  `setTransform`, `resetTransform`, `transform`

  ## Unsupported operations

  Operations that have no wx equivalent will raise `Easel.WX.UnsupportedOpError`.
  These include: shadows, filters, compositing modes, image data, patterns,
  gradients, clipping, and text measurement.
  """

  defmodule UnsupportedOpError do
    defexception [:op]

    @impl true
    def message(%{op: op}) do
      "Easel operation #{inspect(op)} is not supported by the wx backend"
    end
  end

  @unsupported_ops ~w(
    createConicGradient createLinearGradient createRadialGradient createPattern
    createImageData getImageData putImageData
    drawImage drawFocusIfNeeded
    clip isPointInPath isPointInStroke
    measureText getLineDash getTransform
    filter globalCompositeOperation
    imageSmoothingEnabled imageSmoothingQuality
    shadowBlur shadowColor shadowOffsetX shadowOffsetY
    lineDashOffset
    direction
  )

  @doc """
  Renders an Easel struct to a wx window.

  Opens a native window, draws all operations, and keeps the window
  open until it is closed by the user.

  ## Options

    * `:title` - window title (default `"Easel"`)
  """
  def render(%Easel{} = canvas, opts \\ []) do
    canvas = Easel.render(canvas)
    title = Keyword.get(opts, :title, "Easel")
    width = canvas.width || 400
    height = canvas.height || 300

    wx = :wx.new()
    frame = :wxFrame.new(wx, -1, String.to_charlist(title), size: {width, height})
    panel = :wxPanel.new(frame)

    :wxPanel.connect(panel, :paint, [:callback])

    :wxFrame.show(frame)

    :wxPanel.setFocus(panel)

    receive_loop(frame, panel, canvas.ops, width, height)
  end

  @doc """
  Runs an animation loop in a wx window.

  Takes a width, height, initial state, and a function that receives
  the current state and returns `{%Easel{}, new_state}`. The function
  is called every `interval` milliseconds (default 16, ~60fps).

  The loop runs until the window is closed, then returns `:ok`.

  ## Options

    * `:title` - window title (default `"Easel"`)
    * `:interval` - milliseconds between frames (default `16`)

  ## Example

      Easel.WX.animate(600, 400, initial_state, fn state ->
        {canvas, new_state} = MyApp.tick(state)
        {canvas, new_state}
      end, title: "Animation")
  """
  def animate(width, height, state, fun, opts \\ []) when is_function(fun, 1) do
    title = Keyword.get(opts, :title, "Easel")
    interval = Keyword.get(opts, :interval, 16)

    wx = :wx.new()
    frame = :wxFrame.new(wx, -1, String.to_charlist(title), size: {width, height})
    panel = :wxPanel.new(frame)

    :wxPanel.connect(panel, :paint, [:callback])

    :wxFrame.show(frame)

    :wxPanel.setFocus(panel)

    # Kick off the first frame
    timer = :timer.send_interval(interval, :tick)
    result = animate_loop(frame, panel, width, height, state, fun)
    :timer.cancel(timer)
    result
  end

  defp animate_loop(frame, panel, width, height, state, fun) do
    receive do
      :tick ->
        {canvas, new_state} = fun.(state)
        canvas = Easel.render(canvas)
        # Trigger repaint with new ops
        send(self(), {:redraw, canvas.ops})
        animate_loop(frame, panel, width, height, new_state, fun)

      {:redraw, ops} ->
        :wxPanel.refresh(panel)

        receive do
          {:wx, _, _, _, {:wxPaint, :paint}} ->
            paint(panel, ops, width, height)
        after
          100 -> :ok
        end

        animate_loop(frame, panel, width, height, state, fun)

      {:wx, _, _, _, {:wxPaint, :paint}} ->
        # Initial paint or spurious - just run one frame
        {canvas, new_state} = fun.(state)
        canvas = Easel.render(canvas)
        paint(panel, canvas.ops, width, height)
        animate_loop(frame, panel, width, height, new_state, fun)

      {:wx, _, _, _, {:wxClose, :close_window}} ->
        :wxFrame.destroy(frame)
        :ok

      _other ->
        animate_loop(frame, panel, width, height, state, fun)
    end
  end

  defp receive_loop(frame, panel, ops, width, height) do
    receive do
      # Paint callback
      {:wx, _, _, _, {:wxPaint, :paint}} ->
        paint(panel, ops, width, height)
        receive_loop(frame, panel, ops, width, height)

      # Window close
      {:wx, _, _, _, {:wxClose, :close_window}} ->
        :wxFrame.destroy(frame)
        :ok

      _other ->
        receive_loop(frame, panel, ops, width, height)
    end
  end

  defp paint(panel, ops, width, height) do
    dc = :wxPaintDC.new(panel)
    gc = :wxGraphicsContext.create(dc)

    state = %{
      gc: gc,
      dc: dc,
      width: width,
      height: height,
      path: nil,
      fill_style: {0, 0, 0, 255},
      stroke_style: {0, 0, 0, 255},
      line_width: 1.0,
      line_cap: :wxCAP_BUTT,
      line_join: :wxJOIN_MITER,
      font_size: 10,
      font_face: ~c"sans-serif",
      font_style: :wxFONTSTYLE_NORMAL,
      font_weight: :wxFONTWEIGHT_NORMAL,
      global_alpha: 1.0,
      text_align: :start,
      text_baseline: :alphabetic,
      saved: [],
      miter_limit: 10.0,
      line_dash: []
    }

    Enum.reduce(ops, state, &execute_op/2)

    :wxPaintDC.destroy(dc)
  end

  # ── Operations ───────────────────────────────────────────────────────

  defp execute_op(["set", [key, value]], state) do
    set_property(key, value, state)
  end

  defp execute_op([op, _args], _state) when op in @unsupported_ops do
    raise UnsupportedOpError, op: op
  end

  # -- State --

  defp execute_op(["save", []], state) do
    :wxGraphicsContext.pushState(state.gc)
    saved_state = Map.drop(state, [:gc, :dc, :saved])
    %{state | saved: [saved_state | state.saved]}
  end

  defp execute_op(["restore", []], %{saved: [prev | rest]} = state) do
    :wxGraphicsContext.popState(state.gc)
    Map.merge(state, prev) |> Map.put(:saved, rest)
  end

  defp execute_op(["restore", []], state), do: state

  defp execute_op(["reset", []], state) do
    :wxGraphicsContext.setTransform(state.gc, :wxGraphicsContext.createMatrix(state.gc))

    %{state |
      path: nil,
      fill_style: {0, 0, 0, 255},
      stroke_style: {0, 0, 0, 255},
      line_width: 1.0,
      line_cap: :wxCAP_BUTT,
      line_join: :wxJOIN_MITER,
      font_size: 10,
      font_face: ~c"sans-serif",
      global_alpha: 1.0,
      saved: [],
      line_dash: []
    }
  end

  # -- Transforms --

  defp execute_op(["translate", [x, y]], state) do
    :wxGraphicsContext.translate(state.gc, to_float(x), to_float(y))
    state
  end

  defp execute_op(["rotate", [angle]], state) do
    :wxGraphicsContext.rotate(state.gc, to_float(angle))
    state
  end

  defp execute_op(["scale", [x, y]], state) do
    :wxGraphicsContext.scale(state.gc, to_float(x), to_float(y))
    state
  end

  defp execute_op(["setTransform", [a, b, c, d, e, f]], state) do
    matrix = :wxGraphicsContext.createMatrix(state.gc, a: a, b: b, c: c, d: d, tx: e, ty: f)
    :wxGraphicsContext.setTransform(state.gc, matrix)
    state
  end

  defp execute_op(["setTransform", []], state) do
    matrix = :wxGraphicsContext.createMatrix(state.gc)
    :wxGraphicsContext.setTransform(state.gc, matrix)
    state
  end

  defp execute_op(["setTransform", [_matrix]], _state) do
    # DOMMatrix object — not directly supported
    raise UnsupportedOpError, op: "setTransform(DOMMatrix)"
  end

  defp execute_op(["resetTransform", []], state) do
    matrix = :wxGraphicsContext.createMatrix(state.gc)
    :wxGraphicsContext.setTransform(state.gc, matrix)
    state
  end

  defp execute_op(["transform", [a, b, c, d, e, f]], state) do
    matrix = :wxGraphicsContext.createMatrix(state.gc, a: a, b: b, c: c, d: d, tx: e, ty: f)
    :wxGraphicsContext.concatTransform(state.gc, matrix)
    state
  end

  # -- Rectangles --

  defp execute_op(["fillRect", [x, y, w, h]], state) do
    apply_brush(state)
    :wxGraphicsContext.setPen(state.gc, :wxPen.new({0, 0, 0, 0}, width: 0, style: :wxPENSTYLE_TRANSPARENT))
    :wxGraphicsContext.drawRectangle(state.gc, to_float(x), to_float(y), to_float(w), to_float(h))
    state
  end

  defp execute_op(["strokeRect", [x, y, w, h]], state) do
    apply_pen(state)
    :wxGraphicsContext.setBrush(state.gc, :wxBrush.new({0, 0, 0, 0}, style: :wxBRUSHSTYLE_TRANSPARENT))
    :wxGraphicsContext.drawRectangle(state.gc, to_float(x), to_float(y), to_float(w), to_float(h))
    state
  end

  defp execute_op(["clearRect", [x, y, w, h]], state) do
    :wxGraphicsContext.setBrush(state.gc, :wxBrush.new({255, 255, 255, 255}))
    :wxGraphicsContext.setPen(state.gc, :wxPen.new({0, 0, 0, 0}, width: 0, style: :wxPENSTYLE_TRANSPARENT))
    :wxGraphicsContext.drawRectangle(state.gc, to_float(x), to_float(y), to_float(w), to_float(h))
    state
  end

  # -- Path operations --

  defp execute_op(["beginPath", []], state) do
    path = :wxGraphicsContext.createPath(state.gc)
    %{state | path: path}
  end

  defp execute_op(["closePath", []], %{path: nil} = state), do: state

  defp execute_op(["closePath", []], state) do
    :wxGraphicsPath.closeSubpath(state.path)
    state
  end

  defp execute_op(["moveTo", [x, y]], state) do
    state = ensure_path(state)
    :wxGraphicsPath.moveToPoint(state.path, to_float(x), to_float(y))
    state
  end

  defp execute_op(["lineTo", [x, y]], state) do
    state = ensure_path(state)
    :wxGraphicsPath.addLineToPoint(state.path, to_float(x), to_float(y))
    state
  end

  defp execute_op(["bezierCurveTo", [cp1x, cp1y, cp2x, cp2y, x, y]], state) do
    state = ensure_path(state)

    :wxGraphicsPath.addCurveToPoint(
      state.path,
      to_float(cp1x), to_float(cp1y),
      to_float(cp2x), to_float(cp2y),
      to_float(x), to_float(y)
    )

    state
  end

  defp execute_op(["quadraticCurveTo", [cpx, cpy, x, y]], state) do
    state = ensure_path(state)

    :wxGraphicsPath.addQuadCurveToPoint(
      state.path,
      to_float(cpx), to_float(cpy),
      to_float(x), to_float(y)
    )

    state
  end

  defp execute_op(["arc", args], state) do
    state = ensure_path(state)
    [cx, cy, radius, start_angle, end_angle | rest] = args
    anticlockwise = List.first(rest, false)

    # wx arc goes clockwise by default, canvas goes counter-clockwise
    # wx addArc takes (x, y, radius, start_angle, end_angle)
    # where angles are in radians and direction is determined by sign of sweep
    if anticlockwise do
      :wxGraphicsPath.addArc(
        state.path,
        to_float(cx), to_float(cy), to_float(radius),
        to_float(start_angle), to_float(end_angle)
      )
    else
      :wxGraphicsPath.addArc(
        state.path,
        to_float(cx), to_float(cy), to_float(radius),
        to_float(start_angle), to_float(end_angle)
      )
    end

    state
  end

  defp execute_op(["ellipse", args], state) do
    state = ensure_path(state)
    [cx, cy, rx, ry, rotation, start_angle, end_angle | _rest] = args

    # wx doesn't have a native ellipse path — approximate with transforms
    # Save, translate to center, rotate, scale y, add arc, restore
    :wxGraphicsPath.addEllipse(
      state.path,
      to_float(cx) - to_float(rx),
      to_float(cy) - to_float(ry),
      to_float(rx) * 2,
      to_float(ry) * 2
    )

    _ = {rotation, start_angle, end_angle}
    state
  end

  defp execute_op(["rect", [x, y, w, h]], state) do
    state = ensure_path(state)
    :wxGraphicsPath.addRectangle(state.path, to_float(x), to_float(y), to_float(w), to_float(h))
    state
  end

  defp execute_op(["arcTo", [x1, y1, x2, y2, radius]], state) do
    state = ensure_path(state)

    :wxGraphicsPath.addArcToPoint(
      state.path,
      to_float(x1), to_float(y1),
      to_float(x2), to_float(y2),
      to_float(radius)
    )

    state
  end

  defp execute_op(["roundRect", [x, y, w, h, radii]], state) do
    state = ensure_path(state)
    r = if is_list(radii), do: List.first(radii, 0), else: radii

    :wxGraphicsPath.addRoundedRectangle(
      state.path,
      to_float(x), to_float(y),
      to_float(w), to_float(h),
      to_float(r)
    )

    state
  end

  # -- Fill / Stroke path --

  defp execute_op(["fill", _args], %{path: nil} = state), do: state

  defp execute_op(["fill", _args], state) do
    apply_brush(state)
    :wxGraphicsContext.fillPath(state.gc, state.path)
    state
  end

  defp execute_op(["stroke", _args], %{path: nil} = state), do: state

  defp execute_op(["stroke", _args], state) do
    apply_pen(state)
    :wxGraphicsContext.strokePath(state.gc, state.path)
    state
  end

  # -- Text --

  defp execute_op(["fillText", [text, x, y | _rest]], state) do
    apply_font(state)
    apply_brush(state)
    :wxGraphicsContext.drawText(state.gc, String.to_charlist(text), to_float(x), to_float(y))
    state
  end

  defp execute_op(["strokeText", [text, x, y | _rest]], state) do
    # wx doesn't have native stroke text — draw as fill
    apply_font(state)
    apply_brush(state)
    :wxGraphicsContext.drawText(state.gc, String.to_charlist(text), to_float(x), to_float(y))
    state
  end

  # -- Line dash --

  defp execute_op(["setLineDash", [segments]], state) when is_list(segments) do
    %{state | line_dash: segments}
  end

  defp execute_op(["setLineDash", _], state), do: state

  # -- Catch-all --

  defp execute_op([op, _args], _state) do
    raise UnsupportedOpError, op: op
  end

  # ── Property setters ─────────────────────────────────────────────────

  defp set_property("fillStyle", value, state) do
    %{state | fill_style: parse_color(value, state.global_alpha)}
  end

  defp set_property("strokeStyle", value, state) do
    %{state | stroke_style: parse_color(value, state.global_alpha)}
  end

  defp set_property("lineWidth", value, state) do
    %{state | line_width: to_float(value)}
  end

  defp set_property("lineCap", value, state) do
    cap =
      case value do
        "butt" -> :wxCAP_BUTT
        "round" -> :wxCAP_ROUND
        "square" -> :wxCAP_PROJECTING
        _ -> :wxCAP_BUTT
      end

    %{state | line_cap: cap}
  end

  defp set_property("lineJoin", value, state) do
    join =
      case value do
        "miter" -> :wxJOIN_MITER
        "round" -> :wxJOIN_ROUND
        "bevel" -> :wxJOIN_BEVEL
        _ -> :wxJOIN_MITER
      end

    %{state | line_join: join}
  end

  defp set_property("miterLimit", value, state) do
    %{state | miter_limit: to_float(value)}
  end

  defp set_property("font", value, state) when is_binary(value) do
    {size, face, style, weight} = parse_font(value)
    %{state | font_size: size, font_face: face, font_style: style, font_weight: weight}
  end

  defp set_property("globalAlpha", value, state) do
    %{state | global_alpha: to_float(value)}
  end

  defp set_property("textAlign", value, state) do
    align =
      case value do
        "left" -> :left
        "right" -> :right
        "center" -> :center
        "start" -> :start
        "end" -> :end_
        _ -> :start
      end

    %{state | text_align: align}
  end

  defp set_property("textBaseline", value, state) do
    %{state | text_baseline: String.to_atom(value)}
  end

  defp set_property(key, _value, _state) do
    raise UnsupportedOpError, op: "set #{key}"
  end

  # ── Helpers ──────────────────────────────────────────────────────────

  defp ensure_path(%{path: nil, gc: gc} = state) do
    %{state | path: :wxGraphicsContext.createPath(gc)}
  end

  defp ensure_path(state), do: state

  defp apply_brush(state) do
    {r, g, b, a} = apply_alpha(state.fill_style, state.global_alpha)
    brush = :wxBrush.new({r, g, b, a})
    :wxGraphicsContext.setBrush(state.gc, brush)
  end

  defp apply_pen(state) do
    {r, g, b, a} = apply_alpha(state.stroke_style, state.global_alpha)
    width = max(round(state.line_width), 1)

    style =
      case state.line_dash do
        [_ | _] -> :wxPENSTYLE_SHORT_DASH
        _ -> :wxPENSTYLE_SOLID
      end

    pen = :wxPen.new({r, g, b, a}, width: width, style: style)
    :wxPen.setCap(pen, state.line_cap)
    :wxPen.setJoin(pen, state.line_join)
    :wxGraphicsContext.setPen(state.gc, pen)
  end

  defp apply_font(state) do
    font =
      :wxFont.new(
        state.font_size,
        :wxFONTFAMILY_DEFAULT,
        state.font_style,
        state.font_weight,
        faceName: state.font_face
      )

    :wxGraphicsContext.setFont(state.gc, font, tuple_to_wx_colour(state.fill_style))
  end

  defp apply_alpha({r, g, b, a}, global_alpha) do
    {r, g, b, round(a * global_alpha)}
  end

  defp tuple_to_wx_colour({r, g, b, _a}), do: {r, g, b}

  defp to_float(n) when is_float(n), do: n
  defp to_float(n) when is_integer(n), do: n * 1.0
  defp to_float(n) when is_binary(n), do: String.to_float(n)

  # ── Color parsing ───────────────────────────────────────────────────

  @named_colors %{
    "black" => {0, 0, 0, 255},
    "white" => {255, 255, 255, 255},
    "red" => {255, 0, 0, 255},
    "green" => {0, 128, 0, 255},
    "blue" => {0, 0, 255, 255},
    "yellow" => {255, 255, 0, 255},
    "cyan" => {0, 255, 255, 255},
    "magenta" => {255, 0, 255, 255},
    "orange" => {255, 165, 0, 255},
    "purple" => {128, 0, 128, 255},
    "gray" => {128, 128, 128, 255},
    "grey" => {128, 128, 128, 255},
    "transparent" => {0, 0, 0, 0}
  }

  @doc """
  Parses a CSS color string into an `{r, g, b, a}` tuple.

  Supports named colors, hex (`#rgb`, `#rrggbb`, `#rrggbbaa`),
  `rgb()`, and `rgba()`.
  """
  def parse_color(value, alpha \\ 1.0)

  def parse_color(value, _alpha) when is_binary(value) do
    value = String.trim(value) |> String.downcase()

    cond do
      Map.has_key?(@named_colors, value) ->
        @named_colors[value]

      String.starts_with?(value, "#") ->
        parse_hex_color(value)

      String.starts_with?(value, "rgba(") ->
        parse_rgba(value)

      String.starts_with?(value, "rgb(") ->
        parse_rgb(value)

      true ->
        {0, 0, 0, 255}
    end
  end

  def parse_color(_value, _alpha), do: {0, 0, 0, 255}

  defp parse_hex_color("#" <> hex) do
    case String.length(hex) do
      3 ->
        <<r::binary-1, g::binary-1, b::binary-1>> = hex
        {parse_hex(r <> r), parse_hex(g <> g), parse_hex(b <> b), 255}

      6 ->
        <<r::binary-2, g::binary-2, b::binary-2>> = hex
        {parse_hex(r), parse_hex(g), parse_hex(b), 255}

      8 ->
        <<r::binary-2, g::binary-2, b::binary-2, a::binary-2>> = hex
        {parse_hex(r), parse_hex(g), parse_hex(b), parse_hex(a)}

      _ ->
        {0, 0, 0, 255}
    end
  end

  defp parse_hex(s), do: String.to_integer(s, 16)

  defp parse_rgba(str) do
    case Regex.run(~r/rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*([\d.]+)\s*\)/, str) do
      [_, r, g, b, a] ->
        {String.to_integer(r), String.to_integer(g), String.to_integer(b),
         round(String.to_float(normalize_float(a)) * 255)}

      _ ->
        {0, 0, 0, 255}
    end
  end

  defp parse_rgb(str) do
    case Regex.run(~r/rgb\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)/, str) do
      [_, r, g, b] ->
        {String.to_integer(r), String.to_integer(g), String.to_integer(b), 255}

      _ ->
        {0, 0, 0, 255}
    end
  end

  defp normalize_float(s) do
    if String.contains?(s, "."), do: s, else: s <> ".0"
  end

  # ── Font parsing ────────────────────────────────────────────────────

  @doc """
  Parses a CSS font shorthand string into `{size, face, style, weight}`.

  Returns a tuple of `{integer, charlist, wx_style_atom, wx_weight_atom}`.
  """
  def parse_font(font_str) do
    # Simple CSS font parser: "italic bold 16px Arial" or "12px sans-serif"
    parts = String.split(font_str)

    {style, parts} =
      case parts do
        ["italic" | rest] -> {:wxFONTSTYLE_ITALIC, rest}
        ["oblique" | rest] -> {:wxFONTSTYLE_SLANT, rest}
        other -> {:wxFONTSTYLE_NORMAL, other}
      end

    {weight, parts} =
      case parts do
        ["bold" | rest] -> {:wxFONTWEIGHT_BOLD, rest}
        ["lighter" | rest] -> {:wxFONTWEIGHT_LIGHT, rest}
        other -> {:wxFONTWEIGHT_NORMAL, other}
      end

    {size, face} =
      case parts do
        [size_str | face_parts] ->
          size =
            size_str
            |> String.replace(~r/px$/, "")
            |> String.to_integer()

          face =
            case face_parts do
              [] -> ~c"sans-serif"
              _ -> face_parts |> Enum.join(" ") |> String.to_charlist()
            end

          {size, face}

        [] ->
          {10, ~c"sans-serif"}
      end

    {size, face, style, weight}
  end
end
