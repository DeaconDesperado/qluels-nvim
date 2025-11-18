---Tests for qluels.query module
local query = require("qluels.query")

describe("qluels.query", function()
  describe("format_results", function()
    it("formats SPARQL JSON results as a table", function()
      local results = {
        head = {
          vars = { "subject", "predicate", "object" },
        },
        results = {
          bindings = {
            {
              subject = { value = "http://example.org/s1" },
              predicate = { value = "http://example.org/p1" },
              object = { value = "Object 1" },
            },
            {
              subject = { value = "http://example.org/s2" },
              predicate = { value = "http://example.org/p2" },
              object = { value = "Object 2" },
            },
          },
        },
      }

      local lines = query.format_results(results)

      -- Should have header, separator, and rows
      assert.is_true(#lines > 0)

      -- Check that it contains the variables
      assert.matches("subject", lines[1])
      assert.matches("predicate", lines[1])
      assert.matches("object", lines[1])

      -- Check that it contains the data
      local all_lines = table.concat(lines, "\n")
      assert.matches("http://example.org/s1", all_lines)
      assert.matches("Object 1", all_lines)

      -- Check that it has a row count
      assert.matches("%(2 rows%)", all_lines)
    end)

    it("handles empty results", function()
      local results = {
        head = {
          vars = { "subject" },
        },
        results = {
          bindings = {},
        },
      }

      local lines = query.format_results(results)

      assert.is_true(#lines > 0)
      assert.matches("%(0 rows%)", table.concat(lines, "\n"))
    end)

    it("handles results with no variables", function()
      local results = {
        head = {
          vars = {},
        },
        results = {
          bindings = {},
        },
      }

      local lines = query.format_results(results)

      assert.is_true(#lines > 0)
      assert.matches("No variables", lines[1])
    end)

    it("handles missing bindings gracefully", function()
      local results = {
        head = {
          vars = { "subject", "object" },
        },
        results = {
          bindings = {
            {
              subject = { value = "http://example.org/s1" },
              -- object is missing
            },
          },
        },
      }

      local lines = query.format_results(results)

      -- Should not error, just show empty cell
      assert.is_true(#lines > 0)
    end)

    it("handles non-standard result format", function()
      local results = { some = "unknown format" }

      local lines = query.format_results(results)

      -- Should fall back to inspection
      assert.is_true(#lines > 0)
      assert.matches("Results:", lines[1])
    end)
  end)

  describe("buffer management", function()
    it("creates a result buffer", function()
      local bufnr, winnr = query.create_result_buffer()

      assert.is_not_nil(bufnr)
      assert.is_not_nil(winnr)
      assert.is_true(vim.api.nvim_buf_is_valid(bufnr))
      assert.is_true(vim.api.nvim_win_is_valid(winnr))

      -- Clean up
      vim.api.nvim_win_close(winnr, true)
    end)

    it("reuses existing result buffer", function()
      local bufnr1, winnr1 = query.create_result_buffer()
      local bufnr2, winnr2 = query.create_result_buffer()

      -- Should reuse the same buffer
      assert.equals(bufnr1, bufnr2)
      assert.equals(winnr1, winnr2)

      -- Clean up
      vim.api.nvim_win_close(winnr1, true)
    end)
  end)
end)
