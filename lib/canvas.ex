defmodule Canvas do
  defstruct width: nil, height: nil, ops: []

  def new() do
    %Canvas{}
  end

  def new(width, height) do
    %Canvas{width: width, height: height}
  end

  def push_op(%Canvas{} = ctx, op) do
    Map.update!(ctx, :ops, fn ops -> [op | ops] end)
  end

  def render(%Canvas{} = ctx) do
    Map.update!(ctx, :ops, fn ops -> Enum.reverse(ops) end)
  end
end
