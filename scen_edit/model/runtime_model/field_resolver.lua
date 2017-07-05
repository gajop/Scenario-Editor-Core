FieldResolver = LCS.class{}

function FieldResolver:init()
end

function FieldResolver:CallExpression(expr, exprType, params, canExecuteUnsynced)
    local resolvedInputs = {}
    local fail = false
    for _, input in pairs(exprType.input) do
        local resolvedInput = self:Resolve(expr[input.name], input.type, input.rawVariable, params)
        if not input.allowNil then
            fail = fail or SB.resolveAssert(resolvedInput, input, expr)
        end
        resolvedInputs[input.name] = resolvedInput
    end
    if fail then
        return
    end

    if exprType.execute == nil and (exprType.executeUnsynced and canExecuteUnsynced) then
        SB.rtModel:ExecuteUnsynced(exprType.name, resolvedInputs)
        return
    end
    if not exprType.execute then
        Log.Error("There is no function \"execute\" for expression: " .. exprType.name)
    else
        local result = exprType.execute(resolvedInputs)
        if exprType.doRepeat and result then
            table.insert(SB.rtModel.repeatCalls, {exprType = exprType, resolvedInputs = resolvedInputs})
        end
        return result
    end
end

function FieldResolver:Resolve(field, type, rawVariable, params)
    if field.type == "expr" then
        local expr = field.expr
        local typeName = expr.typeName
        local exprType = SB.metaModel.functionTypes[typeName]
        return self:CallExpression(expr, exprType, params)
    elseif field.type == "var" then
        local variable = SB.model.variableManager:getVariable(field.value)
        if not rawVariable then
            return self:Resolve(variable.value, variable.type, nil, params)
        else
            return variable
        end
    elseif field.type == "spec" then
        local value = {
            type = "pred",
            value = params[field.name],
        }
        return self:Resolve(value, type, nil, params)
    end

    if field.type ~= "pred" then
        Log.Error("Unexpected field type: " .. tostring(field.type) ..
            " for field name: " .. tostring(field.name))
        table.echo(field)
        return
    end

    if type == "unit" then
        local unitID = tonumber(field.value)
        if unitID ~= nil then
            local springID = SB.model.unitManager:getSpringUnitID(unitID)
            if Spring.ValidUnitID(springID) then
                return springID
            end
        end
    elseif type == "unitType" then
        return tonumber(field.value)
    elseif type == "feature" then
        local featureID = tonumber(field.value)
        if featureID ~= nil then
            local springID = SB.model.featureManager:getSpringfeatureID(featureID)
            if Spring.ValidFeatureID(springID) then
                return springID
            end
        end
    elseif type == "featureType" then
        return tonumber(field.value)
    elseif type == "team" then
        return SB.model.teamManager:getTeam(field.value).id
    elseif type == "area" then
        return SB.model.areaManager:getArea(tonumber(field.value))
    elseif type == "trigger" then
        return SB.model.triggerManager:getTrigger(tonumber(field.value))
    elseif type == "order" then
        -- FIXME: maybe we should be saving orders directly as well
        field = field.value
        local orderType = SB.metaModel.orderTypes[field.typeName]
        local order = {
            typeName = field.typeName,
            input = {}
        }
        for i = 1, #orderType.input do
            local input = orderType.input[i]
            local resolvedInput = self:Resolve(field[input.name], input.type, nil, params)
            order.input[input.name] = resolvedInput
        end
        return order
    elseif type == "string" then
        return field.value
    elseif type == "number" then
        return field.value
    elseif type == "bool" then
        return field.value
    elseif type == "position" then
        return field.value
    elseif type == "numericComparison" then
        return SB.metaModel.numericComparisonTypes[field.value]
    elseif type == "identityComparison" then
        return SB.metaModel.identityComparisonTypes[field.value]
    elseif type:find("_array") then
        local atomicType = type:sub(1, type:find("_array") - 1)
        local values = {}
        for _, element in pairs(field.value) do
            local value = self:Resolve(element, atomicType, nil, params)
            table.insert(values, value)
        end
        return values
    elseif type == "action" then
        local expr = field.value
        local typeName = expr.typeName
        local exprType = SB.metaModel.actionTypes[typeName]
        return function(functionParams)
            local fParams = params
            if functionParams then
                fParams = SB.deepcopy(params)
                for k, v in pairs(functionParams) do
                    fParams[k] = v
                end
            end
            self:CallExpression(expr, exprType, fParams)
        end
    elseif type == "function" then
        local expr = field.value
        local typeName = expr.typeName
        local exprType = SB.metaModel.functionTypes[typeName]
        return function(functionParams)
            local fParams = params
            if functionParams then
                fParams = SB.deepcopy(params)
                for k, v in pairs(functionParams) do
                    fParams[k] = v
                end
            end
            return self:CallExpression(expr, exprType, fParams)
        end
    elseif type ~= nil then
        local value = field.value
        local dataType = SB.metaModel:GetCustomDataType(value.typeName)
        if dataType then
            local retVal = {}
            for _, input in pairs(dataType.input) do
                local name = input.name
                retVal[name] = self:Resolve(value[name], input.type,
                                            false, params)
            end
            return retVal
        end
    end
end
