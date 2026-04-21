---Tests for qluels.query module
local query = require("qluels.query")

describe("qluels.query", function()
  describe("format_results", function()
    it("formats SPARQL JSON results as a table", function()
      local results = {
        queryResult = {
          result = {
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
          },
        },
      }

      local lines = query.format_results(results)

      -- Should have header, separator, and rows
      assert.is_true(#lines > 0)

      -- Check that it contains the data (in expanded format)
      local all_lines = table.concat(lines, "\n")
      assert.matches("http://example.org/s1", all_lines)
      assert.matches("Object 1", all_lines)

      -- Check that it has a row count
      assert.matches("%(2 rows%)", all_lines)
    end)

    it("handles empty results", function()
      local results = {
        queryResult = {
          result = {
            head = {
              vars = { "subject" },
            },
            results = {
              bindings = {},
            },
          },
        },
      }

      local lines = query.format_results(results)

      assert.is_true(#lines > 0)
      assert.matches("%(0 rows%)", table.concat(lines, "\n"))
    end)

    it("handles results with no variables", function()
      local results = {
        queryResult = {
          result = {
            head = {
              vars = {},
            },
            results = {
              bindings = {},
            },
          },
        },
      }

      local lines = query.format_results(results)

      assert.is_true(#lines > 0)
      assert.matches("No variables", lines[1])
    end)

    it("handles missing bindings gracefully", function()
      local results = {
        queryResult = {
          result = {
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
          },
        },
      }

      local lines = query.format_results(results)

      -- Should not error, just show empty cell
      assert.is_true(#lines > 0)
    end)

    it("handles non-standard result format", function()
      local results = {
        queryResult = {
          result = { some = "unknown format" }
        }
      }

      local lines = query.format_results(results)

      -- Should fall back to inspection
      assert.is_true(#lines > 0)
      assert.matches("Results:", lines[1])
    end)

    it("formats UPDATE results with a single step", function()
      local results = {
        updateResult = {
          {
            status = "OK",
            deltaTriples = {
              before   = { deleted = 1, inserted = 3, total = 4 },
              after    = { deleted = 1, inserted = 3, total = 4 },
              difference = { deleted = 0, inserted = 0, total = 0 },
              operation  = { deleted = 0, inserted = 1, total = 1 },
            },
            time = {
              total = 42,
              planning = 1,
              ["where"] = 5,
              update = { total = 36, preparation = 10, delete = 6, insert = 20 },
            },
          },
        },
      }

      local lines = query.format_results(results)
      local all = table.concat(lines, "\n")

      assert.matches("UPDATE 1", all)
      assert.matches("OK", all)
      assert.matches("operation", all)
      assert.matches("%(1 update step%(s%)%)", all)
      assert.matches("42", all) -- total time
    end)

    it("formats UPDATE results with multiple steps", function()
      local results = {
        updateResult = {
          { status = "OK", deltaTriples = { operation = { deleted = 0, inserted = 1, total = 1 } } },
          { status = "OK", deltaTriples = { operation = { deleted = 1, inserted = 0, total = 1 } } },
        },
      }

      local lines = query.format_results(results)
      local all = table.concat(lines, "\n")

      assert.matches("UPDATE 1", all)
      assert.matches("UPDATE 2", all)
      assert.matches("%(2 update step%(s%)%)", all)
    end)

    it("handles UPDATE results with missing optional fields", function()
      local results = {
        updateResult = {
          { status = "OK" },
        },
      }

      local lines = query.format_results(results)
      local all = table.concat(lines, "\n")

      assert.matches("OK", all)
      assert.matches("%(1 update step%(s%)%)", all)
    end)

    it("prefers updateResult over queryResult when both present", function()
      local results = {
        updateResult = { { status = "OK" } },
        queryResult = {
          result = { head = { vars = { "x" } }, results = { bindings = {} } },
        },
      }

      local lines = query.format_results(results)
      local all = table.concat(lines, "\n")

      assert.matches("UPDATE 1", all)
      assert.not_matches("%(0 rows%)", all)
    end)
  end)

  describe("format_update_results", function()
    it("formats delta triples as aligned columns", function()
      local steps = {
        {
          status = "OK",
          deltaTriples = {
            before     = { deleted = 0, inserted = 0, total = 100 },
            after      = { deleted = 0, inserted = 1, total = 101 },
            difference = { deleted = 0, inserted = 1, total = 1 },
            operation  = { deleted = 0, inserted = 1, total = 1 },
          },
        },
      }

      local lines = query.format_update_results(steps)
      local all = table.concat(lines, "\n")

      assert.matches("Delta Triples", all)
      assert.matches("deleted", all)
      assert.matches("inserted", all)
      assert.matches("total", all)
      assert.matches("operation", all)
      assert.matches("before", all)
      assert.matches("after", all)
      assert.matches("difference", all)
    end)

    it("formats timing breakdown including the where field", function()
      local steps = {
        {
          status = "OK",
          time = {
            total = 100,
            planning = 5,
            ["where"] = 30,
            update = { total = 65, preparation = 10, delete = 20, insert = 35 },
          },
        },
      }

      local lines = query.format_update_results(steps)
      local all = table.concat(lines, "\n")

      assert.matches("Timing %(ms%):", all)
      assert.matches("total%s+100", all)
      assert.matches("planning%s+5", all)
      assert.matches("where%s+30", all)
      assert.matches("prepare%s+10", all)
      assert.matches("delete%s+20", all)
      assert.matches("insert%s+35", all)
    end)

    it("handles step with only timing and no deltaTriples", function()
      local steps = {
        {
          status = "OK",
          time = { total = 50, planning = 2, ["where"] = 10 },
        },
      }

      local lines = query.format_update_results(steps)
      local all = table.concat(lines, "\n")

      assert.matches("OK", all)
      assert.matches("Timing", all)
      assert.not_matches("Delta Triples", all)
    end)

    it("handles step with only deltaTriples and no timing", function()
      local steps = {
        {
          status = "OK",
          deltaTriples = {
            operation = { deleted = 0, inserted = 1, total = 1 },
          },
        },
      }

      local lines = query.format_update_results(steps)
      local all = table.concat(lines, "\n")

      assert.matches("operation", all)
      assert.not_matches("Timing", all)
    end)

    it("returns empty highlights list", function()
      local steps = { { status = "OK" } }
      local _, highlights = query.format_update_results(steps)
      assert.equals(0, #highlights)
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
