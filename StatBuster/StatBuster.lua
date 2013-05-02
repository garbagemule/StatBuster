
-- Hyperlink tables
local leftItems = {};
local rightItems = {};

-- Checkbox tables
local leftChecked = {};
local rightChecked = {};

-- Stat tables
local leftStats = {};
local rightStats = {};
local diffStats = {};
local indexStats = {};

-- Offsets for scrolling
local leftOffset = 0;
local rightOffset = 0;
local statsCount = 0;

-- Maximum number of items and stats
local maxItems = 6;
local maxStats = 8;

-- Zero inclusion flag
local includeZeroes = false;



--[[-------------------------------------------------------------||--

        EVENT HANDLERS
        
--||-------------------------------------------------------------]]--

function SB_MainFrame_OnLoad(self)
    SB_ZeroesText:SetText("Show no-diff stats");

    -- Height function
    function height(frame)
        return frame:GetHeight() + abs(select(5, frame:GetPoint())) + 5;
    end
    local height = height(SB_LeftPanel) + height(SB_TotalsPanel) + height(SB_Close);
    SB_MainFrame:SetHeight(height);

    SB_MainFrame:Hide();
end

-- Fired when an item is clicked while holding down a modifier key.
local origClick = HandleModifiedItemClick;
HandleModifiedItemClick = function(item)
    -- Only act when visible
    if not SB_MainFrame:IsVisible() then
        return origClick(item);
    end

    -- Only act on Ctrl clicks
    if not IsControlKeyDown() then
        return origClick(item);
    end

    -- Require left or right mouse button
    local button = GetMouseButtonClicked();
    if not button == "LeftButton" and not button == "RightButton" then
        return origClick(item);
    end

    -- Handle the item
    SB_HandleItemClick(item, button);
    return nil;
end

-- Fired when an item is clicked in the chatframe.
local origLink = ChatFrame_OnHyperlinkShow;
ChatFrame_OnHyperlinkShow = function(...)
    -- Only act when visible
    if not SB_MainFrame:IsVisible() then
        return origLink(...);
    end

    -- Only act on Ctrl clicks
    if not IsControlKeyDown() then
        return origLink(...);
    end

    -- Grab the parameters
    local _,_,item,button = ...;

    -- Require left or right mouse button
    if not button == "LeftButton" and not button == "RightButton" then
        return origLink(...);
    end

    -- Handle the item
    SB_HandleItemClick(item, button);
    return nil;
end

-- Unenchanted middle bit of an item link
local middle = "0:0:0:0:0:0:0"

function SB_HandleItemClick(item, button)
    -- Strip gems and enchants
    local _, _, first, second = string.find(item, "(|.*|Hitem:%d+:)%d+:%d+:%d+:%d+:%d+:%d+:%d+(:80|.*)");
    item = first .. middle .. second;

    -- Get the correct tables
    local items, checked = SB_GetTables(button);
    
    -- Insert values
    table.insert(items, item);
    table.insert(checked, true);

    -- Recalculate stat differences and update UI
    SB_CalculateStats();
    SB_UpdateUI();
end

function SB_GetTables(button)
    if button == "LeftButton" then
        return leftItems, leftChecked;
    else
        return rightItems, rightChecked;
    end
end

function SB_ListItem_OnEnter(self)
    -- Get the table and index
    local index, items, _ = SB_ParseListItem(self:GetName());

    -- Get the hyperlink from the table
    local link = items[index];

    -- Set the tooltip
    GameTooltip:SetOwner(SB_MainFrame);
    GameTooltip:SetHyperlink(link);
    GameTooltip:Show();
end

function SB_ListItem_OnLeave(self)
    GameTooltip:Hide();
end

function SB_ListItemRemove_OnClick(self)
    -- Get the table and index
    local index, items, checked = SB_ParseListItem(self:GetParent():GetName());

    -- Remove the item from the table
    table.remove(items, index);
    table.remove(checked, index);

    -- Recalculate stat differences and update UI
    SB_CalculateStats();
    SB_UpdateUI();
end

function SB_ListItemCheck_OnClick(self)
    -- Get the table and index
    local index, _, checked = SB_ParseListItem(self:GetParent():GetName());

    -- Set the checkbox in the table
    checked[index] = self:GetChecked() and true or false;

    -- Recalculate stat differences and update UI
    SB_CalculateStats();
    SB_UpdateUI();
end

function SB_Close_OnClick()
    SB_MainFrame:Hide();
end

function SB_ZeroesCheck_OnClick(self)
    includeZeroes = self:GetChecked() and true or false;

    SB_CalculateStats();
    SB_UpdateUI();
end

function SB_LeftScroller_OnValueChanged(self)
    if #leftItems <= maxItems then return end
    SB_Scroller_OnValueChanged(self, leftItems, leftChecked);
end

function SB_RightScroller_OnValueChanged(self)
    if #rightItems <= maxItems then return end
    SB_Scroller_OnValueChanged(self, rightItems, rightChecked);
end

function SB_Scroller_OnValueChanged(scroller, items, checked)
    SB_UpdateUI();
end

function SB_TotalsScroller_OnValueChanged(self)
    if statsCount <= maxStats then return end
    SB_UpdateUI();
end



--[[-------------------------------------------------------------||--

        INTERNAL STUFF
        
--||-------------------------------------------------------------]]--

-- Stats as ordered on tooltips in-game
local allStats = {
    "Armor", "Strength", "Agility", "Stamina", "Intellect", "Spirit",
    "defense rating", "dodge rating", "parry rating", "expertise rating",
    "attack power", "spell power", "hit rating", "resilience rating",
    "critical strike rating", "haste rating", "armor penetration rating",
    "mana per 5 sec", "Meta Socket", "Red Socket", "Blue Socket", "Yellow Socket"
}

local SB_Tooltip = CreateFrame("GameTooltip", "SB_Tooltip", nil, "GameTooltipTemplate");
function SB_CalculateStats()
    -- Reset the stats tables
    leftStats = {};
    rightStats = {};
    diffStats = {};
    indexStats = {};

    -- Parse all items
    SB_ParseItems(leftItems,  leftChecked,  leftStats);
    SB_ParseItems(rightItems, rightChecked, rightStats);

    -- Go through each stat and see if it is included
    local j = 1;
    for i = 1, #allStats do
        local name = allStats[i];

        -- Included stats return true
        if SB_IncludeStat(name, leftStats[name], rightStats[name]) then
            indexStats[j] = name;
            j = j + 1;
        end
    end

    -- Update the stats counter
    statsCount = j-1;
end

function SB_IncludeStat(name, left, right)
    -- If both values are missing, don't bother
    if not left and not right then return false end

    -- If at least one value is present, we do some calculations
    local value = 0;

    -- Start with right, then subtract left
    if right then value = right;        end
    if left  then value = value - left; end;
    
    -- If we are not including zeroes, check and skip
    if (value == 0) and not includeZeroes then
        return false;
    end

    -- Fill in the blanks if necessary
    if not left  then leftStats[name]  = 0; end
    if not right then rightStats[name] = 0; end

    -- Store the value
    diffStats[name] = value;

    return true;
end

function SB_ParseItems(items, checked, stats)
    for i = 1, #items do
        -- Only include checked items
        if checked[i] then
            -- Update our tooltip
            SB_Tooltip:SetOwner(UIParent, "ANCHOR_NONE");
            SB_Tooltip:SetHyperlink(items[i]);

            -- Run through each line
            for j = 1, SB_Tooltip:NumLines() do
                -- Extract the line
                local text = _G["SB_TooltipTextLeft" .. j]:GetText();

                -- Parse the line
                SB_ParseLine(text, stats);
            end
        end
    end
end

-- Strings used for item matching
local equip  = "Equip:%s.*%s("
local rating = "%srating"
local value  = ")%sby%s([0-9]+)"
local block  = "block%svalue)%s.*by%s([0-9]+)"
local mp5    = "[0-9]+)%s(mana%sper%s5%ssec).*"

-- Different stats
local sockets = { "Meta", "Red", "Yellow", "Blue" }
local powers  = { "spell%spower", "attack%spower" }
local combats = { "defense", "parry", "dodge", "resilience", "shield%sblock",
                  "hit", "armor%spenetration", "expertise", "critical%sstrike",
                  "haste" }
function SB_ParseLine(text, stats)
    -- Don't count procs
    if string.find(text, "chance") then
        return true;
    end

    -- Power stats
    for i = 1, #powers do
        if SB_CheckStat(text, stats, equip .. powers[i] .. value, true) then
            return true;
        end
    end

    -- Combat stats
    for i = 1, #combats do
        if SB_CheckStat(text, stats, equip .. combats[i] .. rating .. value, true) then
            return true;
        end
    end

    -- Shield block
    if SB_CheckStat(text, stats, equip .. block, true) then
        return true;
    end

    -- Mana per 5
    if SB_CheckStat(text, stats, equip .. mp5, false) then
        return true;
    end

    -- Sockets
    for i = 1, #sockets do
        local s = sockets[i] .. " Socket";
        if string.find(text, "(" .. s .. ")") then
            stats[s] = 1 + (stats[s] and stats[s] or 0);
        end
    end

    -- Armor and base stats
    return SB_CheckStat(text, stats, "(%d+)%s(Armor)", false)   -- <amount> Armor
        or SB_CheckStat(text, stats, "^\+(%d+)%s(.+)$", false)  -- +<amount> <stat>
    ;
end

function SB_CheckStat(text, stats, pattern, combat)
    local amount, stat;
    if not combat then
        _, _, amount, stat = string.find(text, pattern);
    else
        _, _, stat, amount = string.find(text, pattern);
    end
    if amount and stat then
        stats[stat] = tonumber(amount) + (stats[stat] and stats[stat] or 0);
        return true;
    end
    return false;
end

function SB_UpdateUI()
    -- Update scrollers
    SB_LeftScroller:SetMinMaxValues(1, (#leftItems > maxItems) and #leftItems-(maxItems-1) or 1);
    SB_RightScroller:SetMinMaxValues(1, (#rightItems > maxItems) and #rightItems-(maxItems-1) or 1);
    SB_TotalsScroller:SetMinMaxValues(1, (statsCount > maxStats) and statsCount-(maxStats-1) or 1);
    
    -- Update offsets
    leftOffset = SB_LeftScroller:GetValue() - 1;
    rightOffset = SB_RightScroller:GetValue() - 1;
    totalsOffset = SB_TotalsScroller:GetValue() - 1;

    -- Update the item lists
    for i = 1, maxItems do
        SB_UpdateListItem(i, leftOffset+i,  "L", leftItems,  leftChecked);
        SB_UpdateListItem(i, rightOffset+i, "R", rightItems, rightChecked);
    end

    -- Update the totals list
    for i = 1, maxStats do
        local frame = _G["SB_T" .. i];
        local index = totalsOffset + i;
        if statsCount < index then
            frame:Hide();
        else
            local name = indexStats[index];
            local pretty, tex = SB_NameAndTex(name);
            local left  = leftStats[name];
            local right = rightStats[name];

            -- Textures (for sockets)
            if tex then
                frame.tex:SetTexture(tex);
                frame.tex:Show();
            else
                frame.tex:Hide();
            end

            -- Stat name
            frame.stat:SetText(pretty);

            -- Diff value
            frame.diff:SetText(SB_SignedValue(diffStats[name]));
            frame.diff:SetTextColor(SB_DiffColor(diffStats[name]));

            -- Left value
            frame.left:SetText(left);
            frame.left:SetTextColor(SB_NeutralColor(left));

            -- Right value
            frame.right:SetText(right);
            frame.right:SetTextColor(SB_NeutralColor(right));

            -- Percentage
            if not (left == 0) and not (right == 0) then
                local percentage = right * 100 / left;
                frame.percent:SetText(string.format("%d", percentage));
                frame.percent:SetTextColor(SB_PercentColor(percentage));
            else
                frame.percent:SetText("-");
                frame.percent:SetTextColor(SB_NeutralColor(-1));
            end

            frame:Show();
        end
    end
end

function SB_NameAndTex(name)
    local _, _, color = string.find(name, "(%a+)%sSocket");
    if color then
        return "    " .. name, "Interface/ITEMSOCKETINGFRAME/UI-EmptySocket-" .. color;
    end
    return string.upper(string.sub(name, 1, 1)) .. string.sub(name, 2), nil;
end

function SB_SignedValue(value)
    return (value > 0) and "+" .. value or value;
end

function SB_NeutralColor(value)
    if value > 0 then return 0.8, 0.8, 0.8, 1.0; end;
    return 0.4, 0.4, 0.4, 1.0;
end

function SB_DiffColor(value)
    if value < 0 then return 1.0, 0.1, 0.1, 1.0; end
    if value > 0 then return 0.1, 1.0, 0.1, 1.0; end
    return 0.4, 0.4, 0.4, 1.0;
end

function SB_PercentColor(value)
    return SB_DiffColor(value - 100);
end

function SB_UpdateListItem(i, index, side, items, checked)
    -- Grab the frame
    local frame = _G["SB_" .. side .. i];

    -- If the index is greater than the number of items, hide the frame
    if #items < index then
        frame:Hide();
        return;
    end

    -- Otherwise update it and show it
    frame.name:SetText(items[index]);
    frame.check:SetChecked(checked[index]);
    frame:Show();
end

function SB_SlashCommand(msg, editbox)
    -- No message? Toggle
    if msg == "" then
        return SB_ToggleVisible(SB_MainFrame);
    end
end

function SB_ToggleVisible(frame)
    if frame:IsVisible() then frame:Hide() else frame:Show() end
end

SlashCmdList["STATBUSTER"] = SB_SlashCommand;
SLASH_STATBUSTER1 = '/sb';
SLASH_STATBUSTER2 = '/stat';



--[[-------------------------------------------------------------||--

        HELPER FUNCTIONS
        
--||-------------------------------------------------------------]]--

-- Parse a table and an index from a given list item name of
-- the form SB_[L|R][1..6], e.g. SB_L2, SB_R6
function SB_ParseListItem(name)
    -- Determine side and offset
    local side = string.sub(name, 4, 4);
    local offset = (side == "L") and leftOffset or rightOffset;

    -- Index
    local str = string.sub(name, 5);
    local index = tonumber(str) + offset;

    -- Items and checked
    local items, checked;
    if side == "L" then
        items = leftItems;
        checked = leftChecked;
    else
        items = rightItems;
        checked = rightChecked;
    end

    -- Return the pair
    return index, items, checked;
end
