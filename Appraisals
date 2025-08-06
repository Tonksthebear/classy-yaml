appraise "rails7" do
  gem "rails", "~> 7.0"
  gem "sprockets-rails"
  gem "view_component", "~> 2.0"
end

appraise "rails8_sprockets" do
  gem "rails", "~> 8.0"
  # Ensure sprockets-rails is included if not default in Rails 8
  gem "sprockets-rails"
  gem "view_component", ">= 3.0"
end

appraise "rails8_propshaft" do
  gem "rails", "~> 8.0"
  # Ensure propshaft is included
  gem "propshaft"
  gem "view_component", ">= 3.0"
end
