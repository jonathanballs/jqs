defmodule Jqs.Web.ErrorJSON do
  def render("error.json", %{error: :queue_not_found}) do
    %{errors: %{detail: "queue does not exist"}}
  end

  def render(template, _assigns) do
    %{errors: %{detail: Phoenix.Controller.status_message_from_template(template)}}
  end
end
