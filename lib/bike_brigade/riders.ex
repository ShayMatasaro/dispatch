defmodule BikeBrigade.Riders do
  @moduledoc """
  The Riders context.
  """

  import Ecto.Query, warn: false
  alias BikeBrigade.Repo

  alias BikeBrigade.Riders.{Rider, Tag}
  alias BikeBrigade.Delivery.CampaignRider

  alias BikeBrigade.EctoPhoneNumber

  @doc """
  Returns the list of riders.

  ## Examples

      iex> list_riders()
      [%Rider{}, ...]

  """
  def list_riders do
    Repo.all(Rider)
  end

  def list_riders_with_tag(tag) do
    tag = Repo.get_by(Tag, name: tag) |> Repo.preload(:riders)
    if tag, do: tag.riders, else: []
  end

  def search_riders(search \\ "", opts \\ []) do
    opts = Keyword.merge([limit: 100, name_search: true, email_search: false, phone_search: false], opts)


    where = false
    where = if Keyword.get(opts, :name_search) do
      dynamic([r], ^where or ilike(r.name, ^"%#{search}%"))
    else
      where
    end

    where = if Keyword.get(opts, :email_search) do
      dynamic([r], ^where or ilike(r.email, ^"%#{search}%"))
    else
      where
    end

    where = if Keyword.get(opts, :phone_search) and search =~ ~r/\d/ do
      dynamic([r], ^where or ilike(r.phone, ^"%#{Regex.replace(~r/[^\d]/, search, "")}%"))
    else
      where
    end

    query =
      from r in Rider,
        where: ^where,
        left_join: cr in CampaignRider,
        on: cr.rider_id == r.id,
        limit: ^Keyword.get(opts, :limit),
        group_by: r.id,
        order_by: [desc: count(cr.id)]

    Repo.all(query)
  end

  @doc """
  Gets a single rider.

  Raises `Ecto.NoResultsError` if the Rider does not exist.

  ## Examples

      iex> get_rider!(123)
      %Rider{}

      iex> get_rider!(456)
      ** (Ecto.NoResultsError)

  """
  def get_rider(id) do
    Repo.get(Rider, id)
  end

  def get_rider!(id) do
    Repo.get!(Rider, id)
  end

  def get_riders(ids) do
    Repo.all(from r in Rider, where: r.id in ^ids)
  end

  def get_rider_by_email!(email) do
    email = String.downcase(email)

    Rider
    |> Repo.get_by!(email: email)
  end

  def get_rider_by_email(email) do
    email = String.downcase(email)

    Rider
    |> Repo.get_by(email: email)
  end

  def get_rider_by_phone!(phone) do
    case EctoPhoneNumber.Canadian.cast(phone) do
      {:ok, phone} ->
        Repo.get_by!(Rider, phone: phone)

      {:error, err} ->
        raise EctoPhoneNumber.InvalidNumber, message: err
    end
  end

  def get_rider_by_phone(phone) do
    case BikeBrigade.EctoPhoneNumber.Canadian.cast(phone) do
      {:ok, phone} -> Repo.get_by(Rider, phone: phone)
      {:error, _err} -> nil
    end
  end

  @doc """
  Creates a rider.

  ## Examples

      iex> create_rider(%{field: value})
      {:ok, %Rider{}}

      iex> create_rider(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_rider(attrs \\ %{}, opts \\ []) do
    %Rider{}
    |> Rider.changeset(attrs)
    |> Repo.insert(opts)
    |> broadcast(:rider_created)
  end

  @doc """
  Updates a rider.

  ## Examples

      iex> update_rider(rider, %{field: new_value})
      {:ok, %Rider{}}

      iex> update_rider(rider, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_rider(%Rider{} = rider, attrs) do
    rider
    |> Rider.changeset(attrs)
    |> Repo.update()
    |> broadcast(:rider_updated)
  end

  @doc """
  Deletes a rider.

  ## Examples

      iex> delete_rider(rider)
      {:ok, %Rider{}}

      iex> delete_rider(rider)
      {:error, %Ecto.Changeset{}}

  """
  def delete_rider(%Rider{} = rider) do
    Repo.delete(rider)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking rider changes.

  ## Examples

      iex> change_rider(rider)
      %Ecto.Changeset{data: %Rider{}}

  """
  def change_rider(%Rider{} = rider, attrs \\ %{}) do
    Rider.changeset(rider, attrs)
  end

  def count_riders() do
    Rider
    |> select([r], count(r.id))
    |> Repo.one()
  end

  def subscribe do
    Phoenix.PubSub.subscribe(BikeBrigade.PubSub, "riders")
  end

  defp broadcast({:error, _reason} = error, _event), do: error

  defp broadcast({:ok, struct}, event) do
    Phoenix.PubSub.broadcast(BikeBrigade.PubSub, "riders", {event, struct})
    {:ok, struct}
  end
end
