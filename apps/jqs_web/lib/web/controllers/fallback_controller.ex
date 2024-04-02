defmodule Jqs.Web.FallbackController do
  require Logger

  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use Jqs.Web, :controller

  # This clause handles errors returned by Ecto's insert/update/delete.
  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:bad_request)
    |> put_view(json: Jqs.Web.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end

  # This clause is an example of how to handle resources that cannot be found.
  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(html: Jqs.Web.ErrorHTML, json: Jqs.Web.ErrorJSON)
    |> render(:"404")
  end

  def call(conn, {:error, :queue_not_found}) do
    conn
    |> put_status(:bad_request)
    |> put_view(json: Jqs.Web.ErrorJSON)
    |> render(:error, error: :queue_not_found)
  end

  def call(conn, {:error, _} = error) do
    Logger.error("No handler in FallbackController for #{inspect(error)}")

    conn
    |> put_status(:internal_server_error)
    |> put_view(json: Jqs.Web.ErrorJSON)
    |> render(:"500")
  end
end
