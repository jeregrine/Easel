defmodule Easel do
  defstruct width: nil, height: nil, ops: []

  def new() do
    %Easel{}
  end

  def new(width, height) do
    %Easel{width: width, height: height}
  end

  def push_op(%Easel{} = ctx, op) do
    Map.update!(ctx, :ops, fn ops -> [op | ops] end)
  end

  def render(%Easel{} = ctx) do
    Map.update!(ctx, :ops, fn ops -> Enum.reverse(ops) end)
  end
end
