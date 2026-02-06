defmodule PhxDemo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PhxDemoWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:phx_demo, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: PhxDemo.PubSub},
      # Start a worker by calling: PhxDemo.Worker.start_link(arg)
      # {PhxDemo.Worker, arg},
      # Start to serve requests, typically the last entry
      PhxDemoWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PhxDemo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PhxDemoWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
