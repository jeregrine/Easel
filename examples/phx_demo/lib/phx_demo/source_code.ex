defmodule PhxDemo.SourceCode do
  @moduledoc false

  @entries %{
    "smiley" => %{title: "Smiley", files: [{"Smiley module", "lib/phx_demo/examples/smiley.ex"}]},
    "chart" => %{title: "Chart", files: [{"Chart module", "lib/phx_demo/examples/chart.ex"}]},
    "starfield" => %{
      title: "Starfield",
      files: [{"Starfield module", "lib/phx_demo/examples/starfield.ex"}]
    },
    "spiral" => %{title: "Spiral", files: [{"Spiral module", "lib/phx_demo/examples/spiral.ex"}]},
    "tree" => %{title: "Fractal Tree", files: [{"Tree module", "lib/phx_demo/examples/tree.ex"}]},
    "mondrian" => %{
      title: "Mondrian",
      files: [{"Mondrian module", "lib/phx_demo/examples/mondrian.ex"}]
    },
    "sierpinski" => %{
      title: "Sierpinski",
      files: [{"Sierpinski module", "lib/phx_demo/examples/sierpinski.ex"}]
    },
    "mandelbrot" => %{
      title: "Mandelbrot",
      files: [{"Mandelbrot module", "lib/phx_demo/examples/mandelbrot.ex"}]
    },
    "clock" => %{
      title: "Clock",
      files: [
        {"Clock module", "lib/phx_demo/examples/clock.ex"},
        {"Clock LiveView", "lib/phx_demo_web/live/clock_live.ex"}
      ]
    },
    "boids" => %{
      title: "Boids",
      files: [
        {"Boids module", "lib/phx_demo/examples/boids.ex"},
        {"Boids LiveView", "lib/phx_demo_web/live/boids_live.ex"}
      ]
    },
    "matrix" => %{
      title: "Matrix",
      files: [
        {"Matrix module", "lib/phx_demo/examples/matrix.ex"},
        {"Matrix LiveView", "lib/phx_demo_web/live/matrix_live.ex"}
      ]
    },
    "life" => %{
      title: "Life",
      files: [
        {"Life module", "lib/phx_demo/examples/life.ex"},
        {"Life LiveView", "lib/phx_demo_web/live/life_live.ex"}
      ]
    },
    "lissajous" => %{
      title: "Lissajous",
      files: [
        {"Lissajous module", "lib/phx_demo/examples/lissajous.ex"},
        {"Lissajous LiveView", "lib/phx_demo_web/live/lissajous_live.ex"}
      ]
    },
    "flow" => %{
      title: "Flow Field",
      files: [
        {"Flow Field module", "lib/phx_demo/examples/flow_field.ex"},
        {"Flow Field LiveView", "lib/phx_demo_web/live/flow_field_live.ex"}
      ]
    },
    "wave" => %{
      title: "Wave Grid",
      files: [
        {"Wave Grid module", "lib/phx_demo/examples/wave_grid.ex"},
        {"Wave Grid LiveView", "lib/phx_demo_web/live/wave_grid_live.ex"}
      ]
    },
    "pathfinding" => %{
      title: "Pathfinding",
      files: [
        {"Pathfinding module", "lib/phx_demo/examples/pathfinding.ex"},
        {"Pathfinding LiveView", "lib/phx_demo_web/live/pathfinding_live.ex"}
      ]
    }
  }

  @root Path.expand("../..", __DIR__)

  @compiled_entries Enum.into(@entries, %{}, fn {id, %{title: title, files: files}} ->
                      embedded =
                        Enum.map(files, fn {label, rel} ->
                          %{label: label, path: rel, code: File.read!(Path.join(@root, rel))}
                        end)

                      {id, %{id: id, title: title, files: embedded}}
                    end)

  def all, do: @compiled_entries
  def get(id), do: Map.get(@compiled_entries, id)
end
