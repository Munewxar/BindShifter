-- Minimal stand-ins for the WoW UI and Ace3 libraries, enough to execute UI/Platform code
-- outside the game. Records chat output, popups, windows and buttons for assertions.
local M = {}

local function noop() end

-- A widget whose unknown methods are no-ops; known ones record state.
local function newWidget(kind, registry)
	-- Every field read by the stub must exist: the metatable turns missing keys into no-ops.
	local w = { kind = kind, callbacks = {}, children = {}, text = false, title = false,
		disabled = false, hidden = false }
	function w:SetCallback(name, fn)
		self.callbacks[name] = fn
	end
	function w:Fire(name, ...)
		if self.callbacks[name] then
			self.callbacks[name](self, name, ...)
		end
	end
	function w:SetText(t)
		self.text = t
	end
	function w:GetText()
		return self.text or ""
	end
	function w:SetTitle(t)
		self.title = t
	end
	function w:SetDisabled(d)
		self.disabled = d
	end
	function w:AddChild(child)
		self.children[#self.children + 1] = child
	end
	function w:Hide()
		if not self.hidden then
			self.hidden = true
			self:Fire("OnClose")
		end
	end
	w.editBox = { SetFocus = noop, HighlightText = noop }
	w.button = {
		shown = true,
		Hide = function(b)
			b.shown = false
		end,
		Show = function(b)
			b.shown = true
		end,
	}
	setmetatable(w, { __index = function()
		return noop
	end })
	registry[#registry + 1] = w
	return w
end

function M.install()
	local env = { chat = {}, popups = {}, widgets = {}, options = nil, notifyChanges = 0, opened = 0, hooks = {} }

	DEFAULT_CHAT_FRAME = {
		AddMessage = function(_, text)
			env.chat[#env.chat + 1] = text
		end,
	}
	GetBindingText = function(key)
		return key
	end
	date = os.date
	time = os.time
	GetLocale = function()
		return env.locale or "ruRU"
	end
	YES, NO, ACCEPT, CANCEL = "Yes", "No", "Accept", "Cancel"
	StaticPopupDialogs = {}
	StaticPopup_Show = function(which, text, _, data)
		local dialog = { which = which, text = text, editText = "", data = data }
		dialog.Hide = function()
			dialog.hidden = true
		end
		dialog.editBox = {
			SetText = function(_, t)
				dialog.editText = t
			end,
			GetText = function()
				return dialog.editText
			end,
			HighlightText = noop,
			SetFocus = noop,
		}
		dialog.GetName = function()
			return "StaticPopup1"
		end
		env.popups[#env.popups + 1] = dialog
		return dialog
	end
	InterfaceOptionsFrame_OpenToCategory = function()
		env.opened = env.opened + 1
	end

	local libs = {}
	libs["AceAddon-3.0"] = {
		NewAddon = function(_, name)
			local addon = { name = name, events = {}, commands = {} }
			function addon:RegisterEvent(e)
				self.events[e] = true
			end
			function addon:UnregisterEvent(e)
				self.events[e] = nil
			end
			function addon:RegisterChatCommand(cmd, fn)
				self.commands[cmd] = fn
			end
			env.addon = addon
			return addon
		end,
	}
	libs["AceConfig-3.0"] = {
		RegisterOptionsTable = function(_, _, options)
			env.options = options
		end,
	}
	libs["AceConfigRegistry-3.0"] = {
		NotifyChange = function()
			env.notifyChanges = env.notifyChanges + 1
		end,
	}
	libs["AceConfigDialog-3.0"] = {
		AddToBlizOptions = function()
			return {
				HookScript = function(_, script, fn)
					env.hooks[script] = fn
				end,
			}
		end,
	}
	libs["AceGUI-3.0"] = {
		Create = function(_, kind)
			return newWidget(kind, env.widgets)
		end,
		Release = noop,
	}
	LibStub = setmetatable({}, {
		__call = function(_, name)
			return libs[name] or env.realLibs[name]
		end,
	})
	env.realLibs = {}

	-- Helpers ----------------------------------------------------------------
	function env.lastPopup()
		return env.popups[#env.popups]
	end

	-- Accepts the last popup (with input text for edit-box popups).
	function env.acceptPopup(text)
		local dialog = table.remove(env.popups)
		assert(dialog, "no popup to accept")
		if text then
			dialog.editText = text
		end
		local def = StaticPopupDialogs[dialog.which]
		def.OnAccept(dialog, dialog.data)
	end

	-- Clicks the second button of the last popup.
	function env.secondPopup()
		local dialog = table.remove(env.popups)
		assert(dialog, "no popup")
		StaticPopupDialogs[dialog.which].OnCancel(dialog, dialog.data, "clicked")
	end

	function env.findButton(label)
		for i = #env.widgets, 1, -1 do
			local w = env.widgets[i]
			if w.kind == "Button" and w.text == label and not w.disabled then
				return w
			end
		end
		return nil
	end

	function env.click(label)
		local b = assert(env.findButton(label), "button not found or disabled: " .. tostring(label))
		b:Fire("OnClick")
	end

	function env.lastWindow()
		for i = #env.widgets, 1, -1 do
			if env.widgets[i].kind == "Frame" then
				return env.widgets[i]
			end
		end
	end

	function env.chatContains(fragment)
		for _, line in ipairs(env.chat) do
			if line:find(fragment, 1, true) then
				return true
			end
		end
		return false
	end

	return env
end

return M
