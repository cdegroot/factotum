# Factotum

Home automation stuff. MQTT, LiveView, and NodeMCU based IoT devices.

NodeMCU is an ESP8266 board; the ESP8266 in turn is an IoT microcontroller that has WiFi on board
and is powerful enough to run a TCP/IP stack, an MQTT client, and Lua code.

This project attempts to extend the ideas of Phoenix LiveView by introducing the concepts of
IoTlets - Elixir modules that have a UI (in LiveView) and contain the code (through transpiling
macros) that runs on the board. The basic idea is that you select an IoTlet, plug in a board,
burn the generated Lua code on it and then also get the UI added to your dashboard.

To minimize configuration, the devices only need to be pre-seeded with WiFi credentials. The MQTT
broker is discovered using mDNS (TODO. mDNS for NodeMCU: https://github.com/udaygin/nodemcu-mdns-client,
mDNS for Elixir: https://github.com/rosetta-home/mdns).

Initial targets, purely because I want:
* Furnace fan control (we have one of these expensive filters and often run the fan for days when
  we get visitors with asthma or allergies to clean the air in the home);
* Espresso machine temperature control (Rancilio Silvia)
* Outdoor weather station (probably fed by but not needing PoE)

# List

* [ ] Main control app
* [ ] LiveView app
* [x] Start MQTT
* [x] Lua MQTT client
* [-] Lua Coffee Control
* [ ] LiveView Coffee Control
* [ ] Lua Fan Control
* [ ] LiveView Fan Control
* [ ] Applets - Lua + Elixir combos that can get pushed to a certain device.
