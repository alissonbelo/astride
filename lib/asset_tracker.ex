defmodule AssetTracker do
  @moduledoc """
    Módulo para rastreamento de ativos financeiros, incluindo compras, vendas e cálculo de ganhos ou perdas não realizados.
  """

  @doc """
    Inicializa o estado do rastreador de ativos.

    Retorna o estado inicial vazio do rastreador.

    ## Exemplo

        iex> asset_data = AssetTracker.new()
        %{}

  """
  def new do
    %{}
  end

  @doc """
    Adiciona uma compra de ativo ao rastreador.

    Params:
      - `asset_data` (map): O estado atual do rastreador.
      - `asset_name` (String): O nome do ativo.
      - `settle_date` (Date): A data de liquidação da compra.
      - `quantity` (float): A quantidade de ativos comprados.
      - `unit_price` (float): O preço unitário do ativo comprado.

    Retorna:
      - `{:ok, new_asset_data}`: Uma tupla com o novo estado do rastreador após a adição da compra.
      - `{:error, reason}`: Uma mensagem de erro se os valores não forem válidos.

  """
def add_purchase(asset_data, asset_name, settle_date, quantity, unit_price) do
  case validate_positive_values(quantity, unit_price) do
    :ok ->
      new_purchase = %{quantity: quantity, settle_date: settle_date, unit_price: unit_price}

      updated_assets =
        case asset_data do
          %{} = current_assets ->
            current_purchases = Map.get(current_assets, asset_name, [])
            updated_purchases = [new_purchase | current_purchases]
            Map.update(current_assets, asset_name, updated_purchases, fn _purchases ->
              updated_purchases
            end)

          [current_purchase | _] = current_assets when is_map(current_purchase) ->
            current_assets
            |> Enum.reduce(%{}, fn %{quantity: q, settle_date: date, unit_price: price}, acc ->
              Map.update(acc, asset_name, [%{quantity: q, settle_date: date, unit_price: price} | Map.get(acc, asset_name, [])], fn purchases ->
                [%{quantity: q, settle_date: date, unit_price: price} | purchases]
              end)
            end)

          _ ->
            asset_data
        end

      updated_assets

    {:error, reason} ->
      {:error, reason}
  end
end

  @doc """
    Adiciona uma venda de ativo ao rastreador.

    Params:
      - `asset_data` (map): O estado atual do rastreador.
      - `asset_name` (String): O nome do ativo.
      - `settle_date` (Date): A data de liquidação da venda.
      - `quantity` (float): A quantidade de ativos vendidos.
      - `unit_price` (float): O preço unitário do ativo vendido.

    Retorna:
      - `{:ok, {new_asset_data, gain_or_loss}}`: Uma tupla com o novo estado do rastreador após a adição da venda e o ganho ou perda realizado.
      - `{:error, reason}`: Uma mensagem de erro se os valores não forem válidos.

  """
  def add_sale(asset_data, asset_name, _settle_date, quantity, unit_price) do
    case validate_positive_values(quantity) do
      :ok ->
        current_purchases = Map.get(asset_data, asset_name, [])

        case process_sale(current_purchases, quantity, unit_price) do
          {:ok, {updated_assets, gain_or_loss}} ->
            updated_assets =
              updated_assets
              |> Enum.filter(fn purchase -> purchase.quantity > 0 end)

            if length(updated_assets) > 0 do
              updated_data = Map.put(asset_data, asset_name, updated_assets)
              {:ok, {updated_data, gain_or_loss}}
            else
              updated_data = Map.delete(asset_data, asset_name)
              {:ok, {updated_data, gain_or_loss}}
            end

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
    Calcula o ganho ou perda não realizado para um ativo.

    Params:
      - `asset_data` (map): O estado atual do rastreador.
      - `asset_name` (String): O nome do ativo.
      - `market_price` (float): O preço de mercado atual do ativo.

    Retorna:
      - `{:ok, gain_or_loss}`: Uma tupla com o ganho ou perda não realizado para o ativo.
      - `{:error, reason}`: Uma mensagem de erro se o ativo não for encontrado.

  """
  def unrealized_gain_or_loss(asset_data, asset_name, market_price) do
    case Map.get(asset_data, asset_name) do
      nil ->
        {:error, "Ativo não encontrado."}

      purchases ->
        current_quantity = calculate_current_quantity(purchases)
        cost_basis = calculate_cost_basis(purchases)
        current_value = current_quantity * market_price
        gain_or_loss = current_value - cost_basis
        {:ok, gain_or_loss}
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

  defp process_sale_recursively(_, _, _, _, _), do: {:error, "Formato de compra inválido."}

  defp validate_positive_values(quantity) when quantity > 0, do: :ok

  defp validate_positive_values(_), do: {:error, "A quantidade deve ser positivos."}

  defp validate_positive_values(quantity, unit_price) when quantity > 0 and unit_price > 0, do: :ok

  defp validate_positive_values(_, _), do: {:error, "A quantidade e o preço unitário devem ser positivos."}
end
