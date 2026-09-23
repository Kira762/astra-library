local services = {}

function services.getService(serviceName)
    local service = game:GetService(serviceName)
    return if cloneref then cloneref(service) else service
end

return services
