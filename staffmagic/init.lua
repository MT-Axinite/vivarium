minetest.register_privilege("staffer","Trust players to use staves")

staffmagic = {}

staffmagic.forbidden_nodes = {
	"default:stone_with",
	"moreores:mineral_",
	"default:nyancat",
	"steel_bottle",
	".+steelblock", -- lua does not include the "|" operator which is a PAIN.
	".+copperblock",
	"copperpatina",
	".+bronzeblock",
	".+goldblock",
	".+diamondblock",
	".+tin_block",
	".+silver_block",
	".+mithril_block",
	"default:mese",
	"protector:",
	"basic_machines:",
	"ethereal:crystal_spike",
	".+crystal_block",
	"mobs:beehive",
	"mobs:spawner",
	"more_chests:",
	"fire:basic_flame",
	"fire:permanent_fire",
}

function staffmagic:tellem(player,message)
	minetest.chat_send_player(player:get_player_name() , message)
end

function staffmagic:wearitem(itemstack,maxuses)
	itemstack:add_wear(math.ceil(65536/maxuses))
	return itemstack
end

function staffmagic:staffcheck(player)
	local stafflevel = 0
	if minetest.check_player_privs(player:get_player_name(), {staffer=true}) then stafflevel = 1; end
	if minetest.check_player_privs(player:get_player_name(), {creative=true}) then stafflevel = 100; end
	--minetest.chat_send_all("Staff level : "..stafflevel)
	return stafflevel
end

function staffmagic:staffmagic:isforbidden(nodename)
	for _,pat in pairs(staffmagic.forbidden_nodes) do
		if string.match(nodename,pat) then
			--minetest.chat_send_all("Forbidden : "..nodename)
			return true
		end
	end
	return false
end

function staffmagic:bomf(pos,radius)
	minetest.add_particlespawner(
		200, --amount
		0.1, --time
		{x=pos.x-radius/2, y=pos.y-radius/2, z=pos.z-radius/2}, --minpos
		{x=pos.x+radius/2, y=pos.y+radius/2, z=pos.z+radius/2}, --maxpos
		{x=-0, y=-0, z=-0}, --minvel
		{x=1, y=1, z=1}, --maxvel
		{x=-0.5,y=5,z=-0.5}, --minacc
		{x=0.5,y=5,z=0.5}, --maxacc
		0.1, --minexptime
		1, --maxexptime
		3, --minsize
		4, --maxsize
		false, --collisiondetection
		"tnt_smoke.png" --texture
	)

	minetest.sound_play("staffmagic_pom", {
		pos = pos,
		max_hear_distance = 10
	})
end

function staffmagic:max(x,y)
	if x < y then return y
	else return x
	end
end
function staffmagic:min(x,y)
	if x < y then return x
	else return y
	end
end


function staffmagic:mobheal(user,luae)
	if not luae.owner or user:get_player_name() ~= luae.owner then
		staffmagic:tellem(user,"This " ..luae.name .. " is not yours.")
		return
	end
	if luae.health < luae.hp_min then
		luae.health = luae.hp_min
		staffmagic:tellem(user,"Your " ..luae.name .. " has been healed.")
	else
		staffmagic:tellem(user,"This " ..luae.name .. " does not need healing.")
	end
end

function staffmagic:mobtransform(user,luae, forced)
	if not forced and math.random(1,20) > 1 then return ; end -- 1:20 chance of transforming

	luae.state="walk"

	if luae.type == "monster" then
		luae.type="npc"
		luae.attacks_monsters=true
		staffmagic:tellem(user,luae.name .. " became a friendly NPC")
	elseif luae.type == "npc" then
		luae.type = "animal"
		staffmagic:tellem(user,luae.name .. " became a docile animal")
	elseif luae.type == "animal" then
		luae.type = "monster"
		luae.passive = false
		staffmagic:tellem(user,luae.name .. " became a vicious monster")
	end
end

-- Staff of X (based on Staff of Light by Xanthin)

minetest.register_tool("staffmagic:staff_stack", { -- this will be the wall staff
	description = "Column Staff (make walls)",
	inventory_image = "water_staff.png^[colorize:yellow:90",
	wield_image = "water_staff.png^[colorize:yellow:90",
	range = 12,
	stack_max = 1,
	on_use = function(itemstack, user, pointed_thing)
		local stafflevel = staffmagic:staffcheck(user)
		if stafflevel < 1 then return; end

		if pointed_thing.type ~= "node" then
			if stafflevel < 2 then return; end

			if pointed_thing.type == "object" then
				local newpos = pointed_thing.ref:getpos()
				staffmagic:bomf(newpos,2 )
				local luae = pointed_thing.ref:get_luaentity()
				
				staffmagic:mobtransform(user,luae,true)
			end
			return
		end

		local pos = pointed_thing.under
		local pname = user:get_player_name()

		if minetest.is_protected(pos, pname) then
			minetest.record_protection_violation(pos, pname)
			return
		end


		local height = 5
		local targetnode = minetest.get_node(pos).name
		local userpos = user:getpos()

		local relpos = (userpos.y - pos.y)/math.sqrt((userpos.y - pos.y)^2)
		local lower = 0 ; local higher = 0

		if staffmagic:isforbidden(targetnode) and stafflevel < 2 then
			targetnode = "default:dirt"
		end


		if relpos < 0 then
			-- minetest.chat_send_player(pname, "Stack down")
			lower = -1*height
		elseif relpos >= 0 then
			-- minetest.chat_send_player(pname, "Stack up")
			higher = height
		end

                local airnodes = minetest.find_nodes_in_area(
                        {x = pos.x, y = pos.y+lower, z = pos.z},
                        {x = pos.x, y = pos.y+higher, z = pos.z},
                        {"air","default:water_source","default:lava_source","default:river_water_source"}
		)

		staffmagic:bomf(pos,2)
                for _,fpos in pairs(airnodes) do
			minetest.swap_node(fpos, {name = targetnode })
		end
		if staffmagic:staffcheck(user) < 90 then itemstack = staffmagic:wearitem(itemstack,50); end
		return itemstack

	end,
})

minetest.register_tool("staffmagic:staff_clone", { -- this will be the floor staff
	description = "Staff of Cloning (make floors)",
	inventory_image = "water_staff.png^[colorize:green:90",
	wield_image = "water_staff.png^[colorize:green:90",
	range = 12,
	stack_max = 1,
	on_use = function(itemstack, user, pointed_thing)
		local stafflevel = staffmagic:staffcheck(user)
		if stafflevel < 1 then return; end

		if pointed_thing.type ~= "node" then

			if stafflevel < 2 then -- can only clone mobs if super staffer else abuse
				return
			end
			if pointed_thing.type == "object" then
				local newpos = pointed_thing.ref:getpos()
				newpos = {x=newpos.x+math.random(-1,1), y=newpos.y+0.5, z=newpos.z+math.random(-1,1)}
				staffmagic:bomf(newpos,2 )
				minetest.add_entity(newpos, pointed_thing.ref:get_luaentity().name)
			end
			return
		end

		local pos = pointed_thing.under
		local playerpos = user:getpos()
		local pname = user:get_player_name()

		if minetest.is_protected(pos, pname) then
			minetest.record_protection_violation(pos, pname)
			return
		end


		local targetnode = minetest.get_node(pos).name
		local userpos = user:getpos()

		local startpos = {x = staffmagic:min(pos.x,playerpos.x),y = pos.y,z = staffmagic:min(pos.z,playerpos.z)}
		local endpos = {x = staffmagic:max(pos.x,playerpos.x),y = pos.y,z = staffmagic:max(pos.z,playerpos.z)}

		if staffmagic:isforbidden(targetnode) and stafflevel < 2 then
			targetnode = "default:dirt"
		end

                local airnodes = minetest.find_nodes_in_area(
                        startpos,
			endpos,
                        {"air","default:water_source","default:lava_source","default:river_water_source"}
		)
		
		staffmagic:bomf({x = (playerpos.x+pos.x)/2 , y = (playerpos.y+pos.y)/2 , z = (playerpos.z+pos.z)/2},4)

                for _,fpos in pairs(airnodes) do
			minetest.swap_node(fpos, {name = targetnode })
		end

		if staffmagic:staffcheck(user) < 90 then itemstack = staffmagic:wearitem(itemstack,50); end
		return itemstack

	end,
})

minetest.register_tool("staffmagic:staff_creative", { -- this will be the super creative staff
	description = "Creator Staff (make blocks or blocks)",
	inventory_image = "water_staff.png^[colorize:purple:90",
	wield_image = "water_staff.png^[colorize:purple:90",
	range = 15,
	stack_max = 1,
	on_use = function(itemstack, user, pointed_thing)
		local stafflevel = staffmagic:staffcheck(user)
		if stafflevel < 50 then return; end -- really do not want to give this to regular staffers

		local playerpos = user:getpos()
		local pname = user:get_player_name()

		if pointed_thing.type ~= "node" then
			if pointed_thing.type == "object" then
				local mobpos = pointed_thing.ref:getpos()
				local newpos = mobpos
				local distance = 30
				
				while (vector.distance(playerpos,newpos) < distance/2) do
					local airnodes = minetest.find_nodes_in_area(
						{x = playerpos.x -distance, y = playerpos.y - 10, z = playerpos.z -distance},
						{x = playerpos.x +distance, y = playerpos.y + 10, z = playerpos.z +distance},
						{"air","default:water_source","default:lava_source","default:river_water_source"}
					)
					newpos = airnodes[ math.random(1,#airnodes) ]
				end

				staffmagic:bomf( mobpos , 3)
				staffmagic:bomf( newpos , 5)
				pointed_thing.ref:setpos(newpos)
			end
			return
		end

		local pos = pointed_thing.under
		if minetest.is_protected(pos, pname) then
			minetest.record_protection_violation(pos, pname)
			return
		end


		local targetnode = minetest.get_node(pos).name
		local userpos = user:getpos()

		local startpos = {x = staffmagic:min(pos.x,playerpos.x),y = staffmagic:min(pos.y,playerpos.y),z = staffmagic:min(pos.z,playerpos.z)}
		local endpos = {x = staffmagic:max(pos.x,playerpos.x),y = staffmagic:max(pos.y,playerpos.y-1),z = staffmagic:max(pos.z,playerpos.z)}

		if staffmagic:isforbidden(targetnode) and stafflevel < 2 then
			targetnode = "default:dirt"
		end

                local airnodes = minetest.find_nodes_in_area(
                        startpos,
			endpos,
                        {"air","default:water_source","default:lava_source","default:river_water_source"}
		)
		
		staffmagic:bomf({x = (playerpos.x+pos.x)/2 , y = (playerpos.y+pos.y)/2 , z = (playerpos.z+pos.z)/2},4)

                for _,fpos in pairs(airnodes) do
			minetest.swap_node(fpos, {name = targetnode })
		end

		if staffmagic:staffcheck(user) < 90 then itemstack = staffmagic:wearitem(itemstack,50); end
		return itemstack

	end,
})

--[[

--]]

minetest.register_tool("staffmagic:staff_boom", {
	description = "Bomf Staff (delete nodes)",
	inventory_image = "water_staff.png^[colorize:black:140",
	wield_image = "water_staff.png^[colorize:black:140",
	range = 12,
	stack_max = 1,
	on_use = function(itemstack, user, pointed_thing)
		local stafflevel = staffmagic:staffcheck(user)
		if stafflevel < 2 then return; end

		if pointed_thing.type ~= "node" then
			if pointed_thing.type == "object" then
				staffmagic:bomf(pointed_thing.ref:getpos(),1 )
				pointed_thing.ref:remove()
			end
			return
		end

		local pos = pointed_thing.under
		local pname = user:get_player_name()

		if minetest.is_protected(pos, pname) then
			minetest.record_protection_violation(pos, pname)
			return
		end


		local radius = 3
		local targetnode = minetest.get_node(pos).name
		local userpos = user:getpos()
                local targetnodes = minetest.find_nodes_in_area(
                        {x = pos.x - radius, y = pos.y-radius, z = pos.z - radius},
                        {x = pos.x + radius, y = pos.y+radius, z = pos.z + radius},
                        {targetnode}
		)

		staffmagic:bomf(pos,radius)

                for _,fpos in pairs(targetnodes) do
			minetest.swap_node(fpos, {name = "air" })
		end
		return itemstack

	end,
})

-- quick and dirty tool to repair carnage caused by NSSM ice mobs
minetest.register_tool("staffmagic:staff_melt", {
	description = "Staff of Melting (Fix Ice Mobs damage)",
	inventory_image = "water_staff.png^[colorize:blue:90",
	wield_image = "water_staff.png^[colorize:blue:90",
	range = 12,
	stack_max = 1,
	on_use = function(itemstack, user, pointed_thing)

		if pointed_thing.type ~= "node" then
			if pointed_thing.type == "object" then
				local newpos = pointed_thing.ref:getpos()
				staffmagic:bomf(newpos,2 )
				local luae = pointed_thing.ref:get_luaentity()
				
				staffmagic:mobheal(user,luae)
				staffmagic:mobtransform(user,luae)
			end
			return
		end

		local pos = pointed_thing.under
		local pname = user:get_player_name()

		if minetest.is_protected(pos, pname) then
			minetest.record_protection_violation(pos, pname)
			return
		end


		local breadth = 2 -- full square is 2*breadth+1 on side
                local frostarea = minetest.find_nodes_in_area(
                        {x = pos.x - breadth, y = pos.y, z = pos.z - breadth},
                        {x = pos.x + breadth, y = pos.y, z = pos.z + breadth},
                        {"default:ice","default:snowblock"}
		)

		staffmagic:bomf(pos,breadth*2)

                for _,fpos in pairs(frostarea) do
				local replname = minetest.get_node({x=fpos.x,y=fpos.y-1,z=fpos.z}).name
				if replname == "default:ice" or replname == "default:snowblock" then
					local newreplname = minetest.get_node({x=fpos.x,y=fpos.y+1,z=fpos.z}).name
					if newreplname ~= "air" then --  don't dig down so much
						-- TODO if replname == air, then get average node around  that is not air, use that
						replname = newreplname
					end
				end
				local sealevel = 0 -- TODO get the custom setting for sealevel
				if fpos.y > 0 and replname == "default:water_source" then -- don't bother with water above sea level
					replname = "air"
				end
				--minetest.chat_send_all("Replicating "..replname)
				if staffmagic:isforbidden(replname) then
					replname = "default:dirt"
				end
				minetest.swap_node(fpos, {name = replname })
		end

		if staffmagic:staffcheck(user) < 90 then itemstack = staffmagic:wearitem(itemstack,50); end
		return itemstack

	end,
})

minetest.register_craft(
{
	output = "staffmagic:staff_melt",
	recipe = {
		{"default:mese_crystal_fragment","bucket:bucket_lava","default:mese_crystal_fragment"},
		{"","default:obsidian_shard",""},
		{"","default:obsidian_shard",""},
	}
}
)