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

-- Public Functions

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
    end
end

function WoWGoldGambler:drawUi()
    -- Create all UI elements. To be called when the addon is initialized
    container = self:createFrameWidget(UIParent)

    wagerEditBox = self:createEditBoxWidget(container, "Wager Amount", self.db.global.game.wager, "large")
    wagerEditBox:SetScript("OnTextChanged", function() self:setWager(wagerEditBox:GetText()) end)
    wagerEditBox:SetPoint("TOP", container, "TOP", 0, -40)

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

end

-- Implementation Functions

function WoWGoldGambler:createFrameWidget(parent)
    -- Creates the base frame for the WGG UI. Includes a header with the name and version of the addon.
    local widget, title

    widget = CreateFrame("Frame", "WGG_UI_Container", parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    widget:SetSize(300, 180)
    widget:SetPoint("CENTER", parent, "CENTER", 0, 0)
    widget:SetMovable(true)
    widget:EnableMouse(true)
    widget:SetUserPlaced(true)
    widget:RegisterForDrag("LeftButton")
    widget:SetScript("OnDragStart", widget.StartMoving)
    widget:SetScript("OnDragStop", widget.StopMovingOrSizing)
    widget:SetBackdrop(backdrop)
    widget:SetBackdropBorderColor(0, 0, 0, 0.8)
    widget:SetBackdropColor(26 / 255, 26 / 255, 26 / 255, 0.8)

    title = CreateFrame("Frame", "WGG_UI_ContainerTitle", widget, BackdropTemplateMixin and "BackdropTemplate" or nil)
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
    widget:SetFont("Fonts\\FRIZQT__.TTF", 16)
    widget:SetText(text)
    widget:SetAutoFocus(false)
    widget:SetNumeric(true)
    widget:SetJustifyH("CENTER")

    widget.label = widget:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    widget.label:SetPoint("TOP", widget, "TOP", 0, 15)
    widget.label:SetTextColor(1, 229 / 255, 153 / 255)
    widget.label:SetJustifyH("CENTER")
    widget.label:SetText(labelText)

    if (size == "large") then
        widget:SetHeight(30)
	    widget:SetWidth(260)
    elseif (size == "small") then
        widget:SetHeight(30)
	    widget:SetWidth(130)
    end

    return widget
end

function WoWGoldGambler:createButtonWidget(parent, text, size)
    -- Creates a button stylized for the WGG UI. There are three sizes available (small, medium, large)
    local widget, label
    -- Button inherits from frame - so just make the same backdrop
    widget = CreateFrame("Button", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    widget:SetBackdrop(backdrop)
    widget:SetBackdropBorderColor(0, 0, 0, 0.8)
    widget:SetBackdropColor(1, 0, 34 / 255, 1)

    label = widget:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOP", widget, "TOP", 0, -6)
    label:SetTextColor(1, 229 / 255, 153 / 255)
    label:SetJustifyH("CENTER")
    label:SetText(text)

    if (size == "large") then
        widget:SetHeight(25)
	    widget:SetWidth(125)
    elseif (size == "medium") then
        widget:SetHeight(25)
	    widget:SetWidth(75)
    elseif (size == "small") then
        widget:SetHeight(25)
	    widget:SetWidth(20)
    end

    return widget
end

function WoWGoldGambler:createLineWidget()
    local widget

    widget = CreateFrame("Frame")
    widget:SetPoint("CENTER", 0, 100)
    widget:SetSize(100,100)

    widget.line = widget:CreateLine()
    widget.line:SetColorTexture(1,0,0,1)
    widget.line:SetStartPoint("TOPLEFT",10,10)
    widget.line:SetEndPoint("BOTTOMRIGHT",10,10)
    widget:Show()

    return widget
end