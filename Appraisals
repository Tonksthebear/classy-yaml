appraise "rails7" do
  gem "rails", "~> 7.0"
  gem "sprockets-rails"
  gem "view_component", "~> 2.0"
end

appraise "rails8_sprockets" do
  # Assuming rails 8 is not released yet, using a placeholder.
  # You might need to adjust this when Rails 8 is available.
  gem "rails", github: "rails/rails", branch: "main"
  # Ensure sprockets-rails is included if not default in Rails 8
  gem "sprockets-rails"
  gem "view_component", ">= 3.0"
end

appraise "rails8_propshaft" do
  # Assuming rails 8 is not released yet, using a placeholder.
  # You might need to adjust this when Rails 8 is available.
  gem "rails", github: "rails/rails", branch: "main"
  # Ensure propshaft is included
  gem "propshaft"
  gem "view_component", ">= 3.0"
end
