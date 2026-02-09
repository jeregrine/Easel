defmodule PhxDemo.Examples.Sierpinski do
  def render do
    width = 600
    height = 520
    depth = 8
    padding = 20
    side = width - padding * 2
    h = side * :math.sqrt(3) / 2

    canvas =
      Easel.new(width, height)
      |> Easel.set_fill_style("#0d1117")
      |> Easel.fill_rect(0, 0, width, height)
      |> Easel.set_fill_style("#58a6ff")

    tri(canvas, width / 2, padding, padding, padding + h, width - padding, padding + h, depth)
    |> Easel.render()
  end

  defp tri(canvas, _ax, _ay, _bx, _by, _cx, _cy, depth) when depth <= 0, do: canvas

  defp tri(canvas, ax, ay, bx, by, cx, cy, 1) do
    canvas
    |> Easel.begin_path()
    |> Easel.move_to(ax, ay)
    |> Easel.line_to(bx, by)
    |> Easel.line_to(cx, cy)
    |> Easel.close_path()
    |> Easel.fill()
  end

  defp tri(canvas, ax, ay, bx, by, cx, cy, depth) do
    mab_x = (ax + bx) / 2
    mab_y = (ay + by) / 2
    mbc_x = (bx + cx) / 2
    mbc_y = (by + cy) / 2
    mac_x = (ax + cx) / 2
    mac_y = (ay + cy) / 2

    canvas
    |> tri(ax, ay, mab_x, mab_y, mac_x, mac_y, depth - 1)
    |> tri(mab_x, mab_y, bx, by, mbc_x, mbc_y, depth - 1)
    |> tri(mac_x, mac_y, mbc_x, mbc_y, cx, cy, depth - 1)
  end
end
