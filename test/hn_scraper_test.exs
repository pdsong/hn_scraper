defmodule HnScraperTest do
  use ExUnit.Case
  doctest HnScraper

  test "greets the world" do
    assert HnScraper.hello() == :world
  end
end
