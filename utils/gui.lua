local Token = require 'utils.token'
local Event = require 'utils.event'
local Game = require 'utils.game'
local Global = require 'utils.global'

local tostring = tostring
local next = next

local Gui = {}

local data = {}

Global.register(
    data,
    function(tbl)
        data = tbl
    end
)

local top_elements = {}
local on_visible_handlers = {}
local on_pre_hidden_handlers = {}

function Gui.uid_name()
    return tostring(Token.uid())
end

-- Associates data with the LuaGuiElement. If data is nil then removes the data
function Gui.set_data(element, value)
    local player_index = element.player_index
    local values = data[player_index]

    if value == nil then
        if not values then
            return
        end

        values[element.index] = nil

        if next(values) == nil then
            data[player_index] = nil
        end
    else
        if not values then
            values = {}
            data[player_index] = values
        end

        values[element.index] = value
    end
end
local set_data = Gui.set_data

-- Gets the Associated data with this LuaGuiElement if any.
function Gui.get_data(element)
    local player_index = element.player_index

    local values = data[player_index]
    if not values then
        return nil
    end

    return values[element.index]
end

local remove_data_recursively
-- Removes data associated with LuaGuiElement and its children recursively.
function Gui.remove_data_recursively(element)
    set_data(element, nil)

    local children = element.children

    if not children then
        return
    end

    for _, child in next, children do
        if child.valid then
            remove_data_recursively(child)
        end
    end
end
remove_data_recursively = Gui.remove_data_recursively

local remove_children_data
function Gui.remove_children_data(element)
    local children = element.children

    if not children then
        return
    end

    for _, child in next, children do
        if child.valid then
            set_data(child, nil)
            remove_children_data(child)
        end
    end
end
remove_children_data = Gui.remove_children_data

function Gui.destroy(element)
    remove_data_recursively(element)
    element.destroy()
end

function Gui.clear(element)
    remove_children_data(element)
    element.clear()
end

local function handler_factory(event_id)
    local handlers

    local function on_event(event)
        local element = event.element
        if not element or not element.valid then
            return
        end

        local handler = handlers[element.name]
        if not handler then
            return
        end

        local player = Game.get_player_by_index(event.player_index)
        if not player or not player.valid then
            return
        end
        event.player = player

        handler(event)
    end

    return function(element_name, handler)
        if not handlers then
            handlers = {}
            Event.add(event_id, on_event)
        end

        handlers[element_name] = handler
    end
end

local function custom_handler_factory(handlers)
    return function(element_name, handler)
        handlers[element_name] = handler
    end
end

local function custom_raise(handlers, element, player)
    local handler = handlers[element.name]
    if not handler then
        return
    end

    handler({element = element, player = player})
end

-- Register a handler for the on_gui_checked_state_changed event for LuaGuiElements with element_name.
-- Can only have one handler per element name.
-- Guarantees that the element and the player are valid when calling the handler.
-- Adds a player field to the event table.
Gui.on_checked_state_changed = handler_factory(defines.events.on_gui_checked_state_changed)

-- Register a handler for the on_gui_click event for LuaGuiElements with element_name.
-- Can only have one handler per element name.
-- Guarantees that the element and the player are valid when calling the handler.
-- Adds a player field to the event table.
Gui.on_click = handler_factory(defines.events.on_gui_click)

-- Register a handler for the on_gui_closed event for a custom LuaGuiElements with element_name.
-- Can only have one handler per element name.
-- Guarantees that the element and the player are valid when calling the handler.
-- Adds a player field to the event table.
Gui.on_custom_close = handler_factory(defines.events.on_gui_closed)

-- Register a handler for the on_gui_elem_changed event for LuaGuiElements with element_name.
-- Can only have one handler per element name.
-- Guarantees that the element and the player are valid when calling the handler.
-- Adds a player field to the event table.
Gui.on_elem_changed = handler_factory(defines.events.on_gui_elem_changed)

-- Register a handler for the on_gui_selection_state_changed event for LuaGuiElements with element_name.
-- Can only have one handler per element name.
-- Guarantees that the element and the player are valid when calling the handler.
-- Adds a player field to the event table.
Gui.on_selection_state_changed = handler_factory(defines.events.on_gui_selection_state_changed)

-- Register a handler for the on_gui_text_changed event for LuaGuiElements with element_name.
-- Can only have one handler per element name.
-- Guarantees that the element and the player are valid when calling the handler.
-- Adds a player field to the event table.
Gui.on_text_changed = handler_factory(defines.events.on_gui_text_changed)

-- Register a handler for the on_gui_value_changed event for LuaGuiElements with element_name.
-- Can only have one handler per element name.
-- Guarantees that the element and the player are valid when calling the handler.
-- Adds a player field to the event table.
Gui.on_value_changed = handler_factory(defines.events.on_gui_value_changed)

-- Register a handler for when the player shows the top LuaGuiElements with element_name.
-- Assuming the element_name has been added with Gui.allow_player_to_toggle_top_element_visibility.
-- Can only have one handler per element name.
-- Guarantees that the element and the player are valid when calling the handler.
-- Adds a player field to the event table.
Gui.on_player_show_top = custom_handler_factory(on_visible_handlers)

-- Register a handler for when the player hides the top LuaGuiElements with element_name.
-- Assuming the element_name has been added with Gui.allow_player_to_toggle_top_element_visibility.
-- Can only have one handler per element name.
-- Guarantees that the element and the player are valid when calling the handler.
-- Adds a player field to the event table.
Gui.on_pre_player_hide_top = custom_handler_factory(on_pre_hidden_handlers)

--- Allows the player to show / hide this element.
-- The element must be part in gui.top.
-- This function must be called in the control stage, i.e not inside an event.
-- @param element_name<string> This name must be globally unique.
function Gui.allow_player_to_toggle_top_element_visibility(element_name)
    top_elements[#top_elements + 1] = element_name
end

local toggle_button_name = Gui.uid_name()

Event.add(
    defines.events.on_player_created,
    function(event)
        local player = Game.get_player_by_index(event.player_index)

        if not player or not player.valid then
            return
        end

        local b =
            player.gui.top.add {
            type = 'button',
            name = toggle_button_name,
            caption = '<',
            tooltip = 'Shows / hides the Redmew Gui buttons.'
        }
        local style = b.style
        style.width = 18
        style.height = 38
        style.left_padding = 0
        style.top_padding = 0
        style.right_padding = 0
        style.bottom_padding = 0
        style.font = 'default-small-bold'
    end
)

Gui.on_click(
    toggle_button_name,
    function(event)
        local button = event.element
        local player = event.player
        local top = player.gui.top

        if button.caption == '<' then
            for i = 1, #top_elements do
                local name = top_elements[i]
                local ele = top[name]
                if ele and ele.valid then
                    local style = ele.style

                    -- if visible is not set it has the value of nil.
                    -- Hence nil is treated as is visible.
                    local v = style.visible
                    if v or v == nil then
                        custom_raise(on_pre_hidden_handlers, ele, player)
                        style.visible = false
                    end
                end
            end

            button.caption = '>'
            button.style.height = 24
        else
            for i = 1, #top_elements do
                local name = top_elements[i]
                local ele = top[name]
                if ele and ele.valid then
                    local style = ele.style

                    if not style.visible then
                        style.visible = true
                        custom_raise(on_visible_handlers, ele, player)
                    end
                end
            end

            button.caption = '<'
            button.style.height = 38
        end
    end
)

if _DEBUG then
    local concat = table.concat

    local names = {}
    Gui.names = names

    function Gui.uid_name()
        local info = debug.getinfo(2, 'Sl')
        local filepath = info.source:match('^.+/currently%-playing/(.+)$'):sub(1, -5)
        local line = info.currentline

        local token = tostring(Token.uid())

        local name = concat {token, ' - ', filepath, ':line:', line}
        names[token] = name

        return token
    end

    Gui.data = data
end

return Gui
