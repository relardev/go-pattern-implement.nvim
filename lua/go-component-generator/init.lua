local Job = require 'plenary.job'
local Path = require 'plenary.path'

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

local function split(str, delimiter)
	local result = {}
	local from = 1
	local delim_from, delim_to = string.find(str, delimiter, from, true)
	while delim_from do
		table.insert(result, string.sub(str, from, delim_from - 1))
		from = delim_to + 1
		delim_from, delim_to = string.find(str, delimiter, from, true)
	end
	table.insert(result, string.sub(str, from))
	return result
end

local function selectImplementation(args)
	-- use telescope if available, or fallback to vim.ui.select
	local ok, _ = pcall(require, 'telescope')
	if ok then
		local items = {}
		for _, line in ipairs(args.values) do
			local split = split(line, " - ")
			table.insert(items, { name = line, value = split[1] })
		end
		local pickers = require('telescope.pickers')
		local finders = require('telescope.finders')
		local previewers = require('telescope.previewers')
		local conf = require('telescope.config').values
		local actions = require('telescope.actions')
		local action_state = require('telescope.actions.state')

		local previewer = function(opts)
			return previewers.new_buffer_previewer({
				get_buffer_by_name = function(_, entry)
					-- This function can be used to create a unique buffer name
					return entry.value
				end,

				define_preview = function(self, entry)
					-- Define how to fill the buffer with the command's output
					local tmpfile = Path:new('/tmp/telescope_preview_component_generator')
					tmpfile:write(args.text, 'w')

					local cmd = string.format("go-component-generator implement %s --package=%s < %s",
						entry.value,
						args.packageName,
						tmpfile
					)

					-- Use plenary.job to run the command and capture its output
					Job:new({
						command = "bash",
						args = { "-c", cmd },
						on_exit = function(j)
							local result = table.concat(j:result(), "\n")
							-- Use vim.schedule to interact with the Neovim API safely from an async context
							vim.schedule(function()
								-- Ensure the buffer is valid and hasn't been deleted
								if not vim.api.nvim_buf_is_valid(self.state.bufnr) then return end
								-- Set buffer content
								vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, vim.split(result, '\n'))
								-- Set filetype for syntax highlighting
								vim.api.nvim_buf_set_option(self.state.bufnr, 'filetype', 'go')
							end)
						end,
					}):start()
				end
			})
		end

		local on_item_selected = function(entry)
			sendTextToExternalCommand(entry.value, args.packageName, args.text, args.end_line)
		end

		pickers.new({}, {
			prompt_title = "Select implementaion",
			finder = finders.new_table({
				results = items,
				entry_maker = function(entry)
					return {
						value = entry.value,
						display = entry.name,
						ordinal = entry.name,
					}
				end
			}),
			sorter = conf.generic_sorter({}),
			previewer = previewer({}),
			attach_mappings = function(prompt_bufnr, _)
				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry()
					actions.close(prompt_bufnr)
					-- Call your custom function on selection
					on_item_selected(selection)
				end)
				return true
			end
		}):find()
	else
		vim.ui.select(args.values, { prompt = 'Select implementaion' }, function(implementation)
			if implementation then
				local split = split(implementation, " - ")
				implementation = split[1]
				print("Selected:", implementation)
				sendTextToExternalCommand(implementation, args.packageName, args.text, args.end_line)
			else
				print("No choice made.")
			end
		end)
	end
end


local function askForPossibleImplementations(args)
	Job:new({
		command = "go-component-generator",
		args = { "list", "--available" },
		writer = args.text, -- Sends `text` as stdin to the command
		on_exit = function(j, return_val)
			-- Process output or handle errors
			local result = j:result()

			vim.schedule(function()
				if return_val == 0 and result ~= "" then
					args.values = result
					selectImplementation(args)
				else
					-- Handle error output
					local err = table.concat(j:stderr_result(), "\n")
					print("Command error:", err)
				end
			end)
		end,
	}):start()
end


M.implement = function(opts)
	local start_line = opts.line1 or vim.api.nvim_win_get_cursor(0)[1]
	local end_line = opts.line2 or vim.api.nvim_win_get_cursor(0)[1]
	local text = getTextFromRange(start_line, end_line)
	local packageName = getGoPackageName()
	local args = {}
	args.packageName = packageName
	args.text = text
	args.end_line = end_line

	askForPossibleImplementations(args)
end


return M
