defmodule Jqs.Web.Validators.TaskCreate do
  @moduledoc """
    Ecto schema for validating the json body of a create task request
  """
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field(:queue, :string)
    field(:context, :map, default: %{})

    embeds_one :options, Options do
      field(:max_retries, :integer)
      field(:backoff_ms, :integer)
      field(:priority, Ecto.Enum, values: [:low, :high])

      def changeset(schema, body) do
        schema
        |> cast(body, [:priority], message: fn _, _ -> "must be \"high\" or \"low\"" end)
        |> cast(body, [:max_retries, :backoff_ms])
        |> validate_number(:backoff_ms, greater_than_or_equal_to: 0)
        |> validate_number(:max_retries, greater_than_or_equal_to: 0, less_than: 100)
      end
    end
  end

  defp changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:queue, :context])
    |> cast_embed(:options)
    |> validate_required([:queue])
  end

  @spec validate_params(any()) :: {:ok, TaskCreate.t()} | {:error, Changeset.t()}
  def validate_params(params) do
    case changeset(params) do
      %Ecto.Changeset{valid?: false} = changeset ->
        {:error, changeset}

      %Ecto.Changeset{valid?: true} = changeset ->
        {:ok, apply_changes(changeset)}
    end
  end
end
