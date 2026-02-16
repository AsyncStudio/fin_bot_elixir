defmodule FinBotWeb.WhatsappControllerTest do
  use FinBotWeb.ConnCase

  describe "POST /whatsapp" do
    test "creates a transaction from whatsapp message", %{conn: conn} do
      payload = %{
        "sender" => "5548999999999",
        "content" => "Paguei 50 reais de sushi agora no centro de Floripa",
        "message_type" => "text"
      }

      conn = post(conn, Routes.whatsapp_path(conn, :create), payload)

      assert response(conn, 200)
    end
  end
end
