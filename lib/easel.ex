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

  ## Backends

    * `Easel.LiveView` — Phoenix LiveView component with colocated JS hook
    * `Easel.WX` — Native desktop window via Erlang's `:wx` (wxWidgets)
    * Custom — consume `canvas.ops` directly in your own renderer
  """

  defstruct width: nil, height: nil, ops: [], rendered: false

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
  Finalizes the canvas by reversing the ops list into execution order.

  Must be called before passing the canvas to a backend for rendering.
  Safe to call multiple times — subsequent calls are no-ops.
  """
  def render(%Easel{rendered: true} = ctx), do: ctx

  def render(%Easel{} = ctx) do
    %{ctx | ops: Enum.reverse(ctx.ops), rendered: true}
  end
end
