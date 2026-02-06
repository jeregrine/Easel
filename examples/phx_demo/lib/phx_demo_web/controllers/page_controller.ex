defmodule PhxDemoWeb.PageController do
  use PhxDemoWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
