local backdrop  = {
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
}

-- UI Elements
local container
local wagerEditBox
local startGameButton
local lastCallButton
local startRollButton
local joinGameButton
local rollForMeButton
local cancelGameButton
local optionsButton
local optionsDivider
local gameModeEditBox
local gameModeLeftButton
local gameModeRightButton
local channelEditBox
local channelLeftButton
local channelRightButton
local houseCutEditBox

-- Public Functions --

function WoWGoldGambler:showUi(info)
    -- Show the WGG UI if it is not already visible
    if (container:IsVisible() ~= true) then
        container:Show()
    end
end

function WoWGoldGambler:hideUi(info)
    -- Hide the WGG UI if it is currently visible
    if (container:IsVisible()) then
        container:Hide()
    end
end

function WoWGoldGambler:enableWidget(widget)
    -- Enables the given widget if it is currently disabled
    if (widget:IsEnabled() ~= true) then
        widget:Enable()
    end
end

function WoWGoldGambler:disableWidget(widget)
    -- Disables the given widget if it is currently enabled
    if (widget:IsEnabled()) then
        widget:Disable()

        if (widget:GetObjectType() == "Button") then
            self:Print("Button!")
        elseif (widget:GetObjectType() == "EditBox") then
            widget:SetTextColor(0.5, 0.5, 0.5)
        end
    end
end

function WoWGoldGambler:drawUi()
    -- Create all UI elements. To be called when the addon is initialized
    container = self:createFrameWidget(UIParent)

    wagerEditBox = self:createEditBoxWidget(container, "Wager Amount", self.db.global.game.wager, "large")
    wagerEditBox:SetScript("OnTextChanged", function() self:setWager(wagerEditBox:GetText()) end)
    wagerEditBox:SetPoint("TOPLEFT", container, "TOPLEFT", 20, -40)
    wagerEditBox:SetNumeric(true)
    wagerEditBox:SetMaxLetters(18)

    startGameButton = self:createButtonWidget(container, "Start Game", "large")
    startGameButton:SetScript("OnClick", function() self:startGame() end)
	startGameButton:SetPoint("TOPLEFT", wagerEditBox, "TOPLEFT", 0, -35)

    joinGameButton = self:createButtonWidget(container, "Join Game", "large")
    joinGameButton:SetScript("OnClick", function() self:enterMe() end)
	joinGameButton:SetPoint("TOPLEFT", wagerEditBox, "TOPRIGHT", -125, -35)

    lastCallButton = self:createButtonWidget(container, "Last Call", "large")
    lastCallButton:SetScript("OnClick", function() self:lastCall() end)
	lastCallButton:SetPoint("TOPLEFT", startGameButton, "TOPLEFT", 0, -30)

    rollForMeButton = self:createButtonWidget(container, "Roll For Me", "large")
    rollForMeButton:SetScript("OnClick", function() self:rollMe() end)
	rollForMeButton:SetPoint("TOPLEFT", joinGameButton, "TOPLEFT", 0, -30)

    startRollButton = self:createButtonWidget(container, "Start Rolling", "large")
    startRollButton:SetScript("OnClick", function() self:startRolls() end)
	startRollButton:SetPoint("TOPLEFT", lastCallButton, "TOPLEFT", 0, -30)

    cancelGameButton = self:createButtonWidget(container, "Cancel Game", "large")
    cancelGameButton:SetScript("OnClick", function() self:cancelGame() end)
	cancelGameButton:SetPoint("TOPLEFT", rollForMeButton, "TOPLEFT", 0, -30)

    optionsDivider = self:createLineWidget(container)
    optionsDivider:SetPoint("TOPRIGHT", wagerEditBox, "TOPRIGHT", 19, 11)

    gameModeEditBox = self:createEditBoxWidget(container, "Game Mode", self.db.global.game.mode, "small")
    gameModeEditBox:SetPoint("TOPRIGHT", container, "TOPRIGHT", -50, -40)
    self:disableWidget(gameModeEditBox)
    gameModeEditBox:Hide()

    gameModeLeftButton = self:createButtonWidget(container, "<", "small")
	gameModeLeftButton:SetPoint("LEFT", gameModeEditBox, "LEFT", -30, 0)
    gameModeLeftButton:SetScript("OnClick", function()
        self:changeGameMode("prev")
        gameModeEditBox:SetText(self.db.global.game.mode)
    end)
    gameModeLeftButton:Hide()

    gameModeRightButton = self:createButtonWidget(container, ">", "small")
	gameModeRightButton:SetPoint("RIGHT", gameModeEditBox, "RIGHT", 30, 0)
    gameModeRightButton:SetScript("OnClick", function()
        self:changeGameMode("next")
        gameModeEditBox:SetText(self.db.global.game.mode)
    end)
    gameModeRightButton:Hide()

    channelEditBox = self:createEditBoxWidget(container, "Chat Channel", self.db.global.game.chatChannel, "small")
    channelEditBox:SetPoint("TOP", gameModeEditBox, "TOP", 0, -45)
    self:disableWidget(channelEditBox)
    channelEditBox:Hide()

    channelLeftButton = self:createButtonWidget(container, "<", "small")
	channelLeftButton:SetPoint("LEFT", channelEditBox, "LEFT", -30, 0)
    channelLeftButton:SetScript("OnClick", function()
        self:changeChannel("prev")
        channelEditBox:SetText(self.db.global.game.chatChannel)
    end)
    channelLeftButton:Hide()

    channelRightButton = self:createButtonWidget(container, ">", "small")
	channelRightButton:SetPoint("RIGHT", channelEditBox, "RIGHT", 30, 0)
    channelRightButton:SetScript("OnClick", function()
        self:changeChannel("next")
        channelEditBox:SetText(self.db.global.game.chatChannel)
    end)
    channelRightButton:Hide()

    houseCutEditBox = self:createEditBoxWidget(container, "House Cut", self.db.global.game.houseCut, "small")
    houseCutEditBox:SetScript("OnTextChanged", function() self:setHouseCut(houseCutEditBox:GetText()) end)
    houseCutEditBox:SetPoint("TOP", channelEditBox, "TOP", 0, -45)
    houseCutEditBox:SetNumeric(true)
    houseCutEditBox:SetMaxLetters(2)
    houseCutEditBox:Hide()
end

-- Implementation Functions --

function WoWGoldGambler:openOptionsTab()
    -- Expands the size of the main container and shows the options menu
    container:SetSize(550, 190)
    optionsButton:SetScript("OnClick", function() self:closeOptionsTab() end)
    container.optionsLabel:SetText("< Options")
    gameModeEditBox:Show()
    gameModeLeftButton:Show()
    gameModeRightButton:Show()
    channelEditBox:Show()
    channelLeftButton:Show()
    channelRightButton:Show()
    houseCutEditBox:Show()
end

function WoWGoldGambler:closeOptionsTab()
    -- Shrinks the size of the main container and hides the options menu
    container:SetSize(300, 190)
    optionsButton:SetScript("OnClick", function() self:openOptionsTab() end)
    container.optionsLabel:SetText("Options >")
    gameModeEditBox:Hide()
    gameModeLeftButton:Hide()
    gameModeRightButton:Hide()
    channelEditBox:Hide()
    channelLeftButton:Hide()
    channelRightButton:Hide()
    houseCutEditBox:Hide()
end

-- Custom Widgets --

function WoWGoldGambler:createFrameWidget(parent)
    -- Creates the base frame for the WGG UI. Includes a header with the name and version of the addon.
    local widget, title

    widget = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    widget:SetSize(300, 190)
    widget:SetPoint("TOP", parent, "TOP", 0, -15)
    widget:SetMovable(true)
    widget:EnableMouse(true)
    widget:SetUserPlaced(true)
    widget:RegisterForDrag("LeftButton")
    widget:SetScript("OnDragStart", widget.StartMoving)
    widget:SetScript("OnDragStop", widget.StopMovingOrSizing)
    widget:SetBackdrop(backdrop)
    widget:SetBackdropBorderColor(0, 0, 0, 0.8)
    widget:SetBackdropColor(26 / 255, 26 / 255, 26 / 255, 0.8)

    title = CreateFrame("Frame", nil, widget, BackdropTemplateMixin and "BackdropTemplate" or nil)
    title:SetSize(225, 30)
    title:SetPoint("TOP", widget, "TOP", 0, 10)
    title:SetBackdrop(backdrop)
    title:SetBackdropBorderColor(0, 0, 0)
    title:SetBackdropColor(0.1, 0.1, 0.1)

    widget.titleLabel = title:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    widget.titleLabel:SetPoint("TOP", title, "TOP", 0, -8)
    widget.titleLabel:SetTextColor(1, 229 / 255, 153 / 255)
    widget.titleLabel:SetJustifyH("CENTER")
    widget.titleLabel:SetText("WoWGoldGambler v1.0")

    optionsButton = CreateFrame("Button", nil, widget, BackdropTemplateMixin and "BackdropTemplate" or nil)
    optionsButton:SetSize(75, 20)
    optionsButton:SetPoint("BOTTOMRIGHT", widget, "BOTTOMRIGHT", -5, 10)
    optionsButton:SetBackdrop(backdrop)
    optionsButton:SetBackdropBorderColor(0, 0, 0, 0)
    optionsButton:SetBackdropColor(1, 0, 34 / 255, 0)
    optionsButton:SetScript("OnClick", function() self:openOptionsTab() end)

    widget.optionsLabel = widget:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    widget.optionsLabel:SetPoint("TOP", optionsButton, "TOP", 0, -8)
    widget.optionsLabel:SetTextColor(1, 229 / 255, 153 / 255)
    widget.optionsLabel:SetJustifyH("CENTER")
    widget.optionsLabel:SetText("Options >")

    return widget
end

function WoWGoldGambler:createEditBoxWidget(parent, labelText, text, size)
    -- Creates a textbox stylized for the WGG UI. There are two sizes available (small, large)
    local widget
    -- Button inherits from frame - so just make the same backdrop
    widget = CreateFrame("EditBox", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    widget:SetBackdrop(backdrop)
    widget:SetBackdropBorderColor(0, 0, 0)
    widget:SetBackdropColor(0.1, 0.1, 0.1)
    widget:SetText(text)
    widget:SetAutoFocus(false)
    widget:SetJustifyH("CENTER")

    widget.label = widget:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    widget.label:SetPoint("TOP", widget, "TOP", 0, 15)
    widget.label:SetTextColor(1, 229 / 255, 153 / 255)
    widget.label:SetJustifyH("CENTER")
    widget.label:SetText(labelText)

    if (size == "large") then
        widget:SetHeight(30)
	    widget:SetWidth(260)
        widget:SetFont("Fonts\\FRIZQT__.TTF", 16)
    elseif (size == "small") then
        widget:SetHeight(25)
	    widget:SetWidth(150)
        widget:SetFont("Fonts\\FRIZQT__.TTF", 14)
    end

    return widget
end

function WoWGoldGambler:createButtonWidget(parent, text, size)
    -- Creates a button stylized for the WGG UI. There are three sizes available (small, medium, large)
    local widget
    -- Button inherits from frame - so just make the same backdrop
    widget = CreateFrame("Button", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    widget:SetBackdrop(backdrop)
    widget:SetBackdropBorderColor(0, 0, 0, 0.8)
    widget:SetBackdropColor(1, 0, 34 / 255, 1)

    widget.label = widget:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    widget.label:SetPoint("TOP", widget, "TOP", 0, -6)
    widget.label:SetTextColor(1, 229 / 255, 153 / 255)
    widget.label:SetJustifyH("CENTER")
    widget.label:SetText(text)

    if (size == "large") then
        widget:SetHeight(25)
	    widget:SetWidth(125)
    elseif (size == "medium") then
        widget:SetHeight(25)
	    widget:SetWidth(95)
    elseif (size == "small") then
        widget:SetHeight(20)
	    widget:SetWidth(20)
        widget.label:SetPoint("TOP", widget, "TOP", 0, -4)
    end

    return widget
end

function WoWGoldGambler:createLineWidget(parent)
    local widget

    widget = CreateFrame("Frame", nil, parent)
    widget:SetSize(1, 150)

    widget.line = widget:CreateLine()
    widget.line:SetColorTexture(0.1, 0.1, 0.1, 1)
    widget.line:SetStartPoint("TOP", 0, 0)
    widget.line:SetEndPoint("BOTTOM", 0, 0)
    widget.line:SetThickness(2)

    return widget
end