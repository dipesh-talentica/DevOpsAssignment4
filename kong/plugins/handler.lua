local CustomHeaderHandler = {
  PRIORITY = 1000,
  VERSION = "1.0.0",
}

function CustomHeaderHandler:header_filter(conf)
  kong.response.set_header(conf.header_name, conf.header_value)
end

return CustomHeaderHandler