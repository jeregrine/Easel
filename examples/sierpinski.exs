# Sierpinski triangle fractal
# Run: mix run examples/sierpinski.exs


width = 600
height = 520

defmodule Sierpinski do
  def triangle(canvas, _ax, _ay, _bx, _by, _cx, _cy, depth) when depth <= 0 do
    canvas
  end

  def triangle(canvas, ax, ay, bx, by, cx, cy, depth) do
    if depth == 1 do
      # Draw filled triangle
      canvas
      |> Easel.begin_path()
      |> Easel.move_to(ax, ay)
      |> Easel.line_to(bx, by)
      |> Easel.line_to(cx, cy)
      |> Easel.close_path()
      |> Easel.fill()
    else
      # Midpoints
      mab_x = (ax + bx) / 2
      mab_y = (ay + by) / 2
      mbc_x = (bx + cx) / 2
      mbc_y = (by + cy) / 2
      mac_x = (ax + cx) / 2
      mac_y = (ay + cy) / 2

      canvas
      |> triangle(ax, ay, mab_x, mab_y, mac_x, mac_y, depth - 1)
      |> triangle(mab_x, mab_y, bx, by, mbc_x, mbc_y, depth - 1)
      |> triangle(mac_x, mac_y, mbc_x, mbc_y, cx, cy, depth - 1)
    end
  end
end

depth = 8
padding = 20
side = width - padding * 2
h = side * :math.sqrt(3) / 2

ax = width / 2
ay = padding
bx = padding
by = padding + h
cx = width - padding
cy = padding + h

canvas =
  Easel.new(width, height)
  |> Easel.set_fill_style("#0d1117")
  |> Easel.fill_rect(0, 0, width, height)
  |> Easel.set_fill_style("#58a6ff")
  |> Sierpinski.triangle(ax, ay, bx, by, cx, cy, depth)
  |> Easel.render()

if Code.ensure_loaded?(Easel.WX) and Easel.WX.available?() do
  Easel.WX.render(canvas, title: "Sierpinski Triangle")
else
  IO.puts("Sierpinski triangle (depth #{depth}): #{length(canvas.ops)} operations")
end
