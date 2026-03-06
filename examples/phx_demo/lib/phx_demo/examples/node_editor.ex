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
  @port_hover_radius 18

  @grid 32
  @min_zoom 0.5
  @max_zoom 2.5

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
      pending_link: nil,
      pointer: nil,
      viewport: %{scale: 1.0, offset_x: 0.0, offset_y: 0.0}
    }
  end

  def selected_title(%{selected: selected, nodes: nodes}) do
    case Enum.find(nodes, &(&1.id == selected)) do
      nil -> nil
      node -> node.title
    end
  end

  def pending_output_label(%{pending_link: nil}), do: nil

  def pending_output_label(%{
        pending_link: %{dragging_endpoint: :to, from: {node_id, out_idx}},
        nodes: nodes
      }) do
    with %{title: title, outputs: outputs} <- Enum.find(nodes, &(&1.id == node_id)),
         label when is_binary(label) <- Enum.at(outputs, out_idx) do
      "#{title}.#{label}"
    else
      _ -> nil
    end
  end

  def pending_output_label(_), do: nil

  def zoom_percent(state) do
    state
    |> viewport()
    |> Map.fetch!(:scale)
    |> Kernel.*(100)
    |> round()
  end

  def zoom_wheel(state, screen_x, screen_y, delta_y) do
    factor = :math.pow(1.0015, -delta_y)
    zoom_at(state, screen_x, screen_y, factor)
  end

  def zoom_pinch(state, screen_x, screen_y, scale_delta) do
    zoom_at(state, screen_x, screen_y, scale_delta)
  end

  def mouse_down(state, screen_x, screen_y) do
    {x, y} = screen_to_world(state, screen_x, screen_y)

    case port_hit(state.nodes, x, y, viewport_scale(state)) do
      {:output, node, out_idx, label} ->
        nodes = bring_to_front(state.nodes, node.id)

        case state.pending_link do
          %{dragging_endpoint: :from, to: {to_id, to_idx}, color: color} when to_id != node.id ->
            link = %{from: {node.id, out_idx}, to: {to_id, to_idx}, color: color}

            %{
              state
              | nodes: nodes,
                selected: node.id,
                dragging: nil,
                pending_link: nil,
                pointer: %{x: x, y: y},
                links: upsert_link(state.links, link)
            }

          _ ->
            {detached, links} = pop_link_from_output(state.links, node.id, out_idx)

            pending_link =
              if detached do
                %{
                  dragging_endpoint: :from,
                  from: nil,
                  to: detached.to,
                  color: detached.color
                }
              else
                %{
                  dragging_endpoint: :to,
                  from: {node.id, out_idx},
                  to: nil,
                  color: wire_color(label)
                }
              end

            %{
              state
              | nodes: nodes,
                selected: node.id,
                dragging: nil,
                pending_link: pending_link,
                pointer: %{x: x, y: y},
                links: links
            }
        end

      {:input, node, in_idx, _label} ->
        nodes = bring_to_front(state.nodes, node.id)

        case state.pending_link do
          %{dragging_endpoint: :to, from: {from_id, out_idx}, color: color}
          when from_id != node.id ->
            link = %{from: {from_id, out_idx}, to: {node.id, in_idx}, color: color}

            %{
              state
              | nodes: nodes,
                selected: node.id,
                dragging: nil,
                pending_link: nil,
                pointer: %{x: x, y: y},
                links: upsert_link(state.links, link)
            }

          _ ->
            {detached, links} = pop_link_from_input(state.links, node.id, in_idx)

            pending_link =
              if detached do
                %{
                  dragging_endpoint: :to,
                  from: detached.from,
                  to: nil,
                  color: detached.color
                }
              else
                nil
              end

            %{
              state
              | nodes: nodes,
                selected: node.id,
                dragging: nil,
                pending_link: pending_link,
                pointer: %{x: x, y: y},
                links: links
            }
        end

      nil ->
        if state.pending_link do
          %{state | selected: nil, dragging: nil, pending_link: nil, pointer: %{x: x, y: y}}
        else
          start_drag(state, x, y)
        end
    end
  end

  def start_drag(state, x, y) do
    case node_at(state.nodes, x, y) do
      nil ->
        %{state | selected: nil, dragging: nil, pending_link: nil, pointer: %{x: x, y: y}}

      node ->
        nodes = bring_to_front(state.nodes, node.id)

        %{
          state
          | nodes: nodes,
            selected: node.id,
            dragging: %{id: node.id, dx: x - node.x, dy: y - node.y},
            pointer: %{x: x, y: y}
        }
    end
  end

  def drag(%{dragging: nil} = state, screen_x, screen_y) do
    {x, y} = screen_to_world(state, screen_x, screen_y)
    %{state | pointer: %{x: x, y: y}}
  end

  def drag(%{dragging: %{id: id, dx: dx, dy: dy}} = state, screen_x, screen_y) do
    {x, y} = screen_to_world(state, screen_x, screen_y)
    state = %{state | pointer: %{x: x, y: y}}

    update_node(state, id, fn node ->
      h = node_height(node)
      nx = clamp(x - dx, 12, @width - @node_w - 12)
      ny = clamp(y - dy, 12, @height - h - 12)
      %{node | x: nx, y: ny}
    end)
  end

  def stop_drag(state), do: %{state | dragging: nil}

  def render_background(state \\ %{}) do
    %{scale: scale, offset_x: offset_x, offset_y: offset_y} = viewport(state)

    {wx0, wy0} = {(0.0 - offset_x) / scale, (0.0 - offset_y) / scale}
    {wx1, wy1} = {(@width - offset_x) / scale, (@height - offset_y) / scale}

    min_wx = min(wx0, wx1)
    max_wx = max(wx0, wx1)
    min_wy = min(wy0, wy1)
    max_wy = max(wy0, wy1)

    x_start = floor_to_grid_index(min_wx) - 1
    x_end = floor_to_grid_index(max_wx) + 1
    y_start = floor_to_grid_index(min_wy) - 1
    y_end = floor_to_grid_index(max_wy) + 1

    Easel.new(@width, @height)
    |> Easel.set_fill_style("#040712")
    |> Easel.fill_rect(0, 0, @width, @height)
    |> Easel.save()
    |> Easel.translate(offset_x, offset_y)
    |> Easel.scale(scale, scale)
    |> then(fn canvas ->
      Enum.reduce(x_start..x_end, canvas, fn i, acc ->
        x = i * @grid + 0.5

        color =
          if Integer.mod(i, 4) == 0,
            do: "rgba(148, 163, 184, 0.16)",
            else: "rgba(71, 85, 105, 0.14)"

        acc
        |> Easel.begin_path()
        |> Easel.move_to(x, min_wy - @grid)
        |> Easel.line_to(x, max_wy + @grid)
        |> Easel.set_stroke_style(color)
        |> Easel.set_line_width(1 / scale)
        |> Easel.stroke()
      end)
    end)
    |> then(fn canvas ->
      Enum.reduce(y_start..y_end, canvas, fn i, acc ->
        y = i * @grid + 0.5

        color =
          if Integer.mod(i, 4) == 0,
            do: "rgba(148, 163, 184, 0.16)",
            else: "rgba(71, 85, 105, 0.14)"

        acc
        |> Easel.begin_path()
        |> Easel.move_to(min_wx - @grid, y)
        |> Easel.line_to(max_wx + @grid, y)
        |> Easel.set_stroke_style(color)
        |> Easel.set_line_width(1 / scale)
        |> Easel.stroke()
      end)
    end)
    |> Easel.restore()
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

    hovered_port =
      hover_attach_target(state.nodes, state.pending_link, state.pointer, viewport_scale(state))

    viewport = viewport(state)

    base_canvas =
      Easel.new(@width, @height)
      |> maybe_with_template_opts(template_opts)
      |> maybe_define_port_templates(template_opts)
      |> Easel.save()
      |> Easel.translate(viewport.offset_x, viewport.offset_y)
      |> Easel.scale(viewport.scale, viewport.scale)

    Enum.reduce(state.links, base_canvas, fn link, canvas ->
      draw_link(canvas, nodes_by_id, link)
    end)
    |> then(fn canvas ->
      Enum.reduce(state.nodes, canvas, fn node, acc ->
        draw_node(acc, node, state.selected == node.id, pending_from, hovered_port)
      end)
    end)
    |> maybe_draw_pending_link(nodes_by_id, state.pending_link, state.pointer)
    |> Easel.restore()
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
      draw_wire(canvas, x1, y1, x2, y2, color)
    else
      _ -> canvas
    end
  end

  defp maybe_draw_pending_link(canvas, _nodes_by_id, nil, _pointer), do: canvas
  defp maybe_draw_pending_link(canvas, _nodes_by_id, _pending_link, nil), do: canvas

  defp maybe_draw_pending_link(
         canvas,
         nodes_by_id,
         %{dragging_endpoint: :to, from: {from_id, out_idx}, color: color},
         %{x: x, y: y}
       ) do
    with from_node when not is_nil(from_node) <- Map.get(nodes_by_id, from_id) do
      {x1, y1} = output_port(from_node, out_idx)
      draw_wire(canvas, x1, y1, x, y, color)
    else
      _ -> canvas
    end
  end

  defp maybe_draw_pending_link(
         canvas,
         nodes_by_id,
         %{dragging_endpoint: :from, to: {to_id, in_idx}, color: color},
         %{x: x, y: y}
       ) do
    with to_node when not is_nil(to_node) <- Map.get(nodes_by_id, to_id) do
      {x2, y2} = input_port(to_node, in_idx)
      draw_wire(canvas, x, y, x2, y2, color)
    else
      _ -> canvas
    end
  end

  defp draw_wire(canvas, x1, y1, x2, y2, color) do
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
  end

  defp draw_node(canvas, node, selected?, pending_from, hovered_port) do
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
        %{label: label, idx: idx, px: px, py: py}
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
      for(row <- output_rows, pending_from == {node.id, row.idx}, do: %{x: row.px, y: row.py}) ++
        for(
          row <- output_rows,
          hovered_port == {:output, node.id, row.idx},
          do: %{x: row.px, y: row.py}
        ) ++
        for row <- input_rows,
            hovered_port == {:input, node.id, row.idx},
            do: %{x: row.px, y: row.py}

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

  defp port_hit(nodes, x, y, scale) do
    nodes
    |> Enum.reverse()
    |> Enum.find_value(fn node ->
      input_hit(node, x, y, scale) || output_hit(node, x, y, scale)
    end)
  end

  defp input_hit(node, x, y, scale) do
    node.inputs
    |> Enum.with_index()
    |> Enum.find_value(fn {label, idx} ->
      {px, py} = input_port(node, idx)
      if near_port?(x, y, px, py, scale), do: {:input, node, idx, label}
    end)
  end

  defp output_hit(node, x, y, scale) do
    node.outputs
    |> Enum.with_index()
    |> Enum.find_value(fn {label, idx} ->
      {px, py} = output_port(node, idx)
      if near_port?(x, y, px, py, scale), do: {:output, node, idx, label}
    end)
  end

  defp near_port?(x, y, px, py, scale) do
    radius = @port_hit_radius / max(scale, 0.001)
    dx = x - px
    dy = y - py
    dx * dx + dy * dy <= radius * radius
  end

  defp hover_attach_target(_nodes, nil, _pointer, _scale), do: nil
  defp hover_attach_target(_nodes, _pending_link, nil, _scale), do: nil

  defp hover_attach_target(
         nodes,
         %{dragging_endpoint: :to, from: {from_id, _out_idx}},
         %{
           x: x,
           y: y
         },
         scale
       ) do
    candidates =
      for node <- nodes,
          node.id != from_id,
          {_label, idx} <- Enum.with_index(node.inputs) do
        {px, py} = input_port(node, idx)
        {:input, node.id, idx, px, py}
      end

    nearest_port(candidates, x, y, scale)
  end

  defp hover_attach_target(
         nodes,
         %{dragging_endpoint: :from, to: {to_id, _in_idx}},
         %{x: x, y: y},
         scale
       ) do
    candidates =
      for node <- nodes,
          node.id != to_id,
          {_label, idx} <- Enum.with_index(node.outputs) do
        {px, py} = output_port(node, idx)
        {:output, node.id, idx, px, py}
      end

    nearest_port(candidates, x, y, scale)
  end

  defp hover_attach_target(_nodes, _pending_link, _pointer, _scale), do: nil

  defp nearest_port(candidates, x, y, scale) do
    radius = @port_hover_radius / max(scale, 0.001)
    hover_radius_sq = radius * radius

    candidates
    |> Enum.reduce(nil, fn {kind, node_id, idx, px, py}, best ->
      dx = x - px
      dy = y - py
      dist_sq = dx * dx + dy * dy

      cond do
        dist_sq > hover_radius_sq ->
          best

        best == nil ->
          {kind, node_id, idx, dist_sq}

        dist_sq < elem(best, 3) ->
          {kind, node_id, idx, dist_sq}

        true ->
          best
      end
    end)
    |> case do
      nil -> nil
      {kind, node_id, idx, _} -> {kind, node_id, idx}
    end
  end

  defp upsert_link(links, %{to: to} = link) do
    links
    |> Enum.reject(&(&1.to == to))
    |> Kernel.++([link])
  end

  defp pop_link_from_input(links, node_id, in_idx) do
    split_link(links, fn link -> link.to == {node_id, in_idx} end)
  end

  defp pop_link_from_output(links, node_id, out_idx) do
    split_link(links, fn link -> link.from == {node_id, out_idx} end)
  end

  defp split_link(links, pred) do
    case Enum.split_with(links, fn link -> not pred.(link) end) do
      {before, [link | rest]} -> {link, before ++ rest}
      _ -> {nil, links}
    end
  end

  defp zoom_at(state, _screen_x, _screen_y, scale_delta)
       when not is_number(scale_delta) or scale_delta <= 0,
       do: state

  defp zoom_at(state, screen_x, screen_y, scale_delta) do
    viewport = viewport(state)
    scale = viewport.scale

    new_scale = clamp(scale * scale_delta, @min_zoom, @max_zoom)

    if abs(new_scale - scale) < 0.0001 do
      state
    else
      {world_x, world_y} = screen_to_world(state, screen_x, screen_y)

      new_viewport = %{
        scale: new_scale,
        offset_x: screen_x - world_x * new_scale,
        offset_y: screen_y - world_y * new_scale
      }

      %{state | viewport: new_viewport, pointer: %{x: world_x, y: world_y}}
    end
  end

  defp viewport(%{viewport: %{scale: scale, offset_x: ox, offset_y: oy}}) do
    %{scale: scale, offset_x: ox, offset_y: oy}
  end

  defp viewport(_), do: %{scale: 1.0, offset_x: 0.0, offset_y: 0.0}

  defp viewport_scale(state), do: state |> viewport() |> Map.fetch!(:scale)

  defp screen_to_world(state, screen_x, screen_y) do
    %{scale: scale, offset_x: offset_x, offset_y: offset_y} = viewport(state)
    {(screen_x - offset_x) / scale, (screen_y - offset_y) / scale}
  end

  defp update_node(%{nodes: nodes} = state, id, fun) do
    updated =
      Enum.map(nodes, fn node ->
        if node.id == id, do: fun.(node), else: node
      end)

    %{state | nodes: updated}
  end

  defp clamp(v, lo, hi), do: v |> max(lo) |> min(hi)

  defp floor_to_grid_index(v) do
    v
    |> Kernel./(@grid)
    |> Float.floor()
    |> trunc()
  end

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
