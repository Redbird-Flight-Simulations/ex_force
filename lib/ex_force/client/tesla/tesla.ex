defmodule ExForce.Client.Tesla do
  @moduledoc """
  HTTP Client for Salesforce REST API using `Tesla`.

  ## Adapter

  To use a different `Tesla` adapter, set it via Mix configuration.

  ```elixir
  config :tesla, ExForce.Client.Tesla, adapter: Tesla.Adapter.Hackney
  ```
  """

  @behaviour ExForce.Client

  alias ExForce.{
    Request,
    Response
  }

  @default_api_version "42.0"
  @default_user_agent "ex_force"

  @doc """
  Returns a `Tesla` client for `ExForce` functions

  ### Options

  - `:headers`: set additional headers; default: `[{"user-agent", "#{@default_user_agent}"}]`
  - `:api_version`: use the given api_version; default: `"#{@default_api_version}"`
  - `:adapter`: use the given adapter with custom opts; default: `nil`, which makes `Tesla` to use the default adapter or the one set in config.
  """
  @impl ExForce.Client
  def build_client(context, opts \\ [])

  def build_client(%{instance_url: instance_url, access_token: access_token}, opts) do
    new_headers = [{"authorization", "Bearer " <> access_token} | get_headers(opts)]
    new_opts = Keyword.put(opts, :headers, new_headers)

    build_client(instance_url, new_opts)
  end

  def build_client(instance_url, opts) when is_binary(instance_url) do
    Tesla.client(
      [
        {ExForce.Client.Tesla.Middleware,
         {instance_url, Keyword.get(opts, :api_version, @default_api_version)}},
        {Tesla.Middleware.JSON, engine: Jason},
        {Tesla.Middleware.Headers, get_headers(opts)},
        {Tesla.Middleware.Compression, format: "gzip"}
      ],
      Keyword.get(opts, :adapter)
    )
  end

  defp get_headers(opts), do: Keyword.get(opts, :headers, [{"user-agent", @default_user_agent}])

  @doc """
  Returns a `Tesla` client for `ExForce.OAuth` functions

  ### Options

  - `:headers`: set additional headers; default: `[{"user-agent", "#{@default_user_agent}"}]`
  - `:adapter`: use the given adapter with custom opts; default: `nil`, which makes `Tesla` to use the default adapter or the one set in config.
  """
  @impl ExForce.Client
  def build_oauth_client(instance_url, opts \\ []) do
    Tesla.client(
      [
        {Tesla.Middleware.BaseUrl, instance_url},
        Tesla.Middleware.FormUrlencoded,
        {Tesla.Middleware.DecodeJson, engine: Jason},
        {Tesla.Middleware.Headers, get_headers(opts)},
        {Tesla.Middleware.Compression, format: "gzip"}
      ],
      Keyword.get(opts, :adapter)
    )
  end

  @doc """
  Sends a request to Salesforce
  """
  @impl ExForce.Client
  def request(%Tesla.Client{} = client, %Request{} = request) do
    client
    |> Tesla.request(cast_tesla_request(request))
    |> cast_response()
  end

  defp cast_tesla_request(%Request{} = request) do
    request
    |> convert_struct(Tesla.Env)
    |> Map.to_list()
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp convert_struct(%_struct{} = fields, new_struct),
    do: struct(new_struct, Map.from_struct(fields))

  defp cast_response({:ok, %Tesla.Env{} = response}),
    do: {:ok, convert_struct(response, Response)}

  defp cast_response({:error, error}), do: {:error, error}
end
