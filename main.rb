require './otomoto_scraper.rb'

scraper = Otomoto_scraper.new(link: "https://www.otomoto.pl/osobowe/bmw")

scraper.scrape_cars(1)
scraper.save_to_csv
scraper.save_images_to_pdf
#puts scraper.offer
#puts scraper.all_offers

