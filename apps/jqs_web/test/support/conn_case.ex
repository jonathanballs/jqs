defmodule Jqs.Web.ConnCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint Jqs.Web.Endpoint

      use Jqs.Web, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import Jqs.Web.ConnCase
    end
  end
end
