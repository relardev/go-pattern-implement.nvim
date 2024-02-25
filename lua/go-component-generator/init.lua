local Job = require 'plenary.job'

local M = {}

function M.setup()
	vim.api.nvim_create_user_command(
		"GoImplement",
		function(opts)
			M.implement(opts)
		end,
		{ range = true }
	)
end

local function getTextFromRange(start_line, end_line)
	-- Neovim API indexes lines starting from 0, but user input is 1-indexed
	local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
	return table.concat(lines, "\n")
end

local function sendTextToExternalCommand(implementation, package, text, end_line)
	Job:new({
		command = "go-component-generator",
		args = { "implement", implementation, "--package=" .. package },
		writer = text, -- Sends `text` as stdin to the command
		on_exit = function(j, return_val)
			-- Process output or handle errors
			local result = j:result()

			vim.schedule(function()
				if return_val == 0 and result ~= "" then
					-- Adjust end_line + 1 to end_line + 0 or another value as needed
					local gnerated = { "" }
					for i = 1, #result do
						table.insert(gnerated, result[i])
					end
					vim.api.nvim_buf_set_lines(0, end_line, end_line, false, gnerated)
				else
					-- Handle error output
					local err = table.concat(j:stderr_result(), "\n")
					print("Command error:", err)
				end
			end)
		end,
	}):start()
end

local function getGoPackageName()
	-- Get the current buffer
	local bufnr = vim.api.nvim_get_current_buf()

	-- Get all lines in the current buffer
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	-- Iterate through each line to find the package declaration
	for _, line in ipairs(lines) do
		-- Check if the line starts with the package keyword
		if line:match("^package%s+") then
			-- Extract the package name and return it
			return line:match("^package%s+(%S+)")
		end
	end

	-- Return nil if no package declaration was found
	return nil
end


M.implement = function(opts)
	local start_line = opts.line1 or vim.api.nvim_win_get_cursor(0)[1]
	local end_line = opts.line2 or vim.api.nvim_win_get_cursor(0)[1]
	local text = getTextFromRange(start_line, end_line)
	local packageName = getGoPackageName()

	local values = {
		"prometheus",
	}

	vim.ui.select(values, { prompt = 'Select implementaion' }, function(implementation)
		if implementation then
			-- Use the choice by calling another function
			sendTextToExternalCommand(implementation, packageName, text, end_line)
		else
			print("No choice made.")
		end
	end)
end


return M
