require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "root renders the Home Inertia page" do
    get root_path

    assert_response :success
    assert_includes response.body, "data-page"
    assert_includes response.body, "Home"
  end
end
