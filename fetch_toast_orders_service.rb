# frozen_string_literal: true

class FetchToastOrdersService
  attr_reader :integration_client, :location

  def initialize(location:, integration_client: ToastClient)
    @integration_client = integration_client
    @location = location
  end

  def run(range:, params: {})
    client = integration_client.new(location: location, service: :orders)

    response = client.fetch_orders(range: range, query_params: params)

    orders = response[:orders]
    items = response[:items]

    next_page = response[:next_page]
    search_range = response[:search_range]

    Order.upsert_all(orders, unique_by: [:external_id, :location_id], returning: nil) if orders.present?
    Item.upsert_all(items, unique_by: [:external_id, :order_external_id], returning: nil) if items.present?

    if next_page.nil?
      ExportToastOrdersJob.perform_later(location_id: location.id, range: search_range)
    else
      FetchToastOrdersJob.perform_later(location_id: location.id, range: range, params: next_page)
    end
  end
end
