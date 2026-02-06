defmodule Easel.WX do
  @moduledoc """
  A wx (wxWidgets) backend for Easel that renders draw operations
  to a native window using wxGraphicsContext.

  Uses `:wx_object` for proper OTP lifecycle management and
  double buffering via `wxBitmap` + `wxMemoryDC` for flicker-free rendering.

  Requires Erlang compiled with wx support. When wx is not available,
  `render/2` and `animate/5` will raise at runtime.

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

  ## Animation

      Easel.WX.animate(600, 400, initial_state, fn state ->
        {canvas, new_state} = MyApp.tick(state)
        {canvas, new_state}
      end, title: "Animation")

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

  # ── Always-available code ───────────────────────────────────────────

  defmodule UnsupportedOpError do
    defexception [:op]

    @impl true
    def message(%{op: op}) do
      "Easel operation #{inspect(op)} is not supported by the wx backend"
    end
  end

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

      String.starts_with?(value, "hsla(") ->
        parse_hsla(value)

      String.starts_with?(value, "hsl(") ->
        parse_hsl(value)

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

  defp parse_hsl(str) do
    case Regex.run(~r/hsl\(\s*([\d.]+)\s*,\s*([\d.]+)%\s*,\s*([\d.]+)%\s*\)/, str) do
      [_, h, s, l] ->
        hsl_to_rgb(parse_number(h), parse_number(s) / 100, parse_number(l) / 100, 255)

      _ ->
        {0, 0, 0, 255}
    end
  end

  defp parse_hsla(str) do
    case Regex.run(
           ~r/hsla\(\s*([\d.]+)\s*,\s*([\d.]+)%\s*,\s*([\d.]+)%\s*,\s*([\d.]+)\s*\)/,
           str
         ) do
      [_, h, s, l, a] ->
        hsl_to_rgb(
          parse_number(h),
          parse_number(s) / 100,
          parse_number(l) / 100,
          round(parse_number(a) * 255)
        )

      _ ->
        {0, 0, 0, 255}
    end
  end

  defp parse_number(s) do
    if String.contains?(s, ".") do
      String.to_float(s)
    else
      String.to_integer(s) * 1.0
    end
  end

  defp hsl_to_rgb(h, s, l, a) do
    h = h / 360.0
    {r, g, b} =
      if s == 0.0 do
        {l, l, l}
      else
        q = if l < 0.5, do: l * (1 + s), else: l + s - l * s
        p = 2 * l - q
        {hue_to_rgb(p, q, h + 1 / 3), hue_to_rgb(p, q, h), hue_to_rgb(p, q, h - 1 / 3)}
      end

    {round(r * 255), round(g * 255), round(b * 255), a}
  end

  defp hue_to_rgb(p, q, t) do
    t = cond do
      t < 0 -> t + 1
      t > 1 -> t - 1
      true -> t
    end

    cond do
      t < 1 / 6 -> p + (q - p) * 6 * t
      t < 1 / 2 -> q
      t < 2 / 3 -> p + (q - p) * (2 / 3 - t) * 6
      true -> p
    end
  end

  @doc """
  Parses a CSS font shorthand string into `{size, face, style, weight}`.

  Returns a tuple of `{integer, charlist, wx_style_atom, wx_weight_atom}`.
  """
  def parse_font(font_str) do
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

  @doc """
  Returns true if wx is available in the current Erlang runtime.
  """
  def available? do
    match?({:module, _}, Code.ensure_loaded(:wx))
  end

  # ── wx-dependent code ───────────────────────────────────────────────

  # Everything below requires wx at compile time for Record.extract
  # and the :wx_object behaviour. When wx is not available, render/2
  # and animate/5 are defined as stubs that raise.

  @wx_available match?({:module, _}, Code.ensure_compiled(:wx))

  if @wx_available do
    @behaviour :wx_object

    require Record
    Record.defrecordp(:wx, Record.extract(:wx, from_lib: "wx/include/wx.hrl"))
    Record.defrecordp(:wxClose, Record.extract(:wxClose, from_lib: "wx/include/wx.hrl"))
    Record.defrecordp(:wxPaint, Record.extract(:wxPaint, from_lib: "wx/include/wx.hrl"))
    Record.defrecordp(:wxMouse, Record.extract(:wxMouse, from_lib: "wx/include/wx.hrl"))
    Record.defrecordp(:wxKey, Record.extract(:wxKey, from_lib: "wx/include/wx.hrl"))

    # wx constants — plain integers, safe as compile-time attrs
    @wx_id_any -1
    @wx_default_frame_style 541_072_960
    @wx_resize_border 64
    @wx_vertical 8
    @wx_expand 8192

    # Style constants are runtime-resolved via persistent_term (require wx:new() first).
    # We use wxe_util:get_const/1 which is what the Erlang wx.hrl macros expand to.
    # Callers pass atoms like :wxPENSTYLE_TRANSPARENT and get back integers.
    defp wx_const(atom) when is_atom(atom), do: :wxe_util.get_const(atom)



    defstruct [
      :frame, :panel, :bitmap, :ops, :width, :height,
      :animate_fn, :animate_state, :event_handlers
    ]

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

    # ── Public API ──────────────────────────────────────────────────

    @doc """
    Renders an Easel struct to a wx window.

    Opens a native window, draws all operations, and blocks until
    the window is closed by the user.

    ## Options

      * `:title` - window title (default `"Easel"`)
      * `:on_click` - `fn x, y -> ... end` called on mouse click
      * `:on_mouse_down` - `fn x, y -> ... end` called on mouse button press
      * `:on_mouse_up` - `fn x, y -> ... end` called on mouse button release
      * `:on_mouse_move` - `fn x, y -> ... end` called on mouse movement
      * `:on_key_down` - `fn key_event -> ... end` called on key press
    """
    def render(%Easel{} = canvas, opts \\ []) do
      canvas = Easel.render(canvas)
      title = Keyword.get(opts, :title, "Easel")
      width = canvas.width || 400
      height = canvas.height || 300

      options = [
        title: String.to_charlist(title),
        width: width,
        height: height,
        ops: canvas.ops,
        event_handlers: extract_event_handlers(opts)
      ]

      {:wx_ref, _, _, pid} = :wx_object.start_link(__MODULE__, options, [])

      ref = Process.monitor(pid)

      receive do
        {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
      end
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
      * `:on_click` - `fn x, y, state -> new_state end` called on mouse click
      * `:on_mouse_down` - `fn x, y, state -> new_state end`
      * `:on_mouse_up` - `fn x, y, state -> new_state end`
      * `:on_mouse_move` - `fn x, y, state -> new_state end`
      * `:on_key_down` - `fn key_event, state -> new_state end`

    Event handlers for `animate` receive the current state and must return
    the new state. The updated state will be used by the next tick.

    ## Example

        Easel.WX.animate(600, 400, initial_state, fn state ->
          {canvas, new_state} = MyApp.tick(state)
          {canvas, new_state}
        end, title: "Animation", on_click: fn x, y, state ->
          %{state | target: {x, y}}
        end)
    """
    def animate(width, height, state, fun, opts \\ []) when is_function(fun, 1) do
      title = Keyword.get(opts, :title, "Easel")
      interval = Keyword.get(opts, :interval, 16)

      options = [
        title: String.to_charlist(title),
        width: width,
        height: height,
        ops: [],
        animate_fn: fun,
        animate_state: state,
        interval: interval,
        event_handlers: extract_event_handlers(opts)
      ]

      {:wx_ref, _, _, pid} = :wx_object.start_link(__MODULE__, options, [])

      ref = Process.monitor(pid)

      receive do
        {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
      end
    end

    # ── wx_object callbacks ───────────────────────────────────────────

    @impl true
    def init(options) do
      title = Keyword.fetch!(options, :title)
      width = Keyword.fetch!(options, :width)
      height = Keyword.fetch!(options, :height)
      ops = Keyword.fetch!(options, :ops)
      animate_fn = Keyword.get(options, :animate_fn)
      animate_state = Keyword.get(options, :animate_state)
      interval = Keyword.get(options, :interval, 16)
      event_handlers = Keyword.get(options, :event_handlers, %{})

      :wx.new()

      :wx.batch(fn ->
        frame_style =
          Bitwise.bxor(
            @wx_default_frame_style,
            @wx_resize_border
          )

        frame = :wxFrame.new(:wx.null(), @wx_id_any, title, style: frame_style)

        panel = :wxPanel.new(frame)
        bitmap = :wxBitmap.new(width, height)

        :wxFrame.connect(panel, :paint, [:callback])
        :wxFrame.connect(frame, :close_window)

        # Connect mouse events if any handlers are registered
        if map_size(event_handlers) > 0 do
          :wxPanel.connect(panel, :left_down)
          :wxPanel.connect(panel, :left_up)
          :wxPanel.connect(panel, :motion)
          :wxPanel.connect(panel, :key_down)
        end

        :wxFrame.setClientSize(frame, {width, height})

        sizer = :wxBoxSizer.new(@wx_vertical)
        :wxSizer.add(sizer, panel, flag: @wx_expand, proportion: 1)
        :wxPanel.setSizer(frame, sizer)
        :wxSizer.layout(sizer)

        frame_size = :wxFrame.getSize(frame)
        :wxFrame.setMinSize(frame, frame_size)
        :wxFrame.setMaxSize(frame, frame_size)

        :wxFrame.center(frame)
        :wxFrame.show(frame)

        if animate_fn do
          :timer.send_interval(interval, :tick)
        end

        state = %__MODULE__{
          frame: frame,
          panel: panel,
          bitmap: bitmap,
          ops: ops,
          width: width,
          height: height,
          animate_fn: animate_fn,
          animate_state: animate_state,
          event_handlers: event_handlers
        }

        {frame, state}
      end)
    end

    @impl true
    def handle_sync_event(wx(event: wxPaint()), _paint_event, state) do
      paint(state)
      :ok
    end

    @impl true
    def handle_event(wx(event: wxClose()), state) do
      {:stop, :normal, state}
    end

    # Mouse click (left_up after left_down)
    def handle_event(wx(event: wxMouse(type: :left_up, x: x, y: y)), state) do
      state = dispatch_event(state, :on_click, [x, y])
      state = dispatch_event(state, :on_mouse_up, [x, y])
      {:noreply, state}
    end

    def handle_event(wx(event: wxMouse(type: :left_down, x: x, y: y)), state) do
      state = dispatch_event(state, :on_mouse_down, [x, y])
      {:noreply, state}
    end

    def handle_event(wx(event: wxMouse(type: :motion, x: x, y: y)), state) do
      state = dispatch_event(state, :on_mouse_move, [x, y])
      {:noreply, state}
    end

    def handle_event(
          wx(event: wxKey(keyCode: key, controlDown: ctrl, shiftDown: shift, altDown: alt, metaDown: meta)),
          state
        ) do
      key_event = %{key: key, ctrl: ctrl, shift: shift, alt: alt, meta: meta}
      state = dispatch_event(state, :on_key_down, [key_event])
      {:noreply, state}
    end

    def handle_event(_event, state) do
      {:noreply, state}
    end

    @impl true
    def handle_info(:tick, state) do
      {canvas, new_animate_state} = state.animate_fn.(state.animate_state)
      canvas = Easel.render(canvas)
      new_state = %{state | ops: canvas.ops, animate_state: new_animate_state}

      :wxFrame.refresh(state.frame, eraseBackground: false)

      {:noreply, new_state}
    end

    def handle_info(_info, state) do
      {:noreply, state}
    end

    @impl true
    def handle_call(_msg, _from, state) do
      {:reply, :ok, state}
    end

    @impl true
    def handle_cast(_msg, state) do
      {:noreply, state}
    end

    @impl true
    def terminate(_reason, %__MODULE__{frame: frame}) do
      :wxFrame.destroy(frame)
      :wx.destroy()
    end

    def terminate(_reason, _state), do: :ok

    @impl true
    def code_change(_old_vsn, state, _extra) do
      {:ok, state}
    end

    # ── Event helpers ───────────────────────────────────────────────

    @event_keys ~w(on_click on_mouse_down on_mouse_up on_mouse_move on_key_down)a

    defp extract_event_handlers(opts) do
      opts
      |> Keyword.take(@event_keys)
      |> Map.new()
    end

    defp dispatch_event(state, event_name, args) do
      case Map.get(state.event_handlers, event_name) do
        nil ->
          state

        handler when state.animate_fn != nil ->
          # Animation mode: handler receives args + state, returns new state
          new_animate_state = apply(handler, args ++ [state.animate_state])
          %{state | animate_state: new_animate_state}

        handler ->
          # Static mode: handler just receives args
          apply(handler, args)
          state
      end
    end

    # ── Painting (double buffered) ──────────────────────────────────

    defp paint(%__MODULE__{panel: panel, bitmap: bitmap, ops: ops, width: width, height: height}) do
      panel_dc = :wxPaintDC.new(panel)
      bitmap_dc = :wxMemoryDC.new(bitmap)

      :wxMemoryDC.setBackground(bitmap_dc, :wxBrush.new({255, 255, 255, 255}))
      :wxMemoryDC.clear(bitmap_dc)

      gc = :wxGraphicsContext.create(bitmap_dc)

      draw_state = %{
        gc: gc,
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

      Enum.reduce(ops, draw_state, &execute_op/2)

      :wxPaintDC.blit(
        panel_dc,
        {0, 0},
        {width, height},
        bitmap_dc,
        {0, 0}
      )

      :wxPaintDC.destroy(panel_dc)
      :wxMemoryDC.destroy(bitmap_dc)
    end

    # ── Operations ──────────────────────────────────────────────────

    defp execute_op(["set", [key, value]], state) do
      set_property(key, value, state)
    end

    defp execute_op([op, _args], _state) when op in @unsupported_ops do
      raise UnsupportedOpError, op: op
    end

    # -- State --

    defp execute_op(["save", []], state) do
      transform = :wxGraphicsContext.getTransform(state.gc)
      saved_state = Map.drop(state, [:gc, :saved]) |> Map.put(:transform, transform)
      %{state | saved: [saved_state | state.saved]}
    end

    defp execute_op(["restore", []], %{saved: [prev | rest]} = state) do
      if prev[:transform] do
        :wxGraphicsContext.setTransform(state.gc, prev.transform)
      end

      Map.merge(state, Map.delete(prev, :transform)) |> Map.put(:saved, rest)
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
      :wxGraphicsContext.setPen(state.gc, :wxPen.new({0, 0, 0, 0}, width: 0, style: wx_const(:wxPENSTYLE_TRANSPARENT)))
      :wxGraphicsContext.drawRectangle(state.gc, to_float(x), to_float(y), to_float(w), to_float(h))
      state
    end

    defp execute_op(["strokeRect", [x, y, w, h]], state) do
      apply_pen(state)
      :wxGraphicsContext.setBrush(state.gc, :wxBrush.new({0, 0, 0, 0}, style: wx_const(:wxBRUSHSTYLE_TRANSPARENT)))
      :wxGraphicsContext.drawRectangle(state.gc, to_float(x), to_float(y), to_float(w), to_float(h))
      state
    end

    defp execute_op(["clearRect", [x, y, w, h]], state) do
      :wxGraphicsContext.setBrush(state.gc, :wxBrush.new({255, 255, 255, 255}))
      :wxGraphicsContext.setPen(state.gc, :wxPen.new({0, 0, 0, 0}, width: 0, style: wx_const(:wxPENSTYLE_TRANSPARENT)))
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
      # Canvas "anticlockwise" is the inverse of wx "Clockwise"
      clockwise = not anticlockwise

      :wxGraphicsPath.addArc(
        state.path,
        to_float(cx), to_float(cy), to_float(radius),
        to_float(start_angle), to_float(end_angle),
        clockwise
      )

      state
    end

    defp execute_op(["ellipse", args], state) do
      state = ensure_path(state)
      [cx, cy, rx, ry, rotation, start_angle, end_angle | _rest] = args

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

    # ── Property setters ────────────────────────────────────────────

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

    # ── Helpers ─────────────────────────────────────────────────────

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
          [_ | _] -> wx_const(:wxPENSTYLE_SHORT_DASH)
          _ -> wx_const(:wxPENSTYLE_SOLID)
        end

      pen = :wxPen.new({r, g, b, a}, width: width, style: style)
      :wxPen.setCap(pen, wx_const(state.line_cap))
      :wxPen.setJoin(pen, wx_const(state.line_join))
      :wxGraphicsContext.setPen(state.gc, pen)
    end

    defp apply_font(state) do
      font =
        :wxFont.new(
          state.font_size,
          wx_const(:wxFONTFAMILY_DEFAULT),
          wx_const(state.font_style),
          wx_const(state.font_weight),
          face: state.font_face
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
  else
    # wx not available — define stubs that raise at runtime

    @doc """
    Renders an Easel struct to a wx window.

    Requires Erlang compiled with wx support. See the README for setup instructions.
    """
    def render(%Easel{} = _canvas, _opts \\ []) do
      raise "Easel.WX requires Erlang compiled with wx support. See the README for setup instructions."
    end

    @doc """
    Runs an animation loop in a wx window.

    Requires Erlang compiled with wx support. See the README for setup instructions.
    """
    def animate(_width, _height, _state, _fun, _opts \\ []) do
      raise "Easel.WX requires Erlang compiled with wx support. See the README for setup instructions."
    end
  end
end
