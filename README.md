# Astride

O Asset Tracker é uma aplicação Elixir para rastrear compras e vendas de ativos financeiros e calcular ganhos ou perdas não realizados.

## Como Usar
Inicie o ambiente Elixir com o Mix:
`iex -S mix`

Criar um novo rastreador de ativos:
```elixir
asset_data = AssetTracker.new()
# Retorna: {:ok, #PID<0.198.0>}
```
Adicionar uma compra de ativo:
```elixir
asset_data = AssetTracker.add_purchase(asset_data, "AAPL", ~D[2023-09-28], 8, 170.0)
# Retorna: {:ok, %AssetTracker.State{
#   assets: %{
#     "AAPL" => [%{quantity: 8, settle_date: ~D[2023-09-28], unit_price: 170.0}]
#   }
# }}
```
Adicionar uma venda de ativo:
```elixir
asset_data = AssetTracker.add_sale(asset_data, "AAPL", ~D[2023-10-31], 9, 200.0)
# Retorna: {:ok, {%AssetTracker.State{
#   assets: %{
#     "AAPL" => [%{quantity: 3, settle_date: ~D[2023-09-29], unit_price: 180.0}]
#   }
# }, 260.0}}
```
Calcular o ganho ou perda não realizado para um ativo:
```elixir
AssetTracker.unrealized_gain_or_loss(asset_data, "AAPL", 180.0)
# Retorna: {:ok, 80.0}
```
