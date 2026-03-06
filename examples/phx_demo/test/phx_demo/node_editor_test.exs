defmodule PhxDemo.NodeEditorTest do
  use ExUnit.Case, async: true

  alias PhxDemo.Examples.NodeEditor

  test "drag updates pointer while pending link is active" do
    state =
      NodeEditor.init()
      |> Map.put(:links, [])
      |> NodeEditor.mouse_down(280.0, 230.0)

    assert %{dragging_endpoint: :to, from: {:tick, 0}, to: nil} = state.pending_link
    assert state.pointer == %{x: 280.0, y: 230.0}
    assert state.dragging == nil

    moved = NodeEditor.drag(state, 420.0, 260.0)

    assert moved.pending_link == state.pending_link
    assert moved.dragging == nil
    assert moved.pointer == %{x: 420.0, y: 260.0}
  end

  test "render draws pending wire toward current pointer" do
    state =
      NodeEditor.init()
      |> Map.put(:links, [])
      |> NodeEditor.mouse_down(280.0, 230.0)
      |> NodeEditor.drag(420.0, 260.0)

    canvas = NodeEditor.render(state)

    beziers =
      for ["bezierCurveTo", [_, _, _, _, x, y]] <- canvas.ops,
          x == 420.0 and y == 260.0,
          do: {x, y}

    # pending link draws shadow stroke + colored stroke
    assert length(beziers) == 2
  end

  test "clicking connected input detaches existing link and starts dragging link end" do
    state = NodeEditor.init()

    # set_color input 0 port coordinates
    state = NodeEditor.mouse_down(state, 830.0, 260.0)

    assert %{dragging_endpoint: :to, from: {:tick, 0}, to: nil} = state.pending_link
    assert state.pointer == %{x: 830.0, y: 260.0}
    refute Enum.any?(state.links, &(&1.to == {:set_color, 0}))
  end

  test "clicking connected output detaches existing link and starts dragging link start" do
    state = NodeEditor.init()

    # tick output 0 port coordinates
    state = NodeEditor.mouse_down(state, 280.0, 230.0)

    assert %{dragging_endpoint: :from, from: nil, to: {:set_color, 0}} = state.pending_link
    assert state.pointer == %{x: 280.0, y: 230.0}
    refute Enum.any?(state.links, &(&1.from == {:tick, 0} and &1.to == {:set_color, 0}))
  end

  test "clicking background while dragging a link deletes the detached link" do
    state =
      NodeEditor.init()
      |> NodeEditor.mouse_down(280.0, 230.0)

    state = NodeEditor.mouse_down(state, 20.0, 20.0)

    assert state.pending_link == nil
    refute Enum.any?(state.links, &(&1.to == {:set_color, 0}))
  end

  test "dragging link start can reconnect by clicking another output" do
    state =
      NodeEditor.init()
      |> NodeEditor.mouse_down(280.0, 230.0)
      |> NodeEditor.mouse_down(510.0, 230.0)

    assert state.pending_link == nil
    assert Enum.any?(state.links, &(&1.from == {:time, 0} and &1.to == {:set_color, 0}))
  end

  test "dragging link end highlights nearby valid input attachment" do
    state =
      NodeEditor.init()
      |> NodeEditor.mouse_down(830.0, 260.0)
      |> NodeEditor.drag(312.0, 232.0)

    canvas = NodeEditor.render(state)

    assert {310, 230} in active_points(canvas)
  end

  test "dragging link start highlights nearby valid output attachment" do
    state =
      NodeEditor.init()
      |> NodeEditor.mouse_down(280.0, 230.0)
      |> NodeEditor.drag(512.0, 232.0)

    canvas = NodeEditor.render(state)

    assert {510, 230} in active_points(canvas)
  end

  test "zooming keeps cursor anchor stable for picking" do
    state =
      NodeEditor.init()
      |> NodeEditor.zoom_wheel(280.0, 230.0, -240.0)
      |> NodeEditor.mouse_down(280.0, 230.0)

    assert NodeEditor.zoom_percent(state) > 100
    assert %{dragging_endpoint: :from, from: nil, to: {:set_color, 0}} = state.pending_link
  end

  test "dragging link end can reconnect by clicking another input" do
    state =
      NodeEditor.init()
      |> NodeEditor.mouse_down(830.0, 260.0)
      |> NodeEditor.mouse_down(310.0, 230.0)

    assert state.pending_link == nil
    assert Enum.any?(state.links, &(&1.from == {:tick, 0} and &1.to == {:time, 0}))
  end

  defp active_points(canvas) do
    Enum.flat_map(canvas.ops, fn
      ["__instances", ["port_active", rows, _palette, cols]] ->
        col_pos = cols |> Enum.with_index() |> Map.new()
        x_pos = Map.get(col_pos, 0)
        y_pos = Map.get(col_pos, 1)

        Enum.map(rows, fn row ->
          {Enum.at(row, x_pos), Enum.at(row, y_pos)}
        end)

      _ ->
        []
    end)
  end
end
