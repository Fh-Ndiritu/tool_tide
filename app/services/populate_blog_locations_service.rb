class PopulateBlogLocationsService
  DATA = [
    # Australia
    {
      country: "Australia",
      region_category: "Australia (Peak Summer)",
      focus: "Heat management, mulching, and irrigation systems.",
      entries: [
        { state: "Queensland", city: "Brisbane", major_counties: "South East Queensland, Gold Coast, Sunshine Coast" },
        { state: "New South Wales", city: "Sydney", major_counties: "Greater Western Sydney, Illawarra, Hunter Valley" },
        { state: "Victoria", city: "Melbourne", major_counties: "Mornington Peninsula, Yarra Valley, Geelong" },
        { state: "Western Australia", city: "Perth", major_counties: "Swan Valley, Joondalup, Fremantle" },
        { state: "South Australia", city: "Adelaide", major_counties: "Barossa Valley, Fleurieu Peninsula" },
        { state: "Australian Capital Territory", city: "Canberra", major_counties: "North Canberra, South Canberra" }
      ]
    },
    # New Zealand
    {
      country: "New Zealand",
      region_category: "New Zealand (Peak Summer)",
      focus: "Fruit harvesting (stone fruit/berries) and lawn protection.",
      entries: [
        { state: "Auckland", city: "Auckland", major_counties: "North Shore, Waitakere, Manukau" }, # Region = State for consistency
        { state: "Canterbury", city: "Christchurch", major_counties: "Selwyn, Waimakariri, Banks Peninsula" },
        { state: "Wellington", city: "Wellington", major_counties: "Hutt Valley, Porirua, Kapiti Coast" },
        { state: "Waikato", city: "Hamilton", major_counties: "Waipa, Matamata-Piako" },
        { state: "Hawke's Bay", city: "Napier / Hastings", major_counties: "Central Hawke's Bay" },
        { state: "Otago", city: "Dunedin", major_counties: "Queenstown-Lakes, Central Otago" }
      ]
    },
    # United States
    {
      country: "United States",
      region_category: "United States (Year-Round & Warm Winter)",
      focus: "Winter gardening, tropical landscaping, and early spring seeding.",
      entries: [
        { state: "Florida", city: "Miami", major_counties: "Miami-Dade, Broward, Palm Beach" },
        { state: "Florida", city: "Tampa", major_counties: "Hillsborough, Pinellas, Pasco" },
        { state: "California", city: "San Diego", major_counties: "San Diego County" },
        { state: "California", city: "Los Angeles", major_counties: "Los Angeles County, Orange County" },
        { state: "Arizona", city: "Phoenix", major_counties: "Maricopa, Pinal" },
        { state: "Texas", city: "Austin", major_counties: "Travis, Hays, Williamson" },
        { state: "Texas", city: "San Antonio", major_counties: "Bexar, Comal" },
        { state: "Hawaii", city: "Honolulu", major_counties: "Honolulu County (Oahu)" },
        { state: "Georgia", city: "Atlanta", major_counties: "Fulton, Gwinnett, Cobb (Mild Winter/Prep)" }
      ]
    },
    # Europe
    {
      region_category: "Europe (Mild Winter / Mediterranean Climate)", # Country varies
      focus: "Hardscaping, pruning, and soil preparation for early spring.",
      entries: [
        { country: "Spain", city: "Málaga", major_counties: "Costa del Sol, Andalusia" },
        { country: "Spain", city: "Valencia", major_counties: "Valencian Community" },
        { country: "Spain", city: "Tenerife", major_counties: "Canary Islands" },
        { country: "Portugal", city: "Faro", major_counties: "Algarve" },
        { country: "Portugal", city: "Funchal", major_counties: "Madeira" },
        { country: "Greece", city: "Athens", major_counties: "Attica" },
        { country: "Italy", city: "Palermo", major_counties: "Sicily" },
        { country: "Malta", city: "Valletta", major_counties: "(Entire Island Nation)" },
        { country: "Cyprus", city: "Paphos", major_counties: "Paphos District" }
      ]
    }
  ]

  def self.call
    DATA.each do |group|
      group[:entries].each do |entry|
        country = entry[:country] || group[:country]
        state = entry[:state]

        # Use simple finding by country and city to update if exists
        location = BlogLocation.find_or_initialize_by(
          country: country,
          city: entry[:city]
        )

        location.region_category = group[:region_category]
        location.state = state
        location.major_counties = entry[:major_counties]

        location.save!
      end
    end
    puts "Successfully populated Blog Locations."
  end
end
