# frozen_string_literal: true

class FetchSquareOrdersService
  attr_reader :location, :integration_client

  def initialize(location:, integration_client: SquareClient)
    @location = location
    @integration_client = integration_client
  end

  def run(range:, params: nil)
    client = integration_client.new(location: location)

    response = client.fetch_orders(range: range, query_params: params)

    orders = response[:orders]
    cursor = response[:cursor]
    search_range = response[:search_range]
    query_params = { cursor: cursor, search_range: search_range }

    Order.upsert_all(orders, unique_by: [:external_id, :location_id], returning: nil) if orders.present?

    if cursor.nil?
      mark_orders_as_imported!
      ExportSquareOrdersJob.perform_later(location_id: location.id, range: search_range)
    else
      FetchSquareOrdersJob.perform_later(location_id: location.id, range: range, params: query_params)
    end
  end

  private

  def mark_orders_as_imported!
    location.integration_settings['orders_imported'] = true
    location.save!
  end
end
