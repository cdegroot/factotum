-- D2 is a GPIO port not used for anything else
HEATER_PIN = 2

gpio.mode(HEATER_PIN, gpio.OUTPUT)
gpio.write(HEATER_PIN, gpio.LOW)

mqtt = mqtt.Client("silvia", 60)

mqtt:on("message", function(client, topic, data)
  print(topic .. ": " .. data)
  if data == "on" then
    gpio.write(HEATER_PIN, gpio.HIGH)
  elseif data == "off" then
    gpio.write(HEATER_PIN, gpio.LOW)
  else
    print("Unknown message, ignored")
  end
end)

mqtt:connect("192.168.1.168", 1883, false, function(client)
  client:subscribe("/dtv/silvia/heater", 0)
end)