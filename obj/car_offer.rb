class Car_offer
  # Creates a new car offer object storing scraped data
  attr_reader :img_url, :offer_name, :quick_info, :mileage, :fuel_type, :gearbox, :year, :localization, :price, :currency
  def initialize(img_url, offer_name, quick_info, mileage, fuel_type, gearbox, year, localization, price, currency)
    @img_url = img_url
    @offer_name = offer_name
    @quick_info = quick_info
    @mileage = mileage
    @fuel_type = fuel_type
    @gearbox = gearbox
    @year = year
    @localization = localization
    @price = price
    @currency = currency
  end
end