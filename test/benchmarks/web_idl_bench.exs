source = File.read!(Path.join(:code.priv_dir(:canvas), "canvas.webidl"))

# A minimal snippet for micro-benchmarking individual aspects
small_interface = """
interface mixin CanvasRect {
  undefined clearRect(double x, double y, double w, double h);
  undefined fillRect(double x, double y, double w, double h);
  undefined strokeRect(double x, double y, double w, double h);
};
"""

overloaded_interface = """
interface mixin CanvasDrawPath {
  undefined beginPath();
  undefined fill(optional CanvasWindingRule winding = "nonzero");
  undefined fill(Path2D path, optional CanvasWindingRule winding = "nonzero");
  undefined stroke();
  undefined stroke(Path2D path);
  undefined clip(optional CanvasWindingRule winding = "nonzero");
  undefined clip(Path2D path, optional CanvasWindingRule winding = "nonzero");
};
"""

Benchee.run(
  %{
    "parse - full canvas.webidl" => fn -> Canvas.WebIDL.parse(source) end,
    "parse - small interface" => fn -> Canvas.WebIDL.parse(small_interface) end,
    "parse - overloaded interface" => fn -> Canvas.WebIDL.parse(overloaded_interface) end,
    "members_by_name - full canvas.webidl" => fn -> Canvas.WebIDL.members_by_name(source) end
  },
  warmup: 2,
  time: 5,
  memory_time: 2
)
