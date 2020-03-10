.PHONY: all clean serve compile

all: compile

compile:
	mix do deps.get, compile
	cd apps/factotum_web/assets; npm install

clean:
	git -dfx

serve:
	cd apps/factotum_web; iex -S mix phx.server
