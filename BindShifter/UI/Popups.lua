-- Yes/no and text-input confirmations through StaticPopupDialogs.
local _, ns = ...

local Popups = {}
ns.Popups = Popups

local function editBoxOf(dialog)
	return dialog.editBox or _G[dialog:GetName() .. "EditBox"]
end

function Popups.register()
	-- In 3.3.5 StaticPopup_OnClick hides the dialog after OnAccept unless OnAccept returns
	-- true. A callback that opens another BindShifter popup may reuse the same frame, so
	-- every handler hides its own dialog first, then runs the callback, then returns true.
	StaticPopupDialogs.BINDSHIFTER_CONFIRM = {
		text = "%s",
		button1 = YES,
		button2 = NO,
		OnAccept = function(self, data)
			self:Hide()
			if data and data.onAccept then
				data.onAccept()
			end
			return true
		end,
		timeout = 0,
		whileDead = 1,
		hideOnEscape = 1,
	}

	-- Two actions: button1 = data.onFirst, button2 = data.onSecond, Escape = nothing.
	StaticPopupDialogs.BINDSHIFTER_CHOICE = {
		text = "%s",
		button1 = "",
		button2 = "",
		OnShow = function(self)
			local data = self.data
			if data then
				_G[self:GetName() .. "Button1"]:SetText(data.first)
				_G[self:GetName() .. "Button2"]:SetText(data.second)
			end
		end,
		OnAccept = function(self, data)
			self:Hide()
			if data and data.onFirst then
				data.onFirst()
			end
			return true
		end,
		-- 3.3.5 calls OnCancel(dialog, data, "clicked") for button2 and, unless
		-- noCancelOnEscape is set, for Escape too. Escape must only close the dialog.
		OnCancel = function(self, data, reason)
			if reason ~= "clicked" then
				return
			end
			self:Hide()
			if data and data.onSecond then
				data.onSecond()
			end
			return true
		end,
		noCancelOnEscape = 1,
		timeout = 0,
		whileDead = 1,
		hideOnEscape = 1,
	}

	StaticPopupDialogs.BINDSHIFTER_INPUT = {
		text = "%s",
		button1 = ACCEPT,
		button2 = CANCEL,
		hasEditBox = 1,
		maxLetters = 50,
		OnAccept = function(self, data)
			local text = editBoxOf(self):GetText()
			self:Hide()
			if data and data.onAccept then
				data.onAccept(text)
			end
			return true
		end,
		EditBoxOnEnterPressed = function(self)
			local dialog = self:GetParent()
			local data = dialog.data
			dialog:Hide()
			if data and data.onAccept then
				data.onAccept(self:GetText())
			end
		end,
		EditBoxOnEscapePressed = function(self)
			self:GetParent():Hide()
		end,
		timeout = 0,
		whileDead = 1,
		hideOnEscape = 1,
	}
end

-- StaticPopup_Show(which, text_arg1, text_arg2, data) stores data before OnShow (3.3.5).
function Popups.confirm(text, onAccept)
	local data = { onAccept = onAccept }
	local dialog = StaticPopup_Show("BINDSHIFTER_CONFIRM", text, nil, data)
	if dialog then
		dialog.data = data
	end
end

-- Two-button choice. The button labels are set after the dialog is shown.
function Popups.choice(text, first, second, onFirst, onSecond)
	local data = { first = first, second = second, onFirst = onFirst, onSecond = onSecond }
	local dialog = StaticPopup_Show("BINDSHIFTER_CHOICE", text, nil, data)
	if dialog then
		dialog.data = data
		local b1, b2 = _G[dialog:GetName() .. "Button1"], _G[dialog:GetName() .. "Button2"]
		if b1 then
			b1:SetText(first)
		end
		if b2 then
			b2:SetText(second)
		end
	end
end

function Popups.input(prompt, default, onAccept)
	local data = { onAccept = onAccept }
	local dialog = StaticPopup_Show("BINDSHIFTER_INPUT", prompt, nil, data)
	if dialog then
		dialog.data = data
		local box = editBoxOf(dialog)
		box:SetText(default or "")
		box:HighlightText()
		box:SetFocus()
	end
end
