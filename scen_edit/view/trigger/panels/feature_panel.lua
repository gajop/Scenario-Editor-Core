FeaturePanel = AbstractTypePanel:extends{}

function FeaturePanel:MakePredefinedOpt()
    --PREDEFINED
    local stackFeaturePanel = MakeComponentPanel(self.parent)
    self.cbPredefined = Checkbox:New {
        caption = "Predefined feature: ",
        right = 100 + 10,
        x = 1,
        checked = false,
        parent = stackFeaturePanel,
    }
    table.insert(self.radioGroup, self.cbPredefined)
    self.btnPredefined = Button:New {
        caption = '...',
        right = 40,
        width = 60,
        height = SB.conf.B_HEIGHT,
        parent = stackFeaturePanel,
        featureId = nil,
    }
    self.OnSelectObject = function(objectID)
        self.btnPredefined.featureId = objectID
        self.btnPredefined.caption = "Id=" .. objectID
        self.btnPredefined:Invalidate()
        if not self.cbPredefined.checked then
            self.cbPredefined:Toggle()
        end
    end
    self.btnPredefined.OnClick = {
        function()
            SB.stateManager:SetState(SelectFeatureState(self.OnSelectObject))
        end
    }
    self.btnPredefinedZoom = Button:New {
        caption = "",
        right = 1,
        width = SB.conf.B_HEIGHT,
        height = SB.conf.B_HEIGHT,
        parent = stackFeaturePanel,
        padding = {0, 0, 0, 0},
        children = {
            Image:New {
                tooltip = "Select feature",
                file=SB_IMG_DIR .. "search.png",
                height = SB.conf.B_HEIGHT,
                width = SB.conf.B_HEIGHT,
                padding = {0, 0, 0, 0},
                margin = {0, 0, 0, 0},
            },
        },
        OnClick = {
            function()
                if self.btnPredefined.featureId ~= nil then
                    local featureId = SB.model.featureManager:getSpringFeatureId(self.btnPredefined.featureId)
                    if featureId ~= nil and Spring.ValidFeatureID(featureId) then
                        local x, y, z = Spring.GetFeaturePosition(featureId)
                        SB.view.selectionManager:Select({
                            features = {featureId}
                        })
                        Spring.SetCameraTarget(x, y, z)
                    end
                end
            end
        }
    }
end

function FeaturePanel:UpdateModel(field)
    if self.cbPredefined and self.cbPredefined.checked and self.btnPredefined.featureId ~= nil then
        field.type = "pred"
        field.value = self.btnPredefined.featureId
        return true
    end
    return self:super('UpdateModel', field)
end

function FeaturePanel:UpdatePanel(field)
    if field.type == "pred" then
        if not self.cbPredefined.checked then
            self.cbPredefined:Toggle()
        end
        self.OnSelectFeature(field.value)
        return true
    end
    return self:super('UpdatePanel', field)
end
