# Benchmark the compilation of the Easel.API module, which includes:
# - Parsing the WebIDL file
# - Reading/decoding the compat JSON
# - Metaprogramming to generate all function definitions

# Pre-read the files so we can isolate file I/O if needed
webidl_source = File.read!(Path.join(:code.priv_dir(:easel), "easel.webidl"))
compat_source = File.read!(Path.join(:code.priv_dir(:easel), "compat.json"))

Benchee.run(
  %{
    "full API module compile" => fn ->
      :code.purge(Easel.API)
      :code.delete(Easel.API)
      Code.compile_file("lib/api.ex")
    end,
    "WebIDL parse only" => fn ->
      Easel.WebIDL.members_by_name(webidl_source)
    end,
    "compat JSON decode only" => fn ->
      JSON.decode!(compat_source)
    end
  },
  warmup: 2,
  time: 5,
  memory_time: 2
)
