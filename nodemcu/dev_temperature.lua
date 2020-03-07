if adc.force_init_mode(adc.INIT_ADC)
then
  node.restart()
  return
end

mqtt = mqtt.Client("silvia", 60)

-- Steinhart-Hart coefficients for NTC 10k/1%
A = 1.129148e-3
B = 2.34125e-4
C = 8.76741e-8

R_FIXED = 1000
VCC = 3.3
-- The ADC is not very linear, but we are only interested
-- in a narrow temperature range, so we punch in the 
-- value here that will make things work for our range
RES = 1119 -- Observed value, should be 1023

-- Shameless copied from https://www.electronicwings.com/nodemcu/thermistor-interfacing-with-nodemcu
function ln(x)      --natural logarithm function for x>0 real values
    local y = (x-1)/(x+1)
    local sum = 1 
    local val = 1
    if(x == nil) then
        return 0
    end
    -- we are using limited iterations to acquire reliable accuracy.
    -- here its upto 10000 and increased by 2
    for i = 3, 10000, 2 do
        val = val*(y*y)
        sum = sum + (val/i)
    end
    return 2*y*sum
end

function mv_to_c(adc_value)
  dv_r = adc_value * VCC / RES
  print("adc_value: ", adc_value)
  print("dv_r: ", dv_r)
  -- Sue me. I'm bad at electronics
  i = dv_r / R_FIXED
  print("i: ", i)
  r_ntc = (VCC - dv_r) / i
  print("r_ntc:", r_ntc)
  temp_k =  (1 / (A + (B * ln(r_ntc)) + (C * (ln(r_ntc))^3)))
  return temp_k - 273.15
end

mqtt:connect("192.168.1.168", 1883, 0, function(client)
  looper = tmr.create()
  looper:register(3000, tmr.ALARM_AUTO, function()
    temp = mv_to_c(adc.read(0))
    print(string.format("Temp: %0.3g °C", temp))
    client:publish("/dtv/silvia/temperature", temp, 0, 0)
  end)
  looper:start()
end) 