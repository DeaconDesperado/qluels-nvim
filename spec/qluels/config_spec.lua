---Tests for qluels.config module
local config = require("qluels.config")

describe("qluels.config", function()
  before_each(function()
    -- Reset config to defaults before each test
    config.current = vim.deepcopy(config.defaults)
  end)

  describe("validate_backend", function()
    it("validates a valid backend", function()
      local backend = {
        service = {
          name = "wikidata",
          url = "https://query.wikidata.org/sparql",
        },
        default = true,
      }

      local valid, err = config.validate_backend("wikidata", backend)
      assert.is_true(valid)
      assert.is_nil(err)
    end)

    it("rejects backend with missing service", function()
      local backend = {
        default = true,
      }

      local valid, err = config.validate_backend("test", backend)
      assert.is_false(valid)
      assert.is_not_nil(err)
      assert.matches("service must be a table", err)
    end)

    it("rejects backend with missing service.name", function()
      local backend = {
        service = {
          url = "http://example.com/sparql",
        },
      }

      local valid, err = config.validate_backend("test", backend)
      assert.is_false(valid)
      assert.is_not_nil(err)
      assert.matches("service.name", err)
    end)

    it("rejects backend with invalid requestMethod", function()
      local backend = {
        service = {
          name = "test",
          url = "http://example.com/sparql",
        },
        requestMethod = "PUT",
      }

      local valid, err = config.validate_backend("test", backend)
      assert.is_false(valid)
      assert.matches("requestMethod", err)
    end)

    it("accepts GET requestMethod", function()
      local backend = {
        service = {
          name = "test",
          url = "http://example.com/sparql",
        },
        requestMethod = "GET",
      }

      local valid, err = config.validate_backend("test", backend)
      assert.is_true(valid)
      assert.is_nil(err)
    end)

    it("accepts POST requestMethod", function()
      local backend = {
        service = {
          name = "test",
          url = "http://example.com/sparql",
        },
        requestMethod = "POST",
      }

      local valid, err = config.validate_backend("test", backend)
      assert.is_true(valid)
      assert.is_nil(err)
    end)
  end)

  describe("validate", function()
    it("validates a valid configuration", function()
      local cfg = {
        backends = {
          wikidata = {
            service = {
              name = "wikidata",
              url = "https://query.wikidata.org/sparql",
            },
            default = true,
          },
        },
        auto_attach = true,
      }

      local valid, err = config.validate(cfg)
      assert.is_true(valid)
      assert.is_nil(err)
    end)

    it("rejects invalid result_buffer.position", function()
      local cfg = {
        result_buffer = {
          position = "center",
        },
      }

      local valid, err = config.validate(cfg)
      assert.is_false(valid)
      assert.matches("result_buffer.position", err)
    end)

    it("accepts valid result_buffer.position values", function()
      for _, pos in ipairs({ "right", "left", "above", "below" }) do
        local cfg = {
          result_buffer = {
            position = pos,
          },
        }

        local valid, err = config.validate(cfg)
        assert.is_true(valid, "position '" .. pos .. "' should be valid")
        assert.is_nil(err)
      end
    end)
  end)

  describe("setup", function()
    it("merges user config with defaults", function()
      local user_config = {
        backends = {
          test = {
            service = {
              name = "test",
              url = "http://localhost/sparql",
            },
          },
        },
      }

      local success, err = config.setup(user_config)
      assert.is_true(success)
      assert.is_nil(err)

      -- Check that defaults are preserved
      assert.is_true(config.current.auto_attach)

      -- Check that user config is applied
      assert.is_not_nil(config.current.backends.test)
      assert.equals("test", config.current.backends.test.service.name)
    end)

    it("rejects invalid configuration", function()
      local invalid_config = {
        auto_attach = "yes", -- should be boolean
      }

      local success, err = config.setup(invalid_config)
      assert.is_false(success)
      assert.is_not_nil(err)
    end)
  end)
end)
