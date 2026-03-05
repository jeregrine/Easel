defmodule PhxDemo.Examples.NodeEditor do
  @width 1080
  @height 560

  @node_w 220
  @header_h 30
  @row_h 24
  @rows_top_pad 8
  @rows_bottom_pad 10
  @port_x_pad 10
  @port_radius 5
  @port_hit_radius 9

  @grid 32

  def width, do: @width
  def height, do: @height

  def init do
    %{
      nodes: [
        %{
          id: :tick,
          title: "Event Tick",
          color: "#f59e0b",
          x: 70.0,
          y: 180.0,
          inputs: [],
          outputs: ["Exec", "Delta"]
        },
        %{
          id: :time,
          title: "Time",
          color: "#3b82f6",
          x: 300.0,
          y: 180.0,
          inputs: ["Delta"],
          outputs: ["Seconds"]
        },
        %{
          id: :sin,
          title: "Sine",
          color: "#22c55e",
          x: 560.0,
          y: 120.0,
          inputs: ["Value"],
          outputs: ["Result"]
        },
        %{
          id: :multiply,
          title: "Multiply",
          color: "#a855f7",
          x: 560.0,
          y: 280.0,
          inputs: ["A", "B"],
          outputs: ["Result"]
        },
        %{
          id: :set_color,
          title: "Set Material Color",
          color: "#ef4444",
          x: 820.0,
          y: 210.0,
          inputs: ["Exec", "Hue"],
          outputs: []
        }
      ],
      links: [
        %{from: {:tick, 0}, to: {:set_color, 0}, color: "rgba(248, 250, 252, 0.9)"},
        %{from: {:tick, 1}, to: {:time, 0}, color: "rgba(56, 189, 248, 0.95)"},
        %{from: {:time, 0}, to: {:sin, 0}, color: "rgba(56, 189, 248, 0.95)"},
        %{from: {:sin, 0}, to: {:multiply, 0}, color: "rgba(196, 181, 253, 0.95)"},
        %{from: {:time, 0}, to: {:multiply, 1}, color: "rgba(196, 181, 253, 0.95)"},
        %{from: {:multiply, 0}, to: {:set_color, 1}, color: "rgba(244, 114, 182, 0.95)"}
      ],
      selected: :set_color,
      dragging: nil,
      pending_link: nil
    }
  end

  def selected_title(%{selected: selected, nodes: nodes}) do
    case Enum.find(nodes, &(&1.id == selected)) do
      nil -> nil
      node -> node.title
    end
  end

  def pending_output_label(%{pending_link: nil}), do: nil

  def pending_output_label(%{pending_link: %{from: {node_id, out_idx}}, nodes: nodes}) do
    with %{title: title, outputs: outputs} <- Enum.find(nodes, &(&1.id == node_id)),
         label when is_binary(label) <- Enum.at(outputs, out_idx) do
      "#{title}.#{label}"
    else
      _ -> nil
    end
  end

  def mouse_down(state, x, y) do
    case port_hit(state.nodes, x, y) do
      {:output, node, out_idx, label} ->
        nodes = bring_to_front(state.nodes, node.id)

        %{
          state
          | nodes: nodes,
            selected: node.id,
            dragging: nil,
            pending_link: %{from: {node.id, out_idx}, color: wire_color(label)}
        }

      {:input, node, in_idx, _label} ->
        nodes = bring_to_front(state.nodes, node.id)

        case state.pending_link do
          %{from: {from_id, out_idx}, color: color} when from_id != node.id ->
            link = %{from: {from_id, out_idx}, to: {node.id, in_idx}, color: color}

            %{
              state
              | nodes: nodes,
                selected: node.id,
                dragging: nil,
                pending_link: nil,
                links: upsert_link(state.links, link)
            }

          _ ->
            %{state | nodes: nodes, selected: node.id, dragging: nil, pending_link: nil}
        end

      nil ->
        start_drag(state, x, y)
    end
  end

  def start_drag(state, x, y) do
    case node_at(state.nodes, x, y) do
      nil ->
        %{state | selected: nil, dragging: nil, pending_link: nil}

      node ->
        nodes = bring_to_front(state.nodes, node.id)

        %{
          state
          | nodes: nodes,
            selected: node.id,
            dragging: %{id: node.id, dx: x - node.x, dy: y - node.y}
        }
    end
  end

  def drag(%{dragging: nil} = state, _x, _y), do: state

  def drag(%{dragging: %{id: id, dx: dx, dy: dy}} = state, x, y) do
    update_node(state, id, fn node ->
      h = node_height(node)
      nx = clamp(x - dx, 12, @width - @node_w - 12)
      ny = clamp(y - dy, 12, @height - h - 12)
      %{node | x: nx, y: ny}
    end)
  end

  def stop_drag(state), do: %{state | dragging: nil}

  def render_background do
    canvas =
      Easel.new(@width, @height)
      |> Easel.set_fill_style("#040712")
      |> Easel.fill_rect(0, 0, @width, @height)

    canvas =
      Enum.reduce(0..div(@width, @grid), canvas, fn i, acc ->
        x = i * @grid + 0.5

        color =
          if rem(i, 4) == 0,
            do: "rgba(148, 163, 184, 0.16)",
            else: "rgba(71, 85, 105, 0.14)"

        acc
        |> Easel.begin_path()
        |> Easel.move_to(x, 0)
        |> Easel.line_to(x, @height)
        |> Easel.set_stroke_style(color)
        |> Easel.set_line_width(1)
        |> Easel.stroke()
      end)

    Enum.reduce(0..div(@height, @grid), canvas, fn i, acc ->
      y = i * @grid + 0.5

      color =
        if rem(i, 4) == 0,
          do: "rgba(148, 163, 184, 0.16)",
          else: "rgba(71, 85, 105, 0.14)"

      acc
      |> Easel.begin_path()
      |> Easel.move_to(0, y)
      |> Easel.line_to(@width, y)
      |> Easel.set_stroke_style(color)
      |> Easel.set_line_width(1)
      |> Easel.stroke()
    end)
    |> Easel.set_fill_style("rgba(2, 6, 23, 0.9)")
    |> Easel.fill_rect(0, 0, @width, 38)
    |> Easel.set_fill_style("rgba(226, 232, 240, 0.9)")
    |> Easel.set_font("12px sans-serif")
    |> Easel.set_text_align("left")
    |> Easel.set_text_baseline("middle")
    |> Easel.fill_text("Simple Blueprint-style graph", 14, 20)
    |> Easel.render()
  end

  def template_canvas do
    Easel.new(@width, @height)
    |> port_templates()
  end

  def render(state), do: render(state, nil)

  def render(state, template_opts) do
    nodes_by_id = Map.new(state.nodes, &{&1.id, &1})
    pending_from = state.pending_link && state.pending_link.from

    state.links
    |> Enum.reduce(
      Easel.new(@width, @height)
      |> maybe_with_template_opts(template_opts)
      |> maybe_define_port_templates(template_opts),
      fn link, canvas ->
        draw_link(canvas, nodes_by_id, link)
      end
    )
    |> then(fn canvas ->
      Enum.reduce(state.nodes, canvas, fn node, acc ->
        draw_node(acc, node, state.selected == node.id, pending_from)
      end)
    end)
    |> Easel.render()
  end

  defp port_templates(canvas) do
    canvas
    |> Easel.template(
      :port,
      fn c ->
        c
        |> Easel.begin_path()
        |> Easel.arc(0, 0, @port_radius, 0, 2 * :math.pi())
        |> Easel.fill()
        |> Easel.set_stroke_style("rgba(15, 23, 42, 0.95)")
        |> Easel.set_line_width(1)
        |> Easel.stroke()
      end,
      x: 0,
      y: 0
    )
    |> Easel.template(
      :port_active,
      fn c ->
        c
        |> Easel.begin_path()
        |> Easel.arc(0, 0, @port_radius + 3, 0, 2 * :math.pi())
        |> Easel.set_stroke_style("rgba(248, 250, 252, 0.95)")
        |> Easel.set_line_width(1.6)
        |> Easel.stroke()
      end,
      x: 0,
      y: 0
    )
  end

  defp draw_link(canvas, nodes_by_id, %{
         from: {from_id, out_idx},
         to: {to_id, in_idx},
         color: color
       }) do
    with from_node when not is_nil(from_node) <- Map.get(nodes_by_id, from_id),
         to_node when not is_nil(to_node) <- Map.get(nodes_by_id, to_id) do
      {x1, y1} = output_port(from_node, out_idx)
      {x2, y2} = input_port(to_node, in_idx)
      bend = max(48.0, abs(x2 - x1) * 0.55)

      canvas
      |> Easel.begin_path()
      |> Easel.move_to(x1, y1)
      |> Easel.bezier_curve_to(x1 + bend, y1, x2 - bend, y2, x2, y2)
      |> Easel.set_stroke_style("rgba(15, 23, 42, 0.85)")
      |> Easel.set_line_width(5)
      |> Easel.stroke()
      |> Easel.begin_path()
      |> Easel.move_to(x1, y1)
      |> Easel.bezier_curve_to(x1 + bend, y1, x2 - bend, y2, x2, y2)
      |> Easel.set_stroke_style(color)
      |> Easel.set_line_width(2.4)
      |> Easel.stroke()
    else
      _ -> canvas
    end
  end

  defp draw_node(canvas, node, selected?, pending_from) do
    h = node_height(node)

    canvas =
      canvas
      |> Easel.set_fill_style("rgba(15, 23, 42, 0.95)")
      |> Easel.fill_rect(node.x, node.y, @node_w, h)
      |> Easel.set_fill_style(node.color)
      |> Easel.fill_rect(node.x, node.y, @node_w, @header_h)
      |> Easel.set_stroke_style(if(selected?, do: "#f8fafc", else: "rgba(100, 116, 139, 0.95)"))
      |> Easel.set_line_width(if(selected?, do: 2.4, else: 1.2))
      |> Easel.stroke_rect(node.x + 0.5, node.y + 0.5, @node_w - 1, h - 1)
      |> Easel.set_fill_style("#f8fafc")
      |> Easel.set_font("bold 13px sans-serif")
      |> Easel.set_text_align("left")
      |> Easel.set_text_baseline("middle")
      |> Easel.fill_text(node.title, node.x + 10, node.y + @header_h / 2)

    input_rows =
      node.inputs
      |> Enum.with_index()
      |> Enum.map(fn {label, idx} ->
        {px, py} = input_port(node, idx)
        %{label: label, px: px, py: py}
      end)

    output_rows =
      node.outputs
      |> Enum.with_index()
      |> Enum.map(fn {label, idx} ->
        {px, py} = output_port(node, idx)
        %{label: label, idx: idx, px: px, py: py}
      end)

    port_instances =
      Enum.map(input_rows, fn row -> %{x: row.px, y: row.py, fill: pin_color(row.label)} end) ++
        Enum.map(output_rows, fn row -> %{x: row.px, y: row.py, fill: pin_color(row.label)} end)

    active_instances =
      for row <- output_rows, pending_from == {node.id, row.idx}, do: %{x: row.px, y: row.py}

    canvas =
      canvas
      |> instances_if_any(:port, port_instances)
      |> instances_if_any(:port_active, active_instances)

    canvas =
      Enum.reduce(input_rows, canvas, fn row, acc ->
        acc
        |> Easel.set_fill_style("#cbd5e1")
        |> Easel.set_font("12px sans-serif")
        |> Easel.set_text_align("left")
        |> Easel.set_text_baseline("middle")
        |> Easel.fill_text(row.label, row.px + 10, row.py)
      end)

    Enum.reduce(output_rows, canvas, fn row, acc ->
      acc
      |> Easel.set_fill_style("#cbd5e1")
      |> Easel.set_font("12px sans-serif")
      |> Easel.set_text_align("right")
      |> Easel.set_text_baseline("middle")
      |> Easel.fill_text(row.label, row.px - 10, row.py)
    end)
  end

  defp instances_if_any(canvas, _name, []), do: canvas
  defp instances_if_any(canvas, name, instances), do: Easel.instances(canvas, name, instances)

  defp maybe_with_template_opts(canvas, nil), do: canvas

  defp maybe_with_template_opts(canvas, opts) when is_map(opts),
    do: Easel.with_template_opts(canvas, opts)

  defp maybe_with_template_opts(canvas, _), do: canvas

  defp maybe_define_port_templates(canvas, nil), do: port_templates(canvas)
  defp maybe_define_port_templates(canvas, _), do: canvas

  defp input_port(node, idx), do: {node.x + @port_x_pad, port_y(node, idx)}
  defp output_port(node, idx), do: {node.x + @node_w - @port_x_pad, port_y(node, idx)}

  defp port_y(node, idx) do
    node.y + @header_h + @rows_top_pad + idx * @row_h + @row_h / 2
  end

  defp node_height(node) do
    rows = max(max(length(node.inputs), length(node.outputs)), 1)
    @header_h + @rows_top_pad + rows * @row_h + @rows_bottom_pad
  end

  defp node_at(nodes, x, y) do
    nodes
    |> Enum.reverse()
    |> Enum.find(fn node ->
      h = node_height(node)
      x >= node.x and x <= node.x + @node_w and y >= node.y and y <= node.y + h
    end)
  end

  defp bring_to_front(nodes, id) do
    case Enum.split_with(nodes, &(&1.id != id)) do
      {other, [node]} -> other ++ [node]
      _ -> nodes
    end
  end

  defp port_hit(nodes, x, y) do
    nodes
    |> Enum.reverse()
    |> Enum.find_value(fn node ->
      input_hit(node, x, y) || output_hit(node, x, y)
    end)
  end

  defp input_hit(node, x, y) do
    node.inputs
    |> Enum.with_index()
    |> Enum.find_value(fn {label, idx} ->
      {px, py} = input_port(node, idx)
      if near_port?(x, y, px, py), do: {:input, node, idx, label}
    end)
  end

  defp output_hit(node, x, y) do
    node.outputs
    |> Enum.with_index()
    |> Enum.find_value(fn {label, idx} ->
      {px, py} = output_port(node, idx)
      if near_port?(x, y, px, py), do: {:output, node, idx, label}
    end)
  end

  defp near_port?(x, y, px, py) do
    dx = x - px
    dy = y - py
    dx * dx + dy * dy <= @port_hit_radius * @port_hit_radius
  end

  defp upsert_link(links, %{to: to} = link) do
    links
    |> Enum.reject(&(&1.to == to))
    |> Kernel.++([link])
  end

  defp update_node(%{nodes: nodes} = state, id, fun) do
    updated =
      Enum.map(nodes, fn node ->
        if node.id == id, do: fun.(node), else: node
      end)

    %{state | nodes: updated}
  end

  defp clamp(v, lo, hi), do: v |> max(lo) |> min(hi)

  defp wire_color("Exec"), do: "rgba(248, 250, 252, 0.95)"
  defp wire_color("Hue"), do: "rgba(244, 114, 182, 0.95)"
  defp wire_color("Delta"), do: "rgba(56, 189, 248, 0.95)"
  defp wire_color("Seconds"), do: "rgba(56, 189, 248, 0.95)"
  defp wire_color(_), do: "rgba(196, 181, 253, 0.95)"

  defp pin_color("Exec"), do: "#f8fafc"
  defp pin_color("Hue"), do: "#f472b6"
  defp pin_color("Delta"), do: "#38bdf8"
  defp pin_color("Seconds"), do: "#38bdf8"
  defp pin_color(_), do: "#c084fc"
end
