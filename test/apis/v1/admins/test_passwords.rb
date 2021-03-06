require_relative "../../../test_helper"

class Test::Apis::V1::Admins::TestPasswords < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_ignores_passwords_on_create
    attributes = FactoryGirl.build(:admin).serializable_hash.deep_merge({
      "encrypted_password" => BCrypt::Password.create("password234567"),
      "password" => "password234567",
      "password_confirmation" => "password234567",
    })
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/admins.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :admin => attributes },
    }))
    assert_response_code(201, response)

    data = MultiJson.load(response.body)
    admin = Admin.find(data["admin"]["id"])
    assert_nil(admin.encrypted_password)
  end

  def test_ignores_passwords_when_updating_another_admin
    other_admin = FactoryGirl.create(:admin)
    original_encrypted_password = other_admin.encrypted_password

    attributes = FactoryGirl.build(:admin).serializable_hash.deep_merge({
      "encrypted_password" => BCrypt::Password.create("password234567"),
      "password" => "password234567",
      "password_confirmation" => "password234567",
    })
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admins/#{other_admin.id}.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :admin => attributes },
    }))
    assert_response_code(200, response)

    other_admin.reload
    assert_equal(original_encrypted_password, other_admin.encrypted_password)
  end

  def test_accepts_password_change_when_updating_own_admin
    admin = FactoryGirl.create(:admin)
    original_encrypted_password = admin.encrypted_password

    attributes = admin.serializable_hash.deep_merge({
      "encrypted_password" => BCrypt::Password.create("ignored"),
      "current_password" => "password123456",
      "password" => "password234567",
      "password_confirmation" => "password234567",
    })
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admins/#{admin.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :admin => attributes },
    }))
    assert_response_code(200, response)

    admin.reload
    refute_equal(original_encrypted_password, admin.encrypted_password)
  end

  def test_rejects_password_change_when_current_password_missing
    admin = FactoryGirl.create(:admin)
    original_encrypted_password = admin.encrypted_password

    attributes = admin.serializable_hash.deep_merge({
      "password" => "password234567",
      "password_confirmation" => "password234567",
    })
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admins/#{admin.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :admin => attributes },
    }))
    assert_response_code(422, response)
    data = MultiJson.load(response.body)
    assert_equal([
      "Current Password: can't be blank",
    ].sort, data["errors"].map { |e| e["full_message"] }.sort)

    admin.reload
    assert_equal(original_encrypted_password, admin.encrypted_password)
  end

  def test_rejects_password_change_when_current_password_empty
    admin = FactoryGirl.create(:admin)
    original_encrypted_password = admin.encrypted_password

    attributes = admin.serializable_hash.deep_merge({
      "current_password" => "",
      "password" => "password234567",
      "password_confirmation" => "password234567",
    })
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admins/#{admin.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :admin => attributes },
    }))
    assert_response_code(422, response)
    data = MultiJson.load(response.body)
    assert_equal([
      "Current Password: can't be blank",
    ].sort, data["errors"].map { |e| e["full_message"] }.sort)

    admin.reload
    assert_equal(original_encrypted_password, admin.encrypted_password)
  end

  def test_rejects_password_change_when_current_password_invalid
    admin = FactoryGirl.create(:admin)
    original_encrypted_password = admin.encrypted_password

    attributes = admin.serializable_hash.deep_merge({
      "current_password" => "password234567",
      "password" => "password234567",
      "password_confirmation" => "password234567",
    })
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admins/#{admin.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :admin => attributes },
    }))
    assert_response_code(422, response)
    data = MultiJson.load(response.body)
    assert_equal([
      "Current Password: is invalid",
    ].sort, data["errors"].map { |e| e["full_message"] }.sort)

    admin.reload
    assert_equal(original_encrypted_password, admin.encrypted_password)
  end

  def test_requires_confirmation_if_password_present
    admin = FactoryGirl.create(:admin)
    original_encrypted_password = admin.encrypted_password

    attributes = admin.serializable_hash.deep_merge({
      "current_password" => "password123456",
      "password" => "password234567",
    })
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admins/#{admin.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :admin => attributes },
    }))
    assert_response_code(422, response)
    data = MultiJson.load(response.body)
    assert_equal([
      "Password Confirmation: can't be blank",
    ].sort, data["errors"].map { |e| e["full_message"] }.sort)

    admin.reload
    assert_equal(original_encrypted_password, admin.encrypted_password)
  end

  def test_requires_password_if_confirmation_present
    admin = FactoryGirl.create(:admin)
    original_encrypted_password = admin.encrypted_password

    attributes = admin.serializable_hash.deep_merge({
      "current_password" => "password123456",
      "password_confirmation" => "password234567",
    })
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admins/#{admin.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :admin => attributes },
    }))
    assert_response_code(422, response)
    data = MultiJson.load(response.body)
    assert_equal([
      "Password: can't be blank",
      "Password Confirmation: doesn't match Password",
    ].sort, data["errors"].map { |e| e["full_message"] }.sort)

    admin.reload
    assert_equal(original_encrypted_password, admin.encrypted_password)
  end

  def test_validates_password_length
    admin = FactoryGirl.create(:admin)
    original_encrypted_password = admin.encrypted_password

    attributes = admin.serializable_hash.deep_merge({
      "current_password" => "password123456",
      "password" => "short",
      "password_confirmation" => "short",
    })
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admins/#{admin.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :admin => attributes },
    }))
    assert_response_code(422, response)
    data = MultiJson.load(response.body)
    assert_equal([
      "Password: is too short (minimum is 14 characters)",
    ].sort, data["errors"].map { |e| e["full_message"] }.sort)

    admin.reload
    assert_equal(original_encrypted_password, admin.encrypted_password)
  end

  def test_validates_password_confirmation_matches
    admin = FactoryGirl.create(:admin)
    original_encrypted_password = admin.encrypted_password

    attributes = admin.serializable_hash.deep_merge({
      "current_password" => "password123456",
      "password" => "mismatch123456",
      "password_confirmation" => "mismatcH123456",
    })
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/admins/#{admin.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :admin => attributes },
    }))
    assert_response_code(422, response)
    data = MultiJson.load(response.body)
    assert_equal([
      "Password Confirmation: doesn't match Password",
    ].sort, data["errors"].map { |e| e["full_message"] }.sort)

    admin.reload
    assert_equal(original_encrypted_password, admin.encrypted_password)
  end
end
