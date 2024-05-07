require 'nokogiri'
require 'open-uri'
require 'csv'
require 'prawn'
require './obj/car_offer.rb'
require 'thread'

class Otomoto_scraper
  # Creates a new scraper object
  #
  # Example:
  #   1. With no specified link (car), the default link is "https://www.otomoto.pl/osobowe/bmw"
  #     Otomoto_spraper.new
  #
  #   2. With specified link
  #     Otomoto_spraper.new(link: "https://www.otomoto.pl/osobowe/bmw")
  #
  #   3. With specified maximum number of simultaneously working threads, the default number is 10. It is not recommended to change this.
  #     Otomoto_spraper.new(max_threads: 10)
  def initialize(link: "https://www.otomoto.pl/osobowe/bmw", max_threads: 10)
    raise 'Invalid link' unless link.start_with?("https://www.otomoto.pl/")
    begin
      @doc = Nokogiri::HTML(URI.open(link))
    rescue OpenURI::HTTPError
      raise 'Page does not exist'
    end
    @link = link
    @car_offers=[]
    @number_of_pages=@doc.css("a.ooa-g4wbjr").last.css("span").text.to_i
    @max_threads = max_threads
  end


  def scrape_page(page_number=1)
    if page_number > 1
      begin
        @doc = Nokogiri::HTML(URI.open(@link+"?page=#{page_number}"))
      rescue OpenURI::HTTPError
        raise 'Page does not exist'
      end
    end

    page_car_offers = @doc.css("section.ooa-10gfd0w")

    page_car_offers.each do |offer|
      img_url = offer.css("img.e17vhtca4")
      if !img_url.empty?
        img_url = img_url.attribute("src").value
      else
        img_url = "nil"
      end

      offer_name = offer.css("div.ooa-1qo9a0p").css("h1").first.text
      quick_info = offer.css("div.ooa-1qo9a0p").css("p").first.text
      mileage = offer.css("div.ooa-d3dp2q").css("dl.ooa-1uwk9ii").css("dd")[0].text
      fuel_type= offer.css("div.ooa-d3dp2q").css("dl.ooa-1uwk9ii").css("dd")[1].text
      gearbox= offer.css("div.ooa-d3dp2q").css("dl.ooa-1uwk9ii").css("dd")[2].text
      year = offer.css("div.ooa-d3dp2q").css("dl.ooa-1uwk9ii").css("dd")[3].text
      localization = offer.css("div.ooa-d3dp2q").css("dl.ooa-1o0axny").css("dd").css("p").first.text
      price = offer.css("div.ooa-1a2gnf2").css("div.ooa-vtik1a").css("div.ooa-2p9dfw").css("h3").first.text
      currency = offer.css("div.ooa-1a2gnf2").css("div.ooa-vtik1a").css("div.ooa-2p9dfw").css("p").first.text
      car_offer = Car_offer.new(img_url, offer_name, quick_info, mileage, fuel_type, gearbox, year, localization, price, currency)
      @car_offers.push(car_offer)
    end
  end

  # Fills the created object with data scraped form 'page_limit' pages.
  # If page_limit is not specified, the default is set to all pages
  #
  # Example:
  #   scraper = Otomoto_spraper.new("https://www.otomoto.pl/osobowe/bmw")
  #
  #   1. With no arguments, scrapes all available pages
  #     scraper.scrape_cars
  #
  #   2. With specified page_limit, if possible, scrapes 'page_limit' pages
  #     scraper.save_to_csv(filename: 'new_filename.csv')
  def scrape_cars(page_limit = @number_of_pages)
    if page_limit > @number_of_pages
      page_limit = @number_of_pages
    end

    threads=[]
    thread = Queue.new
    (1..page_limit).each do |i|
      while thread.size >= @max_threads
        sleep 0.1
      end

      thread << 1
      threads << Thread.new do
        begin
          scrape_page(i)
        ensure
          thread.pop
        end
      end
    end
    threads.each(&:join)
  end

  # Saves stored data into a csv file.
  #
  # Example:
  #   scraper = Otomoto_spraper.new("https://www.otomoto.pl/osobowe/bmw")
  #   scraper.scrape_cars(5)
  #
  #   1. With no arguments, saves data into file named "car_offers.csv" and overrides the file if exists
  #     scraper.save_to_csv
  #
  #   2. With specified filename, saves data into given filename, overrides the file if exists
  #     scraper.save_to_csv(filename: 'new_filename.csv')
  #
  #   3, With override set to false, saves data and does not override the file
  #     scraper.save_to_csv(override: false)
  def save_to_csv(override: true, filename: "car_offers.csv")
    raise 'There are no car offers' if @car_offers.nil? || @car_offers.empty?

    if override || !(File::exist?(filename))
      csv_headers = ["offer_name", "quick_info", "mileage", "fuel_type", "gearbox", "year", "localization", "price", "currency"]
      csv = CSV.open(filename, "wb", write_headers: true, headers: csv_headers)
    else
      csv = CSV.open(filename, "a+b")
    end

    @car_offers.each do |car_offer|
      csv << [car_offer.offer_name, car_offer.quick_info, car_offer.mileage, car_offer.fuel_type, car_offer.gearbox, car_offer.year, car_offer.localization, car_offer.price, car_offer.currency]
    end
    csv.close
  end

  # Saves stored images into a pdf file.
  #
  # Example:
  #   scraper = Otomoto_spraper.new("https://www.otomoto.pl/osobowe/bmw")
  #   scraper.scrape_cars(5)
  #
  #   1. With no arguments, saves images (one image per page) into file named "car_offers.pdf" and overrides the file if exists
  #     scraper.save_images_to_pdf
  #
  #   2. With specified filename, saves images into given filename, overrides the file if exists
  #     scraper.save_images_to_pdf(filename: 'new_filename.pdf')
  #
  #   3, With one_img_per_page set to false, saves images and tries to fit as many as possible into one page
  #     scraper.save_to_csv(override: false)
  def save_images_to_pdf(filename: "car_offers.pdf", one_img_per_page: true)
    raise 'There are no car offers' if @car_offers.nil? || @car_offers.empty?

    car_offers_copy = @car_offers
    Prawn::Document.generate(filename) do
      car_offers_copy.each do |car_offer|
        begin
            url = car_offer.img_url.to_s.split(';s=').first
            image_data = URI.open(url).read
          begin
            image_string_io = StringIO.new(image_data)
            self.image image_string_io, scale: 0.5
          rescue
            retry
          ensure
            image_string_io.close unless image_string_io.closed?
          end
        rescue
          text "nil"
        end
        if one_img_per_page
          start_new_page
        end
      end
    end
  end

  # Returns an array that contains all data (including img_url) about an offer
  #
  # Example:
  #   scraper = Otomoto_spraper.new("https://www.otomoto.pl/osobowe/bmw")
  #
  #   1. With no arguments, returns the first stored offer ( starts with 0 )
  #     scraper.offer
  #   2. With given number offer_no, if possible, returns the offer_no offer, else returns an empty array
  #     scraper.offer(3)
  def offer(offer_no = 0)
    raise 'There are no car offers' if @car_offers.nil? || @car_offers.empty?
    if @car_offers.length <= offer_no
      []
    else
      car_offer = @car_offers[offer_no]
      [car_offer.offer_name, car_offer.quick_info, car_offer.mileage, car_offer.fuel_type, car_offer.gearbox, car_offer.year, car_offer.localization, car_offer.price, car_offer.currency, car_offer.img_url]
    end
  end

  # Returns an array that contains all data (including img_url) about every offer
  #
  # Example:
  #   scraper = Otomoto_spraper.new("https://www.otomoto.pl/osobowe/bmw")
  #
  #   scraper.all_offers
  def all_offers
    raise 'There are no car offers' if @car_offers.nil? || @car_offers.empty?
    result = []
    offer_no = 0
    @car_offers.each {
      result << offer(offer_no)
      offer_no += 1
    }
    result
  end
  private :scrape_page
end