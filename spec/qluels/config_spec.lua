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
        name = "wikidata",
        url = "https://query.wikidata.org/sparql",
        default = true,
      }

      local valid, err = config.validate_backend("wikidata", backend)
      assert.is_true(valid)
      assert.is_nil(err)
    end)

    it("rejects backend with missing name", function()
      local backend = {
        url = "http://example.com/sparql",
        default = true,
      }

      local valid, err = config.validate_backend("test", backend)
      assert.is_false(valid)
      assert.is_not_nil(err)
      assert.matches("name", err)
    end)

    it("rejects backend with missing url", function()
      local backend = {
        name = "test",
      }

      local valid, err = config.validate_backend("test", backend)
      assert.is_false(valid)
      assert.is_not_nil(err)
      assert.matches("url", err)
    end)

    it("rejects backend with invalid requestMethod", function()
      local backend = {
        name = "test",
        url = "http://example.com/sparql",
        requestMethod = "PUT",
      }

      local valid, err = config.validate_backend("test", backend)
      assert.is_false(valid)
      assert.matches("requestMethod", err)
    end)

    it("accepts GET requestMethod", function()
      local backend = {
        name = "test",
        url = "http://example.com/sparql",
        requestMethod = "GET",
      }

      local valid, err = config.validate_backend("test", backend)
      assert.is_true(valid)
      assert.is_nil(err)
    end)

    it("accepts POST requestMethod", function()
      local backend = {
        name = "test",
        url = "http://example.com/sparql",
        requestMethod = "POST",
      }

      local valid, err = config.validate_backend("test", backend)
      assert.is_true(valid)
      assert.is_nil(err)
    end)

    it("accepts engine field", function()
      local backend = {
        name = "test",
        url = "http://example.com/sparql",
        engine = "QLever",
      }

      local valid, err = config.validate_backend("test", backend)
      assert.is_true(valid)
      assert.is_nil(err)
    end)

    it("accepts healthCheckUrl field", function()
      local backend = {
        name = "test",
        url = "http://example.com/sparql",
        healthCheckUrl = "http://example.com/health",
      }

      local valid, err = config.validate_backend("test", backend)
      assert.is_true(valid)
      assert.is_nil(err)
    end)

    it("accepts additionalData field", function()
      local backend = {
        name = "test",
        url = "http://example.com/sparql",
        additionalData = { foo = "bar" },
      }

      local valid, err = config.validate_backend("test", backend)
      assert.is_true(valid)
      assert.is_nil(err)
    end)

    it("rejects invalid additionalData", function()
      local backend = {
        name = "test",
        url = "http://example.com/sparql",
        additionalData = "not a table",
      }

      local valid, err = config.validate_backend("test", backend)
      assert.is_false(valid)
      assert.matches("additionalData", err)
    end)
  end)

  describe("validate", function()
    it("validates a valid configuration", function()
      local cfg = {
        backends = {
          wikidata = {
            name = "wikidata",
            url = "https://query.wikidata.org/sparql",
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

    it("accepts on_type_formatting option", function()
      local cfg = {
        on_type_formatting = true,
      }

      local valid, err = config.validate(cfg)
      assert.is_true(valid)
      assert.is_nil(err)
    end)

    it("rejects invalid on_type_formatting", function()
      local cfg = {
        on_type_formatting = "yes",
      }

      local valid, err = config.validate(cfg)
      assert.is_false(valid)
      assert.matches("on_type_formatting", err)
    end)

    it("accepts semantic_highlighting = true", function()
      local cfg = {
        semantic_highlighting = true,
      }

      local valid, err = config.validate(cfg)
      assert.is_true(valid)
      assert.is_nil(err)
    end)

    it("accepts semantic_highlighting = false", function()
      local cfg = {
        semantic_highlighting = false,
      }

      local valid, err = config.validate(cfg)
      assert.is_true(valid)
      assert.is_nil(err)
    end)

    it("rejects invalid semantic_highlighting", function()
      local cfg = {
        semantic_highlighting = "yes",
      }

      local valid, err = config.validate(cfg)
      assert.is_false(valid)
      assert.matches("semantic_highlighting", err)
    end)

    it("accepts settings option", function()
      local cfg = {
        settings = {
          format = { keep_empty_lines = true },
        },
      }

      local valid, err = config.validate(cfg)
      assert.is_true(valid)
      assert.is_nil(err)
    end)

    it("rejects invalid settings", function()
      local cfg = {
        settings = "not a table",
      }

      local valid, err = config.validate(cfg)
      assert.is_false(valid)
      assert.matches("settings", err)
    end)
  end)

  describe("setup", function()
    it("merges user config with defaults", function()
      local user_config = {
        backends = {
          test = {
            name = "test",
            url = "http://localhost/sparql",
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
      assert.equals("test", config.current.backends.test.name)
    end)

    it("rejects invalid configuration", function()
      local invalid_config = {
        auto_attach = "yes", -- should be boolean
      }

      local success, err = config.setup(invalid_config)
      assert.is_false(success)
      assert.is_not_nil(err)
    end)

    it("defaults semantic_highlighting to true", function()
      local success = config.setup({})
      assert.is_true(success)
      assert.is_true(config.current.semantic_highlighting)
    end)

    it("allows disabling semantic_highlighting", function()
      local success = config.setup({ semantic_highlighting = false })
      assert.is_true(success)
      assert.is_false(config.current.semantic_highlighting)
    end)
  end)
end)
