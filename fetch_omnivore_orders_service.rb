# frozen_string_literal: true

class FetchOmnivoreOrdersService
  attr_reader :integration_client, :location

  def initialize(location:, integration_client: OmnivoreClient)
    @integration_client = integration_client
    @location = location
  end

  def run(range, query_params = {})
    client = integration_client.new(location: location, service: 'tickets')

    response = client.fetch_orders(range: range, query_params: query_params)

    orders = response[:orders]
    next_page = response[:next_page_link]
    search_range = response[:search_range]

    Order.upsert_all(orders, unique_by: [:external_id, :location_id], returning: nil) if orders.present?

    if next_page.nil?
      ExportOmnivoreOrdersJob.perform_later(location_id: location.id, range: search_range)
    else
      query_params = parse_params(next_page)
      FetchOmnivoreOrdersJob.perform_later(location_id: location.id, range: range, params: query_params)
    end
  end

  private

  def parse_params(url)
    Rack::Utils.parse_nested_query(url.split('?').try(:last))
  end
end
