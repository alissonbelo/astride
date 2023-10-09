defmodule AssetTrackerTest do
  use ExUnit.Case
  alias AssetTracker

  describe "add_purchase/4" do
    test "successful purchase" do
      tracker = AssetTracker.new()

      tracker = AssetTracker.add_purchase(tracker, "AAPL", ~D[2023-09-28], 10.00, 160.0)

      assert tracker["AAPL"] == [%{quantity: 10.00, settle_date: ~D[2023-09-28], unit_price: 160.0}]
    end

    test "purchase with invalid quantity or price" do
      tracker = AssetTracker.new()

      {:error, error} = AssetTracker.add_purchase(tracker, "AAPL", ~D[2023-09-28], 0.0, 160.0)
      assert error == "A quantidade e o preço unitário devem ser positivos."

      {:error, error} = AssetTracker.add_purchase(tracker, "AAPL", ~D[2023-09-28], 1.0, 0.0)
      assert error == "A quantidade e o preço unitário devem ser positivos."
    end
  end

  describe "add_sale/4" do
    test "successful sale following FIFO pattern" do
      tracker = AssetTracker.new()

      tracker = AssetTracker.add_purchase(tracker, "AAPL", ~D[2023-09-28], 10.0, 160.0)
      tracker = AssetTracker.add_purchase(tracker, "AAPL", ~D[2023-09-29], 10.0, 160.0)

      {:ok, {%{"AAPL" => updated_assets}, gain_or_loss}} = AssetTracker.add_sale(tracker, "AAPL", ~D[2023-10-31], 9.0, 200.0)

      assert updated_assets == [
        %{quantity: 1.0, settle_date: ~D[2023-09-28], unit_price: 160.0},
        %{quantity: 10.0, settle_date: ~D[2023-09-29], unit_price: 160.0}
      ]

      assert gain_or_loss == 360.00
    end

    test "selling all and deducting from the purchase" do
      tracker = AssetTracker.new()

      tracker = AssetTracker.add_purchase(tracker, "AAPL", ~D[2023-09-28], 10.0, 160.0)

      {:ok, {tracker, gain_or_loss}} = AssetTracker.add_sale(tracker, "AAPL", ~D[2023-09-29], 10.0, 200.0)

      assert tracker["AAPL"] == nil

      assert gain_or_loss == 400.00
    end

    test "sell using FIFO with remaining quantity from another purchase" do
      tracker = AssetTracker.new()

      tracker = AssetTracker.add_purchase(tracker, "AAPL", ~D[2023-09-28], 10.0, 160.0)
      tracker = AssetTracker.add_purchase(tracker, "AAPL", ~D[2023-09-29], 10.0, 170.0)

      {:ok, {tracker, gain_or_loss}} = AssetTracker.add_sale(tracker, "AAPL", ~D[2023-10-31], 11.0, 200.0)

      assert tracker["AAPL"] == [
        %{quantity: 9.0, settle_date: ~D[2023-09-29], unit_price: 170.0}
      ]

      assert gain_or_loss == 430.00
    end

    test "sale with invalid quantity" do
      tracker = AssetTracker.new()

      tracker = AssetTracker.add_purchase(tracker, "AAPL", ~D[2023-09-28], 10.0, 160.0)

      {:error, error} = AssetTracker.add_sale(tracker, "AAPL", ~D[2023-10-31], 0.0, 200.0)

      assert error == "A quantidade deve ser positivos."
    end
    end

  describe "unrealized_gain_or_loss/2" do
    test "calculates unrealized gain or loss successfully" do
      tracker = AssetTracker.new()

      tracker = AssetTracker.add_purchase(tracker, "AAPL", ~D[2023-09-28], 10.0, 160.0)

      {:ok, gain_or_loss} = AssetTracker.unrealized_gain_or_loss(tracker, "AAPL", 140.0)
      assert gain_or_loss == -200.0

      {:ok, gain_or_loss} = AssetTracker.unrealized_gain_or_loss(tracker, "AAPL", 160.0)
      assert gain_or_loss == 00.0

      {:ok, gain_or_loss} = AssetTracker.unrealized_gain_or_loss(tracker, "AAPL", 180.0)
      assert gain_or_loss == 200.0
    end
  end
end
