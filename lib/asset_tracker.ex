defmodule AssetTracker do
  @moduledoc """
    Módulo para rastreamento de ativos financeiros, incluindo compras, vendas e cálculo de ganhos ou perdas não realizados.
  """
  use GenServer

  defmodule State do
    defstruct assets: %{}
  end

  @doc """
  Inicializa o estado do rastreador de ativos.

  Retorna o estado inicial vazio do rastreador.

  ## Exemplo

      iex> {:ok, state} = AssetTracker.new()
      {:ok, %AssetTracker.State{assets: %{}}}

  """
  def new do
    GenServer.start_link(__MODULE__, %State{}, name: __MODULE__)
  end

  def init(_args) do
    {:ok, %State{assets: %{}}}
  end

  @doc """
    Adiciona uma compra de ativo ao rastreador.

    Params:
      - `asset_name` (String): O nome do ativo.
      - `settle_date` (Date): A data de liquidação da compra.
      - `quantity` (float): A quantidade de ativos comprados.
      - `unit_price` (float): O preço unitário do ativo comprado.

    Retorna:
      - `{:ok, new_state}`: Uma tupla com o novo estado do rastreador após a adição da compra.
      - `error`: Uma mensagem de erro se os valores não forem válidos.

  """
  def add_purchase(asset_name, settle_date, quantity, unit_price) do
    case validate_positive_values(quantity, unit_price) do
      :ok ->
        new_state = GenServer.call(__MODULE__, {:add_purchase, asset_name, settle_date, quantity, unit_price})
        {:ok, new_state}

      error ->
        error
    end
  end

  @doc """
    Adiciona uma venda de ativo ao rastreador.

    Params:
      - `asset_name` (String): O nome do ativo.
      - `settle_date` (Date): A data de liquidação da venda.
      - `quantity` (float): A quantidade de ativos vendidos.
      - `unit_price` (float): O preço unitário do ativo vendido.

    Retorna:
      - `{:ok, {new_state, gain_or_loss}}`: Uma tupla com o novo estado do rastreador após a adição da venda e o ganho ou perda realizado.
      - `{:error, reason}`: Uma mensagem de erro se os valores não forem válidos.

  """
  def add_sale(asset_name, settle_date, quantity, unit_price) do
    case validate_positive_values(quantity) do
      :ok ->
        new_state = GenServer.call(__MODULE__, {:add_sale, asset_name, settle_date, quantity, unit_price})
        {:ok, new_state}

      error ->
        error
    end

  end

  @doc """
    Calcula o ganho ou perda não realizado para um ativo.

    Params:
      - `asset_name` (String): O nome do ativo.
      - `market_price` (float): O preço de mercado atual do ativo.

    Retorna:
      - `{:ok, gain_or_loss}`: Uma tupla com o ganho ou perda não realizado para o ativo.
      - `{:error, reason}`: Uma mensagem de erro se o ativo não for encontrado.

  """
  def unrealized_gain_or_loss(asset_name, market_price) do
    GenServer.call(__MODULE__, {:get_unrealized_gain_or_loss, asset_name, market_price})
  end

  def handle_call({:add_purchase, asset_name, settle_date, quantity, unit_price}, _from, state) do
    current_purchases = Map.get(state.assets, asset_name, [])

    new_purchase = %{quantity: quantity, settle_date: settle_date, unit_price: unit_price}
    updated_purchases = [new_purchase | current_purchases]

    new_assets = Map.update(state.assets, asset_name, updated_purchases, fn _purchases ->
      # Atualize as compras acumuladas para o ativo
      updated_purchases
    end)

    new_state = %State{state | assets: new_assets}

    {:reply, new_state, new_state}
  end

  def handle_call({:add_sale, asset_name, _settle_date, quantity, unit_price}, _from, state) do
    current_purchases = Map.get(state.assets, asset_name, [])

    case process_sale(current_purchases, quantity, unit_price) do
      {:ok, {updated_assets, gain_or_loss}} ->
        updated_assets =
          updated_assets
          |> Enum.filter(fn purchase -> purchase.quantity > 0 end)

        if length(updated_assets) > 0 do
          new_state = %State{state | assets: Map.put(state.assets, asset_name, updated_assets)}
          {:reply, {new_state, gain_or_loss}, new_state}
        else
          new_state = %State{state | assets: Map.delete(state.assets, asset_name)}
          {:reply, {new_state, gain_or_loss}, new_state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:get_unrealized_gain_or_loss, asset_name, market_price}, _from, state) do
    case Map.get(state.assets, asset_name) do
      nil ->
        {:reply, {:error, "Ativo não encontrado."}, state}

      purchases ->
        current_quantity = calculate_current_quantity(purchases)
        cost_basis = calculate_cost_basis(purchases)
        current_value = current_quantity * market_price
        gain_or_loss = current_value - cost_basis
        {:reply, {:ok, gain_or_loss}, state}
    end
  end

  defp calculate_current_quantity(purchases) do
    Enum.reduce(purchases, 0, fn purchase, acc ->
      acc + purchase.quantity
    end)
  end

  defp calculate_cost_basis(purchases) do
    purchases
    |> Enum.map(&(&1.quantity * &1.unit_price))
    |> Enum.sum()
  end

  defp process_sale(purchases, quantity, unit_price) do
    sorted_purchases = Enum.sort_by(purchases, &(&1.settle_date))

    process_sale_recursively(sorted_purchases, quantity, unit_price, [], 0.0)
  end

  defp process_sale_recursively(purchases, quantity, unit_price, acc, gain_or_loss) when quantity > 0 do
    case purchases do
      [] ->
        {:error, "Não há compras suficientes para vender."}

      [%{quantity: purchase_quantity, unit_price: purchase_unit_price, settle_date: settle_date} | rest]
        when purchase_quantity >= quantity ->
        gain_or_loss = gain_or_loss + (unit_price - purchase_unit_price) * quantity
        sold_purchase = %{quantity: purchase_quantity - quantity, unit_price: purchase_unit_price, settle_date: settle_date}
        updated_purchases = acc ++ [sold_purchase | rest]
        {:ok, {updated_purchases, gain_or_loss}}

      [%{quantity: purchase_quantity, unit_price: purchase_unit_price, settle_date: settle_date} | rest]
        when purchase_quantity < quantity ->
        gain_or_loss = gain_or_loss + (unit_price - purchase_unit_price) * purchase_quantity
        sold_purchase = %{quantity: 0, unit_price: purchase_unit_price, settle_date: settle_date}
        process_sale_recursively(
          rest,
          quantity - purchase_quantity,
          unit_price,
          acc ++ [sold_purchase],
          gain_or_loss
        )

      _ ->
        {:error, "Formato de compra inválido."}
    end
  end

  defp process_sale_recursively(_, _, _, _, _) do
    {:error, "Formato de compra inválido."}
  end

  defp validate_positive_values(quantity) when quantity > 0 do
    :ok
  end

  defp validate_positive_values(_) do
    {:error, "A quantidade deve ser positivos."}
  end

  defp validate_positive_values(quantity, unit_price) when quantity > 0 and unit_price > 0 do
    :ok
  end

  defp validate_positive_values(_, _) do
    {:error, "A quantidade e o preço unitário devem ser positivos."}
  end
end
