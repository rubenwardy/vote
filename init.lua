vote = {
	active = {},
	queue = {}
}

function vote.new_vote(creator, voteset)
	local max_votes = tonumber(minetest.setting_get("vote_maximum_active")) or 1

	if #vote.active < max_votes then
		vote.start_vote(voteset)
	else
		table.insert(vote.queue, voteset)
		if creator then
			minetest.chat_send_player(creator,
					"Vote queued until there is less then " .. max_votes ..
					" votes active.")
		end
	end
end

function vote.start_vote(voteset)
	minetest.log("action", "Vote started: " .. voteset.description)

	table.insert(vote.active, voteset)

	-- Build results table
	voteset.results = {
		abstain = {},
		voted = {}
	}
	if voteset.options then
		for _, option in pairs(voteset.options) do
			voteset.results[option] = {}
			print(" - " .. option)
		end
	else
		voteset.results.yes = {}
		voteset.results.no = {}
	end

	-- Run start callback
	if voteset.on_start then
		voteset:on_start()
	end

	-- Timer for end
	if voteset.time then
		minetest.after(voteset.time + 0.1, function()
			vote.end_vote(voteset)
		end)
	end

	-- Send notification to players
	local players = minetest.get_connected_players()
	for _, player in pairs(players) do
		local name = player:get_player_name()
		if not voteset.can_vote or
				voteset:can_vote(name) then
			local nextvote = vote.get_next_vote(name)
			if nextvote == voteset then
				minetest.chat_send_player(name,
						"Vote started: " .. voteset.description)
				if voteset.help then
					minetest.chat_send_player(name,  voteset.help)
				end
			else
				minetest.chat_send_player(name,
						"A new vote started, please respond to this one first:")
				minetest.chat_send_player(name,
						"Next vote: " .. nextvote.description)
				if nextvote.help then
					minetest.chat_send_player(name,  nextvote.help)
				end
			end
		end
	end
end

function vote.end_vote(voteset)
	local removed = false
	for i, voteset2 in pairs(vote.active) do
		if voteset == voteset2 then
			table.remove(vote.active, i, 1)
			removed = true
		end
	end
	if not removed then
		return
	end


	local result = nil
	if voteset.on_decide then
		result = voteset:on_decide(voteset.results)
	elseif voteset.results.yes and voteset.results.no then
		local total = #voteset.results.yes + #voteset.results.no

		if #voteset.results.yes / total > 0.8 then
			result = "yes"
		else
			result = "no"
		end
	end

	minetest.log("action", "Vote '" .. voteset.description ..
			"' ended with result '" .. result .. "'.")

	if voteset.on_result then
		voteset:on_result(result, voteset.results)
	end

	local max_votes = tonumber(minetest.setting_get("vote_maximum_active")) or 1
	if #vote.active < max_votes and #vote.queue > 0 then
		local nextvote = table.remove(vote.queue, 1)
		vote.start_vote(nextvote)
	end
end

function vote.get_next_vote(name)
	for _, voteset in pairs(vote.active) do
		if not voteset.results.voted[name] then
			return voteset
		end
	end
	return nil
end

function vote.check_vote(voteset)
	local all_players_voted = true
	local players = minetest.get_connected_players()
	for _, player in pairs(players) do
		local name = player:get_player_name()
		if not voteset.results.voted[name] then
			all_players_voted = false
			break
		end
	end

	if all_players_voted then
		vote.end_vote(voteset)
	end
end

function vote.vote(voteset, name, value)
	if not voteset.results[value] then
		return
	end

	minetest.log("action", name .. " voted '" .. value .. "' to '"
			.. voteset.description .. "'")

	table.insert(voteset.results[value], name)
	voteset.results.voted[name] = true
	if voteset.on_vote then
		voteset:on_vote(name, value)
	end
	vote.check_vote(voteset)

	local nextvote = vote.get_next_vote(name)
	if nextvote then
		minetest.chat_send_player(name, "Next vote: " .. nextvote.description)
		if nextvote.help then
			minetest.chat_send_player(name,  nextvote.help)
		end
	end
end

minetest.register_chatcommand("yes", {
	privs = {
		interact = true
	},
	func = function(name, params)
		local voteset = vote.get_next_vote(name)
		if not voteset then
			minetest.chat_send_player(name,
					"There is no vote currently running!")
			return
		elseif not voteset.results.yes then
			minetest.chat_send_player(name, "The vote is not a yes/no one.")
			return
		elseif voteset.can_vote and not voteset:can_vote(name) then
			minetest.chat_send_player(name,
					"You can't vote in the currently active vote!")
			return
		end

		vote.vote(voteset, name, "yes")
	end
})

minetest.register_chatcommand("no", {
	privs = {
		interact = true
	},
	func = function(name, params)
		local voteset = vote.get_next_vote(name)
		if not voteset then
			minetest.chat_send_player(name,
					"There is no vote currently running!")
			return
		elseif not voteset.results.no then
			minetest.chat_send_player(name, "The vote is not a yes/no one.")
			return
		elseif voteset.can_vote and not voteset:can_vote(name) then
			minetest.chat_send_player(name,
					"You can't vote in the currently active vote!")
			return
		end

		vote.vote(voteset, name, "no")
	end
})

minetest.register_chatcommand("abstain", {
	privs = {
		interact = true
	},
	func = function(name, params)
		local voteset = vote.get_next_vote(name)
		if not voteset then
			minetest.chat_send_player(name,
					"There is no vote currently running!")
			return
		elseif voteset.can_vote and not voteset:can_vote(name) then
			minetest.chat_send_player(name,
					"You can't vote in the currently active vote!")
			return
		end

		table.insert(voteset.results.abstain, name)
		voteset.results.voted[name] = true
		if voteset.on_abstain then
			voteset:on_abstain(name)
		end
		vote.check_vote(voteset)
	end
})

minetest.register_chatcommand("vote_kick", {
	privs = {
		interact = true
	},
	func = function(name, param)
		if not minetest.get_player_by_name(param) then
			minetest.chat_send_player(name, "There is no player called '" ..
					param .. "'")
		end

		vote.new_vote(name, {
			description = "Kick player " .. param,
			help = "/yes,  /no  or  /abstain",
			name = param,
			time = 60,

			can_vote = function(self, name)
				-- eg:  return (self.name ~= name)
				return true
			end,

			on_result = function(self, result, results)
				if result == "yes" then
					minetest.chat_send_all("Vote passed, " ..
							#results.yes .. " to " .. #results.no .. ", " ..
							self.name .. " will be kicked.")
					minetest.kick_player(self.name, "The vote to kick you passed")
				else
					minetest.chat_send_all("Vote failed, " ..
							#results.yes .. " to " .. #results.no .. ", " ..
							self.name .. " remains ingame.")
				end
			end,

			on_vote = function(self, name, vote)
				minetest.chat_send_all(name .. " voted " .. vote .. " to '" ..
						self.description .. "'")
			end
		})
	end
})
