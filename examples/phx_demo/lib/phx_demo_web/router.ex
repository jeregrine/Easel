defmodule PhxDemoWeb.Router do
  use PhxDemoWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PhxDemoWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", PhxDemoWeb do
    pipe_through :browser

    live "/", DemoLive
    live "/clock", ClockLive
    live "/boids", BoidsLive
    live "/matrix", MatrixLive
    live "/life", LifeLive
    live "/lissajous", LissajousLive
    live "/flow", FlowFieldLive
    live "/wave", WaveGridLive
    live "/pathfinding", PathfindingLive
  end
end
