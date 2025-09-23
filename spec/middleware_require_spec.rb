# frozen_string_literal: true

require "verikloak/audience/middleware"
require "spec_helper"

RSpec.describe "Verikloak::Audience::Middleware standalone require" do
  it "loads middleware without requiring the root entrypoint first" do
    app = ->(_env) { [200, {}, ["ok"]] }

    middleware = Verikloak::Audience::Middleware.new(app, required_aud: [])

    expect(middleware).to be_a(Verikloak::Audience::Middleware)
  end
end
