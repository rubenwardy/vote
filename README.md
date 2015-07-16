# Vote
A mod for Minetest adding an API to allow voting on servers.

Created by [rubenwardy](http://rubenwardy.com)  
Copyright (c) 2015, no rights reserved
Licensed under WTFPL or CC0 (you choose)

# Settings

* vote.maximum_active - maximum votes running at a time, votes are queued if it
                        reaches this. Defaults to 1.

# Example

```lua
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
```
